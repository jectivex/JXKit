// swift-tools-version:5.3

import PackageDescription

#if canImport(JavaScriptCore)
let targets: [Target] = [
    .target(name: "JXKit"),
    .testTarget(name: "JXKitTests", dependencies: ["JXKit"])
]
#else
let targets: [Target] = [
    .systemLibrary(name: "CJSCore", pkgConfig: "webkitgtk", providers: [.brew(["webkitgtk"]), .apt(["webkitgtk"])]),
    .target(name: "JXKit", dependencies: ["CJSCore"], cSettings: [.define("_GNU_SOURCE", to: "1")]),
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
