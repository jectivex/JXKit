import JXKit
import XCTest

class JXCoreTests: XCTestCase {

    func testHobbled() {
        #if os(iOS) || os(tvOS)
        #if !targetEnvironment(simulator)
        XCTAssertEqual(true, JXContext.isHobbled) // only check on devices, since simulator seems to permit executable pages
        #endif
        #else
        XCTAssertEqual(false, JXContext.isHobbled)
        #endif
    }

    func testFunction1() {
        let context = JXContext()

        let myFunction = JXValue(newFunctionIn: context) { context, this, arguments in

            let result = arguments[0].numberValue! + arguments[1].numberValue!

            return JXValue(double: result, in: context)
        }

        XCTAssertTrue(myFunction.isFunction)

        let result = myFunction.call(withArguments: [JXValue(double: 1, in: context), JXValue(double: 2, in: context)])
        XCTAssertNil(context.currentError, "\(context.currentError!)")

        XCTAssertTrue(result.isNumber)
        XCTAssertEqual(result.numberValue, 3)
    }

    func testFunction2() {
        let context = JXContext()

        let myFunction = JXValue(newFunctionIn: context) { context, this, arguments in

            let result = arguments[0].numberValue! + arguments[1].numberValue!

            return JXValue(double: result, in: context)
        }

        XCTAssertTrue(myFunction.isFunction)

        context.global["myFunction"] = myFunction

        let result = context.evaluateScript("myFunction(1, 2)")
        XCTAssertNil(context.currentError, "\(context.currentError!)")

        XCTAssertTrue(result.isNumber)
        XCTAssertEqual(result.numberValue, 3)
    }

    func testCalculation() {
        let context = JXContext()

        let result = context.evaluateScript("1 + 1")
        XCTAssertNil(context.currentError, "\(context.currentError!)")

        XCTAssertTrue(result.isNumber)
        XCTAssertEqual(result.numberValue, 2)
    }

    func testArray() {
        let context = JXContext()

        let result = context.evaluateScript("[1 + 2, \"BMW\", \"Volvo\"]")
        XCTAssertNil(context.currentError, "\(context.currentError!)")

        XCTAssertTrue(result.isArray)

        let length = result["length"]
        XCTAssertEqual(length.numberValue, 3)

        XCTAssertEqual(result[0].numberValue, 3)
        XCTAssertEqual(result[1].stringValue, "BMW")
        XCTAssertEqual(result[2].stringValue, "Volvo")
    }

    func testGetter() {
        let context = JXContext()

        context.global["obj"] = JXValue(newObjectIn: context)

        let desc = JXProperty(
            getter: { this in JXValue(double: 3, in: this.env) }
        )

        context.global["obj"].defineProperty("three", desc)

        let result = context.evaluateScript("obj.three")
        XCTAssertNil(context.currentError, "\(context.currentError!)")

        XCTAssertEqual(result.numberValue, 3)
    }

    func testSetter() {
        let context = JXContext()

        context.global["obj"] = JXValue(newObjectIn: context)

        let desc = JXProperty(
            getter: { this in this["number_container"] },
            setter: { this, newValue in this["number_container"] = newValue }
        )

        context.global["obj"].defineProperty("number", desc)

        context.evaluateScript("obj.number = 5")
        XCTAssertNil(context.currentError, "\(context.currentError!)")

        XCTAssertEqual(context.global["obj"]["number"].numberValue, 5)
        XCTAssertEqual(context.global["obj"]["number_container"].numberValue, 5)

        context.evaluateScript("obj.number = 3")
        XCTAssertNil(context.currentError, "\(context.currentError!)")

        XCTAssertEqual(context.global["obj"]["number"].numberValue, 3)
        XCTAssertEqual(context.global["obj"]["number_container"].numberValue, 3)
    }

    @available(macOS 10.12, macCatalyst 13.0, iOS 10.0, tvOS 10.0, *)
    func testArrayBuffer() {
        let context = JXContext()
        
        let bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        context.global["buffer"] = JXValue(newArrayBufferWithBytes: bytes, in: context)

        XCTAssertTrue(context.global["buffer"].isArrayBuffer)
        XCTAssertEqual(context.global["buffer"].byteLength, 8)

        let bufferSize = 999_999
        //let bufferData = Data((1...bufferSize).map({ _ in UInt8.random(in: (.min)...(.max)) }))
        let bufferData = Data(repeating: UInt8.random(in: (.min)...(.max)), count: bufferSize)

        measure { // 1M average: 0.001; 10M average: 0.002; 100M average: average: 0.030
            let arrayBuffer = JXValue(newArrayBufferWithBytes: bufferData, in: context)
            let isView = context.global["ArrayBuffer"]["isView"].call(withArguments: [arrayBuffer])
            XCTAssertEqual(true, isView.isBoolean)
            XCTAssertEqual(false, isView.booleanValue)

            XCTAssertEqual(.init(bufferSize), arrayBuffer["byteLength"].numberValue)
        }
    }
    
    @available(macOS 10.12, macCatalyst 13.0, iOS 10.0, tvOS 10.0, *)
    func testArrayBufferWithBytesNoCopy() {
        var flag = 0

        do {
            let context = JXContext()
            var bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]

            bytes.withUnsafeMutableBytes { bytes in
                context.global["buffer"] = JXValue(
                    newArrayBufferWithBytesNoCopy: bytes,
                    deallocator: { _ in flag = 1 },
                    in: context)

                XCTAssertTrue(context.global["buffer"].isArrayBuffer)
                XCTAssertEqual(context.global["buffer"].byteLength, 8)
            }
        }

        XCTAssertEqual(flag, 1)
    }

    @available(macOS 10.12, macCatalyst 13.0, iOS 10.0, tvOS 10.0, *)
    func testArrayBufferClosure() {
        // this should always measure around zero regardless of the size of the buffer that is passed, since we guarantee that no copy will be made
        let size = 1_000_000
        // let size = 1_000_000_000

        let data = Data(repeating: 9, count: size)
        let context = JXContext()

        XCTAssertEqual(true, context["ArrayBuffer"].isObject)

        measure { // average: 0.000, relative standard deviation: 99.521%, values: [0.000434, 0.000037, 0.000959, 0.000050, 0.000471, 0.000048, 0.000394, 0.000048, 0.000389, 0.000047]
            XCTAssertEqual(Double?.some(.init(size)), context.withArrayBuffer(source: data) { buffer in
                XCTAssertEqual(true, buffer["byteLength"].booleanValue)
                XCTAssertEqual(true, buffer["slice"].isFunction)
                return buffer["byteLength"].numberValue
            })
        }
    }

    @available(macOS 10.12, macCatalyst 13.0, iOS 10.0, tvOS 10.0, *)
    func testDataView() {
        let context = JXContext()
        
        let bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        context.global["buffer"] = JXValue(newArrayBufferWithBytes: bytes, in: context)
        
        context.evaluateScript("new DataView(buffer).setUint8(0, 5)")
        
        XCTAssertEqual(context["buffer"].copyBytes().map(Array.init), [5, 2, 3, 4, 5, 6, 7, 8])
    }
    
    @available(macOS 10.12, macCatalyst 13.0, iOS 10.0, tvOS 10.0, *)
    func testSlice() {
        let context = JXContext()
        
        let bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        context.global["buffer"] = JXValue(newArrayBufferWithBytes: bytes, in: context)
        
        XCTAssertEqual(context.evaluateScript("buffer.slice(2, 4)").copyBytes().map(Array.init), [3, 4])
    }
    
    func testFunctionConstructor() {
        let context = JXContext()

        let myClass = JXValue(newFunctionIn: context) { context, this, arguments in

            let result = arguments[0].numberValue! + arguments[1].numberValue!

            let object = JXValue(newObjectIn: context)
            object["result"] = JXValue(double: result, in: context)

            return object
        }

        XCTAssertTrue(myClass.isConstructor)

        context.global["myClass"] = myClass

        let result = context.evaluateScript("new myClass(1, 2)")
        XCTAssertNil(context.currentError, "\(context.currentError!)")

        XCTAssertTrue(result.isObject)
        XCTAssertEqual(result["result"].numberValue, 3)

        XCTAssertTrue(result.isInstance(of: myClass))
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
    func testPromises() throws {
        let ctx = JXContext()

        do {
            ctx["setTimeout"] = JXValue(newFunctionIn: ctx) { ctx, this, args in
                print("setTimeout", args.map(\.stringValue))
                return ctx.number(0)
            }

            let result = try ctx.eval("""
                var arr = [];
                (async () => {
                  await 1;
                  arr.push(3);
                })();
                arr.push(1);
                setTimeout(() => {});
                arr.push(2);
                """)

            XCTAssertEqual(3, result.numberValue)

            // https://developer.apple.com/forums/thread/678277
            XCTAssertEqual([1, 3, 2], ctx["arr"].array?.compactMap(\.numberValue))
        }

        do {
            let str = UUID().uuidString
            guard let resolvedPromise = JXValue(newPromiseResolvedWithResult: ctx.string(str), in: ctx) else {
                return XCTFail("could not create promise")
            }

            ctx["prm"] = resolvedPromise
            let _ = try ctx.eval("(async () => { this['cb'] = await prm; })();")
            XCTAssertEqual(str, ctx["cb"].stringValue)
        }
    }
}
