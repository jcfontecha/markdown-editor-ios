    // swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let localLexicalPath = "../lexical-ios"
let useRemoteLexical = ProcessInfo.processInfo.environment["MARKDOWNEDITOR_USE_REMOTE_LEXICAL"] == "1"
    || !FileManager.default.fileExists(atPath: localLexicalPath)

let lexicalDependency: Package.Dependency = {
    if useRemoteLexical {
        return .package(url: "https://github.com/jcfontecha/lexical-ios.git", revision: "5a153661f143780a45e22b4c5ec624842b9806e8")
    }
    return .package(path: localLexicalPath)
}()

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
        lexicalDependency,
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
