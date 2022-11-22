# JXKit

[![Build Status][GitHubActionBadge]][ActionsLink]
[![Swift5 compatible][Swift5Badge]][Swift5Link] 
![Platform][SwiftPlatforms]
<!-- [![](https://tokei.rs/b1/github/jectivex/JXKit)](https://github.com/jectivex/JXKit) -->

JXKit is a cross-plarform swift module for interfacing with
`JavaScriptCore`. It provides a fluent API for working with an embedded
[`JXContext`](https://www.jective.org/JXKit/documentation/jxkit/jxcontext),
including script evaluation, error handling, and Codable mashalling.

JXKit is cross-platform for Darwin (macOS/iOS) and Linux,
with experimental support for Windows and Android.

JSC to be used on platforms where the Objective-C runtime is unavailable (e.g., Linux).


## API

Browse the [API Documentation].

### Direct function invocation

Functions can be accessed (and cached) to be invoked directly with codable arguments:

```swift
let context = JXContext()
let hypot = try context.global["Math"]["hypot"]
assert(hypot.isFunction == true)
let result = try hypot.call(withArguments: try [context.encode(3), context.encode(4)])
let hypotValue = try result.double
assert(hypotValue == 5.0)
```

### Codable passing

JXKit supports encoding and decoding Swift types directly into the `JXValue` instances, which enables `Codable`  instances to be passed back and forth to the virtual machine with minimal overhead. Since encoding & decoding doesn't use JSON `stringify` & `parse`, this can lead to considerable performance improvements when interfacing between Swift & JS.

The above invocation of `Math.hypot` can instead be performed by wrapping the arguments in an `Encodable` struct, and returning a `Decodable` value. 

```swift
/// An example of invoking `Math.hypot` in a wrapper function that takes an encodable argument and returns a Decodable retult.
struct AB: Encodable { let a, b: Double }
struct C: Decodable { let c: Double }

let context = JXContext()

let hypot = try context.eval("(function(args) { return { c: Math.hypot(args.a, args.b) }; })")
assert(hypot.isFunction == true)

let result: C = try hypot.call(withArguments: [context.encode(AB(a: 3, b: 4))]).toDecodable(ofType: C.self)
assert(result.c == 5)
```

### JavaScriptCore Compatibility

The JXKit API is a mostly drop-in replacement for the Objective-C `JavaScriptCore` framework available on most Apple devices. E.g., the following JavaScriptCore code:

```swift
import JavaScriptCore

let jsc = JSContext()
let value: JSValue = jsc.evaluateScript("1+2")
assert(value.int == 3)
```

becomes:

```swift
import JXKit

let jxc = JXContext()
let value: JXValue = try jxc.eval("1+2")
assert(try value.int == 3)
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
          .package(name: "JXKit", url: "https://github.com/jectivex/JXKit.git", .upToNextMajor(from: "3.0.0")),
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
[API Documentation]: https://www.jective.org/JXKit/documentation/jxkit/

[ProjectLink]: https://github.com/jectivex/JXKit
[ActionsLink]: https://github.com/jectivex/JXKit/actions
[API Documentation]: https://www.jective.org/JXKit/documentation/jxkit/

[Swift]: https://swift.org/
[OpenCombine]: https://github.com/OpenCombine/OpenCombine
[JXBridge]: https://github.com/jectivex/JXBridge
[JavaScriptCore]: https://trac.webkit.org/wiki/JavaScriptCore

[GitHubActionBadge]: https://img.shields.io/github/workflow/status/jectivex/JXKit/JXKit%20CI

[Swift5Badge]: https://img.shields.io/badge/swift-5-orange.svg?style=flat
[Swift5Link]: https://developer.apple.com/swift/
[SwiftPlatforms]: https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20Linux-teal.svg

## TODO

- Better reporting of errors from async code / Promises.
- Async-save version of `JXContext.withValues`.
