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

        XCTAssertEqual(",,,,,,,,,,,,,,,", try jxc.eval("Array(16)").string)
        XCTAssertEqual("watwatwatwatwatwatwatwatwatwatwatwatwatwatwat", try jxc.eval("Array(16).join('wat')").string)
        XCTAssertEqual("wat1wat1wat1wat1wat1wat1wat1wat1wat1wat1wat1wat1wat1wat1wat1", try jxc.eval("Array(16).join('wat' + 1)").string)
        XCTAssertEqual("NaNNaNNaNNaNNaNNaNNaNNaNNaNNaNNaNNaNNaNNaNNaN Batman!", try jxc.eval("Array(16).join('wat' - 1) + ' Batman!'").string)

        XCTAssertEqual(1, try jxc.eval("let y = {}; y[[]] = 1; Object.keys(y)").array.count)

        XCTAssertEqual(10, try jxc.eval("['10', '10', '10'].map(parseInt)").array.first?.double)
        XCTAssertEqual("NaN", try jxc.eval("['10', '10', '10'].map(parseInt)").array.dropFirst().first?.string)
        XCTAssertEqual(2, try jxc.eval("['10', '10', '10'].map(parseInt)").array.last?.double)

        XCTAssertEqual("Ƕe110", try jxc.eval(#"'Ƕ'+"e"+1+1+0"#).string)
    }

    /// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat/NumberFormat
    func testIntl() throws {
        let jxc = JXContext()

        XCTAssertEqual("12,34 €", try jxc.eval("new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(12.34)").string)
        XCTAssertEqual("65.4", try jxc.eval("new Intl.NumberFormat('en-IN', { maximumSignificantDigits: 3 }).format(65.4321)").string)

        let yen = "new Intl.NumberFormat('ja-JP', { style: 'currency', currency: 'JPY' }).format(45.678)"
        // I'm guessing these are different values because they use combining marks differently
#if os(Linux)
        XCTAssertEqual("￥46", try jxc.eval(yen).string)
#else
        XCTAssertEqual("¥46", try jxc.eval(yen).string)
#endif

        XCTAssertEqual("10/24/2022", try jxc.eval("new Intl.DateTimeFormat('en-US', {timeZone: 'UTC'}).format(new Date('2022-10-24'))").string)
        XCTAssertEqual("24/10/2022", try jxc.eval("new Intl.DateTimeFormat('fr-FR', {timeZone: 'UTC'}).format(new Date('2022-10-24'))").string)


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
        
        XCTAssertTrue(proxy.isObject)
    }

    func testCustomConvertible() throws {
        let ctx = JXContext()

        let obj = ctx.object()
        let url = URL(string: "https://www.example.com")!
        try obj.setProperty("x", url.toJX(in: ctx))
    }
}

/// An example of a custom type conforming to ``JXConvertible``
extension URL : JXConvertible {
    public func toJX(in context: JXContext) -> JXValue {
        context.string(self.absoluteString)
    }

    public static func fromJX(_ value: JXValue) throws -> Self {
        if let url = try URL(string: value.string) { return url }
        throw JXError(message: "Unable to create URL from value '\(value)'")
    }
}
