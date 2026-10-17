// swift-tools-version: 5.9
import PackageDescription

/// The remote file editor: Runestone (UIKit, so iOS and Mac Catalyst) with
/// tree-sitter highlighting for the languages found on servers.
let package = Package(
    name: "TamioEditor",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "TamioEditor", targets: ["TamioEditor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/simonbs/Runestone", exact: "0.5.2"),
        .package(url: "https://github.com/simonbs/TreeSitterLanguages", exact: "0.1.10"),
        .package(name: "TamioDesign", path: "../TamioDesign"),
    ],
    targets: [
        .target(
            name: "TamioEditor",
            dependencies: [
                .product(name: "Runestone", package: "Runestone"),
                .product(name: "TamioDesign", package: "TamioDesign"),
                .product(name: "TreeSitterBashRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterJSONRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterYAMLRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterTOMLRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterPythonRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterJavaScriptRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterTypeScriptRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterGoRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterRustRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterCRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterCPPRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterLuaRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterRubyRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterPHPRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterPerlRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterHTMLRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterCSSRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterMarkdownRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterSQLRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterJavaRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterSwiftRunestone", package: "TreeSitterLanguages"),
            ]
        ),
        .testTarget(name: "TamioEditorTests", dependencies: ["TamioEditor"]),
    ]
)
