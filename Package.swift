// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BlurHashKit",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .library(
            name: "BlurHashKit",
            targets: ["BlurHashKit"]
        ),
    ],
    targets: [
        .target(
            name: "BlurHashKit",
            dependencies: []
        ),
    ]
)
