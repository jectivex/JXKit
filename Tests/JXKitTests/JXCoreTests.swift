import JXKit
import XCTest

@available(macOS 11, iOS 13, tvOS 13, *)
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
        let context = JXContext()
        let myFunction = JXValue(newFunctionIn: context) { context, this, arguments in
            let result = try arguments[0].numberValue + arguments[1].numberValue
            return JXValue(double: result, in: context)
        }

        XCTAssertTrue(myFunction.isFunction)

        let result = try myFunction.call(withArguments: [JXValue(double: 1, in: context), JXValue(double: 2, in: context)])

        XCTAssertTrue(result.isNumber)
        XCTAssertEqual(try result.numberValue, 3)
    }

    func testFunction2() throws {
        let context = JXContext()
        let myFunction = JXValue(newFunctionIn: context) { context, this, arguments in
            let result = try arguments[0].numberValue + arguments[1].numberValue
            return JXValue(double: result, in: context)
        }

        XCTAssertTrue(myFunction.isFunction)
        try context.global.setProperty("myFunction", myFunction)

        let result = try context.eval("myFunction(1, 2)")

        XCTAssertTrue(result.isNumber)
        XCTAssertEqual(try result.numberValue, 3)
    }

    func testCalculation() throws {
        let context = JXContext()

        let result = try context.eval("1 + 1")

        XCTAssertTrue(result.isNumber)
        XCTAssertEqual(try result.numberValue, 2)
    }

    func testArray() throws {
        let context = JXContext()

        let result = try context.eval("[1 + 2, \"BMW\", \"Volvo\"]")

        XCTAssertTrue(try result.isArray)

        let length = try result["length"]
        XCTAssertEqual(try length.numberValue, 3)

        XCTAssertEqual(try result[0].numberValue, 3)
        XCTAssertEqual(try result[1].stringValue, "BMW")
        XCTAssertEqual(try result[2].stringValue, "Volvo")
    }

    func testGetter() throws {
        let context = JXContext()

        XCTAssertTrue(context.global.isObject)
        try context.global.setProperty("obj", JXValue(newObjectIn: context))
        XCTAssertTrue(try context.global["obj"].isObject)

        let desc = JXProperty { this in
            JXValue(double: 3, in: context)
        }

        try context.global["obj"].defineProperty("three", desc)

        let result = try context.eval("obj.three")

        XCTAssertEqual(try result.numberValue, 3)
    }

    func testSetter() throws {
        let context = JXContext()

        try context.global.setProperty("obj", JXValue(newObjectIn: context))

        let desc = JXProperty(
            getter: { this in try this["number_container"] },
            setter: { this, newValue in try this.setProperty("number_container", newValue) }
        )

        try context.global["obj"].defineProperty("number", desc)

        try context.eval("obj.number = 5")

        XCTAssertEqual(try context.global["obj"]["number"].numberValue, 5)
        XCTAssertEqual(try context.global["obj"]["number_container"].numberValue, 5)

        try context.eval("obj.number = 3")

        XCTAssertEqual(try context.global["obj"]["number"].numberValue, 3)
        XCTAssertEqual(try context.global["obj"]["number_container"].numberValue, 3)
    }

    func testArrayBuffer() throws {
        let context = JXContext()
        
        let bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        try context.global.setProperty("buffer", JXValue(newArrayBufferWithBytes: bytes, in: context))

        XCTAssertTrue(try context.global["buffer"].isArrayBuffer)
        XCTAssertEqual(try context.global["buffer"].byteLength, 8)

        let bufferSize = 999_999
        //let bufferData = Data((1...bufferSize).map({ _ in UInt8.random(in: (.min)...(.max)) }))
        let bufferData = Data(repeating: UInt8.random(in: (.min)...(.max)), count: bufferSize)

        measure { // 1M average: 0.001; 10M average: 0.002; 100M average: average: 0.030
            guard let arrayBuffer = try? JXValue(newArrayBufferWithBytes: bufferData, in: context) else {
                return XCTFail("failed")
            }
            guard let isView = try? context.global["ArrayBuffer"]["isView"].call(withArguments: [arrayBuffer]) else {
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
            let context = JXContext()
            var bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]

            try bytes.withUnsafeMutableBytes { bytes in
                try context.global.setProperty("buffer", JXValue(newArrayBufferWithBytesNoCopy: bytes, deallocator: { _ in flag = 1 }, in: context))

                XCTAssertTrue(try context.global["buffer"].isArrayBuffer)
                XCTAssertEqual(try context.global["buffer"].byteLength, 8)
            }
        }

        XCTAssertEqual(flag, 1)
    }

    func testArrayBufferClosure() throws {
        // this should always measure around zero regardless of the size of the buffer that is passed, since we guarantee that no copy will be made
        let size = 1_000_000
        // let size = 1_000_000_000

        let data = Data(repeating: 9, count: size)
        let context = JXContext()

        XCTAssertEqual(true, try context["ArrayBuffer"].isObject)

        measure { // average: 0.000, relative standard deviation: 99.521%, values: [0.000434, 0.000037, 0.000959, 0.000050, 0.000471, 0.000048, 0.000394, 0.000048, 0.000389, 0.000047]
            let result: Double? = try? context.withArrayBuffer(source: data) { buffer in
                XCTAssertEqual(true, try buffer["byteLength"].booleanValue)
                XCTAssertEqual(true, try buffer["slice"].isFunction)
                return try buffer["byteLength"].numberValue
            }
            XCTAssertEqual(Double?.some(.init(size)), result)
        }
    }

    func testDataView() throws {
        let context = JXContext()
        
        let bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        try context.global.setProperty("buffer", JXValue(newArrayBufferWithBytes: bytes, in: context))
        
        try context.eval("new DataView(buffer).setUint8(0, 5)")
        
        XCTAssertEqual(try context["buffer"].copyBytes().map(Array.init), [5, 2, 3, 4, 5, 6, 7, 8])
    }
    
    func testSlice() throws {
        let context = JXContext()
        
        let bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        try context.global.setProperty("buffer", JXValue(newArrayBufferWithBytes: bytes, in: context))

        XCTAssertEqual(try context.eval("buffer.slice(2, 4)").copyBytes().map(Array.init), [3, 4])
    }
    
    func testFunctionConstructor() throws {
        let context = JXContext()

        let myClass = JXValue(newFunctionIn: context) { context, this, arguments in
            let result = try arguments[0].numberValue + arguments[1].numberValue
            let object = JXValue(newObjectIn: context)
            try object.setProperty("result", JXValue(double: result, in: context))

            return object
        }

        XCTAssertTrue(myClass.isConstructor)

        try context.global.setProperty("myClass", myClass)

        let result = try context.eval("new myClass(1, 2)")

        XCTAssertTrue(result.isObject)
        XCTAssertEqual(try result["result"].numberValue, 3)

        XCTAssertTrue(try result.isInstance(of: myClass))
    }

    func testPromises() throws {
        let jsc = JXContext()

        do {
            try jsc.setProperty("setTimeout", JXValue(newFunctionIn: jsc) { jsc, this, args in
                print("setTimeout", try args.map({ try $0.stringValue }))
                return jsc.number(0)
            })

            let result = try jsc.eval("""
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
                XCTAssertEqual([1.0, 2.0, 3.0], try jsc["arr"].array.map({ try $0.numberValue }))
            } else {
                XCTAssertEqual(3, try result.numberValue)
                XCTAssertEqual([1.0, 3.0, 2.0], try jsc["arr"].array.map({ try $0.numberValue }))
            }
        }

        do {
            let str = UUID().uuidString
            let resolvedPromise = try JXValue(newPromiseResolvedWithResult: jsc.string(str), in: jsc)
            try jsc.setProperty("prm", resolvedPromise)
            let _ = try jsc.eval("(async () => { this['cb'] = await prm; })();")
            XCTAssertEqual(str, try jsc["cb"].stringValue)
        }
    }
}
