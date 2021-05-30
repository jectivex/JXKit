import JXKit
import XCTest

final class JXKitTests: XCTestCase {

    func testAPI() throws {
        let ctx = JXContext()
        let value: JXValue = ctx.evaluateScript("1+2")
        XCTAssertEqual(3, value.numberValue)
    }

    /// https://www.destroyallsoftware.com/talks/wat
    func testWAT() throws {
        let ctx = JXContext()

        XCTAssertEqual(true, try ctx.eval(script: "[] + {}").isString)
        XCTAssertEqual("[object Object]", try ctx.eval(script: "[] + {}").stringValue)

        XCTAssertEqual(true, try ctx.eval(script: "[] + []").isString)
        XCTAssertEqual("", try ctx.eval(script: "[] + []").stringValue)

        XCTAssertEqual(true, try ctx.eval(script: "{} + {}").isNumber)
        XCTAssertEqual(true, try ctx.eval(script: "{} + {}").numberValue?.isNaN)

        XCTAssertEqual(true, try ctx.eval(script: "{} + []").isNumber)
        XCTAssertEqual(0.0, try ctx.eval(script: "{} + []").numberValue)

        XCTAssertEqual(true, try ctx.eval(script: "1.0 === 1.0000000000000001").booleanValue)

        XCTAssertEqual(1, try ctx.eval(script: "y = {}; y[[]] = 1; Object.keys(y)").array?.count)

        XCTAssertEqual(10, try ctx.eval(script: "['10', '10', '10'].map(parseInt)").array?.first?.numberValue)
        XCTAssertEqual("NaN", try ctx.eval(script: "['10', '10', '10'].map(parseInt)").array?.dropFirst().first?.stringValue)
        XCTAssertEqual(2, try ctx.eval(script: "['10', '10', '10'].map(parseInt)").array?.last?.numberValue)
    }
}

