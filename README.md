# JXKit

[![Build Status](https://github.com/jectivex/JXKit/workflows/JXKit%20CI/badge.svg?branch=main)](https://github.com/jectivex/JXKit/actions)
[![Swift Package Manager compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![Platform](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20Linux-lightgrey.svg)](https://github.com/jectivex/JXKit)
[![](https://tokei.rs/b1/github/jectivex/JXKit)](https://github.com/jectivex/JXKit)

A pure swift interface the `JavaScriptCore` C API with support for `Encodable` & `Decodable`.

Browse the [API Documentation](https://www.jective.org/docs/JXKit/).

This permits JSC to be used on platforms where the Objective-C runtime is unavailable (e.g., Linux).


## API

Browse the [API Documentation].

### Direct function invocation

Functions can be accessed (and cached) to be invoked directly with codable arguments:

```swift
let ctx = JXContext()
let hypot = ctx["Math"]["hypot"]
assert(hypot.isFunction == true)
let result = hypot.call(withArguments: try [ctx.encode(3), ctx.encode(4)])
assert(result.numberValue == 5)
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
assert(hypot.isFunction == true)

let result: C = try hypot.call(withArguments: [ctx.encode(AB(a: 3, b: 4))]).toDecodable(ofType: C.self)
assert(result.c == 5)
```

### JavaScriptCore Compatibility

The JXKit API is a mostly drop-in replacement for the Objective-C `JavaScriptCore` framework available on most Apple devices. E.g., the following JavaScriptCore code:

```swift
import JavaScriptCore

let jsc = JSContext()
let value: JSValue = jsc.evaluateScript("1+2")
assert(value.doubleValue == 3)
```

becomes:

```swift
import JXKit

let jxc = JXContext()
let value: JXValue = try jxc.eval("1+2")
assert(try value.numberValue == 3)
```

## Installation

> _Note:_ Requires Swift 5.5+

### Swift Package Manager

The [Swift Package Manager][] is a tool for managing the distribution of
Swift code.

1. Add the following to your `Package.swift` file:

  ```swift
  // swift-tools-version:5.6
  import PackageDescription

  let package = Package(
      name: "MyPackage",
      products: [
          .library(
              name: "MyPackage",
              targets: ["MyPackage"]),
      ],
      dependencies: [
          .package(name: "JXKit", url: "https://github.com/jectivex/JXKit.git", .upToNextMajor(from: "2.0")),
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
[API Documentation]: https://www.jective.org/JXKit/documentation/jxkit/


