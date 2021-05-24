import JXKit
import XCTest

final class JXKitTests: XCTestCase {

    func testAPI() throws {
        let ctx = JXContext()
        let value: JXValue = ctx.evaluateScript("1+2")
        XCTAssertEqual(3, value.doubleValue)
    }

    /// https://www.destroyallsoftware.com/talks/wat
    func testWAT() throws {
        let ctx = JXContext()

        XCTAssertEqual(true, try ctx.eval(script: "[] + {}").isString)
        XCTAssertEqual("[object Object]", try ctx.eval(script: "[] + {}").stringValue)

        XCTAssertEqual(true, try ctx.eval(script: "[] + []").isString)
        XCTAssertEqual("", try ctx.eval(script: "[] + []").stringValue)

        XCTAssertEqual(true, try ctx.eval(script: "{} + {}").isNumber)
        XCTAssertEqual(true, try ctx.eval(script: "{} + []").isNumber)

        XCTAssertEqual(true, try ctx.eval(script: "{} + {}").doubleValue?.isNaN)

        XCTAssertEqual(0.0, try ctx.eval(script: "{} + []").doubleValue)

        XCTAssertEqual(true, try ctx.eval(script: "1.0 === 1.0000000000000001").boolValue)

        XCTAssertEqual(1, try ctx.eval(script: "y = {}; y[[]] = 1; Object.keys(y)").array?.count)

        XCTAssertEqual(10, try ctx.eval(script: "['10', '10', '10'].map(parseInt)").array?.first?.doubleValue)
        XCTAssertEqual(2, try ctx.eval(script: "['10', '10', '10'].map(parseInt)").array?.last?.doubleValue)
    }
}

