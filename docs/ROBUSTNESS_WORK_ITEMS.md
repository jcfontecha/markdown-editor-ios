# Robustness Work Item Tracker

This is the actionable backlog derived from `docs/ROBUSTNESS_SPEC.md`.

## P0 — Stop-The-Bleeding (Stabilization)
- [x] RB-001: Fix Backspace fallback direction/behavior in domain bridge (`applySmartBackspaceCommand`).
- [x] RB-002: Store/unregister the Lexical update listener removal handler to prevent ghost callbacks/leaks.
- [x] RB-003: Add non-crashing telemetry/logging for `syncFromLexical` failures (no silent swallowing).
- [x] RB-004: Ensure update-listener async UI work captures `self` weakly (avoid accidental retain until queue drain).
- [x] RB-005: Stop intercepting Enter/Backspace in list contexts; let `LexicalListPlugin` handle it to prevent cursor jumps.
- [x] RB-006: Add a demo/runtime toggle for verbose logging (`MARKDOWNEDITOR_VERBOSE_LOGGING=1` or `-MarkdownEditorVerboseLogging`).
- [x] RB-007: Strip task-list markers (`[x]` / `[ ]`) on import when task lists aren’t supported (treat as normal list items).

## P1 — Reproducible Builds/Tests
- [x] RB-101: Decide canonical test runner (`xcodebuild` iOS-sim vs `swift test`).
- [x] RB-102: Add a single “blessed” test command to docs and CI.
- [ ] RB-103: If `swift test` is desired, resolve `lexical-ios` platform requirements mismatch.

## P1 — Source of Truth Contract
- [x] RB-201: Decide canonical state model (Lexical-first vs Domain-first).
- [x] RB-202: Document the contract and invariants (selection mapping, multi-block semantics, normalization policy).
- [x] RB-203: Align domain services to match the chosen model (remove “simulation” stubs or gate them explicitly).

## P2 — Deterministic Markdown Serialization
- [x] RB-301: Define markdown normalization rules (newlines, trailing newline, list spacing, code fences).
- [x] RB-302: Add round-trip tests (Import→Export and Export→Import invariants).
- [x] RB-303: Add snapshot-style tests for known tricky documents (lists, headings, code blocks, quotes, mixed formatting).

## P2 — Input/Event Robustness
- [x] RB-401: Consolidate Enter/Backspace handling so fallbacks don’t re-enter handlers unpredictably.
- [x] RB-402: Add a dedicated “input sequence” test suite (keystroke sequences against invariants).
- [x] RB-403: Add coverage for ZWSP and whitespace boundary behaviors.
