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
            resources: [
                .copy("PrivacyInfo.xcprivacy"),
                .process("Resources/Media.xcassets"),
                .process("Automation/dom-helpers.js"),
                .process("Platforms/Coinbase/auth-status.js"),
                .process("Platforms/Coinbase/auth-passkey-only.js"),
                .process("Platforms/Coinbase/auth-signup.js"),
                .process("Platforms/Coinbase/auth-hide-social.js"),
                .process("Platforms/Coinbase/auth-prefer-password.js"),
                .process("Platforms/Coinbase/get-deposit-address.js"),
                .process("Platforms/Coinbase/get-balance.js"),
                .process("Platforms/Coinbase/coinbase-balance-queries.js"),
                .process("Platforms/Coinbase/withdraw.js")
            ]),
        .testTarget(
            name: "ConnectSDKTests",
            dependencies: ["ConnectSDK"]
        ),
    ]
)
