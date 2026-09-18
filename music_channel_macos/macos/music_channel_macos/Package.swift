// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "music_channel_macos",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .library(name: "music-channel-macos", targets: ["music_channel_macos"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "music_channel_macos",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ]
        ),
    ]
)
