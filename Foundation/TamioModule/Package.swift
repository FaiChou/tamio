// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TamioModule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "TamioModule",
            type: .static,
            targets: ["TamioModule"]
        ),
    ],
    dependencies: [
        .package(name: "PropertyWrapper", path: "../PropertyWrapper"),
        .package(name: "NSRemoteShell", path: "../../External/NSRemoteShell"),
        .package(name: "Keychain", path: "../Keychain"),
        .package(name: "TamioDesign", path: "../TamioDesign"),
    ],
    targets: [
        .target(
            name: "TamioModule",
            dependencies: [
                "PropertyWrapper",
                "NSRemoteShell",
                "Keychain",
                "TamioDesign",
            ]
        ),
        .testTarget(
            name: "TamioModuleTests",
            dependencies: ["TamioModule"]
        ),
    ]
)
