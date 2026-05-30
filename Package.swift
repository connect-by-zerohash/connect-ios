// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectSDK",
    platforms: [
        .iOS("17.4")
    ],
    products: [
        .library(
            name: "ConnectSDK",
            targets: ["ConnectSDK"]),
    ],
    targets: [
        .target(
            name: "ConnectSDK",
            resources: [.copy("PrivacyInfo.xcprivacy")]),
        .testTarget(
            name: "ConnectSDKTests",
            dependencies: ["ConnectSDK"]
        ),
    ]
)
