import XCTest
import Lexical
@testable import MarkdownEditor

final class StreamingReplacementTests: MarkdownTestCase {

    func testStartReplacement_usesContextToSelectBestBlock() throws {
        try editor.update {
            guard let root = getActiveEditorState()?.getRootNode() else {
                XCTFail("No root node available")
                return
            }

            try root.getChildren().forEach { child in
                try child.remove()
            }

            let p1 = ParagraphNode()
            try p1.append([TextNode(text: "hello world")])

            let p2 = ParagraphNode()
            try p2.append([TextNode(text: "hi world again")])

            try root.append([p1, p2])
        }

        let session = try markdownEditor.startReplacement(
            findText: "world",
            beforeContext: "hi ",
            afterContext: " again"
        )

        session.setText("REPLACED")
        session.finish()

        let exported = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(exported.contains("hello world"), "First paragraph should remain unchanged")
        XCTAssertTrue(exported.contains("REPLACED"), "Second paragraph should be replaced")
        XCTAssertFalse(exported.contains("hi world again"), "Original second paragraph text should be gone")
    }

    func testCancelReplacement_restoresOriginalText() throws {
        try editor.update {
            guard let root = getActiveEditorState()?.getRootNode() else {
                XCTFail("No root node available")
                return
            }

            try root.getChildren().forEach { child in
                try child.remove()
            }

            let p = ParagraphNode()
            try p.append([TextNode(text: "original text")])
            try root.append([p])
        }

        let session = try markdownEditor.startReplacement(
            findText: "original",
            beforeContext: nil,
            afterContext: nil
        )

        session.append("new")
        session.cancel()

        let exported = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(exported.contains("original text"))
        XCTAssertFalse(exported.contains("new"))
    }

    func testStartReplacement_throwsWhenSessionAlreadyActive() throws {
        try editor.update {
            guard let root = getActiveEditorState()?.getRootNode() else {
                XCTFail("No root node available")
                return
            }

            try root.getChildren().forEach { child in
                try child.remove()
            }

            let p = ParagraphNode()
            try p.append([TextNode(text: "hello world")])
            try root.append([p])
        }

        let s1 = try markdownEditor.startReplacement(findText: "world", beforeContext: nil, afterContext: nil)

        XCTAssertThrowsError(
            try markdownEditor.startReplacement(findText: "hello", beforeContext: nil, afterContext: nil)
        ) { error in
            XCTAssertEqual(error as? StreamingReplacementError, .sessionAlreadyActive)
        }

        s1.cancel()
    }
}

