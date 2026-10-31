// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Router",
	platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(
            name: "RouterCore",
            targets: ["RouterCore"]
        ),
        .library(
            name: "RouterUI",
            targets: ["RouterUI"]
        ),
    ],
    targets: [
        .target(
            name: "RouterCore"
        ),
        .target(
            name: "RouterUI",
            dependencies: ["RouterCore"]
        ),
        .testTarget(
            name: "RouterCoreTests",
            dependencies: ["RouterCore"]
        ),
        .testTarget(
            name: "RouterUITests",
            dependencies: ["RouterUI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
