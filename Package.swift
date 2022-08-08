// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "BlurHashKit",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v4),
    ],
    products: [
        .library(
            name: "BlurHashKit",
            targets: ["BlurHashKit"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BlurHashKit",
            dependencies: []
        ),
    ]
)
