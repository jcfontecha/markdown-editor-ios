import XCTest
import Lexical
@testable import MarkdownEditor

@MainActor
final class StreamingAppendTests: MarkdownTestCase {

    func testAppendSession_appendsMarkdownAndIsSingleUndoStep() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: "Hello"))

        let session = try markdownEditor.startAppend()
        session.setText("## Appended\n\nMore text.")
        session.finish()

        let exported = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(exported.contains("Hello"))
        XCTAssertTrue(exported.contains("## Appended"))
        XCTAssertTrue(exported.contains("More text."))

        markdownEditor.undo()
        let afterUndo = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(afterUndo.contains("Hello"))
        XCTAssertFalse(afterUndo.contains("## Appended"))
        XCTAssertFalse(afterUndo.contains("More text."))

        markdownEditor.redo()
        let afterRedo = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(afterRedo.contains("## Appended"))
        XCTAssertTrue(afterRedo.contains("More text."))
    }

    func testAppendSession_cancelRestoresOriginal() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: "Hello"))

        let session = try markdownEditor.startAppend()
        session.setText("New paragraph")
        session.cancel()

        let exported = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(exported.contains("Hello"))
        XCTAssertFalse(exported.contains("New paragraph"))
    }
}
