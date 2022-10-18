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

    func testProxy() throws {
        let jxc = JXContext()

        // create a proxy that acts as a map what sorted an uppercase form of the string
        let value: JXValue = try jxc.eval("""
        var proxyMap = new Proxy(new Map(), {
          // The 'get' function allows you to modify the value returned
          // when accessing properties on the proxy
          get: function(target, name) {
            if (name === 'set') {
              // Return a custom function for Map.set that sets
              // an upper-case version of the value.
              return function(key, value) {
                return target.set(key, value.toUpperCase());
              };
            }
            else {
              var value = target[name];
              // If the value is a function, return a function that
              // is bound to the original target. Otherwise the function
              // would be called with the Proxy as 'this' and Map
              // functions do not work unless the 'this' is the Map.
              if (value instanceof Function) {
                return value.bind(target);
              }
              // Return the normal property value for everything else
              return value;
            }
          }
        });

        proxyMap.set(0, 'foo');
        proxyMap.get(0);
        """)

        XCTAssertEqual("FOO", try value.string)
    }

    func testProxyProperties() throws {
        let ctx = JXContext()

        let dict = ctx.object()
        try dict.setProperty("x", ctx.string("abc"))
        try dict.setProperty("y", ctx.string("qrs"))

        // create a proxy that upper-cases all string property gets and lower-cases all property sets
        let proxy = try dict.proxy { ctx, this, args in
            let (obj, prop) = (args[0], args[1])
            return try ctx.string(obj[prop.string].string.uppercased())
        } set: { ctx, this, args in
            let (obj, prop, value) = (args[0], args[1], args[2])
            return try obj.setProperty(prop.string, ctx.string(value.string.lowercased()))
        }

        XCTAssertEqual("abc", try dict["x"].string)
        XCTAssertEqual("qrs", try dict["y"].string)

        XCTAssertEqual("ABC", try proxy["x"].string)
        XCTAssertEqual("QRS", try proxy["y"].string)

        try proxy.setProperty("z", ctx.string("YoLo"))
        XCTAssertEqual("YOLO", try proxy["z"].string)
        XCTAssertEqual("yolo", try dict["z"].string)
    }

    func testCustomConvertible() throws {
        let ctx = JXContext()

        let obj = ctx.object()
        let url = URL(string: "https://www.example.com")!
        try obj.setProperty("x", url.toJXCodable(in: ctx))
    }
}

/// An example of a custom type conforming to ``JXConvertible``
extension URL : JXConvertible {
    public func toJX(in context: JXContext) -> JXValue {
        context.string(self.absoluteString)
    }

    public static func fromJX(_ value: JXValue) throws -> Self {
        if let url = try URL(string: value.string) { return url }
        throw JXEvalError(context: value.context, value: value.context.string("Unable to create URL from string"))
    }
}
