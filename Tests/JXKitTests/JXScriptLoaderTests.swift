#if DEBUG // Needed for @testable import
#if canImport(Foundation)
import XCTest
@testable import JXKit

final class JXScriptLoaderTests: XCTestCase {
    func testURLStandardization() throws {
        let loader = DefaultScriptLoader()
        let rootURL = URL(string: "file:///tmp/test")!
        let url1 = try loader.scriptURL(resource: "/dir/r1", relativeTo: nil, root: rootURL)
        let url2 = try loader.scriptURL(resource: "./r1", relativeTo: url1, root: rootURL)
        XCTAssertEqual(url1, url2)
        let url3 = try loader.scriptURL(resource: "../dir/r1", relativeTo: url1, root: rootURL)
        XCTAssertEqual(url1, url3)
    }
}
#endif
#endif
