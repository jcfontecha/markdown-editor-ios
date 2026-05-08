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

    func testPasteCommandParsesMarkdownFromUIPasteboard() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: ""))

        let pasteboard = UIPasteboard.withUniqueName()
        pasteboard.string = """
        # Heading 1
        ## Heading 2

        **bold** and *italic* and ***both***

        - bullet point
        - another one
          - nested

        1. numbered
        2. list

        [link text](https://example.com)
        ![alt text](image.jpg)

        `inline code` and:

        ```python
        def hello():
            print("hi")
        ```

        > blockquote

        | col1 | col2 |
        |------|------|
        | a    | b    |

        ---

        ~~strikethrough~~ and - [ ] task list
        """

        editor.dispatchCommand(type: .paste, payload: pasteboard)

        var topLevelTypes: [NodeType] = []
        var hasH1 = false
        var hasH2 = false
        var hasBold = false
        var hasItalic = false
        var hasCode = false
        var hasStrike = false
        var hasLink = false
        try editor.read {
            guard let root = getRoot() else { return }
            topLevelTypes = root.getChildren().map { type(of: $0).getType() }

            for child in root.getChildren() {
                if let heading = child as? HeadingNode {
                    hasH1 = hasH1 || heading.getTag() == .h1
                    hasH2 = hasH2 || heading.getTag() == .h2
                }
            }

            func visit(_ node: Node) {
                if let text = node as? TextNode {
                    hasBold = hasBold || text.getFormat().bold
                    hasItalic = hasItalic || text.getFormat().italic
                    hasCode = hasCode || text.getFormat().code
                    hasStrike = hasStrike || text.getFormat().strikethrough
                }
                hasLink = hasLink || node is LinkNode
                if let element = node as? ElementNode {
                    element.getChildren().forEach(visit)
                }
            }
            visit(root)
        }

        XCTAssertTrue(hasH1)
        XCTAssertTrue(hasH2)
        XCTAssertTrue(topLevelTypes.contains(.list))
        XCTAssertTrue(topLevelTypes.contains(.code))
        XCTAssertTrue(topLevelTypes.contains(.quote))
        XCTAssertTrue(hasBold)
        XCTAssertTrue(hasItalic)
        XCTAssertTrue(hasCode)
        XCTAssertTrue(hasStrike)
        XCTAssertTrue(hasLink)
        XCTAssertFalse(markdownEditor.textView.text.contains("# Heading 1"))
    }

    func testHeadingMarkdownShortcutsConvertEmptyParagraphs() throws {
        for (marker, expectedTag) in [("#", HeadingTagType.h1), ("##", .h2), ("###", .h3), ("####", .h4), ("#####", .h5), ("######", .h5)] {
            try resetToEmptyParagraph()

            markdownEditor.textView.insertText(marker)
            markdownEditor.textView.insertText(" ")

            try editor.read {
                let heading = try XCTUnwrap(getRoot()?.getFirstChild() as? HeadingNode, marker)
                XCTAssertEqual(heading.getTag(), expectedTag, marker)
                XCTAssertEqual(visibleText(heading), "", marker)
            }
        }
    }

    func testHeadingShortcutDoesNotTriggerAwayFromParagraphStart() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: "hello#"))

        try selectText("hello#", offset: 6)
        markdownEditor.textView.insertText(" ")

        try editor.read {
            XCTAssertTrue(getRoot()?.getFirstChild() is ParagraphNode)
            XCTAssertEqual(getRoot()?.getTextContent(), "hello# ")
        }
    }

    func testEmptySubtitleToolbarUpdatesPlaceholderFontBeforeTyping() throws {
        markdownEditor.placeholderText = "Write something"
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: ""))

        markdownEditor.setBlockType(.heading(level: .h2))

        XCTAssertEqual(markdownEditor.textView.font?.pointSize, MarkdownEditorConfiguration.default.theme.typography.h2.pointSize)

        markdownEditor.textView.insertText("Subtitle")
        try editor.read {
            let heading = try XCTUnwrap(getRoot()?.getFirstChild() as? HeadingNode)
            XCTAssertEqual(heading.getTag(), .h2)
            XCTAssertEqual(heading.getTextContent(), "Subtitle")
        }
    }

    func testEnterAtEndOfTitlePlacesNativeAndLexicalCaretInNewParagraph() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: "# Title"))
        try selectText("Title", offset: 5)

        markdownEditor.textView.insertText("\n")

        let nativeLocation = markdownEditor.textView.selectedRange.location
        XCTAssertGreaterThanOrEqual(nativeLocation, ("Title\n" as NSString).length)

        try editor.read {
            let root = try XCTUnwrap(getRoot())
            XCTAssertTrue(root.getFirstChild() is HeadingNode)
            let paragraph = try XCTUnwrap(root.getChildAtIndex(index: 1) as? ParagraphNode)
            let selection = try XCTUnwrap(getSelection() as? RangeSelection)
            let selectedNode = try selection.anchor.getNode()
            XCTAssertTrue(selectedNode === paragraph || selectedNode.getParent() === paragraph)
            XCTAssertEqual(selection.anchor.offset, 0)
        }
    }

    func testSubtitleToolbarConvertsNewEmptyBodyLineBeforeTyping() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: "Body"))
        try selectText("Body", offset: 4)

        markdownEditor.textView.insertText("\n")
        markdownEditor.setBlockType(.heading(level: .h2))

        try editor.read {
            let root = try XCTUnwrap(getRoot())
            XCTAssertTrue(root.getFirstChild() is ParagraphNode)
            let heading = try XCTUnwrap(root.getChildAtIndex(index: 1) as? HeadingNode)
            XCTAssertEqual(heading.getTag(), .h2)
            XCTAssertEqual(visibleText(heading), "")

            let selection = try XCTUnwrap(getSelection() as? RangeSelection)
            let selectedNode = try selection.anchor.getNode()
            XCTAssertTrue(selectedNode === heading || selectedNode.getParent() === heading)
            XCTAssertEqual(selection.anchor.offset, 0)
            XCTAssertEqual(selection.anchor.type, .text)
        }
    }

    func testMarkdownPasteHidesPlaceholder() throws {
        markdownEditor.placeholderText = "Write something"
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: ""))

        let pasteboard = UIPasteboard.withUniqueName()
        pasteboard.string = "# Pasted"
        editor.dispatchCommand(type: .paste, payload: pasteboard)

        let placeholderLabel = markdownEditor.textView.subviews
            .compactMap { $0 as? UILabel }
            .first { $0.text == "Write something" }
        XCTAssertEqual(placeholderLabel?.isHidden, true)
    }

    func testConsecutiveEntersAfterTitleAppendParagraphsAfterTitle() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: "# Title"))
        try selectText("Title", offset: 5)

        markdownEditor.textView.insertText("\n")
        markdownEditor.textView.insertText("\n")

        try editor.read {
            let root = try XCTUnwrap(getRoot())
            XCTAssertTrue(root.getChildAtIndex(index: 0) is HeadingNode)
            XCTAssertTrue(root.getChildAtIndex(index: 1) is ParagraphNode)
            XCTAssertTrue(root.getChildAtIndex(index: 2) is ParagraphNode)
            XCTAssertEqual(
                root.getTextContent()
                    .replacingOccurrences(of: "\u{200B}", with: "")
                    .replacingOccurrences(of: "\n", with: ""),
                "Title"
            )

            let selection = try XCTUnwrap(getSelection() as? RangeSelection)
            let lastParagraph = try XCTUnwrap(root.getChildAtIndex(index: 2) as? ParagraphNode)
            let selectedNode = try selection.anchor.getNode()
            XCTAssertTrue(selectedNode === lastParagraph || selectedNode.getParent() === lastParagraph)
            XCTAssertEqual(selection.anchor.offset, 0)
        }
    }

    func testToolbarConvertsSelectedEmptyParagraphAcrossBlockTypes() throws {
        let cases: [(MarkdownBlockType, NodeType)] = [
            (.heading(level: .h1), .heading),
            (.heading(level: .h2), .heading),
            (.heading(level: .h3), .heading),
            (.quote, .quote),
            (.codeBlock, .code),
            (.paragraph, .paragraph)
        ]

        for (blockType, expectedType) in cases {
            try resetToEmptyParagraph()

            markdownEditor.setBlockType(blockType)

            try editor.read {
                let first = try XCTUnwrap(getRoot()?.getFirstChild(), "\(blockType)")
                XCTAssertEqual(type(of: first).getType(), expectedType, "\(blockType)")
                XCTAssertEqual(visibleText(first), "", "\(blockType)")
            }
        }
    }

    func testCaretRectAfterBodyEnterStaysOnNewLineNotDocumentOrigin() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: """
        First
        Second
        """))
        try selectText("Second", offset: 6)

        let beforeRange = markdownEditor.textView.selectedTextRange
        let beforeRect = beforeRange.map { markdownEditor.textView.caretRect(for: $0.start) } ?? .zero

        markdownEditor.textView.insertText("\n")
        markdownEditor.textView.layoutIfNeeded()

        let afterRange = try XCTUnwrap(markdownEditor.textView.selectedTextRange)
        let afterRect = markdownEditor.textView.caretRect(for: afterRange.start)
        XCTAssertGreaterThan(afterRect.midY, beforeRect.midY)
        XCTAssertGreaterThan(afterRect.minY, 1)
    }

    func testListShortcutStillWorksAfterHeadingShortcutChanges() throws {
        try resetToEmptyParagraph()

        markdownEditor.textView.insertText("-")
        markdownEditor.textView.insertText(" ")

        try editor.read {
            let list = try XCTUnwrap(getRoot()?.getFirstChild() as? ListNode)
            XCTAssertEqual(list.getListType(), .bullet)
            XCTAssertEqual(list.getChildrenSize(), 1)
        }
    }

    func testHeadingShortcutDoesNotTriggerWithEscapedMarker() throws {
        try resetToEmptyParagraph()

        markdownEditor.textView.insertText("\\#")
        markdownEditor.textView.insertText(" ")

        try editor.read {
            XCTAssertTrue(getRoot()?.getFirstChild() is ParagraphNode)
            XCTAssertEqual(getRoot()?.getTextContent(), "\\# ")
        }
    }

    func testMarkdownEditorUsesLexicalFontMetricCaretInsteadOfBlockCursorShim() throws {
        let textView = markdownEditor.textView as! TextView
        XCTAssertNil(textView.cursorDelegate)
    }

    func testNativeAutocorrectReplacementUsesUIKitRangeInsteadOfStaleLexicalSelection() throws {
        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: """
        # Here's a title
        ## And a subtitle
        And some text here
        """))

        try selectText("Here's a title", offset: 0)

        let fullText = markdownEditor.textView.text as NSString
        let bodyRange = fullText.range(of: "here", options: [], range: NSRange(location: 0, length: fullText.length))
        XCTAssertNotEqual(bodyRange.location, NSNotFound)

        markdownEditor.textView.textStorage.replaceCharacters(in: bodyRange, with: "hwre")

        let exported = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
        XCTAssertTrue(exported.contains("# Here's a title"))
        XCTAssertTrue(exported.contains("And some text hwre"))
        XCTAssertFalse(exported.contains("# Here's a hwre"))
    }

    private func resetToEmptyParagraph() throws {
        try editor.update {
            guard let root = getRoot() else {
                XCTFail("Missing root")
                return
            }
            for child in root.getChildren() {
                try child.remove()
            }
            let paragraph = createParagraphNode()
            let text = createTextNode(text: "")
            try paragraph.append([text])
            try root.append([paragraph])
            let point = Point(key: text.key, offset: 0, type: .text)
            getActiveEditorState()?.selection = RangeSelection(anchor: point, focus: point, format: TextFormat())
        }
    }

    private func visibleText(_ node: Node) -> String {
        node.getTextContent()
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\n", with: "")
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
