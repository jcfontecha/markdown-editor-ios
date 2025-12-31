//
//  MarkdownEditorTests.swift
//  MarkdownEditorTests
//
//  Created by Juan Carlos on 6/21/25.
//

import Testing
import XCTest
import Lexical
import LexicalListPlugin
@testable import MarkdownEditor

struct MarkdownEditorTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

final class EditorInteractionRegressionTests: XCTestCase {
    private func makeView() -> MarkdownEditorContentView {
        MarkdownEditorContentView(configuration: .init(behavior: .init(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .smart,
            startWithTitle: false
        )))
    }

    private func rootChildrenTypes(_ editor: Editor) -> [String] {
        var types: [String] = []
        try? editor.read {
            guard let root = getRoot() else { return }
            types = root.getChildren().map { type(of: $0).getType().rawValue }
        }
        return types
    }

    private func firstListItemText(_ editor: Editor, listIndex: Int) -> String? {
        var result: String?
        try? editor.read {
            guard let root = getRoot(),
                  let list = root.getChildAtIndex(index: listIndex) as? ListNode,
                  let item = list.getFirstChild() as? ListItemNode else { return }
            result = item.getTextContent()
                .replacingOccurrences(of: "\u{200B}", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    func testEnterOnEmptyListItemConvertsToParagraph() {
        let view = makeView()

        _ = view.loadMarkdown(MarkdownDocument(content: "- "))

        view.editorForTesting.dispatchCommand(type: .insertText, payload: "\n")

        var firstNodeType: String?
        try? view.editorForTesting.read {
            if let root = getRoot(), let first = root.getFirstChild() {
                firstNodeType = type(of: first).getType().rawValue
            }
        }

        XCTAssertEqual(firstNodeType, NodeType.paragraph.rawValue)
    }

    func testBackspaceOnEmptyListItemConvertsToParagraph() {
        let view = makeView()

        _ = view.loadMarkdown(MarkdownDocument(content: "- "))

        view.editorForTesting.dispatchCommand(type: .deleteCharacter, payload: true)

        var firstNodeType: String?
        try? view.editorForTesting.read {
            if let root = getRoot(), let first = root.getFirstChild() {
                firstNodeType = type(of: first).getType().rawValue
            }
        }

        XCTAssertEqual(firstNodeType, NodeType.paragraph.rawValue)
    }

    func testExportNormalizesLineEndings() {
        let view = makeView()

        _ = view.loadMarkdown(MarkdownDocument(content: "# Title\r\n\r\nParagraph\r\n"))
        let exported = view.exportMarkdown().value?.content
        XCTAssertNotNil(exported)
        XCTAssertFalse(exported?.contains("\r") ?? true)
    }

    func testMarkdownRoundTripIsStable() {
        let view = makeView()

        let input = """
        # Title

        > Quote

        - Item 1
        - Item 2

        ```swift
        let x = 1
        ```
        """

        _ = view.loadMarkdown(MarkdownDocument(content: input))
        guard let first = view.exportMarkdown().value?.content else {
            return XCTFail("Expected first export to succeed")
        }

        _ = view.loadMarkdown(MarkdownDocument(content: first))
        guard let second = view.exportMarkdown().value?.content else {
            return XCTFail("Expected second export to succeed")
        }

        XCTAssertEqual(first, second)
    }

    func testEnterOnZWSPListItemConvertsToParagraph() {
        let view = makeView()

        _ = view.loadMarkdown(MarkdownDocument(content: "- \u{200B}"))
        view.editorForTesting.dispatchCommand(type: .insertText, payload: "\n")

        var firstNodeType: String?
        try? view.editorForTesting.read {
            if let root = getRoot(), let first = root.getFirstChild() {
                firstNodeType = type(of: first).getType().rawValue
            }
        }
        XCTAssertEqual(firstNodeType, NodeType.paragraph.rawValue)
    }

    func testBackspaceOnZWSPListItemConvertsToParagraph() {
        let view = makeView()

        _ = view.loadMarkdown(MarkdownDocument(content: "- \u{200B}"))
        view.editorForTesting.dispatchCommand(type: .deleteCharacter, payload: true)

        var firstNodeType: String?
        try? view.editorForTesting.read {
            if let root = getRoot(), let first = root.getFirstChild() {
                firstNodeType = type(of: first).getType().rawValue
            }
        }
        XCTAssertEqual(firstNodeType, NodeType.paragraph.rawValue)
    }

    func testExportContainsListMarkers() {
        let view = makeView()

        _ = view.loadMarkdown(MarkdownDocument(content: "- One\n- Two"))
        let exported = view.exportMarkdown().value?.content ?? ""
        XCTAssertTrue(exported.contains("- One"))
        XCTAssertTrue(exported.contains("- Two"))
    }

    func testExportContainsCodeFence() {
        let view = makeView()

        _ = view.loadMarkdown(MarkdownDocument(content: "```swift\nlet x = 1\n```"))
        let exported = view.exportMarkdown().value?.content ?? ""
        XCTAssertTrue(exported.contains("```"))
        XCTAssertTrue(exported.contains("let x = 1"))
    }

    func testLoadListCreatesProperListNode() {
        let view = makeView()

        _ = view.loadMarkdown(MarkdownDocument(content: "- One\n- Two"))

        var firstNodeType: String?
        var firstListItemText: String?
        try? view.editorForTesting.read {
            if let root = getRoot(),
               let list = root.getFirstChild() as? ListNode,
               let firstItem = list.getFirstChild() as? ListItemNode {
                firstNodeType = type(of: list).getType().rawValue
                firstListItemText = firstItem.getTextContent()
                    .replacingOccurrences(of: "\u{200B}", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        XCTAssertEqual(firstNodeType, NodeType.list.rawValue)
        XCTAssertEqual(firstListItemText, "One")
    }

    func testBackspaceInMiddleOfListItemDoesNotExitList() {
        let view = makeView()

        _ = view.loadMarkdown(MarkdownDocument(content: "- One"))

        // Place cursor after "On" (middle of list item) and press backspace.
        try? view.editorForTesting.update {
            guard let root = getRoot(),
                  let list = root.getFirstChild() as? ListNode,
                  let item = list.getFirstChild() as? ListItemNode,
                  let text = item.getFirstChild() as? TextNode else { return }
            let p = Point(key: text.key, offset: 2, type: .text)
            getActiveEditorState()?.selection = RangeSelection(anchor: p, focus: p, format: TextFormat())
        }

        view.editorForTesting.dispatchCommand(type: .deleteCharacter, payload: true)

        var blockType: String?
        try? view.editorForTesting.read {
            if let root = getRoot(), let first = root.getFirstChild() {
                blockType = type(of: first).getType().rawValue
            }
        }

        XCTAssertEqual(blockType, NodeType.list.rawValue)
    }

    func testBackspaceDeletingLastCharacterInListItemKeepsStableEmptyLine() {
        let view = makeView()

        _ = view.loadMarkdown(MarkdownDocument(content: "- t"))

        // Place cursor after "t" and press backspace; this used to leave an empty ListItemNode
        // with no children and an element-anchored selection (visual "short line").
        try? view.editorForTesting.update {
            guard let root = getRoot(),
                  let list = root.getFirstChild() as? ListNode,
                  let item = list.getFirstChild() as? ListItemNode,
                  let text = item.getFirstChild() as? TextNode else { return }
            let p = Point(key: text.key, offset: 1, type: .text)
            getActiveEditorState()?.selection = RangeSelection(anchor: p, focus: p, format: TextFormat())
        }

        view.editorForTesting.dispatchCommand(type: .deleteCharacter, payload: true)

        // Ensure list item still has a text anchor (ZWSP) after deletion.
        var listItemChildType: String?
        var listItemText: String?
        var anchorType: SelectionType?
        var anchorOffset: Int?
        try? view.editorForTesting.read {
            guard let root = getRoot(),
                  let list = root.getFirstChild() as? ListNode,
                  let item = list.getFirstChild() as? ListItemNode else { return }

            if let firstChild = item.getFirstChild() {
                listItemChildType = type(of: firstChild).getType().rawValue
            }
            listItemText = item.getTextContent()
            if let selection = try? getSelection() as? RangeSelection {
                anchorType = selection.anchor.type
                anchorOffset = selection.anchor.offset
            }
        }

        XCTAssertEqual(rootChildrenTypes(view.editorForTesting).first, NodeType.list.rawValue)
        XCTAssertEqual(listItemChildType, NodeType.text.rawValue)
        XCTAssertEqual(listItemText, "\u{200B}")
        XCTAssertEqual(anchorType, .text)
        XCTAssertEqual(anchorOffset, 0)
        XCTAssertEqual(view.textView.selectedRange.length, 0)
    }

    func testMarkdownShortcutDashSpaceCreatesList() {
        let view = makeView()

        _ = view.loadMarkdown(MarkdownDocument(content: "Hello"))

        // Create a new paragraph, then type "- " which should convert to a list.
        view.editorForTesting.dispatchCommand(type: .insertText, payload: "\n")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: "-")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: " ")

        var secondNodeType: String?
        var listItemText: String?
        try? view.editorForTesting.read {
            guard let root = getRoot() else { return }
            guard let second = root.getChildAtIndex(index: 1) else { return }
            secondNodeType = type(of: second).getType().rawValue
            if let list = second as? ListNode, let firstItem = list.getFirstChild() as? ListItemNode {
                listItemText = firstItem.getTextContent()
                    .replacingOccurrences(of: "\u{200B}", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        XCTAssertEqual(secondNodeType, NodeType.list.rawValue)
        XCTAssertEqual(listItemText, "")

        // Ensure the Lexical selection is collapsed at the start of the new list item.
        var isCollapsed = false
        var anchorOffset: Int?
        try? view.editorForTesting.read {
            if let selection = try? getSelection() as? RangeSelection {
                isCollapsed = selection.isCollapsed()
                anchorOffset = selection.anchor.offset
            }
        }
        XCTAssertTrue(isCollapsed)
        XCTAssertEqual(anchorOffset, 0)
        XCTAssertEqual(view.textView.selectedRange.length, 0)
    }

    func testMarkdownShortcutDashSpaceCreatesListWhenParagraphHasNextSibling() {
        let view = makeView()

        // Ensure the paragraph we're typing into has a next sibling (a heading).
        _ = view.loadMarkdown(MarkdownDocument(content: "Hello\n\n## Next"))

        // Put cursor at end of "Hello" and insert a new paragraph *before* the heading.
        try? view.editorForTesting.update {
            guard let root = getRoot(),
                  let firstParagraph = root.getFirstChild() as? ParagraphNode,
                  let text = firstParagraph.getFirstChild() as? TextNode else { return }
            let p = Point(key: text.key, offset: text.getTextContentSize(), type: .text)
            getActiveEditorState()?.selection = RangeSelection(anchor: p, focus: p, format: TextFormat())
        }

        view.editorForTesting.dispatchCommand(type: .insertText, payload: "\n")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: "-")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: " ")

        var secondNodeType: String?
        try? view.editorForTesting.read {
            guard let root = getRoot() else { return }
            guard let second = root.getChildAtIndex(index: 1) else { return }
            secondNodeType = type(of: second).getType().rawValue
        }

        XCTAssertEqual(secondNodeType, NodeType.list.rawValue)
    }

    func testMarkdownShortcutWorksAfterExitingEmptyListItemWithEnter() {
        let view = makeView()

        // Create a paragraph with a next sibling heading, then create an empty list item before the heading.
        _ = view.loadMarkdown(MarkdownDocument(content: "Hello\n\n## Next"))

        // Put cursor at end of "Hello" and insert a new paragraph *before* the heading.
        try? view.editorForTesting.update {
            guard let root = getRoot(),
                  let firstParagraph = root.getFirstChild() as? ParagraphNode,
                  let text = firstParagraph.getFirstChild() as? TextNode else { return }
            let p = Point(key: text.key, offset: text.getTextContentSize(), type: .text)
            getActiveEditorState()?.selection = RangeSelection(anchor: p, focus: p, format: TextFormat())
        }

        view.editorForTesting.dispatchCommand(type: .insertText, payload: "\n")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: "-")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: " ")

        XCTAssertEqual(rootChildrenTypes(view.editorForTesting)[1], NodeType.list.rawValue)

        // Exit the empty list item; Lexical may leave a ZWSP in the resulting paragraph.
        view.editorForTesting.dispatchCommand(type: .insertText, payload: "\n")

        XCTAssertEqual(rootChildrenTypes(view.editorForTesting)[1], NodeType.paragraph.rawValue)

        // Typing "-" should not create "-\u{200B}" which would break the "- " shortcut.
        view.editorForTesting.dispatchCommand(type: .insertText, payload: "-")

        var typedText: String?
        try? view.editorForTesting.read {
            guard let root = getRoot(),
                  let paragraph = root.getChildAtIndex(index: 1) as? ParagraphNode,
                  let text = paragraph.getFirstChild() as? TextNode else { return }
            typedText = text.getTextContent()
        }
        XCTAssertEqual(typedText, "-")

        view.editorForTesting.dispatchCommand(type: .insertText, payload: " ")

        XCTAssertEqual(rootChildrenTypes(view.editorForTesting)[1], NodeType.list.rawValue)
        XCTAssertEqual(view.textView.selectedRange.length, 0)
    }

    func testMarkdownShortcutStarSpaceCreatesList() {
        let view = makeView()
        _ = view.loadMarkdown(MarkdownDocument(content: "Hello"))

        view.editorForTesting.dispatchCommand(type: .insertText, payload: "\n")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: "*")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: " ")

        XCTAssertEqual(rootChildrenTypes(view.editorForTesting)[1], NodeType.list.rawValue)
    }

    func testMarkdownShortcutPlusSpaceCreatesList() {
        let view = makeView()
        _ = view.loadMarkdown(MarkdownDocument(content: "Hello"))

        view.editorForTesting.dispatchCommand(type: .insertText, payload: "\n")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: "+")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: " ")

        XCTAssertEqual(rootChildrenTypes(view.editorForTesting)[1], NodeType.list.rawValue)
    }

    func testMarkdownShortcutOrderedListCreatesOrderedList() {
        let view = makeView()
        _ = view.loadMarkdown(MarkdownDocument(content: "Hello"))

        view.editorForTesting.dispatchCommand(type: .insertText, payload: "\n")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: "1")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: ".")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: " ")

        var isNumberList = false
        try? view.editorForTesting.read {
            guard let root = getRoot(),
                  let list = root.getChildAtIndex(index: 1) as? ListNode else { return }
            isNumberList = list.getListType() == .number
        }
        XCTAssertTrue(isNumberList)
    }

    func testMarkdownShortcutDoesNotTriggerMidParagraph() {
        let view = makeView()
        _ = view.loadMarkdown(MarkdownDocument(content: "Hello"))

        // Type " - " at end of the paragraph (not at start of a new block).
        view.editorForTesting.dispatchCommand(type: .insertText, payload: " ")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: "-")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: " ")

        XCTAssertEqual(rootChildrenTypes(view.editorForTesting).first, NodeType.paragraph.rawValue)
        XCTAssertEqual(view.exportMarkdown().value?.content.contains("- ") ?? false, true)
    }

    func testMarkdownShortcutDoesNotTriggerInCodeBlock() {
        let view = makeView()
        _ = view.loadMarkdown(MarkdownDocument(content: "```swift\n\n```"))

        // Place caret inside code node and type "- ".
        try? view.editorForTesting.update {
            guard let root = getRoot(),
                  let code = root.getFirstChild() as? CodeNode,
                  let text = code.getFirstChild() as? TextNode else { return }
            let p = Point(key: text.key, offset: 0, type: .text)
            getActiveEditorState()?.selection = RangeSelection(anchor: p, focus: p, format: TextFormat())
        }

        view.editorForTesting.dispatchCommand(type: .insertText, payload: "-")
        view.editorForTesting.dispatchCommand(type: .insertText, payload: " ")

        // Still a code node, not a list.
        try? view.editorForTesting.read {
            guard let root = getRoot(),
                  let first = root.getFirstChild() else { return XCTFail("missing root child") }
            XCTAssertEqual(type(of: first).getType().rawValue, NodeType.code.rawValue)
        }
    }

    func testExportDoesNotContainZeroWidthSpace() {
        let view = makeView()
        _ = view.loadMarkdown(MarkdownDocument(content: "- "))
        let exported = view.exportMarkdown().value?.content ?? ""
        XCTAssertFalse(exported.contains("\u{200B}"))
    }

    func testTaskListMarkerImportsAsPlainListItem() {
        let view = makeView()
        _ = view.loadMarkdown(MarkdownDocument(content: "- [x] Done\n- [ ] Todo"))
        let exported = view.exportMarkdown().value?.content ?? ""
        XCTAssertTrue(exported.contains("- Done"))
        XCTAssertTrue(exported.contains("- Todo"))
        XCTAssertFalse(exported.contains("[x]"))
        XCTAssertFalse(exported.contains("[ ]"))
    }
}
