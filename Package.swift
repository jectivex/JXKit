// swift-tools-version:5.3

import PackageDescription

#if os(Linux) || os(Windows)
let useCJSCore = true
#else
let useCJSCore = false
#endif

let package = Package(
    name: "JXKit",
    products: [
        .library(name: "JXKit", targets: ["JXKit"]),
    ],
    targets:
        (!useCJSCore
            ? [ .target(name: "JXKit") ]
            : [ .systemLibrary(name: "CJSCore", pkgConfig: "libjavascriptcoregtk-4.0-dev", providers: [.brew(["libjavascriptcoregtk-4.0-dev"]), .apt(["libjavascriptcoregtk-4.0-dev"])]),
                .target(name: "JXKit", dependencies: [ "CJSCore" ],
                    cSettings: [
                        .unsafeFlags(["-I/usr/include/webkitgtk-4.0"])
                    ]
                )
        ]) + [
            .testTarget(
                name: "JXKitTests",
                dependencies: ["JXKit"]
            )
        ]
)
