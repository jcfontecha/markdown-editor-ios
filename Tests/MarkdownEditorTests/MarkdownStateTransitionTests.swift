import XCTest
import Lexical
import LexicalListPlugin
import LexicalLinkPlugin
import LexicalMarkdown
@testable import MarkdownEditor

// MARK: - State Transition Tests (Fixed API Usage)

/// Complex state transition tests using the correct lexical-ios APIs
/// These tests demonstrate the A → X → B pattern you requested
class MarkdownStateTransitionTests: MarkdownTestCase {
    
    // MARK: - Header State Transitions
    
    func testEmptyToHeaderTransition() {
        do {
            // Given: Empty document
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                // Add empty paragraph
                let paragraph = ParagraphNode()
                try rootNode.append([paragraph])
            }
            
            // When: User types "# Title"
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else { return }
                
                // Remove the paragraph and add header
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let header = createHeadingNode(headingTag: .h1)
                let text = TextNode()
                try text.setText("Title")
                try header.append([text])
                try rootNode.append([header])
            }
            
            // Then: Should have H1 with "Title"
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode(),
                      let header = rootNode.getFirstChild() as? HeadingNode else {
                    XCTFail("Expected header node")
                    return
                }
                
                XCTAssertEqual(header.getTag(), .h1)
                XCTAssertEqual(header.getTextContent(), "Title")
            }
        } catch {
            XCTFail("Header transition failed: \(error)")
        }
    }
    
    func testHeaderLevelChangeTransition() {
        do {
            // Given: H1 header
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else { return }
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let h1 = createHeadingNode(headingTag: .h1)
                let text = TextNode()
                try text.setText("Original Title")
                try h1.append([text])
                try rootNode.append([h1])
            }
            
            // When: Change to H2
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode(),
                      let oldHeader = rootNode.getFirstChild() as? HeadingNode else { return }
                
                let content = oldHeader.getTextContent()
                try oldHeader.remove()
                
                let h2 = createHeadingNode(headingTag: .h2)
                let text = TextNode()
                try text.setText(content)
                try h2.append([text])
                try rootNode.append([h2])
            }
            
            // Then: Should have H2 with same content
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode(),
                      let header = rootNode.getFirstChild() as? HeadingNode else {
                    XCTFail("Expected header node")
                    return
                }
                
                XCTAssertEqual(header.getTag(), .h2)
                XCTAssertEqual(header.getTextContent(), "Original Title")
            }
        } catch {
            XCTFail("Header level change failed: \(error)")
        }
    }
    
    // MARK: - List State Transitions
    
    func testParagraphToListTransition() {
        do {
            // Given: Paragraph with text
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else { return }
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let paragraph = ParagraphNode()
                let text = TextNode()
                try text.setText("Item text")
                try paragraph.append([text])
                try rootNode.append([paragraph])
            }
            
            // When: Convert to list item
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode(),
                      let paragraph = rootNode.getFirstChild() as? ParagraphNode else { return }
                
                let content = paragraph.getTextContent()
                try paragraph.remove()
                
                let list = ListNode(listType: .bullet, start: 1)
                let item = ListItemNode()
                let text = TextNode()
                try text.setText(content)
                try item.append([text])
                try list.append([item])
                try rootNode.append([list])
            }
            
            // Then: Should have bulleted list with item
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode(),
                      let list = rootNode.getFirstChild() as? ListNode else {
                    XCTFail("Expected list node")
                    return
                }
                
                XCTAssertEqual(list.getListType(), .bullet)
                XCTAssertEqual(list.getChildrenSize(), 1)
                XCTAssertEqual(list.getTextContent(), "Item text")
            }
        } catch {
            XCTFail("Paragraph to list transition failed: \(error)")
        }
    }
    
    func testListTypeChangeTransition() {
        do {
            // Given: Unordered list
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else { return }
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let list = ListNode(listType: .bullet, start: 1)
                let item = ListItemNode()
                let text = TextNode()
                try text.setText("List item")
                try item.append([text])
                try list.append([item])
                try rootNode.append([list])
            }
            
            // When: Change to ordered list
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode(),
                      let oldList = rootNode.getFirstChild() as? ListNode else { return }
                
                let items = oldList.getChildren()
                try oldList.remove()
                
                let newList = ListNode(listType: .number, start: 1)
                for item in items {
                    try newList.append([item])
                }
                try rootNode.append([newList])
            }
            
            // Then: Should have numbered list
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode(),
                      let list = rootNode.getFirstChild() as? ListNode else {
                    XCTFail("Expected list node")
                    return
                }
                
                XCTAssertEqual(list.getListType(), .number)
                XCTAssertEqual(list.getStart(), 1)
                XCTAssertEqual(list.getTextContent(), "List item")
            }
        } catch {
            XCTFail("List type change transition failed: \(error)")
        }
    }
    
    // MARK: - Text Formatting State Transitions
    
    func testPlainToBoldTransition() {
        do {
            // Given: Plain text
            var textNodeRef: TextNode?
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else { return }
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let paragraph = ParagraphNode()
                let text = TextNode()
                try text.setText("Regular text")
                try paragraph.append([text])
                try rootNode.append([paragraph])
                textNodeRef = text
            }
            
            // When: Apply bold formatting
            try editor.update {
                guard let textNode = textNodeRef else { return }
                try textNode.setBold(true)
            }
            
            // Then: Text should be bold
            try editor.getEditorState().read {
                guard let textNode = textNodeRef else {
                    XCTFail("Lost text node reference")
                    return
                }
                
                XCTAssertTrue(textNode.getFormat().bold)
                XCTAssertFalse(textNode.getFormat().italic)
                XCTAssertEqual(textNode.getTextContent(), "Regular text")
            }
        } catch {
            XCTFail("Plain to bold transition failed: \(error)")
        }
    }
    
    func testBoldToItalicTransition() {
        do {
            // Given: Bold text
            var textNodeRef: TextNode?
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else { return }
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let paragraph = ParagraphNode()
                let text = TextNode()
                try text.setText("Formatted text")
                try text.setBold(true)
                try paragraph.append([text])
                try rootNode.append([paragraph])
                textNodeRef = text
            }
            
            // When: Change to italic
            try editor.update {
                guard let textNode = textNodeRef else { return }
                try textNode.setBold(false)
                try textNode.setItalic(true)
            }
            
            // Then: Text should be italic, not bold
            try editor.getEditorState().read {
                guard let textNode = textNodeRef else {
                    XCTFail("Lost text node reference")
                    return
                }
                
                XCTAssertFalse(textNode.getFormat().bold)
                XCTAssertTrue(textNode.getFormat().italic)
                XCTAssertEqual(textNode.getTextContent(), "Formatted text")
            }
        } catch {
            XCTFail("Bold to italic transition failed: \(error)")
        }
    }
    
    // MARK: - Complex Document State Transitions
    
    func testDocumentRestructureTransition() {
        do {
            // Given: Simple paragraph document
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else { return }
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let paragraph = ParagraphNode()
                let text = TextNode()
                try text.setText("Simple content")
                try paragraph.append([text])
                try rootNode.append([paragraph])
            }
            
            // When: Restructure to title + list
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else { return }
                try rootNode.getChildren().forEach { try $0.remove() }
                
                // Add title
                let title = createHeadingNode(headingTag: .h1)
                let titleText = TextNode()
                try titleText.setText("Document Title")
                try title.append([titleText])
                try rootNode.append([title])
                
                // Add list
                let list = ListNode(listType: .bullet, start: 1)
                let item = ListItemNode()
                let itemText = TextNode()
                try itemText.setText("Simple content")
                try item.append([itemText])
                try list.append([item])
                try rootNode.append([list])
            }
            
            // Then: Should have title and list structure
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                let children = rootNode.getChildren()
                XCTAssertEqual(children.count, 2)
                
                guard let header = children[0] as? HeadingNode,
                      let list = children[1] as? ListNode else {
                    XCTFail("Expected header and list")
                    return
                }
                
                XCTAssertEqual(header.getTag(), .h1)
                XCTAssertEqual(header.getTextContent(), "Document Title")
                XCTAssertEqual(list.getListType(), .bullet)
                XCTAssertEqual(list.getTextContent(), "Simple content")
            }
        } catch {
            XCTFail("Document restructure transition failed: \(error)")
        }
    }
    
    // MARK: - Edge Case State Transitions
    
    func testEmptyToEmptyTransition() {
        do {
            // Given: Empty document
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else { return }
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let paragraph = ParagraphNode()
                try rootNode.append([paragraph])
            }
            
            // When: No change operation
            let initialChildCount = try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode() else { return 0 }
                return rootNode.getChildrenSize()
            }
            
            // Then: Document should remain empty but valid
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                XCTAssertEqual(rootNode.getChildrenSize(), initialChildCount)
                XCTAssertTrue(rootNode.getChildrenSize() > 0, "Should maintain paragraph structure")
            }
        } catch {
            XCTFail("Empty to empty transition failed: \(error)")
        }
    }
    
    func testMultipleFormattingTransition() {
        do {
            // Given: Plain text
            var textNodeRef: TextNode?
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else { return }
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let paragraph = ParagraphNode()
                let text = TextNode()
                try text.setText("Multi format text")
                try paragraph.append([text])
                try rootNode.append([paragraph])
                textNodeRef = text
            }
            
            // When: Apply multiple formats
            try editor.update {
                guard let textNode = textNodeRef else { return }
                try textNode.setBold(true)
                try textNode.setItalic(true)
            }
            
            // Then: Should have both bold and italic
            try editor.getEditorState().read {
                guard let textNode = textNodeRef else {
                    XCTFail("Lost text node reference")
                    return
                }
                
                XCTAssertTrue(textNode.getFormat().bold)
                XCTAssertTrue(textNode.getFormat().italic)
                XCTAssertEqual(textNode.getTextContent(), "Multi format text")
            }
        } catch {
            XCTFail("Multiple formatting transition failed: \(error)")
        }
    }
}