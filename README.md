# JXKit

[![Build Status][GitHubActionBadge]][ActionsLink]
[![Swift5 compatible][Swift5Badge]][Swift5Link] 
![Platform][SwiftPlatforms]
<!-- [![](https://tokei.rs/b1/github/jectivex/Jack)](https://github.com/jectivex/Jack) -->

A pure swift interface the `JavaScriptCore` C API with support for `Encodable` & `Decodable`.

Browse the [API Documentation].

This permits JSC to be used on platforms where the Objective-C runtime is unavailable (e.g., Linux).


## API

Browse the [API Documentation].

### Direct function invocation

Functions can be accessed (and cached) to be invoked directly with codable arguments:

```swift
let ctx = JXContext()
let hypot = try ctx.global["Math"]["hypot"]
assert(hypot.isFunction == true)
let result = try hypot.call(withArguments: try [ctx.encode(3), ctx.encode(4)])
let hypotValue = try result.numberValue
assert(hypotValue == 5)
```

### Codable passing

JXKit supports encoding and decoding Swift types directly into the `JXValue` instances, which enables `Codable`  instances to be passed back and forth to the virtual machine with minimal overhead. Since encoding & decoding doesn't use JSON `stringify` & `parse`, this can lead to considerable performance improvements when interfacing between Swift & JS.

The above invocation of `Math.hypot` can instead be performed by wrapping the arguments in an `Encodable` struct, and returning a `Decodable` value. 

```swift
/// An example of invoking `Math.hypot` in a wrapper function that takes an encodable argument and returns a Decodable retult.
struct AB : Encodable { let a, b: Double }
struct C : Decodable { let c: Double }

let ctx = JXContext()

let hypot = try ctx.eval("(function(args) { return { c: Math.hypot(args.a, args.b) }; })")
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

## License

Like the [JavaScriptCore](https://webkit.org/licensing-webkit/) framework
upon which it is built, JXKit is licensed under the GNU LGPL license.
See [LICENSE.LGPL](LICENSE.LGPL) for details.

## Related

Projects that are based on JXKit:

 - [Jack][]: Cross-platform framework for scripting `Combine.ObservableObject` and SwiftUI (LGPL)

## Dependencies

 - [JavaScriptCore][]: Cross-platform JavaScript engine (LGPL)[^1]

[^1]: JavaScriptCore is included with macOS and iOS as part of the embedded [WebCore](https://webkit.org/licensing-webkit/) framework (LGPL); on Linux JXKit uses [WebKit GTK JavaScriptCore](https://webkitgtk.org/).


[Swift Package Manager]: https://swift.org/package-manager
[API Documentation]: https://www.jective.org/Jack/documentation/jack/

[ProjectLink]: https://github.com/jectivex/Jack
[ActionsLink]: https://github.com/jectivex/Jack/actions
[API Documentation]: https://www.jective.org/Jack/documentation/jack/

[Swift]: https://swift.org/
[OpenCombine]: https://github.com/OpenCombine/OpenCombine
[Jack]: https://github.com/jectivex/Jack
[JXKit]: https://github.com/jectivex/JXKit
[JavaScriptCore]: https://trac.webkit.org/wiki/JavaScriptCore

[GitHubActionBadge]: https://img.shields.io/github/workflow/status/jectivex/Jack/Jack%20CI

[Swift5Badge]: https://img.shields.io/badge/swift-5-orange.svg?style=flat
[Swift5Link]: https://developer.apple.com/swift/
[SwiftPlatforms]: https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20Linux-teal.svg

