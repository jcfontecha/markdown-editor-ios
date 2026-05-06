import XCTest
import Lexical
import LexicalListPlugin
import LexicalLinkPlugin
@testable import MarkdownEditor

final class MarkdownRegressionMatrixTests: MarkdownTestCase {
    struct ImportCase {
        let name: String
        let markdown: String
        let expectedText: String
        let expectedTopLevelTypes: [NodeType]
    }

    func testImporterHandlesBroadMarkdownEdgeCaseMatrix() throws {
        let cases: [ImportCase] = [
            .init(name: "empty", markdown: "", expectedText: "", expectedTopLevelTypes: [.heading]),
            .init(name: "plain", markdown: "hello world", expectedText: "hello world", expectedTopLevelTypes: [.paragraph]),
            .init(name: "leading trailing blanks", markdown: "\n\nalpha\n\n", expectedText: "alpha", expectedTopLevelTypes: [.paragraph]),
            .init(name: "crlf", markdown: "# Title\r\n\r\nBody", expectedText: "TitleBody", expectedTopLevelTypes: [.heading, .paragraph]),
            .init(name: "h1", markdown: "# Title", expectedText: "Title", expectedTopLevelTypes: [.heading]),
            .init(name: "h5 fallback", markdown: "###### Deep", expectedText: "Deep", expectedTopLevelTypes: [.heading]),
            .init(name: "escaped heading plain", markdown: "\\# Not heading", expectedText: "\\# Not heading", expectedTopLevelTypes: [.paragraph]),
            .init(name: "quote", markdown: "> quote\n> next", expectedText: "quotenext", expectedTopLevelTypes: [.quote]),
            .init(name: "fenced backticks", markdown: "```swift\nlet x = 1\n```", expectedText: "let x = 1", expectedTopLevelTypes: [.code]),
            .init(name: "fenced tildes", markdown: "~~~\nlet y = 2\n~~~", expectedText: "let y = 2", expectedTopLevelTypes: [.code]),
            .init(name: "unordered dash", markdown: "- one\n- two", expectedText: "onetwo", expectedTopLevelTypes: [.list]),
            .init(name: "unordered plus", markdown: "+ one\n+ two", expectedText: "onetwo", expectedTopLevelTypes: [.list]),
            .init(name: "ordered", markdown: "10. ten\n11. eleven", expectedText: "teneleven", expectedTopLevelTypes: [.list]),
            .init(name: "task fallback", markdown: "- [x] done\n- [ ] todo", expectedText: "donetodo", expectedTopLevelTypes: [.list]),
            .init(name: "unicode", markdown: "👨‍👩‍👧‍👦 café שלום مرحبا 日本語", expectedText: "👨‍👩‍👧‍👦 café שלום مرحبا 日本語", expectedTopLevelTypes: [.paragraph]),
            .init(name: "inline marks", markdown: "This is **bold**, *italic*, ~~gone~~, and `code`.", expectedText: "This is bold, italic, gone, and code.", expectedTopLevelTypes: [.paragraph]),
            .init(name: "link", markdown: "[OpenAI](https://openai.com)", expectedText: "OpenAI", expectedTopLevelTypes: [.paragraph]),
            .init(name: "unsupported table safe text", markdown: "| A | B |\n| - | - |", expectedText: "| A | B || - | - |", expectedTopLevelTypes: [.paragraph, .paragraph])
        ]

        for testCase in cases {
            _ = markdownEditor.loadMarkdown(MarkdownDocument(content: testCase.markdown))

            var actualText = ""
            var actualTypes: [NodeType] = []
            try editor.read {
                let root = try XCTUnwrap(getRoot(), "Missing root for \(testCase.name)")
                actualText = root.getTextContent()
                    .replacingOccurrences(of: "\u{200B}", with: "")
                    .replacingOccurrences(of: "\n", with: "")
                actualTypes = root.getChildren().map { type(of: $0).getType() }
            }

            XCTAssertEqual(actualText, testCase.expectedText, testCase.name)
            XCTAssertEqual(actualTypes, testCase.expectedTopLevelTypes, testCase.name)
            XCTAssertFalse(markdownEditor.exportMarkdown().value?.content.contains("\u{200B}") ?? true, testCase.name)
        }
    }

    func testEnterAtEndOfUnorderedListItemCreatesSiblingListItem() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: "- first"))

        try selectText("first", offset: 5)
        markdownEditor.textView.insertText("\n")

        try editor.read {
            let list = try XCTUnwrap(getRoot()?.getFirstChild() as? ListNode)
            XCTAssertEqual(list.getChildrenSize(), 2)
            let secondItem = try XCTUnwrap(list.getChildAtIndex(index: 1) as? ListItemNode)
            XCTAssertEqual(secondItem.getTextContent().replacingOccurrences(of: "\u{200B}", with: ""), "")
        }
    }

    func testEnterAtEndOfOrderedListItemCreatesSiblingListItem() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: "1. first"))

        try selectText("first", offset: 5)
        markdownEditor.textView.insertText("\n")

        try editor.read {
            let list = try XCTUnwrap(getRoot()?.getFirstChild() as? ListNode)
            XCTAssertEqual(list.getChildrenSize(), 2)
            XCTAssertEqual(list.getListType(), .number)
            let secondItem = try XCTUnwrap(list.getChildAtIndex(index: 1) as? ListItemNode)
            XCTAssertEqual(secondItem.getTextContent().replacingOccurrences(of: "\u{200B}", with: ""), "")
        }
    }

    func testEnterInMiddleOfListItemSplitsIntoSiblingListItems() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: "- first"))

        try selectText("first", offset: 2)
        markdownEditor.textView.insertText("\n")

        try editor.read {
            let list = try XCTUnwrap(getRoot()?.getFirstChild() as? ListNode)
            XCTAssertEqual(list.getChildrenSize(), 2)
            let firstItem = try XCTUnwrap(list.getChildAtIndex(index: 0) as? ListItemNode)
            let secondItem = try XCTUnwrap(list.getChildAtIndex(index: 1) as? ListItemNode)
            XCTAssertEqual(visibleListItemText(firstItem), "fi")
            XCTAssertEqual(visibleListItemText(secondItem), "rst")
        }
    }

    func testLexicalParagraphInsertionInMiddleOfListItemSplitsIntoSiblingListItems() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: "- first"))

        try selectText("first", offset: 2)
        editor.dispatchCommand(type: .insertParagraph)

        try editor.read {
            let list = try XCTUnwrap(getRoot()?.getFirstChild() as? ListNode)
            XCTAssertEqual(list.getChildrenSize(), 2)
            let firstItem = try XCTUnwrap(list.getChildAtIndex(index: 0) as? ListItemNode)
            let secondItem = try XCTUnwrap(list.getChildAtIndex(index: 1) as? ListItemNode)
            XCTAssertEqual(visibleListItemText(firstItem), "fi")
            XCTAssertEqual(visibleListItemText(secondItem), "rst")
        }
    }

    private func visibleListItemText(_ item: ListItemNode) -> String {
        item.getTextContent()
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    private func selectText(_ text: String, offset: Int) throws {
        try editor.update {
            guard let root = getRoot() else {
                XCTFail("Missing root")
                return
            }

            var target: TextNode?

            func visit(_ node: Node) {
                if target != nil { return }
                if let textNode = node as? TextNode, textNode.getTextContent().contains(text) {
                    target = textNode
                    return
                }
                if let element = node as? ElementNode {
                    element.getChildren().forEach(visit)
                }
            }

            visit(root)

            guard let target else {
                XCTFail("Missing text node containing \(text)")
                return
            }

            let point = Point(key: target.key, offset: offset, type: .text)
            getActiveEditorState()?.selection = RangeSelection(anchor: point, focus: point, format: TextFormat())
        }
    }

    func testPastingMarkdownCreatesFormattedLexicalNodesAndOneUndoStep() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: "Before"))

        try editor.update {
            guard let root = getRoot(),
                  let paragraph = root.getFirstChild() as? ParagraphNode,
                  let text = paragraph.getFirstChild() as? TextNode else { return }
            let point = Point(key: text.key, offset: text.getTextContentSize(), type: .text)
            getActiveEditorState()?.selection = RangeSelection(anchor: point, focus: point, format: TextFormat())
        }

        editor.dispatchCommand(type: .insertText, payload: "\n# Pasted\n\n- **bold** item\n- [link](https://example.com)")

        var containsHeading = false
        var containsList = false
        var containsBold = false
        var containsLink = false
        try editor.read {
            guard let root = getRoot() else { return }
            containsHeading = root.getChildren().contains { $0 is HeadingNode }
            containsList = root.getChildren().contains { $0 is ListNode }

            func visit(_ node: Node) {
                if let text = node as? TextNode, text.getTextContent() == "bold", text.getFormat().bold {
                    containsBold = true
                }
                if node is LinkNode {
                    containsLink = true
                }
                if let element = node as? ElementNode {
                    element.getChildren().forEach(visit)
                }
            }
            visit(root)
        }

        XCTAssertTrue(containsHeading)
        XCTAssertTrue(containsList)
        XCTAssertTrue(containsBold)
        XCTAssertTrue(containsLink)

        let afterPaste = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(afterPaste.contains("# Pasted"))
        markdownEditor.undo()
        let afterUndo = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertFalse(afterUndo.contains("# Pasted"))
        markdownEditor.redo()
        let afterRedo = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(afterRedo.contains("# Pasted"))
    }

    func testExportCacheInvalidatesAfterEditUndoRedoAndReload() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: "A"))
        let first = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        let second = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertEqual(first, second)

        markdownEditor.textView.insertText("B")
        let edited = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(edited.contains("AB"))

        markdownEditor.undo()
        let undone = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertEqual(undone, first)

        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: "# Reloaded"))
        let reloaded = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(reloaded.contains("# Reloaded"))
    }
}
