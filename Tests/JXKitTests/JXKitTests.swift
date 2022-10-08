import JXKit
import XCTest

final class JXKitTests: XCTestCase {
    func testAPI() throws {
        let jxc = JXContext()
        let value: JXValue = try jxc.eval("1+2")
        XCTAssertEqual(3, try value.int)
    }

    /// https://www.destroyallsoftware.com/talks/wat
    func testWAT() throws {
        let jxc = JXContext()

        XCTAssertEqual(true, try jxc.eval("[] + {}").isString)
        XCTAssertEqual("[object Object]", try jxc.eval("[] + {}").string)

        XCTAssertEqual(true, try jxc.eval("[] + []").isString)
        XCTAssertEqual("", try jxc.eval("[] + []").string)

        XCTAssertEqual(true, try jxc.eval("{} + {}").isNumber)
        XCTAssertEqual(true, try jxc.eval("{} + {}").double.isNaN)

        XCTAssertEqual(true, try jxc.eval("{} + []").isNumber)
        XCTAssertEqual(0.0, try jxc.eval("{} + []").double)

        XCTAssertEqual(true, try jxc.eval("1.0 === 1.0000000000000001").bool)

        XCTAssertEqual(1, try jxc.eval("let y = {}; y[[]] = 1; Object.keys(y)").array.count)

        XCTAssertEqual(10, try jxc.eval("['10', '10', '10'].map(parseInt)").array.first?.double)
        XCTAssertEqual("NaN", try jxc.eval("['10', '10', '10'].map(parseInt)").array.dropFirst().first?.string)
        XCTAssertEqual(2, try jxc.eval("['10', '10', '10'].map(parseInt)").array.last?.double)
    }
}

