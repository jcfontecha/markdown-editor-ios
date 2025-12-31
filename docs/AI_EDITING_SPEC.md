# Streaming Replacement Editing — Spec + Plan

## Summary

Add first-class support in `MarkdownEditor` (iOS Swift package wrapping `lexical-ios`) for **streaming text edits** (commonly driven by an assistant/model) that:

1. Find a target region by matching a string (optionally with before/after context).
2. Create a stable “edit session” anchored to that region.
3. Stream incremental replacement text into the editor (delta-by-delta), with cancel/complete semantics.

This is analogous to the webapp’s “script tab” approach (match string → stream replacement), but implemented safely for Lexical’s node/selection model and this repo’s domain bridge constraints.

## Goals

- Provide a **public, framework-level API** to apply AI streaming edits without re-importing Markdown on every chunk.
- Support **match + context** targeting to pick the correct paragraph/list item/etc.
- Stream replacement text in a way that:
  - preserves the rest of the Lexical document structure,
  - avoids inline formatting loss,
  - behaves predictably with selection/caret and user interaction.
- Make integration with `../ai-kit` straightforward (tool-input delta streaming to editor session).

## Non-goals (initially)

- Full-document “diff/patch” application.
- Inline-format-preserving replacement inside arbitrary mixed-format runs (bold/italic/code inside a paragraph) beyond “replace the whole block’s text”.
- Collaborative editing / multi-user reconciliation.
- Perfect “single undo step” semantics if it requires invasive Lexical changes (we’ll design for it, but start pragmatic).

## Background / Constraints

- This repo’s “domain layer” operations are primarily **string-based Markdown transformations** and are not currently used to drive streaming edits.
- Re-importing Markdown during streaming (e.g., repeatedly calling `loadMarkdown`) is **not acceptable** because parsing/bridging currently does not preserve rich inline formatting across arbitrary content.
- Lexical already supports programmatic edits via `editor.update { … }`, `RangeSelection.insertText`, and node operations.
- Lexical uses **ZWSP** (`\u{200B}`) as an internal caret anchor in empty blocks (especially list items). We must not leak ZWSP into exported Markdown and should avoid it interfering with matching.

## Terminology

- **Block candidate**: a top-level “user-perceived unit” that can be targeted for replacement (paragraph, heading, quote, code block line-set, list item).
- **Session anchor**: stable reference to the target, preferably `NodeKey` of a block element (or a list item) plus an internal strategy to compute a selection range.
- **Streaming mode**:
  - `replace`: replace matched content with streaming replacement.
  - `append`: append streaming text at a chosen insertion point (future).

## Proposed Public API (Swift, Concurrency-friendly)

Avoid “AI” in naming. Keep the API “Swifty”, ergonomic, and aligned with Swift Concurrency.

Expose a single active streaming edit session on `MarkdownEditorContentView` (or `MarkdownEditorInterface`). Prefer `@MainActor` because this is UI/editor state.

```swift
@MainActor
public protocol MarkdownStreamingEditing: AnyObject {
  func startReplacement(
    findText: String,
    beforeContext: String?,
    afterContext: String?
  ) throws -> ReplacementSession
}

@MainActor
public final class ReplacementSession {
  /// Append delta text as it streams in (preferred when upstream is delta-based).
  public func append(_ delta: String)

  /// Alternatively, set full replacement-so-far (preferred when upstream is cumulative).
  public func setText(_ fullText: String)

  public func finish()
  public func cancel()

  public var isActive: Bool { get }
}
```

Notes:
- We explicitly support **delta** and **cumulative** update styles.
- We keep “single session” semantics for simplicity (matches webapp behavior and reduces conflict surface).
- Consider adding a convenience that consumes an `AsyncSequence`:

```swift
@MainActor
public extension MarkdownStreamingEditing {
  func replaceText(
    findText: String,
    beforeContext: String? = nil,
    afterContext: String? = nil,
    deltas: some AsyncSequence<String>
  ) async throws {
    let session = try startReplacement(
      findText: findText,
      beforeContext: beforeContext,
      afterContext: afterContext
    )
    do {
      for try await delta in deltas {
        session.append(delta)
      }
      session.finish()
    } catch {
      session.cancel()
      throw error
    }
  }
}
```

## Targeting / Matching Spec

### Candidate enumeration (Lexical)

In `editor.read { … }`:

- Traverse `root.getChildren()`.
- For each top-level child:
  - Paragraph / heading / quote: candidate is that element.
  - List node: candidate is **each `ListItemNode`** (not the list container).
  - Code block: candidate is the code node (treat as one block initially).

For each candidate, compute:

- `plainText`: `candidate.getTextContent()` with:
  - ZWSP removed,
  - CRLF normalized to `\n`,
  - whitespace condensed for matching (optional; see below),
  - punctuation normalized (optional; see below).

### Matching strategy (v1)

Given:
- `findText` (required),
- `beforeContext` / `afterContext` (optional),

We score each candidate similarly to the webapp’s context matching:

- Require `findText` (normalized) be found in candidate (normalized).
- Add score boosts for:
  - suffix match vs `beforeContext`,
  - prefix match vs `afterContext`.
- Pick the highest score; tie-break by earliest match index then earliest block order.

Normalization should broadly mirror the webapp’s `performTextReplacement` approach:

- ignore zero-width code points (at minimum `\u{200B}`),
- normalize CRLF/CR → LF,
- normalize NBSP variants → space,
- normalize “smart quotes / dashes / ellipsis” to ASCII equivalents (optional, but recommended).

### Match boundaries (v1)

For v1 we target one of these scopes:

1) **Replace whole candidate block text** (safe, minimal mapping complexity).
2) Optionally compute the exact substring range inside the candidate and replace only that substring (more complex because mapping requires per-text-node offsets).

We’ll start with **whole-block replacement** to reduce correctness risk.

## Streaming Application Spec

### Session lifecycle

**Begin**
- Find best candidate.
- Store session state:
  - anchor `NodeKey`,
  - originalText (for cancel),
  - replacementTextSoFar (initially empty),
  - insertion strategy (replace-whole-block vs delete-then-append),
  - selection snapshot (optional).
- Apply initial change:
  - Replace target block’s text with empty string (or keep as-is until first delta).

**Update (delta)**
- Ensure the anchor node still exists and is attached.
- Apply delta by either:
  - (A) Delete-once then append:
    - maintain caret at end of target text and call `RangeSelection.insertText(delta)`.
  - (B) Replace-whole-block each tick:
    - set block’s text to `replacementTextSoFar`.

**Complete**
- Finalize session:
  - ensure final replacement text is applied,
  - restore normal editing / interaction,
  - clear session state.

**Cancel**
- Restore original target text (best effort):
  - replace target block text with originalText (stored at begin),
  - clear session state.

### Concurrency / threading

- All Lexical mutations must happen inside `editor.update { … }` on Lexical’s thread.
- Public API should be safe to call from main thread (typical UI integration).

### User interaction during streaming (v1 policy)

To keep behavior deterministic, during an active session:

- Option A (strict): set `textView.isEditable = false` until complete/cancel.
- Option B (soft): keep editable, but cancel the session on user keystroke / selection change.

Start with **Option A** (strict) and revisit once we have stable semantics.

### Undo/redo expectations

There are three acceptable v1 behaviors:

1) Many-step undo (one per chunk) — simplest but noisy.
2) Single-step undo (entire AI edit) — better UX, may require grouping.
3) No undo recording for streaming session — acceptable if cancel covers “oops”.

Initial recommendation:
- Use strict “editable off” + record edits normally; if it’s noisy, we can add grouping later.

If we need grouping:
- Investigate UndoManager grouping at the UIKit level, or a Lexical history integration point.

## Integration with `../ai-kit` (Naming stays generic)

`ai-kit` supports tool input delta streaming via `ToolSpec.onInputDelta`.

Recommended wiring (example):

- `onInputStart`: call `startReplacement(findText:beforeContext:afterContext:)` and retain the returned `ReplacementSession`.
- `onInputDelta`: parse the accumulating tool input or direct delta; call:
  - `session.append(delta)` if delta-based, or
  - `session.setText(full)` if cumulative.
- `onInputAvailable` and/or tool `execute` completion: call `session.finish()`.
- On error/cancellation: call `session.cancel()`.

## Implementation Plan (Phases)

### Phase 1 — Minimal, safe streaming replacement

- Add a new session object (private) owned by `MarkdownEditorContentView`.
- Implement:
  - candidate enumeration and scoring,
  - anchor storage,
  - replace-whole-block streaming application,
  - strict interaction policy (disable editing during session),
  - cancel/complete.

### Phase 2 — Better targeting and UX

- Add exact substring replacement inside the chosen candidate (map normalized match index to text-node offsets).
- Add “fallback targeting” if the original anchor node disappears (e.g., re-find by context).
- Add selection restoration after complete/cancel.

### Phase 3 — Undo grouping + richer edits

- Group streaming edits into a single undo step (if feasible).
- Add append mode / insertion at caret.
- Consider inline-format preservation strategies (complex; likely requires Lexical-level rich-text operations or structured patch model).

## Testing Plan

Add tests in `Tests/MarkdownEditorTests/`:

- Candidate matching:
  - paragraph vs list item selection given ambiguous `findText`,
  - with before/after context choosing the correct block.
- ZWSP handling:
  - list items with ZWSP don’t break matching,
  - exported Markdown remains ZWSP-free.
- Session lifecycle:
  - begin → stream deltas → complete yields expected text,
  - begin → stream deltas → cancel restores original text,
  - begin when another session active returns error.

## Open Questions

1) Should v1 replace scope be:
   - whole block (recommended), or
   - exact substring inside block?
2) What’s the canonical “matching surface” for tools:
   - plain text (user-perceived), or
   - exported Markdown (syntax-aware)?
3) Interaction policy during session:
   - disable editing, or
   - allow edits but cancel/rebase session?
4) Undo semantics requirement for initial release.

---

## Work Item Tracker

Legend: ✅ done · 🟡 in progress · ⬜️ not started · 🔴 blocked

| ID | Status | Area | Work item | Notes / Exit criteria |
|---:|:------:|------|-----------|------------------------|
| 1 | ⬜️ | API | Define public streaming edit API | `@MainActor`, no “AI” naming; `startReplacement` returns a session |
| 2 | ⬜️ | Core | Implement candidate enumeration | Paragraph/heading/quote/code + per-list-item candidates |
| 3 | ⬜️ | Core | Implement normalization utilities | Strip ZWSP, normalize whitespace/punctuation (match web heuristics where useful) |
| 4 | ⬜️ | Core | Implement context scoring + best match selection | Deterministic tie-breaking; unit tests cover ambiguous matches |
| 5 | ⬜️ | Core | Implement session state + anchor tracking | Stores node key + original text + replacement so far |
| 6 | ⬜️ | Core | Implement streaming apply (replace-whole-block) | Delta and cumulative modes both supported |
| 7 | ⬜️ | UX | Enforce interaction policy during session | v1: disable editing during streaming; restore at end |
| 8 | ⬜️ | UX | Handle cancel/complete semantics | Cancel restores original; complete finalizes replacement |
| 9 | ⬜️ | Tests | Add unit tests for matching and lifecycle | Tests in `Tests/MarkdownEditorTests/` |
| 10 | ⬜️ | Integration | Add `ai-kit` bridge example (optional) | Demo wiring using `ToolSpec.onInputDelta` |
| 11 | ⬜️ | Follow-up | Exact substring replacement within block | Map match index to text-node offsets |
| 12 | ⬜️ | Follow-up | Undo grouping | Investigate UndoManager grouping or Lexical history tagging |
