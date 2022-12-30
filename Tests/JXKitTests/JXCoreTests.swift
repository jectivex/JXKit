import JXKit
import XCTest

class JXCoreTests: XCTestCase {
    func testModuleVersion() throws {
        XCTAssertEqual("org.jectivex.JXKit", JXKitBundleIdentifier)
        XCTAssertLessThanOrEqual(3_000_000, JXKitVersionNumber, "should have been version 3.0.0 or higher")
    }

    func testJavaScriptCoreVersion() {
#if canImport(MachO)
        XCTAssertLessThanOrEqual(40174087, JavaScriptCoreVersion) // macOS 12
        // XCTAssertLessThanOrEqual(40239623, JavaScriptCoreVersion) // macOS 13
#endif
    }

    func testHobbled() {
#if arch(x86_64)
        XCTAssertEqual(false, JXVM.isHobbled, "JIT permitted")
#elseif arch(arm64)
        XCTAssertEqual(true, JXVM.isHobbled, "JIT blocked by platform")
#else
        XCTFail("unexpected architecture")
#endif
    }
    
    func testProperties() throws {
        let jxc = JXContext()
        let prop = "prop"
        XCTAssertFalse(jxc.global.hasProperty(prop))
        XCTAssertTrue(try jxc.global[prop].isUndefined)
        XCTAssertFalse(try jxc.global.deleteProperty(prop))
        
        XCTAssertFalse(try jxc.global.setProperty(prop, jxc.object()).isUndefined)
        XCTAssertTrue(jxc.global.hasProperty(prop))
        XCTAssertFalse(try jxc.global[prop].isUndefined)
        XCTAssertTrue(try jxc.global.deleteProperty(prop))
    }

    func testFunction1() throws {
        let jxc = JXContext()
        let myFunction = JXValue(newFunctionIn: jxc) { jxc, this, arguments in
            jxc.number(try arguments[0].int + arguments[1].int)
        }

        XCTAssertTrue(myFunction.isFunction)

        let result = try myFunction.call(withArguments: [jxc.number(1), jxc.number(2)])

        XCTAssertTrue(result.isNumber)
        XCTAssertEqual(try result.int, 3)
    }

    func testFunction2() throws {
        let jxc = JXContext()
        let myFunction = JXValue(newFunctionIn: jxc) { jxc, this, arguments in
            jxc.number(try arguments[0].int + arguments[1].int)
        }

        XCTAssertTrue(myFunction.isFunction)
        try jxc.global.setProperty("myFunction", myFunction)

        let result = try jxc.eval("myFunction(1, 2)")

        XCTAssertTrue(result.isNumber)
        XCTAssertEqual(try result.int, 3)
    }

    func testFunctionError() throws {
        let jxc = JXContext()

        enum CustomError: Error {
            case someError
        }

        let myFunction = JXValue(newFunctionIn: jxc) { jxc, this, arguments in
            throw CustomError.someError
        }

        XCTAssertTrue(myFunction.isFunction)
        try jxc.global.setProperty("myFunction", myFunction)

        do {
            _ = try jxc.eval("myFunction()")
            XCTFail("should have thrown an error")
        } catch {
            XCTAssertFalse(error is CustomError)
            XCTAssertTrue(error is JXError)
            XCTAssertTrue((error as? JXError)?.cause is CustomError)
        }
    }


    func testCalculation() throws {
        let jxc = JXContext()

        let result = try jxc.eval("1 + 1")

        XCTAssertTrue(result.isNumber)
        XCTAssertEqual(try result.int, 2)
    }

    func testArray() throws {
        let jxc = JXContext()

        let result = try jxc.eval("[1 + 2, \"BMW\", \"Volvo\"]")

        XCTAssertTrue(result.isArray)

        let length = try result["length"]
        XCTAssertEqual(try length.int, 3)

        XCTAssertEqual(try result[0].int, 3)
        XCTAssertEqual(try result[1].string, "BMW")
        XCTAssertEqual(try result[2].string, "Volvo")
    }

    func testGetter() throws {
        let jxc = JXContext()

        XCTAssertTrue(jxc.global.isObject)
        try jxc.global.setProperty("obj", jxc.object())
        XCTAssertTrue(try jxc.global["obj"].isObject)

        let desc = JXProperty { _ in jxc.number(3) }

        try jxc.global["obj"].defineProperty(jxc.string("three"), desc)
        let result = try jxc.eval("obj.three")
        XCTAssertEqual(try result.int, 3)
    }

    func testSetter() throws {
        let jxc = JXContext()

        try jxc.global.setProperty("obj", jxc.object())

        let desc = JXProperty(
            getter: { this in try this["number_container"] },
            setter: { this, newValue in try this.setProperty("number_container", newValue) }
        )

        try jxc.global["obj"].defineProperty(jxc.string("number"), desc)

        try jxc.eval("obj.number = 5")

        XCTAssertEqual(try jxc.global["obj"]["number"].int, 5)
        XCTAssertEqual(try jxc.global["obj"]["number_container"].int, 5)

        try jxc.eval("obj.number = 3")

        XCTAssertEqual(try jxc.global["obj"]["number"].int, 3)
        XCTAssertEqual(try jxc.global["obj"]["number_container"].int, 3)
    }

    func testSymbols() throws {
        let jxc = JXContext()

        let obj = jxc.symbol("obj") // The unique symbol for the object

        XCTAssertEqual(true, try jxc.global[symbol: obj].isUndefined)
        try jxc.global.setProperty(symbol: obj, jxc.object())
        XCTAssertEqual(true, try jxc.global[symbol: obj].isObject)

        XCTAssertEqual(true, try jxc.global["obj"].isUndefined, "should not be able to reference symbol by name externally")
//        XCTAssertEqual(true, try jxc.eval("this['obj']").isObject, "should be able to reference symbol by name internally")

        let container = jxc.symbol("container")

        let gobj = try jxc.global[symbol: obj]
        try gobj.setProperty(symbol: container, jxc.number(0))

        let desc = JXProperty(
            getter: { this in try this[symbol: container] },
            setter: { this, newValue in try this.setProperty(symbol: container, newValue) }
        )

        try gobj.defineProperty(jxc.symbol("number"), desc)

        XCTAssertEqual(false, try jxc.global["object_symbol"].isSymbol)
        try jxc.global.setProperty("object_symbol", obj)
        XCTAssertEqual(true, try jxc.global["object_symbol"].isSymbol)

        try jxc.eval("this[object_symbol].number = 5")

        XCTAssertEqual(try gobj["number"].int, 5)

        try jxc.eval("this[object_symbol].number = 3")

        XCTAssertEqual(try jxc.global[symbol: obj]["number"].int, 3)
        //XCTAssertEqual(try jxc.global[symbol: obj][symbol: container].int, 3)
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
            XCTAssertEqual(false, isView.bool)

            XCTAssertEqual(.init(bufferSize), try? arrayBuffer["byteLength"].int)
        }
    }
    
    func testArrayBufferWithBytesNoCopy() throws {
        var flag = 0

        do {
            let vm = JXVM()
            let jxc = JXContext(vm: vm)
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
                XCTAssertEqual(true, try buffer["byteLength"].bool)
                XCTAssertEqual(true, try buffer["slice"].isFunction)
                return try buffer["byteLength"].double
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
            let result = try arguments[0].int + arguments[1].int
            let object = jxc.object()
            try object.setProperty("result", jxc.number(result))

            return object
        }

        XCTAssertTrue(myClass.isConstructor)

        try jxc.global.setProperty("myClass", myClass)

        let result = try jxc.eval("new myClass(1, 2)")

        XCTAssertTrue(result.isObject)
        XCTAssertEqual(try result["result"].int, 3)

        XCTAssertTrue(try result.isInstance(of: myClass))
    }

    func testPromises() throws {
        let jxc = JXContext()

        do {
            try jxc.global.setProperty("setTimeout", JXValue(newFunctionIn: jxc) { jxc, this, args in
                print("setTimeout", try args.map({ try $0.string }))
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

            XCTAssertGreaterThan(try result.int, 0)

            // this appears to be fixed in macOS 13 and iOS 15
            // Bug 161942: Shouldn't drain the micro task queue when calling out
            // https://developer.apple.com/forums/thread/678277

            if #available(macOS 12, iOS 15, tvOS 15, *) {
                XCTAssertEqual(2, try result.int)
                XCTAssertEqual([1, 2, 3], try jxc.global["arr"].array.map({ try $0.int }))
            } else {
                XCTAssertEqual(3, try result.int)
                XCTAssertEqual([1, 3, 2], try jxc.global["arr"].array.map({ try $0.int }))
            }
        }

        do {
            let str = UUID().uuidString
            let resolvedPromise = try JXValue(newPromiseResolvedWithResult: jxc.string(str), in: jxc)
            try jxc.global.setProperty("prm", resolvedPromise)
            let _ = try jxc.eval("(async () => { this['cb'] = await prm; })();")
            XCTAssertEqual(str, try jxc.global["cb"].string)
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

        XCTAssertEqual(true, try jxc.eval("Symbol('xxx')").isSymbol)
        //XCTAssertEqual("xxx", try jxc.eval("Symbol('xxx')"))

        XCTAssertThrowsError(try jxc.eval("new Symbol('xxx')")) { error in
            XCTAssertEqual("TypeError: function is not a constructor (evaluating 'new Symbol('xxx')') <<script: new Symbol('xxx') >>", "\(error)")
        }

        XCTAssertThrowsError(try jxc.eval("Symbol('xxx')").string) { error in
            XCTAssertEqual("TypeError: Cannot convert a symbol to a string", "\(error)")
        }

        XCTAssertEqual(true, jxc.string("").isString)
        XCTAssertEqual(false, jxc.string("").isSymbol)
        XCTAssertEqual(true, jxc.number(1.1).isNumber)
        XCTAssertEqual(true, jxc.null().isNull)
        XCTAssertEqual(true, try jxc.array([]).isArray)

       try jxc.withArrayBuffer(source: Data([1,2,3]), block: { val in
           XCTAssertEqual(true, try val.isArrayBuffer)
       })
    }

    func testCheck() throws {
        func lint(_ script: String, strict: Bool = false) throws -> String {
            do {
                let jxc = JXContext(configuration: .init(strict: strict))
                try jxc.eval(script)
                return ""
            } catch let error as JXError {
                return error.description
            } catch {
                XCTFail("unexpected error type: \(error)")
                return ""
            }
        }

        XCTAssertEqual(try lint("1"), "")
        XCTAssertEqual(try lint("1.1"), "")
        XCTAssertEqual(try lint("Math.PI.x"), "")

        XCTAssertEqual(try lint("Math.PIE.x"), "TypeError: undefined is not an object (evaluating \'Math.PIE.x\') <<script: Math.PIE.x >>")
        XCTAssertEqual(try lint("1X"), "SyntaxError: No identifiers allowed directly after numeric literal <<script: 1X >>")
        XCTAssertEqual(try lint("1["), "SyntaxError: Unexpected end of script <<script: 1[ >>")
        XCTAssertEqual(try lint("1]"), "SyntaxError: Unexpected token \']\'. Parse error. <<script: 1] >>")

        // Strict checks

        XCTAssertEqual(try lint("use strict"), "SyntaxError: Unexpected identifier \'strict\' <<script: use strict >>") // need to quote
        XCTAssertEqual(try lint("'use strict'\nmistypeVarible = 17"), "ReferenceError: Can\'t find variable: mistypeVarible <<script: 'use strict'\nmistypeVarible = 17 >>")
    }


    static var peerCount = 0

    func testPeers() throws {
        class AssociatedObject {
            var str: String
            init(str: String) {
                self.str = str
                JXCoreTests.peerCount += 1
            }
            deinit {
                JXCoreTests.peerCount -= 1
            }
        }

        measure {
            let jxc = JXContext()
            XCTAssertEqual(0, JXCoreTests.peerCount)
            let obj = jxc.object(peer: AssociatedObject(str: "ABC"))
            XCTAssertNotNil(obj.peer)
            XCTAssertEqual("ABC", (obj.peer as? AssociatedObject)?.str)
            XCTAssertEqual(1, JXCoreTests.peerCount)
        }

        XCTAssertEqual(0, JXCoreTests.peerCount, "peer instances should have been deallocated")
    }

    func testJSON() throws {
        let jxc = JXContext()
        XCTAssertNoThrow(try jxc.json(#"{}"#))
        XCTAssertNoThrow(try jxc.json(#"{"a":1}"#))
        XCTAssertNoThrow(try jxc.json(#"{"b":false}"#))
        XCTAssertNoThrow(try jxc.json(#"[1,2,3]"#))
        XCTAssertNoThrow(try jxc.json(#"true"#))
        XCTAssertNoThrow(try jxc.json(#"false"#))
        XCTAssertNoThrow(try jxc.json(#"1.2"#))

        XCTAssertThrowsError(try jxc.json(#"{"#))
        XCTAssertThrowsError(try jxc.json(#"}"#))
        XCTAssertThrowsError(try jxc.json(#"{x:1}"#))
    }

    func testConvey() throws {
        let jxc = JXContext()
        try conveyTest(with: jxc)
    }
    
    private enum _Enum: String, RawRepresentable {
        case x
        case y
    }

    private struct _Codable: Codable, Equatable {
        let x: Int
    }

    func testConveyWithSPI() throws {
        class _SPI: JXContextSPI {
            var toJXWasInvoked = false
            var fromJXWasInvoked = false

            func toJX(_ value: Any, in context: JXContext) throws -> JXValue? {
                toJXWasInvoked = true
                // Should only be invoked on non-convertible types, and the only
                // type we test is Codable
                XCTAssertFalse(value is JXConvertible)
                XCTAssertTrue(value is _Codable)
                return nil
            }

            func fromJX<T>(_ value: JXValue, to type: T.Type) throws -> T? {
                fromJXWasInvoked = true
                // Should only be invoked on non-convertible types, and the only
                // type we test is Codable
                XCTAssertFalse(type is JXConvertible.Type)
                XCTAssertTrue(type is _Codable.Type)
                return nil
            }
        }

        let jxc = JXContext()
        let spi = _SPI()
        jxc.spi = spi
        try conveyTest(with: jxc)
        XCTAssertTrue(spi.toJXWasInvoked)
        XCTAssertTrue(spi.fromJXWasInvoked)
    }

    private func conveyTest(with jxc: JXContext) throws {
        XCTAssertTrue(try jxc.convey(()).isUndefined)
        XCTAssertEqual(try jxc.convey(true).convey(), true)
        XCTAssertEqual(try jxc.convey("string").convey(), "string")
        XCTAssertEqual(try jxc.convey(1.0).convey(), 1.0)
        XCTAssertEqual(try jxc.convey(Float(1.0)).convey(), Float(1.0))
        XCTAssertEqual(try jxc.convey(1).convey(), 1)
        XCTAssertEqual(try jxc.convey(Int32(1)).convey(), Int32(1))
        XCTAssertEqual(try jxc.convey(Int64(1)).convey(), Int64(1))
        XCTAssertEqual(try jxc.convey(UInt(1)).convey(), UInt(1))
        XCTAssertEqual(try jxc.convey(UInt32(1)).convey(), UInt32(1))
        XCTAssertEqual(try jxc.convey(UInt64(1)).convey(), UInt64(1))
        
        XCTAssertEqual(try jxc.convey(Double.infinity).convey(), Double.infinity)
        XCTAssertEqual(try jxc.eval("Infinity").double, Double.infinity)

        XCTAssertEqual(try jxc.convey([1, 2]).convey(), [1, 2])
        XCTAssertEqual(try jxc.convey(["x": 1]).convey(), ["x": 1])
        XCTAssertEqual(try jxc.convey(["x": [1, 2]]).convey(), ["x": [1, 2]])

        let optint1: Int? = 1
        let optintnil: Int? = nil
        XCTAssertEqual(try jxc.convey(optint1).convey(), optint1)
        XCTAssertEqual(try jxc.convey(optintnil).convey(), optintnil)

        let optarray1: [Int]? = [1]
        let optarraynil: [Int]? = nil
        XCTAssertEqual(try jxc.convey(optarray1).convey(), optarray1)
        XCTAssertEqual(try jxc.convey(optarraynil).convey(), optarraynil)
        
        let rawRepresentable = _Enum.x
        let optrawRepresentable: _Enum? = .y
        let optrawRepresentableNil: _Enum? = nil
        XCTAssertEqual(try jxc.convey(rawRepresentable).convey(), rawRepresentable)
        XCTAssertEqual(try jxc.convey(optrawRepresentable).convey(), optrawRepresentable)
        XCTAssertEqual(try jxc.convey(optrawRepresentableNil).convey(), optrawRepresentableNil)

        let codable = _Codable(x: 1)
        let optcodable1: _Codable? = _Codable(x: 1)
        let optcodablenil: _Codable? = nil
        XCTAssertEqual(try jxc.convey(codable).convey(), codable)
        XCTAssertEqual(try jxc.convey(["c": codable]).convey(), ["c": codable])
        XCTAssertEqual(try jxc.convey(optcodable1).convey(), optcodable1)
        XCTAssertEqual(try jxc.convey(optcodablenil).convey(), optcodablenil)
    }

    func testConveyConvenienceFuncs() throws {
        let jxc = JXContext()
        let jxstring1 = jxc.string("jxstring1")
        let jxstring2 = jxc.string("jxstring2")
        let jxstringArray = try jxc.array([jxstring1, jxstring2])
        let stringArray = try jxc.array(["jxstring1", "jxstring2"])
        let jxconveyedArray: [String] = try jxstringArray.convey()
        let conveyedArray: [String] = try stringArray.convey()
        XCTAssertEqual(jxconveyedArray, conveyedArray)
        XCTAssertEqual(conveyedArray[0], "jxstring1")
        XCTAssertEqual(conveyedArray[1], "jxstring2")

        try jxstringArray.addElement(jxc.string("jxstring3"))
        try jxstringArray.addElement("jxstring4")
        let conveyedAddedArray: [String] = try jxstringArray.convey()
        XCTAssertEqual(conveyedAddedArray.count, 4)
        XCTAssertEqual(conveyedAddedArray[2], "jxstring3")
        XCTAssertEqual(conveyedAddedArray[3], "jxstring4")

        let emptyarray = try jxc.array([])
        XCTAssertEqual(0, try emptyarray.count)
    }

    func testWithValues() throws {
        let jxc = JXContext()
        
        try jxc.global.setProperty("$1", 100)
        var result = try jxc.withValues([1, 2]) { try jxc.eval("$0 + $1") }
        XCTAssertEqual(try result.int, 3)
        XCTAssertTrue(try jxc.global["$0"].isUndefined)
        XCTAssertEqual(try jxc.global["$1"].int, 100)

        result = try jxc.withValues("a", 1, "c") { try jxc.eval("$0 + $1 + $2") }
        XCTAssertEqual(try result.string, "a1c")

        do {
            let _ = try jxc.withValues(1) { try jxc.eval("*= $0") }
            XCTFail("eval should have thrown syntax error")
        } catch {
            XCTAssertTrue(try jxc.global["$0"].isUndefined)
        }
        
        try jxc.withValues(1, nil, 3) {
            XCTAssertEqual(try jxc.eval("$0").int, 1)
            XCTAssertTrue(try jxc.eval("$1").isNull)
            XCTAssertEqual(try jxc.eval("$2").int, 3)
        }
    }

    func testNew() throws {
        let jxc = JXContext()
        try jxc.eval("""
class C {
    name;
    constructor(name) {
        this.name = name;
    }
}
""")
        let cinstance = try jxc.new("C", withArguments: ["foo"])
        XCTAssertEqual(try cinstance["name"].string, "foo")
        XCTAssertEqual(try cinstance["constructor"]["name"].string, "C")
    }
}
