// swift-tools-version:5.3

import PackageDescription

#if os(Linux)
let linux = true
#else
let linux = false
#endif

let package = Package(
    name: "JXKit",
    products: [
        .library(name: "JXKit", targets: ["JXKit"]),
    ],
    targets:
        (!linux ? [ .target(name: "JXKit") ]
            : [ .target(name: "CJSCore"),
                .target(name: "JXKit", dependencies: [ "CJSCore" ],
                        cSettings: [ .unsafeFlags(["-I/usr/include/webkitgtk-4.0"]) ]
                )
            ]) + [
                .testTarget(
                    name: "JXKitTests",
                    dependencies: ["JXKit"]
                )
            ]
)
