// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "APIClient",

    platforms: [
        .macOS(.v11), .iOS(.v15), .tvOS(.v15), .watchOS(.v8)
    ],

    products: [
        .library(name: "APIClient", targets: ["APIClient"])
    ],

    targets: [
        .target(name: "APIClient", dependencies: []),
        .testTarget(name: "APIClientTests", dependencies: ["APIClient"])
    ]
)
