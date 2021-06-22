// swift-tools-version:5.3

import PackageDescription

#if os(Linux)
let targets: [Target] = [
    .systemLibrary(name: "CJSCore", pkgConfig: "javascriptcoregtk-4.0", providers: [.apt(["libjavascriptcoregtk-4.0-dev"])]),
    .target(name: "JXKit", dependencies: ["CJSCore"]),
    .testTarget(name: "JXKitTests", dependencies: ["JXKit"])
]
#else
let targets: [Target] = [
    .target(name: "JXKit"),
    .testTarget(name: "JXKitTests", dependencies: ["JXKit"])
]
#endif

//.unsafeFlags(["-I/usr/include/webkitgtk-4.0"])

let package = Package(
    name: "JXKit",
    products: [
        .library(name: "JXKit", targets: ["JXKit"]),
    ],
    targets: targets
)
