// swift-tools-version:5.3

import PackageDescription

#if canImport(JavaScriptCore)
let targets: [Target] = [
    .target(name: "JXKit")
]
#elseif os(Windows)
// Windows iTunes installs JSC at: C:/Program Files/iTunes/JavaScriptCore.dll
let targets: [Target] = [
    .target(name: "JXKit", 
        linkerSettings: [
            .linkedLibrary("Kernel32", .when(platforms: [.windows])),
            .linkedLibrary("JavaScriptCore", .when(platforms: [.windows])),
        ])
]
#else // no native JavaScriptCore falls back to javascriptcoregtk
let targets: [Target] = [
    .systemLibrary(name: "CJSCore", 
        pkgConfig: "javascriptcoregtk-4.0", 
        providers: [.apt(["libjavascriptcoregtk-4.0-dev"])]),
    .target(name: "JXKit", dependencies: ["CJSCore"])
]
#endif

let package = Package(
    name: "JXKit",
    products: [
        .library(name: "JXKit", targets: ["JXKit"]),
    ],
    targets: targets + [
        .testTarget(name: "JXKitTests", 
            dependencies: ["JXKit"])
    ]
)
