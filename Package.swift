// swift-tools-version:5.6

import PackageDescription

#if canImport(JavaScriptCore)
let targets: [Target] = [
    .target(name: "JXKit", resources: [.process("Resources")])
]
#elseif os(Windows)
// Windows iTunes installs JSC at: C:/Program Files/iTunes/JavaScriptCore.dll
// See also: https://pub.dev/packages/flutter_jscore#windows
let targets: [Target] = [
    .target(name: "JXKit", 
        linkerSettings: [
            .linkedLibrary("Kernel32", .when(platforms: [.windows])),
            .linkedLibrary("JavaScriptCore", .when(platforms: [.windows])),
            .linkedLibrary("CoreFoundation", .when(platforms: [.windows])),
            .linkedLibrary("WTF", .when(platforms: [.windows])),
            .linkedLibrary("ASL", .when(platforms: [.windows])),
        ])
]
#else // No native JavaScriptCore falls back to javascriptcoregtk
let targets: [Target] = [
    .systemLibrary(name: "CJSCore", 
        pkgConfig: "javascriptcoregtk-4.1", 
        providers: [.apt(["libjavascriptcoregtk-4.1-dev"]), .yum(["webkit2gtk"])]),
    .target(name: "JXKit", dependencies: ["CJSCore"], resources: [.process("Resources")])
]
#endif

let package = Package(
    name: "JXKit",
    platforms: [ .macOS(.v10_15), .iOS(.v13), .tvOS(.v13) ],
    products: [
        .library(name: "JXKit", targets: ["JXKit"]),
    ],
    dependencies: [ .package(name: "swift-docc-plugin", url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"), 
    ],
    targets: targets + [
        .testTarget(name: "JXKitTests", dependencies: ["JXKit"], resources: [.copy("jsmodules")])
    ]
)
