# JXKit

A pure swift interface the `JavaScriptCore` C API with support for `Codable`.

This permits JSC to be used on platforms where the Objective-C runtime is unavailable (e.g., Linux).

The API is a mostly drop-in replacement. E.g.:

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

JXKit also supports encoding and decoding Swift types directly into the `JXValue` instances, which enables `Codable`  instances to be passed back and forth to the virtual machine with minimal overhead. Since encoding & decoding doesn't use JSON `stringify` & `parse`, this can lead to considerable performance improvements when interfacing between Swift & JS.

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
          .package(name: "JXKit", url: "https://github.com/jectivex/JXKit.git", .branch("main")),
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
