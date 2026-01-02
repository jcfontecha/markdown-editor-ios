import XCTest
@testable import MarkdownEditor

@MainActor
final class UndoRedoTests: MarkdownTestCase {

    func testUndoRedo_roundTrips() throws {
        let initial = MarkdownDocument(content: "Hello")
        _ = markdownEditor.loadMarkdown(initial)

        let before = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(before.contains("Hello"))

        markdownEditor.textView.insertText("!")

        let afterInsert = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(afterInsert.contains("Hello!"), "Expected insertText to update document")

        markdownEditor.undo()
        let afterUndo = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(afterUndo.contains("Hello"), "Expected undo to restore previous content")
        XCTAssertFalse(afterUndo.contains("Hello!"), "Expected undo to remove the inserted text")

        markdownEditor.redo()
        let afterRedo = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(afterRedo.contains("Hello!"), "Expected redo to re-apply the inserted text")
    }

    func testUndoRedo_streamingReplacement_isSingleStep() throws {
        let initial = MarkdownDocument(content: "Find me: The quick brown fox.")
        _ = markdownEditor.loadMarkdown(initial)

        let session = try markdownEditor.startReplacement(
            findText: "The quick brown fox",
            beforeContext: "Find me: ",
            afterContext: nil
        )
        session.setText("A slower red fox")
        session.finish()

        markdownEditor.undo()
        let afterUndo = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(afterUndo.contains("The quick brown fox"))
        XCTAssertFalse(afterUndo.contains("A slower red fox"))

        markdownEditor.redo()
        let afterRedo = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(afterRedo.contains("A slower red fox"))
    }

    func testUndoRedo_newlineIsUndoable() throws {
        let initial = MarkdownDocument(content: "Hello")
        _ = markdownEditor.loadMarkdown(initial)

        func newlineCount(_ s: String) -> Int { s.reduce(0) { $0 + ($1 == "\n" ? 1 : 0) } }

        let beforeText = markdownEditor.textView.text ?? ""
        let beforeNewlines = newlineCount(beforeText)

        markdownEditor.textView.insertText("\n")

        let afterText = markdownEditor.textView.text ?? ""
        let afterNewlines = newlineCount(afterText)
        XCTAssertGreaterThan(afterNewlines, beforeNewlines, "Expected Enter to introduce an additional line break in UITextView")

        markdownEditor.undo()

        let afterUndoText = markdownEditor.textView.text ?? ""
        let afterUndoNewlines = newlineCount(afterUndoText)
        XCTAssertEqual(afterUndoNewlines, beforeNewlines, "Expected undo to remove the inserted line break")
    }
}
