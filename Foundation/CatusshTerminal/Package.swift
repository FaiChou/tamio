// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CatusshTerminal",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "CatusshTerminal", targets: ["CatusshTerminal"]),
        .executable(name: "CatusshConfigurationPreview", targets: ["CatusshConfigurationPreview"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Lakr233/libghostty-spm.git", exact: "2.2.2026100703"),
        .package(name: "CatusshDesign", path: "../CatusshDesign"),
    ],
    targets: [
        .target(
            name: "CatusshTerminal",
            dependencies: [
                .product(name: "GhosttyTerminal", package: "libghostty-spm"),
                .product(name: "CatusshDesign", package: "CatusshDesign"),
            ],
            resources: [.process("Configuration/Resources")]
        ),
        .testTarget(name: "CatusshTerminalTests", dependencies: ["CatusshTerminal"]),
        .executableTarget(name: "CatusshConfigurationPreview", dependencies: ["CatusshTerminal"]),
    ]
)
