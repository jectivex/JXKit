# JXKit

A pure swift interface the `JavaScriptCore` C API with support for `Encodable` & `Decodable`.

This permits JSC to be used on platforms where the Objective-C runtime is unavailable (e.g., Linux).


## API

### Direct function access

Functions can be accessed (and cached), and invoked directly with codable arguments:

```swift
let ctx = JXContext()
let hypot = ctx["Math"]["hypot"]
XCTAssert(hypot.isFunction)
let result = hypot.call(withArguments: try [ctx.encode(3), ctx.encode(4)])
XCTAssertEqual(5, result.doubleValue)
```

### Codable passing

JXKit supports encoding and decoding Swift types directly into the `JXValue` instances, which enables `Codable`  instances to be passed back and forth to the virtual machine with minimal overhead. Since encoding & decoding doesn't use JSON `stringify` & `parse`, this can lead to considerable performance improvements when interfacing between Swift & JS.

The above invocation of `Math.hypot` can instead be performed by wrapping the arguments in an `Encodable` struct, and returning a `Decodable` value. 

```swift
/// An example of invoking `Math.hypot` in a wrapper function that takes an encodable argument and returns a Decodable retult.
struct AB : Encodable { let a, b: Double }
struct C : Decodable { let c: Double }

let ctx = JXContext()

let hypot = try ctx.eval(script: "(function(args) { return { c: Math.hypot(args.a, args.b) }; })")
XCTAssert(hypot.isFunction)

let result: C = try hypot.call(withArguments: [ctx.encode(AB(a: 3, b: 4))]).toDecodable(ofType: C.self)
XCTAssertEqual(5, result.c)
```

### JavaScriptCore Compatibility

The JXKit API is a mostly drop-in replacement for the Objective-C `JavaScriptCore` framework available on most Apple devices. E.g., the following JavaScriptCore code:

```swift
import JavaScriptCore

let ctx = JSContext()
let value: JXValue = ctx.evaluateScript("1+2")
XCTAssertEqual(3, value.doubleValue)
```

becomes:

```swift
import JXKit

let ctx = JXContext()
let value: JXValue = ctx.evaluateScript("1+2")
XCTAssertEqual(3, value.doubleValue)
```


## Installation

> _Note:_ Requires Swift 5.3+

### Swift Package Manager

The [Swift Package Manager][] is a tool for managing the distribution of
Swift code.

1. Add the following to your `Package.swift` file:

  ```swift
  // swift-tools-version:5.3
  import PackageDescription

  let package = Package(
      name: "MyPackage",
      products: [
          .library(
              name: "MyPackage",
              targets: ["MyPackage"]),
      ],
      dependencies: [
          .package(name: "JXKit", url: "https://github.com/jectivex/JXKit.git", .upToNextMajor(from: "1.0")),
      ],
      targets: [
          .target(
              name: "MyPackage",
              dependencies: ["JXKit"]),
              .testTarget(
                  name: "MyPackageTests",
                  dependencies: ["MyPackage"]),
          ]
      )
  ```

2. Build your project:

  ```sh
  $ swift build
  ```

[Swift Package Manager]: https://swift.org/package-manager
