#if DEBUG // Needed for @testable import
#if canImport(Foundation)
@testable import JXKit
import XCTest

final class ScriptManagerTests: XCTestCase {
    func testModuleScriptString() throws {
        try moduleScriptTest(fromResource: false)
    }
    
    func testModuleScriptResource() throws {
        try moduleScriptTest(fromResource: true)
    }
    
    private func moduleScriptTest(fromResource: Bool) throws {
        let context = JXContext()
        let exports = try fromResource ? context.evalModule(resource: "/jsmodules/module1", root: Bundle.module.resourceURL!) : context.evalModule(module1JS)
        
        XCTAssertFalse(context.global.hasProperty("module"))
        XCTAssertFalse(context.global.hasProperty("name"))
        XCTAssertFalse(context.global.hasProperty("getNameFunction"))
        XCTAssertFalse(context.global.hasProperty("getName"))
        XCTAssertFalse(context.global.hasProperty("NameTypeClass"))
        XCTAssertFalse(context.global.hasProperty("NameType"))
        XCTAssertFalse(context.global.hasProperty("privateName"))
        
        XCTAssertFalse(exports.hasProperty("name"))
        XCTAssertFalse(exports.hasProperty("getNameFunction"))
        XCTAssertTrue(exports.hasProperty("getName"))
        let name = try exports["getName"].call()
        XCTAssertEqual(try name.string, "foo")
        XCTAssertFalse(exports.hasProperty("NameTypeClass"))
        XCTAssertTrue(exports.hasProperty("NameType"))
        XCTAssertFalse(exports.hasProperty("privateName"))
        
        try context.global.integrate(exports)
        let result = try context.eval("const obj = new NameType(); obj.getClassName()")
        XCTAssertEqual(try result.string, "classprivatefoo")
    }
    
    func testRequireFromString() throws {
        let context = JXContext()
        let result = try context.eval("const m2 = require('/jsmodules/module2'); m2.getName2();", root: Bundle.module.resourceURL!)
        XCTAssertEqual(try result.string, "foo2")
    }
    
    func testRequireFromResource() throws {
        let context = JXContext()
        let exports = try context.evalModule(resource: "/jsmodules/module2", root: Bundle.module.resourceURL!)

        XCTAssertFalse(exports.hasProperty("getName"))
        XCTAssertFalse(exports.hasProperty("NameType"))
        XCTAssertTrue(exports.hasProperty("getName2"))
        let result = try exports["getName2"].call()
        XCTAssertEqual(try result.string, "foo2")
    }
}

private var module1JS = (try? String(contentsOf: Bundle.module.url(forResource: "jsmodules/module1", withExtension: "js")!)) ?? ""
#endif
#endif
