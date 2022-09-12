import JXKit
import XCTest

@available(macOS 11, iOS 13, tvOS 13, *)
final class JXCodableTests: XCTestCase {

    func testRoundTripCodables() throws {
        let jxc = JXContext()

        func rt<T: Codable & Equatable>(equal: Bool = true, _ item: T, line: UInt = #line) throws {
            let encoded = try jxc.encode(item)
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

            try rt(["1": ["2": ["3": ["4": ["5": "six"]]]]])

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
        let jxc = JXContext()
        let dataValue = try jxc.encode(Data([1,2,3,4]))
        XCTAssertEqual("[object ArrayBuffer]", try dataValue.stringValue)
        XCTAssertEqual(4, try dataValue["byteLength"].numberValue)
    }

    func testCodableDate() throws {
        let jxc = JXContext()
        let dateValue = try jxc.encode(Date(timeIntervalSince1970: 1234))
        XCTAssertEqual("Thu, 01 Jan 1970 00:20:34 GMT", try dateValue.invokeMethod("toGMTString", withArguments: []).stringValue)
    }

    /// An example of invoking `Math.hypot` directly with numeric arguments
    func testCodableParams() throws {
        let jxc = JXContext()
        let hypot = try jxc.global["Math"]["hypot"]
        XCTAssert(hypot.isFunction)
        let result = try hypot.call(withArguments: try [jxc.encode(3), jxc.encode(4)])
        XCTAssertEqual(5, try result.numberValue)
    }

    /// An example of invoking `Math.hypot` in a wrapper function that takes an encodable argument and returns a Decodable retult.
    func testCodableParamObject() throws {
        struct AB : Encodable { let a, b: Double }
        struct C : Decodable { let c: Double }

        let jxc = JXContext()
        let hypot = try jxc.eval("(function(args) { return { c: Math.hypot(args.a, args.b) }; })")
        XCTAssert(hypot.isFunction)

        let result: C = try hypot.call(withArguments: [jxc.encode(AB(a: 3, b: 4))]).toDecodable(ofType: C.self)
        XCTAssertEqual(5, result.c)
    }

    func testFibJS() throws {
        let jxc = JXContext()
        let jsfib = try jxc.eval("(function fibo(x) { if (x<=2) return 1; else return fibo(x-1) + fibo(x-2) })")

        func fib(_ n: Int) throws -> Double {
            try jsfib.call(withArguments: [jxc.number(n)]).numberValue
        }

        XCTAssertEqual(3, try fib(4))
        XCTAssertEqual(5, try fib(5))
        XCTAssertEqual(8, try fib(6))
        XCTAssertEqual(13, try fib(7))
        XCTAssertEqual(21, try fib(8))

        XCTAssertEqual(6765, try fib(20))

        // measured [Time, seconds] average: 0.005, relative standard deviation: 8.271%, values: [0.005701, 0.004532, 0.004498, 0.004410, 0.004411, 0.004482, 0.004414, 0.004397, 0.004411, 0.004485], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , polarity: unspecified, maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
        measure {
            XCTAssertEqual(832040, try? fib(30))
        }
    }

    func testFibNative() throws {
        func fib(_ n: Int) -> Int {
            guard n > 1 else { return n }
            return fib(n-1) + fib(n-2)
        }

        XCTAssertEqual(3, fib(4))
        XCTAssertEqual(5, fib(5))
        XCTAssertEqual(8, fib(6))
        XCTAssertEqual(13, fib(7))
        XCTAssertEqual(21, fib(8))

        XCTAssertEqual(6765, fib(20))

        // measured [Time, seconds] average: 0.018, relative standard deviation: 4.494%, values: [0.020162, 0.018207, 0.017625, 0.017501, 0.017514, 0.017609, 0.017366, 0.017698, 0.018720, 0.018391], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , polarity: unspecified, maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
        measure {
            XCTAssertEqual(832040, fib(30))
        }
    }

    func testCodableAPI() throws {
        let jxc = JXMathContext()
        XCTAssertEqual(5 as Int, try jxc.hypot(3, 4))
        XCTAssertEqual(5 as Float, try jxc.hypot(3, 4))
        XCTAssertEqual(5 as Double, try jxc.hypot(3, 4))
        XCTAssertEqual(5 as Int16, try jxc.hypot(3, 4))
        XCTAssertEqual(5 as Int8, try jxc.hypot(3, 4))
        XCTAssertEqual(5 as UInt32, try jxc.hypot(3, 4))

        // Double vs. Int inference
        XCTAssertEqual(21.02379604162864, try jxc.hypot(9, 19))
        XCTAssertEqual(21, try jxc.hypot(9, 19))
    }

    func testCodableArguments() async throws {
        let jxc = JXContext()

        let htpy = JXValue(newFunctionIn: jxc) { jxc, this, args in
            jxc.number(try sqrt(pow(args.first?["x"].numberValue ?? 0.0, 2) + pow(args.first?["y"].numberValue ?? 0.0, 2)))
        }

        struct Args : Encodable {
            let x: Int16
            let y: Float
        }

        func hfun(_ args: Args) throws -> Double? {
            try htpy.call(withArguments: [try jxc.encode(args)]).numberValue
        }

        XCTAssertEqual(5, try hfun(Args(x: 3, y: 4)))
        XCTAssertEqual(hypot(1, 2), try hfun(Args(x: 1, y: 2)))
        XCTAssertEqual(hypot(2, 2), try hfun(Args(x: 2, y: 2)))
        XCTAssertEqual(hypot(10, 10), try hfun(Args(x: 10, y: 10)))
    }
}

/// An example of wrapping a context to provide structured access to JS APIs with cached function values
@available(macOS 11, iOS 13, tvOS 13, *)
final class JXMathContext {
    let jxc: JXContext
    private lazy var _math = Result { try jxc.global["Math"] }
    private lazy var _hypot = Result { try _math.get()["hypot"] }

    init(jxc: JXContext = JXContext()) {
        self.jxc = jxc
    }

    func hypot<T: Numeric & Codable>(_ a: T, _ b: T) throws -> T {
        try _hypot.get().call(withArguments: try [jxc.encode(a), jxc.encode(b)]).toDecodable(ofType: T.self)
    }
}
