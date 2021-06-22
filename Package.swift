// swift-tools-version:5.4

import PackageDescription

#if canImport(JavaScriptCore)
let targets: [Target] = [
    .target(name: "JXKit"),
    .testTarget(name: "JXKitTests", 
        dependencies: ["JXKit"])
]
#else // no native JavaScriptCore falls back to javascriptcoregtk
let targets: [Target] = [
    .systemLibrary(name: "CJSCore", 
        pkgConfig: "javascriptcoregtk-4.0", 
        providers: [.apt(["libjavascriptcoregtk-4.0-dev"])]),
    .target(name: "JXKit", 
        dependencies: ["CJSCore"]),
    .testTarget(name: "JXKitTests", 
        dependencies: ["JXKit"])
]
#endif

let package = Package(
    name: "JXKit",
    products: [
        .library(name: "JXKit", targets: ["JXKit"]),
    ],
    targets: targets
)
