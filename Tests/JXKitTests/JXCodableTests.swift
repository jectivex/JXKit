import JXKit
import XCTest

final class JXCodableTests: XCTestCase {

    func testRoundTripCodables() throws {
        let ctx = JXContext()

        func rt<T: Codable & Equatable>(equal: Bool = true, _ item: T, line: UInt = #line) throws {
            let encoded = try ctx.encode(item)
            let decoded = try encoded.toDecodable(ofType: T.self)

            if equal {
                XCTAssertEqual(item, decoded, line: line)
            } else {
                XCTAssertNotEqual(item, decoded, line: line)
            }
        }

        for _ in 1...20 {
            try rt(1)
            try rt("X")
            try rt(true)
            try rt(false)
            try rt(1.234)

            try rt(["x": 1])
            try rt(["x": 1.1])
            try rt(["x": true])
            try rt(["x": false])
            try rt(["x": "ABC"])
            try rt(["x": [false, true]])

            try rt(["x": 1])
            try rt(["x": 1.1])
            try rt(["x": true])
            try rt(["x": false])
            try rt(["x": "ABC"])

            try rt([1])
            try rt([true])
            try rt(["X"])

            try rt([[1, 2, 3], [4, 5, 6]])

            struct NumStruct: Codable, Equatable {
                var num: Double?
            }

            try rt(NumStruct(num: nil))
            try rt(NumStruct(num: 123))
            try rt(NumStruct(num: .infinity))
            try rt(NumStruct(num: .pi))

            // NaNs don't equate
            try rt(equal: false, NumStruct(num: .nan))
            try rt(equal: false, NumStruct(num: .signalingNaN))


            struct StringStruct: Codable, Equatable {
                var str: String?
            }

            try rt(StringStruct(str: nil))
            try rt(StringStruct(str: "1Y1"))

            struct DataStruct: Codable, Equatable {
                var data: Data
            }

            try rt(DataStruct(data: Data("XYZ".utf8)))
            try rt(DataStruct(data: Data(UUID().uuidString.utf8)))

            struct DateStruct: Codable, Equatable {
                var date: Date
            }

            try rt(DateStruct(date: Date(timeIntervalSince1970: 0)))
            try rt(DateStruct(date: Date(timeIntervalSinceReferenceDate: 0)))


            struct MultiStruct: Codable, Equatable {
                let str: StringStruct
                let data: DataStruct
                let date: DateStruct
            }

            try rt(MultiStruct(str: StringStruct(str: "123"), data: DataStruct(data: .init([1,2,3])), date: DateStruct(date: .init(timeIntervalSince1970: 123))))
        }
    }

    func testCodableData() throws {
        let ctx = JXContext()
        let dataValue = try ctx.encode(Data([1,2,3,4]))
        XCTAssertEqual("[object ArrayBuffer]", dataValue.stringValue)
        XCTAssertEqual(4, dataValue["byteLength"].numberValue)
    }

    func testCodableDate() throws {
        let ctx = JXContext()
        let dateValue = try ctx.encode(Date(timeIntervalSince1970: 1234))
        XCTAssertEqual("Thu, 01 Jan 1970 00:20:34 GMT", dateValue.invokeMethod("toGMTString", withArguments: []).stringValue)
    }

    /// An example of invoking `Math.hypot` directly with numeric arguments
    func testCodableParams() throws {
        let ctx = JXContext()
        let hypot = ctx["Math"]["hypot"]
        XCTAssert(hypot.isFunction)
        let result = hypot.call(withArguments: try [ctx.encode(3), ctx.encode(4)])
        XCTAssertEqual(5, result.numberValue)
    }

    /// An example of invoking `Math.hypot` in a wrapper function that takes an encodable argument and returns a Decodable retult.
    func testCodableParamObject() throws {
        struct AB : Encodable { let a, b: Double }
        struct C : Decodable { let c: Double }

        let ctx = JXContext()
        let hypot = try ctx.eval(script: "(function(args) { return { c: Math.hypot(args.a, args.b) }; })")
        XCTAssert(hypot.isFunction)

        let result: C = try hypot.call(withArguments: [ctx.encode(AB(a: 3, b: 4))]).toDecodable(ofType: C.self)
        XCTAssertEqual(5, result.c)
    }

    func testCodableAPI() throws {
        let ctx = JXMathContext()
        XCTAssertEqual(5 as Int, try ctx.hypot(3, 4))
        XCTAssertEqual(5 as Float, try ctx.hypot(3, 4))
        XCTAssertEqual(5 as Double, try ctx.hypot(3, 4))
        XCTAssertEqual(5 as Int16, try ctx.hypot(3, 4))
        XCTAssertEqual(5 as Int8, try ctx.hypot(3, 4))
        XCTAssertEqual(5 as UInt32, try ctx.hypot(3, 4))

        // Double vs. Int inferrence
        XCTAssertEqual(21.02379604162864, try ctx.hypot(9, 19))
        XCTAssertEqual(21, try ctx.hypot(9, 19))
    }

    func testCodableArguments() throws {
        let ctx = JXContext()

        let htpy = JXValue(newFunctionIn: ctx) { ctx, this, args in
            JXValue(double: sqrt(pow(args.first?["x"].numberValue ?? 0.0, 2) + pow(args.first?["y"].numberValue ?? 0.0, 2)), in: ctx)
        }

        struct Args : Encodable {
            let x: Int16
            let y: Float
        }

        func hfun(_ args: Args) throws -> Double? {
            htpy.call(withArguments: [try ctx.encode(args)]).numberValue
        }

        XCTAssertEqual(5, try hfun(Args(x: 3, y: 4)))
        XCTAssertEqual(hypot(1, 2), try hfun(Args(x: 1, y: 2)))
        XCTAssertEqual(hypot(2, 2), try hfun(Args(x: 2, y: 2)))
        XCTAssertEqual(hypot(10, 10), try hfun(Args(x: 10, y: 10)))
    }
}

/// An example of wrapping a context to provide structured access to JS APIs with cached function values
final class JXMathContext {
    let ctx: JXContext
    private lazy var _math: JXValue = ctx["Math"]
    private lazy var _hypot: JXValue = _math["hypot"]

    init(ctx: JXContext = JXContext()) {
        self.ctx = ctx
    }

    func hypot<T: Numeric & Codable>(_ a: T, _ b: T) throws -> T {
        try _hypot.call(withArguments: try [ctx.encode(a), ctx.encode(b)]).toDecodable(ofType: T.self)
    }
}
