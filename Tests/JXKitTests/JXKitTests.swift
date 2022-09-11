import JXKit
import XCTest

@available(macOS 11, iOS 13, tvOS 13, *)
final class JXKitTests: XCTestCase {

    func testAPI() throws {
        let jsc = JXContext()
        let value: JXValue = try jsc.eval("1+2")
        XCTAssertEqual(3, try value.numberValue)
    }

    /// https://www.destroyallsoftware.com/talks/wat
    func testWAT() throws {
        let jsc = JXContext()

        XCTAssertEqual(true, try jsc.eval("[] + {}").isString)
        XCTAssertEqual("[object Object]", try jsc.eval("[] + {}").stringValue)

        XCTAssertEqual(true, try jsc.eval("[] + []").isString)
        XCTAssertEqual("", try jsc.eval("[] + []").stringValue)

        XCTAssertEqual(true, try jsc.eval("{} + {}").isNumber)
        XCTAssertEqual(true, try jsc.eval("{} + {}").numberValue.isNaN)

        XCTAssertEqual(true, try jsc.eval("{} + []").isNumber)
        XCTAssertEqual(0.0, try jsc.eval("{} + []").numberValue)

        XCTAssertEqual(true, try jsc.eval("1.0 === 1.0000000000000001").booleanValue)

        XCTAssertEqual(1, try jsc.eval("y = {}; y[[]] = 1; Object.keys(y)").array.count)

        XCTAssertEqual(10, try jsc.eval("['10', '10', '10'].map(parseInt)").array.first?.numberValue)
        XCTAssertEqual("NaN", try jsc.eval("['10', '10', '10'].map(parseInt)").array.dropFirst().first?.stringValue)
        XCTAssertEqual(2, try jsc.eval("['10', '10', '10'].map(parseInt)").array.last?.numberValue)
    }
}

