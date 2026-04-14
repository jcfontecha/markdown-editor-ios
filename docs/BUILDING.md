# Building and Testing

`MarkdownEditor` is an iOS UIKit-based package, so build and test workflows should run through Xcode tooling.

## Recommended build flow (`make`)

- Build the package target:
  - `make build markdown-editor`
- Build the demo app for iOS Simulator:
  - `make build demo-app`
- Build both when you want a broader compile check:
  - `make build`
- Use verbose logs when you need rawer `xcodebuild` output:
  - `make build demo-app --verbose`

## Alternative (Xcode)

- Framework + tests: open `Demo/MarkdownEditor.xcodeproj` or `.swiftpm/xcode/package.xcworkspace` and run the `MarkdownEditor` test target.
- Demo app: open `Demo/MarkdownEditor.xcodeproj` and run the `MarkdownEditorDemo` scheme.

## Dependency notes

The default package dependency is remote:
- `https://github.com/jcfontecha/lexical-ios.git`

For deep Lexical work, temporarily switch to a local checkout in `Package.swift` with:
- `.package(path: "../lexical-ios")`

Restore the remote dependency before committing release-facing changes.
