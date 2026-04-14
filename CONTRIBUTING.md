# Contributing

Thanks for taking the time to contribute.

## Getting started

1. Fork or clone the repository.
2. Open `Demo/MarkdownEditor.xcodeproj` or use the `make` build workflow.
3. Pick one package entry point to modify:
   - `Sources/MarkdownEditor/MarkdownEditor.swift`
   - `Sources/MarkdownEditor/MarkdownConfiguration.swift`
   - `Sources/MarkdownEditor/SwiftUIMarkdownEditor.swift`
4. Keep changes focused and small.

## Coding standards

- Prefer clear, explicit API surfaces over configuration-heavy designs.
- Keep public APIs documented and testable.
- Preserve existing backward-compatible behavior unless a breaking change is intentional.
- Prefer incremental refactors over broad rewrites.

## Build and test

Use these commands as the baseline:

- `make build markdown-editor`
- `make build demo-app`
- `make build`

## Submitting a change

1. Include a short summary of scope and risk.
2. Note touched public APIs.
3. Add or update tests for behavior changes.
4. Validate with local build/run before opening a PR.

## Review checklist

- [ ] No user-facing behavior regressions.
- [ ] No leftover debug artifacts (`print`) in production code paths.
- [ ] Appropriate error handling and logging.
- [ ] Clear commit message and focused diff.
