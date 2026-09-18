// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "music_channel_ios",
    platforms: [
        .iOS("26.0"),
    ],
    products: [
        .library(name: "music-channel-ios", targets: ["music_channel_ios"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "music_channel_ios",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "Sources/music_channel_ios"
        ),
    ]
)
