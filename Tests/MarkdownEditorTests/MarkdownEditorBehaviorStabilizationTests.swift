import XCTest
import Lexical
@testable import MarkdownEditor

final class MarkdownEditorBehaviorStabilizationTests: MarkdownTestCase {
    func testLoadMarkdownParsesInlineFormattingOnInitialRender() {
        let sampleMarkdown = """
        # Heading with **bold**

        This paragraph has **bold**, *italic*, and `code`.

        - List item with **strong** text
        > Quote with *emphasis*
        """

        let loadResult = markdownEditor.loadMarkdown(MarkdownDocument(content: sampleMarkdown))
        switch loadResult {
        case .success:
            break
        case .failure(let error):
            XCTFail("Failed to load markdown: \(error)")
            return
        }

        do {
            try editor.getEditorState().read {
                guard let root = getRoot() else {
                    XCTFail("Expected root node")
                    return
                }

                var textNodes: [TextNode] = []

                func collectTextNodes(from node: Node) {
                    if let textNode = node as? TextNode {
                        textNodes.append(textNode)
                    }

                    if let elementNode = node as? ElementNode {
                        for child in elementNode.getChildren() {
                            collectTextNodes(from: child)
                        }
                    }
                }

                collectTextNodes(from: root)

                XCTAssertTrue(textNodes.contains { $0.getTextContent() == "bold" && $0.getFormat().bold })
                XCTAssertTrue(textNodes.contains { $0.getTextContent() == "italic" && $0.getFormat().italic })
                XCTAssertTrue(textNodes.contains { $0.getTextContent() == "code" && $0.getFormat().code })
                XCTAssertTrue(textNodes.contains { $0.getTextContent() == "strong" && $0.getFormat().bold })
                XCTAssertTrue(textNodes.contains { $0.getTextContent() == "emphasis" && $0.getFormat().italic })
            }
        } catch {
            XCTFail("Failed to inspect editor state: \(error)")
        }
    }

    func testBackwardSelectionFormattingPreservesSelectionOrder() {
        given(paragraphDocument("Hello world"))
            .when(MarkdownTestAction { _ in
                try self.editor.update {
                    guard let root = getRoot(),
                          let paragraph = root.getFirstChild() as? ParagraphNode,
                          let textNode = paragraph.getFirstChild() as? TextNode else {
                        XCTFail("Expected paragraph with text")
                        return
                    }

                    let anchor = Point(key: textNode.key, offset: 5, type: .text)
                    let focus = Point(key: textNode.key, offset: 0, type: .text)
                    let selection = RangeSelection(anchor: anchor, focus: focus, format: TextFormat())
                    getActiveEditorState()?.selection = selection
                }

                self.markdownEditor.applyFormatting(.bold)
            })
            .then(expectFormattedText(text: "Hello", bold: true))
    }

    func testFormattingSelectionAfterHeadingsAndBlankLinesExportsBoldMarkdown() {
        let sampleMarkdown = """
        # Test Editor

        Simple paragraph for testing.

        ## Streaming Replacement Demo

        Find me: The quick brown fox jumps over the lazy dog.

        Another paragraph that should stay unchanged.
        """

        let loadResult = markdownEditor.loadMarkdown(MarkdownDocument(content: sampleMarkdown))
        switch loadResult {
        case .success:
            break
        case .failure(let error):
            XCTFail("Failed to load markdown: \(error)")
            return
        }

        let text = markdownEditor.textView.text as NSString
        let targetRange = text.range(of: "quick brown fox")
        XCTAssertNotEqual(targetRange.location, NSNotFound, "Expected target range in native text")

        markdownEditor.textView.selectedRange = targetRange
        markdownEditor.applyFormatting(.bold)

        switch markdownEditor.exportMarkdown() {
        case .success(let document):
            XCTAssertTrue(
                document.content.contains("**quick brown fox**"),
                "Expected exported markdown to preserve the bold selection"
            )
        case .failure(let error):
            XCTFail("Failed to export markdown: \(error)")
        }
    }
}
