## Repo context (MarkdownEditor)

This repo is an iOS-focused Swift Package + demo app that wraps/extends **Lexical (lexical-ios)**. Most “editor engine” behavior (nodes, selection, commands, plugins) ultimately comes from Lexical, and this repo primarily provides the MarkdownEditor API surface + integrations on top.

### Where the code lives

- Package code (the library you import): `Sources/MarkdownEditor/`
- Package tests: `Tests/MarkdownEditorTests/`
- Demo app project: `Demo/MarkdownEditor.xcodeproj` (scheme: `MarkdownEditorDemo`)

### Heavy dependency: `lexical-ios`

The Swift package has a **path dependency** on Lexical:

- `Package.swift` includes `.package(path: "../lexical-ios")`
- The Lexical source is **not in this repo**; it’s expected at `../lexical-ios` (sibling directory to this repo).

If you need to inspect/modify core editor behavior, you’ll usually be working in `../lexical-ios` rather than here.

## Building (recommended: `xcb`)

This repo is configured with `xcb.json` so you can build by scheme/id without remembering container paths.

Common commands:

- List schemes
  - `xcb schemes --project Demo/MarkdownEditor.xcodeproj`
  - `xcb schemes --package-dir .`
- Build demo app (iOS simulator)
  - `xcb demo`
- Build package targets (generic iOS)
  - `xcb pkg`
  - `xcb pkg-lexical`

Open in Xcode:

- `xcb open` (default)
- `xcb open demo`
- `xcb open pkg`

Notes:

- If your machine doesn’t have an `iPhone 15` simulator runtime, prefer a generic simulator destination (see `xcb.json`), or override with `xcb demo --destination "generic/platform=iOS Simulator"`.
