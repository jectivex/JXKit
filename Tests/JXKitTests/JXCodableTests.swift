import JXKit
import XCTest

final class JXCodableTests: XCTestCase {

    func testRoundTripCodables() throws {
        let ctx = JSContext()

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

    func testCodableArguments() throws {
        let ctx = JSContext()

        let htpy = JSValue(newFunctionIn: ctx) { ctx, this, args in
            JSValue(double: sqrt(pow(args.first?["x"].doubleValue ?? 0.0, 2) + pow(args.first?["y"].doubleValue ?? 0.0, 2)), in: ctx)
        }

        struct Args : Encodable {
            let x: Int16
            let y: Float
        }

        func hfun(_ args: Args) throws -> Double? {
            htpy.call(withArguments: [try ctx.encode(args)]).doubleValue
        }

        XCTAssertEqual(5, try hfun(Args(x: 3, y: 4)))
        XCTAssertEqual(hypot(1, 2), try hfun(Args(x: 1, y: 2)))
        XCTAssertEqual(hypot(2, 2), try hfun(Args(x: 2, y: 2)))
        XCTAssertEqual(hypot(10, 10), try hfun(Args(x: 10, y: 10)))
    }
}

