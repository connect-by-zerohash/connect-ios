// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "ConnectSDK",
            targets: ["ConnectSDK"]),
    ],
    targets: [
        .target(
            name: "ConnectSDK"),
        .testTarget(
            name: "ConnectSDKTests",
            dependencies: ["ConnectSDK"]
        ),
    ]
)
