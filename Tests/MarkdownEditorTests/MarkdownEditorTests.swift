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
import LexicalLinkPlugin
import LexicalMarkdown
@testable import MarkdownEditor

// MARK: - Swift Testing Framework Examples

struct MarkdownEditorTests {

    @Test func basicEditorInitialization() async throws {
        let config = MarkdownEditorConfiguration.default
        let editor = MarkdownEditorView(configuration: config)
        
        #expect(editor.isEditable == true)
        #expect(editor.placeholderText == nil)
    }
    
    @Test func configurationSettings() async throws {
        let config = MarkdownEditorConfiguration()
            .features([.headers, .lists])
            .behavior(EditorBehavior(
                autoSave: false,
                autoCorrection: false,
                smartQuotes: false,
                returnKeyBehavior: .insertParagraph
            ))
        
        #expect(config.features.contains(.headers))
        #expect(config.features.contains(.lists))
        #expect(!config.features.contains(.codeBlocks))
        #expect(config.behavior.autoSave == false)
    }
    
    @Test func markdownDocumentCreation() async throws {
        let content = "# Hello World\n\nThis is a test document."
        let document = MarkdownDocument(content: content)
        
        #expect(document.content == content)
        #expect(document.metadata.version == "1.0")
    }
}

// MARK: - XCTest Examples using our Testing Framework

/// Example tests using XCTest with our comprehensive testing framework
/// These demonstrate the full power of the state transition testing pattern
class MarkdownEditorXCTestExamples: MarkdownTestCase {
    
    // MARK: - Basic Functionality Tests
    
    func testEditorInitialization() {
        XCTAssertNotNil(markdownEditor)
        XCTAssertTrue(markdownEditor.isEditable)
        XCTAssertNotNil(editor)
    }
    
    func testEmptyDocumentState() {
        given(emptyDocument)
            .when(MarkdownTestAction { _ in
                // Do nothing - just verify initial state
            })
            .then(expectEmptyDocument)
    }
    
    // MARK: - Header Conversion Tests
    
    func testSimpleHeaderCreation() {
        given(emptyDocument)
            .when(userTypes("# My Header"))
            .then(expectHeaderNode(.h1, text: "My Header"))
    }
    
    func testHeaderLevelProgression() {
        given(emptyDocument)
            .when(userTypes("# H1\n## H2\n### H3\n#### H4\n##### H5"))
            .then(expectChildCount(5))
    }
    
    func testHeaderBackspaceConversion() {
        given(headerDocument(.h2, "Section Title"))
            .when(userPressesBackspaceAtBeginning)
            .then(expectParagraphNode(text: "## Section Title"))
    }
    
    // MARK: - List Operation Tests
    
    func testUnorderedListCreation() {
        given(emptyDocument)
            .when(userTypes("- First item\n- Second item\n- Third item"))
            .then(expectListNode(type: .bullet))
    }
    
    func testOrderedListCreation() {
        given(emptyDocument)
            .when(userTypes("1. Step one\n2. Step two\n3. Step three"))
            .then(expectListNode(type: .number))
    }
    
    func testListItemBackspaceCollapse() {
        given(unorderedListDocument(items: ["Item 1", ""]))
            .when(userPressesBackspaceAtBeginning)
            .then(expectParagraphNode(text: ""))
    }
    
    // MARK: - Inline Formatting Tests
    
    func testBoldTextCreation() {
        given(emptyDocument)
            .when(userTypes("This text is **bold** and normal"))
            .then(expectFormattedText(text: "bold", bold: true))
    }
    
    func testItalicTextCreation() {
        given(emptyDocument)
            .when(userTypes("This text is *italic* and normal"))
            .then(expectFormattedText(text: "italic", italic: true))
    }
    
    func testMixedInlineFormatting() {
        given(emptyDocument)
            .when(userTypes("**Bold**, *italic*, and `code` formatting"))
            .then(expectNodeStructure({ rootNode in
                guard let paragraph = rootNode.getFirstChild() as? ParagraphNode else { return false }
                let textNodes = paragraph.getChildren().compactMap { $0 as? TextNode }
                
                let hasBold = textNodes.contains { $0.getTextContent() == "Bold" && $0.getFormat().bold }
                let hasItalic = textNodes.contains { $0.getTextContent() == "italic" && $0.getFormat().italic }
                let hasCode = textNodes.contains { $0.getTextContent() == "code" && $0.getFormat().code }
                
                return hasBold && hasItalic && hasCode
            }, description: "Should contain bold, italic, and code formatting"))
    }
    
    // MARK: - Block Element Tests
    
    func testCodeBlockCreation() {
        given(emptyDocument)
            .when(userTypes("```swift\nlet message = \"Hello, World!\"\nprint(message)\n```"))
            .then(expectCodeBlock(code: "let message = \"Hello, World!\"\nprint(message)", language: "swift"))
    }
    
    func testQuoteBlockCreation() {
        given(emptyDocument)
            .when(userTypes("> This is a quoted text\n> that spans multiple lines"))
            .then(expectQuoteBlock(text: "This is a quoted text\nthat spans multiple lines"))
    }
    
    // MARK: - Complex Document Structure Tests
    
    func testMixedContentDocument() {
        given(mixedContentDocument)
            .when(MarkdownTestAction { _ in
                // Just verify the structure is correct
            })
            .then(expectNodeStructure({ rootNode in
                let children = rootNode.getChildren()
                return children.count >= 4 &&
                       children[0] is HeadingNode &&
                       children[1] is ParagraphNode &&
                       children[2] is HeadingNode &&
                       children[3] is ListNode
            }, description: "Should have mixed content structure"))
    }
    
    func testDocumentEditing() {
        given(blogPostDocument)
            .when(userTypes("\n\nThis is an additional paragraph."))
            .then(expectNodeStructure({ rootNode in
                // Should have added content to the existing document
                return rootNode.getChildrenSize() > 5
            }, description: "Should have additional content"))
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyStringHandling() {
        given(emptyDocument)
            .when(userTypes(""))
            .then(expectEmptyDocument)
    }
    
    func testSpecialCharacterHandling() {
        let specialText = "Unicode: äöü, Emoji: 🎉, Math: ∑∞"
        given(emptyDocument)
            .when(userTypes(specialText))
            .then(expectParagraphNode(text: specialText))
    }
    
    func testLargeTextHandling() {
        let largeText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 50)
        given(emptyDocument)
            .when(userTypes(largeText))
            .then(expectParagraphNode(text: largeText))
    }
    
    // MARK: - State Consistency Tests
    
    func testMultipleOperationsConsistency() {
        given(emptyDocument)
            .when(MarkdownTestAction { editor in
                // Perform multiple operations in sequence
                try editor.update {
                    if let selection = try? getSelection() as? RangeSelection {
                        try selection.insertText("# Header\n\nParagraph with **bold** text.\n\n- List item")
                    }
                }
            })
            .then(expectNodeStructure({ rootNode in
                let children = rootNode.getChildren()
                return children.count >= 3 &&
                       children[0] is HeadingNode &&
                       children[1] is ParagraphNode &&
                       children[2] is ListNode
            }, description: "Should maintain consistent structure after multiple operations"))
    }
    
    // MARK: - Selection and Navigation Tests
    
    func testSelectionAfterFormatting() {
        given(emptyDocument)
            .when(MarkdownTestAction { editor in
                try editor.update {
                    if let selection = try? getSelection() as? RangeSelection {
                        try selection.insertText("This is **bold** text")
                    }
                }
                
                // Verify selection is maintained properly
                try editor.getEditorState().read {
                    guard let selection = try? getSelection() as? RangeSelection else {
                        XCTFail("Selection should be maintained")
                        return
                    }
                    XCTAssertTrue(selection.isCollapsed(), "Selection should be collapsed after insertion")
                }
            })
            .then(expectFormattedText(text: "bold", bold: true))
    }
    
    // MARK: - Error Handling Tests
    
    func testMalformedMarkdownHandling() {
        given(emptyDocument)
            .when(userTypes("**unclosed bold\n\n*unclosed italic\n\n```unclosed code"))
            .then(expectNodeStructure({ rootNode in
                // Should handle malformed markdown gracefully
                return rootNode.getChildrenSize() > 0
            }, description: "Should handle malformed markdown"))
    }
    
    // MARK: - Performance Validation Tests
    
    func testRapidEditingPerformance() {
        measure {
            given(emptyDocument)
                .when(MarkdownTestAction { editor in
                    // Simulate rapid editing
                    for i in 1...100 {
                        try editor.update {
                            if let selection = try? getSelection() as? RangeSelection {
                                try selection.insertText("Word\(i) ")
                            }
                        }
                    }
                })
                .then(expectNodeStructure({ rootNode in
                    return rootNode.getTextContent().contains("Word100")
                }, description: "Should handle rapid editing"))
        }
    }
    
    // MARK: - Regression Tests for Known Issues
    
    func testZeroWidthSpaceFixPlugin() {
        // Test the specific plugin we saw in the codebase
        given(unorderedListDocument(items: ["\u{200B}"]))  // Zero-width space
            .when(userPressesBackspaceAtBeginning)
            .then(expectParagraphNode(text: ""))
    }
    
    func testNestedListHandling() {
        given(nestedListDocument)
            .when(MarkdownTestAction { _ in
                // Just verify nested structure is maintained
            })
            .then(expectNodeStructure({ rootNode in
                guard let mainList = rootNode.getFirstChild() as? ListNode,
                      let firstItem = mainList.getFirstChild() as? ListItemNode else { return false }
                
                // First item should contain a sub-list
                let firstItemChildren = firstItem.getChildren()
                return firstItemChildren.count > 1
            }, description: "Should maintain nested list structure"))
    }
    
    // MARK: - Regression: Heading Enter should split to new paragraph
    func testHeadingEnterSplitsToParagraphAndMovesCaret() {
        given(paragraphDocument("New heading"))
            .when(MarkdownTestAction { editor in
                // Place caret at end of text
                try editor.update {
                    guard let selection = try? getSelection() as? RangeSelection,
                          let root = getRoot(),
                          let paragraph = root.getFirstChild() as? ParagraphNode,
                          let textNode = paragraph.getFirstChild() as? TextNode else { return }
                    let p = Point(key: textNode.key, offset: textNode.getTextContentSize(), type: .text)
                    let sel = RangeSelection(anchor: p, focus: p, format: TextFormat())
                    getActiveEditorState()?.selection = sel
                }
                // Toggle to H2 via editor API
                let view = self.markdownEditor!
                view.setBlockType(.heading(level: .h2))
                // Simulate Enter via insertText so our handler is exercised
                editor.dispatchCommand(type: .insertText, payload: "\n")
            })
            .then(expectNodeStructure({ root in
                // Expect two blocks: h2 followed by paragraph with empty or caret at start position
                guard root.getChildrenSize() >= 2,
                      let heading = root.getChildAtIndex(index: 0) as? HeadingNode,
                      let para = root.getChildAtIndex(index: 1) as? ParagraphNode else { return false }
                return heading.getTextContent() == "New heading" && para.isEmpty()
            }, description: "Enter on heading should create a new paragraph below"))
    }
    
    // MARK: - Regression: Toggling list twice should revert to paragraph
    func testUnorderedListToggleRevertsToParagraph() {
        given(paragraphDocument("T"))
            .when(MarkdownTestAction { _ in
                let view = self.markdownEditor!
                view.setBlockType(.unorderedList)
                view.setBlockType(.unorderedList) // toggle off
            })
            .then(expectNodeStructure({ root in
                root.getFirstChild() is ParagraphNode
            }, description: "Reapplying unordered list should toggle back to paragraph"))
    }
    
    // MARK: - Regression: Toggling same heading level reverts to paragraph
    func testHeadingSameLevelToggleRevertsToParagraph() {
        given(paragraphDocument("Te"))
            .when(MarkdownTestAction { _ in
                let view = self.markdownEditor!
                view.setBlockType(.heading(level: .h1))
                view.setBlockType(.heading(level: .h1)) // toggle off
            })
            .then(expectNodeStructure({ root in
                guard let para = root.getFirstChild() as? ParagraphNode else { return false }
                return para.getTextContent() == "Te"
            }, description: "Reapplying same heading level should toggle back to paragraph"))
    }
    
    // MARK: - Regression: Caret preserved when toggling to heading
    func testCaretPreservedWhenTogglingToHeading() {
        given(paragraphDocument("Te"))
            .when(MarkdownTestAction { editor in
                // Place caret at end (offset 2)
                try editor.update {
                    guard let root = getRoot(),
                          let paragraph = root.getFirstChild() as? ParagraphNode,
                          let textNode = paragraph.getFirstChild() as? TextNode else { return }
                    let p = Point(key: textNode.key, offset: textNode.getTextContentSize(), type: .text)
                    let sel = RangeSelection(anchor: p, focus: p, format: TextFormat())
                    getActiveEditorState()?.selection = sel
                }
                // Toggle to H1
                self.markdownEditor.setBlockType(.heading(level: .h1))
                // Assert caret offset remains at end of text node
                try editor.getEditorState().read {
                    guard let selection = try? getSelection() as? RangeSelection,
                          let node = try? selection.anchor.getNode() as? TextNode else {
                        XCTFail("Missing selection or text node after toggle")
                        return
                    }
                    XCTAssertEqual(selection.anchor.offset, node.getTextContentSize())
                }
            })
            .then(expectHeaderNode(.h1, text: "Te"))
    }
    
    // MARK: - Regression: Caret preserved when toggling list on/off
    func testCaretPreservedWhenTogglingListOnOff() {
        given(paragraphDocument("Item"))
            .when(MarkdownTestAction { editor in
                // Place caret at end of text
                try editor.update {
                    guard let root = getRoot(),
                          let paragraph = root.getFirstChild() as? ParagraphNode,
                          let textNode = paragraph.getFirstChild() as? TextNode else { return }
                    let p = Point(key: textNode.key, offset: textNode.getTextContentSize(), type: .text)
                    let sel = RangeSelection(anchor: p, focus: p, format: TextFormat())
                    getActiveEditorState()?.selection = sel
                }
                // Toggle list on then off
                self.markdownEditor.setBlockType(.unorderedList)
                self.markdownEditor.setBlockType(.unorderedList)
                // Verify caret at end of text
                try editor.getEditorState().read {
                    guard let selection = try? getSelection() as? RangeSelection,
                          let node = try? selection.anchor.getNode() as? TextNode else {
                        XCTFail("Missing selection after list toggle")
                        return
                    }
                    XCTAssertEqual(selection.anchor.offset, node.getTextContentSize())
                }
            })
            .then(expectParagraphNode(text: "Item"))
    }
}
