# Building and Testing

`MarkdownEditor` is an iOS UIKit-based package, so build and test workflows should run through Xcode tooling.

## Recommended build flow (`xcb`)

- List available schemes:
  - `xcb schemes --package-dir .`
  - `xcb schemes --project Demo/MarkdownEditor.xcodeproj`
- Build the package targets:
  - `xcb pkg`
  - `xcb pkg-lexical`
- Build and run the demo app:
  - `xcb demo`
  - If a specific simulator isn’t available, use a generic destination:
    `xcb demo --destination "generic/platform=iOS Simulator"`

## Alternative (Xcode)

- Framework + tests: open `Demo/MarkdownEditor.xcodeproj` or `.swiftpm/xcode/package.xcworkspace` and run the `MarkdownEditor` test target.
- Demo app: open `Demo/MarkdownEditor.xcodeproj` and run the `MarkdownEditorDemo` scheme.

## Dependency notes

The default package dependency is remote:
- `https://github.com/jcfontecha/lexical-ios.git`

For deep Lexical work, temporarily switch to a local checkout in `Package.swift` with:
- `.package(path: "../lexical-ios")`

Restore the remote dependency before committing release-facing changes.
