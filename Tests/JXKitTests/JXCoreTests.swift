import JXKit
import XCTest

class JXCoreTests: XCTestCase {

    func testHobbled() {
#if arch(x86_64)
        XCTAssertEqual(false, JXVM.isHobbled, "JIT permitted")
#elseif arch(arm64)
        XCTAssertEqual(true, JXVM.isHobbled, "JIT blocked by platform")
#else
        XCTFail("unexpected architecture")
#endif
    }

    func testFunction1() throws {
        let jxc = JXContext()
        let myFunction = JXValue(newFunctionIn: jxc) { jxc, this, arguments in
            jxc.number(try arguments[0].numberValue + arguments[1].numberValue)
        }

        XCTAssertTrue(myFunction.isFunction)

        let result = try myFunction.call(withArguments: [jxc.number(1), jxc.number(2)])

        XCTAssertTrue(result.isNumber)
        XCTAssertEqual(try result.numberValue, 3)
    }

    func testFunction2() throws {
        let jxc = JXContext()
        let myFunction = JXValue(newFunctionIn: jxc) { jxc, this, arguments in
            jxc.number(try arguments[0].numberValue + arguments[1].numberValue)
        }

        XCTAssertTrue(myFunction.isFunction)
        try jxc.global.setProperty("myFunction", myFunction)

        let result = try jxc.eval("myFunction(1, 2)")

        XCTAssertTrue(result.isNumber)
        XCTAssertEqual(try result.numberValue, 3)
    }

    func testCalculation() throws {
        let jxc = JXContext()

        let result = try jxc.eval("1 + 1")

        XCTAssertTrue(result.isNumber)
        XCTAssertEqual(try result.numberValue, 2)
    }

    func testArray() throws {
        let jxc = JXContext()

        let result = try jxc.eval("[1 + 2, \"BMW\", \"Volvo\"]")

        XCTAssertTrue(try result.isArray)

        let length = try result["length"]
        XCTAssertEqual(try length.numberValue, 3)

        XCTAssertEqual(try result[0].numberValue, 3)
        XCTAssertEqual(try result[1].stringValue, "BMW")
        XCTAssertEqual(try result[2].stringValue, "Volvo")
    }

    func testGetter() throws {
        let jxc = JXContext()

        XCTAssertTrue(jxc.global.isObject)
        try jxc.global.setProperty("obj", jxc.object())
        XCTAssertTrue(try jxc.global["obj"].isObject)

        let desc = JXProperty { _ in jxc.number(3) }

        try jxc.global["obj"].defineProperty("three", desc)
        let result = try jxc.eval("obj.three")
        XCTAssertEqual(try result.numberValue, 3)
    }

    func testSetter() throws {
        let jxc = JXContext()

        try jxc.global.setProperty("obj", jxc.object())

        let desc = JXProperty(
            getter: { this in try this["number_container"] },
            setter: { this, newValue in try this.setProperty("number_container", newValue) }
        )

        try jxc.global["obj"].defineProperty("number", desc)

        try jxc.eval("obj.number = 5")

        XCTAssertEqual(try jxc.global["obj"]["number"].numberValue, 5)
        XCTAssertEqual(try jxc.global["obj"]["number_container"].numberValue, 5)

        try jxc.eval("obj.number = 3")

        XCTAssertEqual(try jxc.global["obj"]["number"].numberValue, 3)
        XCTAssertEqual(try jxc.global["obj"]["number_container"].numberValue, 3)
    }

    func testArrayBuffer() throws {
        let jxc = JXContext()
        
        let bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        try jxc.global.setProperty("buffer", JXValue(newArrayBufferWithBytes: bytes, in: jxc))

        XCTAssertTrue(try jxc.global["buffer"].isArrayBuffer)
        XCTAssertEqual(try jxc.global["buffer"].byteLength, 8)

        let bufferSize = 999_999
        //let bufferData = Data((1...bufferSize).map({ _ in UInt8.random(in: (.min)...(.max)) }))
        let bufferData = Data(repeating: UInt8.random(in: (.min)...(.max)), count: bufferSize)

        measure { // 1M average: 0.001; 10M average: 0.002; 100M average: average: 0.030
            guard let arrayBuffer = try? JXValue(newArrayBufferWithBytes: bufferData, in: jxc) else {
                return XCTFail("failed")
            }
            guard let isView = try? jxc.global["ArrayBuffer"]["isView"].call(withArguments: [arrayBuffer]) else {
                return XCTFail("failed")
            }
            XCTAssertEqual(true, isView.isBoolean)
            XCTAssertEqual(false, isView.booleanValue)

            XCTAssertEqual(.init(bufferSize), try? arrayBuffer["byteLength"].numberValue)
        }
    }
    
    func testArrayBufferWithBytesNoCopy() throws {
        var flag = 0

        do {
            let jxc = JXContext()
            var bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]

            try bytes.withUnsafeMutableBytes { bytes in
                try jxc.global.setProperty("buffer", JXValue(newArrayBufferWithBytesNoCopy: bytes, deallocator: { _ in flag = 1 }, in: jxc))

                XCTAssertTrue(try jxc.global["buffer"].isArrayBuffer)
                XCTAssertEqual(try jxc.global["buffer"].byteLength, 8)
            }
        }

        XCTAssertEqual(flag, 1, "context was not deallocated")
    }

    func testArrayBufferClosure() throws {
        // this should always measure around zero regardless of the size of the buffer that is passed, since we guarantee that no copy will be made
        let size = 1_000_000
        // let size = 1_000_000_000

        let data = Data(repeating: 9, count: size)
        let jxc = JXContext()

        XCTAssertEqual(true, try jxc.global["ArrayBuffer"].isObject)

        measure { // average: 0.000, relative standard deviation: 99.521%, values: [0.000434, 0.000037, 0.000959, 0.000050, 0.000471, 0.000048, 0.000394, 0.000048, 0.000389, 0.000047]
            let result: Double? = try? jxc.withArrayBuffer(source: data) { buffer in
                XCTAssertEqual(true, try buffer["byteLength"].booleanValue)
                XCTAssertEqual(true, try buffer["slice"].isFunction)
                return try buffer["byteLength"].numberValue
            }
            XCTAssertEqual(Double?.some(.init(size)), result)
        }
    }

    func testDataView() throws {
        let jxc = JXContext()
        
        let bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        try jxc.global.setProperty("buffer", JXValue(newArrayBufferWithBytes: bytes, in: jxc))
        
        try jxc.eval("new DataView(buffer).setUint8(0, 5)")
        
        XCTAssertEqual(try jxc.global["buffer"].copyBytes().map(Array.init), [5, 2, 3, 4, 5, 6, 7, 8])
    }
    
    func testSlice() throws {
        let jxc = JXContext()
        
        let bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        try jxc.global.setProperty("buffer", JXValue(newArrayBufferWithBytes: bytes, in: jxc))

        XCTAssertEqual(try jxc.eval("buffer.slice(2, 4)").copyBytes().map(Array.init), [3, 4])
    }
    
    func testFunctionConstructor() throws {
        let jxc = JXContext()

        let myClass = JXValue(newFunctionIn: jxc) { jxc, this, arguments in
            let result = try arguments[0].numberValue + arguments[1].numberValue
            let object = jxc.object()
            try object.setProperty("result", jxc.number(result))

            return object
        }

        XCTAssertTrue(myClass.isConstructor)

        try jxc.global.setProperty("myClass", myClass)

        let result = try jxc.eval("new myClass(1, 2)")

        XCTAssertTrue(result.isObject)
        XCTAssertEqual(try result["result"].numberValue, 3)

        XCTAssertTrue(try result.isInstance(of: myClass))
    }

    func testPromises() throws {
        let jxc = JXContext()

        do {
            try jxc.global.setProperty("setTimeout", JXValue(newFunctionIn: jxc) { jxc, this, args in
                print("setTimeout", try args.map({ try $0.stringValue }))
                return jxc.number(0)
            })

            let result = try jxc.eval("""
                var arr = [];
                (async () => {
                  await 1;
                  arr.push(3);
                })();
                arr.push(1);
                setTimeout(() => {});
                arr.push(2);
                """)

            XCTAssertGreaterThan(try result.numberValue, 0)

            // this appears to be fixed in macOS 13 and iOS 15
            // Bug 161942: Shouldn't drain the micro task queue when calling out
            // https://developer.apple.com/forums/thread/678277

            if #available(macOS 13, iOS 15, tvOS 15, *) {
                XCTAssertEqual(2, try result.numberValue)
                XCTAssertEqual([1.0, 2.0, 3.0], try jxc.global["arr"].array.map({ try $0.numberValue }))
            } else {
                XCTAssertEqual(3, try result.numberValue)
                XCTAssertEqual([1.0, 3.0, 2.0], try jxc.global["arr"].array.map({ try $0.numberValue }))
            }
        }

        do {
            let str = UUID().uuidString
            let resolvedPromise = try JXValue(newPromiseResolvedWithResult: jxc.string(str), in: jxc)
            try jxc.global.setProperty("prm", resolvedPromise)
            let _ = try jxc.eval("(async () => { this['cb'] = await prm; })();")
            XCTAssertEqual(str, try jxc.global["cb"].stringValue)
        }
    }

    func testTypes() throws {
        let jxc = JXContext()

        XCTAssertEqual(true, try jxc.eval("new Object()").isObject)
        XCTAssertEqual(true, try jxc.eval("new Date()").isDate)
        XCTAssertEqual(true, try jxc.eval("new Array()").isArray)
        XCTAssertEqual(true, try jxc.eval("new ArrayBuffer()").isArrayBuffer)
        XCTAssertEqual(true, try jxc.eval("(async () => { })").isFunction)
        XCTAssertEqual(true, try jxc.eval("(async () => { })()").isPromise)

        XCTAssertEqual(true, jxc.string("").isString)
        XCTAssertEqual(true, jxc.number(1.1).isNumber)
        XCTAssertEqual(true, jxc.null().isNull)
        XCTAssertEqual(true, try jxc.array([]).isArray)

       try jxc.withArrayBuffer(source: Data([1,2,3]), block: { val in
           XCTAssertEqual(true, try val.isArrayBuffer)
       })

//        XCTAssertEqual(true, try JXValue(newErrorFromMessage: "", in: jxc).isError)

    }

    func testCheck() throws {
        func lint(_ script: String, strict: Bool = false) throws -> String? {
            do {
                let jxc = JXContext(strict: strict)
                try jxc.eval(script)
                return nil
            } catch let error as JXError {
                return try error.stringValue
            } catch {
                XCTFail("unexpected error type: \(error)")
                return nil
            }
        }

        XCTAssertEqual(try lint("1"), nil)
        XCTAssertEqual(try lint("1.1"), nil)
        XCTAssertEqual(try lint("Math.PI.x"), nil)

        XCTAssertEqual(try lint("Math.PIE.x"), "TypeError: undefined is not an object (evaluating \'Math.PIE.x\')")
        XCTAssertEqual(try lint("1X"), "SyntaxError: No identifiers allowed directly after numeric literal")
        XCTAssertEqual(try lint("1["), "SyntaxError: Unexpected end of script")
        XCTAssertEqual(try lint("1]"), "SyntaxError: Unexpected token \']\'. Parse error.")

        // strict checks

        XCTAssertEqual(try lint("use strict"), "SyntaxError: Unexpected identifier \'strict\'") // need to quote
        XCTAssertEqual(try lint("'use strict'\nmistypeVarible = 17"), "ReferenceError: Can\'t find variable: mistypeVarible")
    }
}
