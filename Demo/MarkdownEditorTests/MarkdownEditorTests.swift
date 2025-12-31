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
    func testEnterOnEmptyListItemConvertsToParagraph() {
        let view = MarkdownEditorContentView(configuration: .init(behavior: .init(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .smart,
            startWithTitle: false
        )))

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
        let view = MarkdownEditorContentView(configuration: .init(behavior: .init(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .smart,
            startWithTitle: false
        )))

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
        let view = MarkdownEditorContentView(configuration: .init(behavior: .init(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .smart,
            startWithTitle: false
        )))

        _ = view.loadMarkdown(MarkdownDocument(content: "# Title\r\n\r\nParagraph\r\n"))
        let exported = view.exportMarkdown().value?.content
        XCTAssertNotNil(exported)
        XCTAssertFalse(exported?.contains("\r") ?? true)
    }

    func testMarkdownRoundTripIsStable() {
        let view = MarkdownEditorContentView(configuration: .init(behavior: .init(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .smart,
            startWithTitle: false
        )))

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
        let view = MarkdownEditorContentView(configuration: .init(behavior: .init(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .smart,
            startWithTitle: false
        )))

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
        let view = MarkdownEditorContentView(configuration: .init(behavior: .init(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .smart,
            startWithTitle: false
        )))

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
        let view = MarkdownEditorContentView(configuration: .init(behavior: .init(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .smart,
            startWithTitle: false
        )))

        _ = view.loadMarkdown(MarkdownDocument(content: "- One\n- Two"))
        let exported = view.exportMarkdown().value?.content ?? ""
        XCTAssertTrue(exported.contains("- One"))
        XCTAssertTrue(exported.contains("- Two"))
    }

    func testExportContainsCodeFence() {
        let view = MarkdownEditorContentView(configuration: .init(behavior: .init(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .smart,
            startWithTitle: false
        )))

        _ = view.loadMarkdown(MarkdownDocument(content: "```swift\nlet x = 1\n```"))
        let exported = view.exportMarkdown().value?.content ?? ""
        XCTAssertTrue(exported.contains("```"))
        XCTAssertTrue(exported.contains("let x = 1"))
    }

    func testLoadListCreatesProperListNode() {
        let view = MarkdownEditorContentView(configuration: .init(behavior: .init(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .smart,
            startWithTitle: false
        )))

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
        let view = MarkdownEditorContentView(configuration: .init(behavior: .init(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .smart,
            startWithTitle: false
        )))

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

    func testMarkdownShortcutDashSpaceCreatesList() {
        let view = MarkdownEditorContentView(configuration: .init(behavior: .init(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .smart,
            startWithTitle: false
        )))

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
    }

    func testMarkdownShortcutDashSpaceCreatesListWhenParagraphHasNextSibling() {
        let view = MarkdownEditorContentView(configuration: .init(behavior: .init(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .smart,
            startWithTitle: false
        )))

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
}
