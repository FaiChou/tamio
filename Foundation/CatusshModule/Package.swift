// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CatusshModule",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "CatusshModule",
            type: .static,
            targets: ["CatusshModule"]
        ),
    ],
    dependencies: [
        .package(name: "PropertyWrapper", path: "../PropertyWrapper"),
        .package(name: "NSRemoteShell", path: "../../External/NSRemoteShell"),
        .package(name: "Keychain", path: "../Keychain"),
        .package(name: "CatusshDesign", path: "../CatusshDesign"),
    ],
    targets: [
        .target(
            name: "CatusshModule",
            dependencies: [
                "PropertyWrapper",
                "NSRemoteShell",
                "Keychain",
                "CatusshDesign",
            ]
        ),
        .testTarget(
            name: "CatusshModuleTests",
            dependencies: ["CatusshModule"]
        ),
    ]
)
