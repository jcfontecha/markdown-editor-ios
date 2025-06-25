// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarkdownEditor",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MarkdownEditor",
            targets: ["MarkdownEditor"]),
    ],
    dependencies: [
        .package(path: "../lexical-ios"),
        .package(url: "https://github.com/microsoft/fluentui-apple.git", from: "0.17.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MarkdownEditor",
            dependencies: [
                .product(name: "Lexical", package: "lexical-ios", condition: .when(platforms: [.iOS])),
                .product(name: "LexicalListPlugin", package: "lexical-ios", condition: .when(platforms: [.iOS])),
                .product(name: "LexicalLinkPlugin", package: "lexical-ios", condition: .when(platforms: [.iOS])),
                .product(name: "LexicalMarkdown", package: "lexical-ios", condition: .when(platforms: [.iOS])),
                .product(name: "FluentUI", package: "fluentui-apple", condition: .when(platforms: [.iOS]))
            ]
        ),
        .testTarget(
            name: "MarkdownEditorTests",
            dependencies: ["MarkdownEditor"]
        ),
    ]
)
