## Repo context (MarkdownEditor)

This repo is an iOS-focused Swift Package + demo app that wraps/extends **Lexical (lexical-ios)**. Most “editor engine” behavior (nodes, selection, commands, plugins) ultimately comes from Lexical, and this repo primarily provides the MarkdownEditor API surface + integrations on top.

### Where the code lives

- Package code (the library you import): `Sources/MarkdownEditor/`
- Package tests: `Tests/MarkdownEditorTests/`
- Demo app project: `Demo/MarkdownEditor.xcodeproj` (scheme: `MarkdownEditorDemo`)

### Heavy dependency: `lexical-ios`

The Swift package uses a remote dependency on Lexical by default:

`Package.swift` includes `.package(url: "https://github.com/jcfontecha/lexical-ios.git", branch: "main")`.
The Lexical source is pulled from the remote package source unless you intentionally
use a local fork for deep Lexical work.

For local Lexical experiments, you may temporarily switch the dependency in `Package.swift` to:
`.package(path: "../lexical-ios")`.

If you need to inspect/modify core editor behavior, you’ll usually be working in `../lexical-ios` rather than here.

## Building

Use `make` as the primary entry point.

Common commands:

- Build the package framework target:
  - `make build markdown-editor`
- Build the demo app for the iOS Simulator:
  - `make build demo-app`
- Build both:
  - `make build`
- Use verbose `xcodebuild` output when needed:
  - `make build demo-app --verbose`

Open in Xcode:

- `make open`

Notes:

- `sim run` uses `.sim.json`, which now builds through `make build demo-app`.
- `xcb.json` still exists for compatibility, but `make` is the supported local build workflow.
