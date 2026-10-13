// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CatusshDesign",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "CatusshDesign",
            targets: ["CatusshDesign"]
        ),
    ],
    targets: [
        .target(
            name: "CatusshDesign",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
