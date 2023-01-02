#if DEBUG // Needed for @testable import
import Foundation
@testable import JXKit
import XCTest

let rootURL = URL(string: "file:///tmp")!

final class DynamicReloadTests: XCTestCase {
    private var context: JXContext!
    private var scriptLoader: TestScriptLoader!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.scriptLoader = TestScriptLoader()
        self.context = JXContext(configuration: .init(scriptLoader: self.scriptLoader))
    }
    
    func testReloadScript() throws {
        let url = try scriptLoader.scriptURL(resource: "test", relativeTo: nil, root: rootURL)
        scriptLoader.scripts["test"] = """
exports.add = function(x) {
    return x + 1;
}
"""
        let script = "const m = require('/test'); return m.add(2);"
        var result = try context.evalClosure(script, root: rootURL)
        XCTAssertEqual(try result.int, 3);
        
        scriptLoader.scripts["test"] = """
exports.add = function(x) {
    return x + 2;
}
"""
        scriptLoader.didChange?.forEach { $0([url]) }
        result = try context.evalClosure(script, root: rootURL)
        XCTAssertEqual(try result.int, 4);
    }
    
    func testDependentModuleReload() throws {
        let url = try scriptLoader.scriptURL(resource: "test", relativeTo: nil, root: rootURL)
        scriptLoader.scripts["test"] = """
exports.add = function(x) {
    return x + 1;
}
"""
        scriptLoader.scripts["module"] = """
const m = require('/test')
exports.transform = function(x) {
    return m.add(x) * 2;
}
"""
        let script = "const m = require('/module'); return m.transform(2);"
        var result = try context.evalClosure(script, root: rootURL)
        XCTAssertEqual(try result.int, 6);
        
        scriptLoader.scripts["test"] = """
exports.add = function(x) {
    return x + 2;
}
"""
        scriptLoader.didChange?.forEach { $0([url]) }
        result = try context.evalClosure(script, root: rootURL)
        XCTAssertEqual(try result.int, 8);
    }
}

private class TestScriptLoader: JXScriptLoader {
    var scripts: [String: String] = [:]
    
    let didChange: JXListenerCollection<(Set<URL>) -> Void>? = JXListenerCollection<(Set<URL>) -> Void>()
    
    func scriptURL(resource: String, relativeTo: URL?, root: URL) throws -> URL {
        return root.appendingPathComponent(resource, isDirectory: false)
    }
    
    func loadScript(from url: URL) throws -> String? {
        let path = url.lastPathComponent
        guard let script = scripts[path] else {
            throw JXError(message: "Unknown script \(path)")
        }
        return script
    }
}
#endif
