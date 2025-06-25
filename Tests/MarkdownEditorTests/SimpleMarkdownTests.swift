import XCTest
import Lexical
import LexicalListPlugin
import LexicalLinkPlugin
import LexicalMarkdown
@testable import MarkdownEditor

// MARK: - Simplified Markdown Tests

/// Simplified testing approach that works with the current lexical-ios API
/// This provides a working foundation that can be expanded as needed
class SimpleMarkdownTests: XCTestCase {
    
    var markdownEditor: MarkdownEditorView!
    var lexicalView: LexicalView { markdownEditor.textView.superview as! LexicalView }
    var editor: Editor { lexicalView.editor }
    
    override func setUp() {
        super.setUp()
        let config = MarkdownEditorConfiguration.default
        markdownEditor = MarkdownEditorView(configuration: config)
        
        // Ensure the view is properly initialized
        _ = markdownEditor.frame
    }
    
    override func tearDown() {
        markdownEditor = nil
        super.tearDown()
    }
    
    // MARK: - Basic Editor Tests
    
    func testEditorInitialization() {
        XCTAssertNotNil(markdownEditor)
        XCTAssertTrue(markdownEditor.isEditable)
        XCTAssertNotNil(editor)
    }
    
    func testEditorConfiguration() {
        let config = MarkdownEditorConfiguration()
            .features([.headers, .lists])
            .behavior(EditorBehavior(
                autoSave: false,
                autoCorrection: false,
                smartQuotes: false,
                returnKeyBehavior: .insertParagraph
            ))
        
        XCTAssertTrue(config.features.contains(.headers))
        XCTAssertTrue(config.features.contains(.lists))
        XCTAssertFalse(config.features.contains(.codeBlocks))
        XCTAssertFalse(config.behavior.autoSave)
    }
    
    // MARK: - Document Model Tests
    
    func testMarkdownDocumentCreation() {
        let content = "# Hello World\n\nThis is a test document."
        let document = MarkdownDocument(content: content)
        
        XCTAssertEqual(document.content, content)
        XCTAssertEqual(document.metadata.version, "1.0")
    }
    
    func testDocumentMetadata() {
        let createdDate = Date()
        let modifiedDate = Date()
        let metadata = DocumentMetadata(
            createdAt: createdDate,
            modifiedAt: modifiedDate,
            version: "2.0"
        )
        
        XCTAssertEqual(metadata.createdAt, createdDate)
        XCTAssertEqual(metadata.modifiedAt, modifiedDate)
        XCTAssertEqual(metadata.version, "2.0")
    }
    
    // MARK: - Basic Editor State Tests
    
    func testEmptyEditorState() {
        do {
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                XCTAssertNotNil(rootNode)
                XCTAssertTrue(rootNode.getChildrenSize() > 0, "Root should have at least one child")
            }
        } catch {
            XCTFail("Failed to read editor state: \(error)")
        }
    }
    
    func testNodeCreation() {
        do {
            try editor.update {
                // Test creating basic nodes
                let textNode = TextNode()
                try textNode.setText("Test text")
                XCTAssertEqual(textNode.getTextContent(), "Test text")
                
                let paragraphNode = ParagraphNode()
                XCTAssertNotNil(paragraphNode)
                
                let headingNode = createHeadingNode(headingTag: .h1)
                XCTAssertEqual(headingNode.getTag(), .h1)
            }
        } catch {
            XCTFail("Failed to create nodes: \(error)")
        }
    }
    
    // MARK: - Text Content Tests
    
    func testSimpleTextInsertion() {
        do {
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode(),
                      let firstChild = rootNode.getFirstChild() as? ParagraphNode else {
                    XCTFail("Expected paragraph as first child")
                    return
                }
                
                let textNode = TextNode()
                try textNode.setText("Hello, World!")
                try firstChild.append([textNode])
            }
            
            // Verify the text was inserted
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode(),
                      let firstChild = rootNode.getFirstChild() as? ParagraphNode else {
                    XCTFail("Expected paragraph as first child")
                    return
                }
                
                XCTAssertEqual(firstChild.getTextContent(), "Hello, World!")
            }
        } catch {
            XCTFail("Failed to insert text: \(error)")
        }
    }
    
    func testMultipleParagraphs() {
        do {
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                // Add first paragraph
                let para1 = ParagraphNode()
                let text1 = TextNode()
                try text1.setText("First paragraph")
                try para1.append([text1])
                
                // Add second paragraph
                let para2 = ParagraphNode()
                let text2 = TextNode()
                try text2.setText("Second paragraph")
                try para2.append([text2])
                
                try rootNode.append([para1, para2])
            }
            
            // Verify structure
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                XCTAssertEqual(rootNode.getChildrenSize(), 2)
                
                let children = rootNode.getChildren()
                XCTAssertTrue(children[0] is ParagraphNode)
                XCTAssertTrue(children[1] is ParagraphNode)
                
                XCTAssertEqual(children[0].getTextContent(), "First paragraph")
                XCTAssertEqual(children[1].getTextContent(), "Second paragraph")
            }
        } catch {
            XCTFail("Failed to create multiple paragraphs: \(error)")
        }
    }
    
    // MARK: - Header Tests
    
    func testHeaderCreation() {
        do {
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                // Create H1 header
                let h1 = createHeadingNode(headingTag: .h1)
                let h1Text = TextNode()
                try h1Text.setText("Main Title")
                try h1.append([h1Text])
                
                // Create H2 header
                let h2 = createHeadingNode(headingTag: .h2)
                let h2Text = TextNode()
                try h2Text.setText("Subtitle")
                try h2.append([h2Text])
                
                try rootNode.append([h1, h2])
            }
            
            // Verify headers
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                let children = rootNode.getChildren()
                XCTAssertEqual(children.count, 2)
                
                guard let h1 = children[0] as? HeadingNode,
                      let h2 = children[1] as? HeadingNode else {
                    XCTFail("Expected heading nodes")
                    return
                }
                
                XCTAssertEqual(h1.getTag(), .h1)
                XCTAssertEqual(h1.getTextContent(), "Main Title")
                
                XCTAssertEqual(h2.getTag(), .h2)
                XCTAssertEqual(h2.getTextContent(), "Subtitle")
            }
        } catch {
            XCTFail("Failed to create headers: \(error)")
        }
    }
    
    // MARK: - List Tests
    
    func testUnorderedListCreation() {
        do {
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                // Create unordered list
                let list = ListNode(listType: .bullet, start: 1)
                
                let item1 = ListItemNode()
                let item1Text = TextNode()
                try item1Text.setText("First item")
                try item1.append([item1Text])
                
                let item2 = ListItemNode()
                let item2Text = TextNode()
                try item2Text.setText("Second item")
                try item2.append([item2Text])
                
                try list.append([item1, item2])
                try rootNode.append([list])
            }
            
            // Verify list
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode(),
                      let list = rootNode.getFirstChild() as? ListNode else {
                    XCTFail("Expected list node")
                    return
                }
                
                XCTAssertEqual(list.getListType(), .bullet)
                XCTAssertEqual(list.getChildrenSize(), 2)
                
                let items = list.getChildren()
                XCTAssertEqual(items[0].getTextContent(), "First item")
                XCTAssertEqual(items[1].getTextContent(), "Second item")
            }
        } catch {
            XCTFail("Failed to create unordered list: \(error)")
        }
    }
    
    func testOrderedListCreation() {
        do {
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                // Create ordered list
                let list = ListNode(listType: .number, start: 1)
                
                let item1 = ListItemNode()
                let item1Text = TextNode()
                try item1Text.setText("Step one")
                try item1.append([item1Text])
                
                let item2 = ListItemNode()
                let item2Text = TextNode()
                try item2Text.setText("Step two")
                try item2.append([item2Text])
                
                try list.append([item1, item2])
                try rootNode.append([list])
            }
            
            // Verify list
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode(),
                      let list = rootNode.getFirstChild() as? ListNode else {
                    XCTFail("Expected list node")
                    return
                }
                
                XCTAssertEqual(list.getListType(), .number)
                XCTAssertEqual(list.getStart(), 1)
                XCTAssertEqual(list.getChildrenSize(), 2)
            }
        } catch {
            XCTFail("Failed to create ordered list: \(error)")
        }
    }
    
    // MARK: - Text Formatting Tests
    
    func testTextFormatting() {
        do {
            try editor.update {
                let textNode = TextNode()
                try textNode.setText("Bold text")
                try textNode.setBold(true)
                
                XCTAssertTrue(textNode.getFormat().bold)
                XCTAssertFalse(textNode.getFormat().italic)
                
                try textNode.setItalic(true)
                XCTAssertTrue(textNode.getFormat().bold)
                XCTAssertTrue(textNode.getFormat().italic)
                
                try textNode.setBold(false)
                XCTAssertFalse(textNode.getFormat().bold)
                XCTAssertTrue(textNode.getFormat().italic)
            }
        } catch {
            XCTFail("Failed to format text: \(error)")
        }
    }
    
    func testMixedFormattingInParagraph() {
        do {
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let paragraph = ParagraphNode()
                
                // Regular text
                let regularText = TextNode()
                try regularText.setText("This is ")
                
                // Bold text
                let boldText = TextNode()
                try boldText.setText("bold")
                try boldText.setBold(true)
                
                // More regular text
                let moreText = TextNode()
                try moreText.setText(" and this is ")
                
                // Italic text
                let italicText = TextNode()
                try italicText.setText("italic")
                try italicText.setItalic(true)
                
                // Final text
                let finalText = TextNode()
                try finalText.setText(" text.")
                
                try paragraph.append([regularText, boldText, moreText, italicText, finalText])
                try rootNode.append([paragraph])
            }
            
            // Verify formatting
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode(),
                      let paragraph = rootNode.getFirstChild() as? ParagraphNode else {
                    XCTFail("Expected paragraph")
                    return
                }
                
                let textNodes = paragraph.getChildren().compactMap { $0 as? TextNode }
                XCTAssertEqual(textNodes.count, 5)
                
                // Check specific formatting
                let boldNode = textNodes.first { $0.getTextContent() == "bold" }
                XCTAssertNotNil(boldNode)
                XCTAssertTrue(boldNode?.getFormat().bold ?? false)
                
                let italicNode = textNodes.first { $0.getTextContent() == "italic" }
                XCTAssertNotNil(italicNode)
                XCTAssertTrue(italicNode?.getFormat().italic ?? false)
            }
        } catch {
            XCTFail("Failed to create mixed formatting: \(error)")
        }
    }
    
    // MARK: - Complex Document Tests
    
    func testComplexDocumentStructure() {
        do {
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                // Title
                let title = createHeadingNode(headingTag: .h1)
                let titleText = TextNode()
                try titleText.setText("Document Title")
                try title.append([titleText])
                try rootNode.append([title])
                
                // Introduction paragraph
                let intro = ParagraphNode()
                let introText = TextNode()
                try introText.setText("This is an introduction paragraph.")
                try intro.append([introText])
                try rootNode.append([intro])
                
                // Section header
                let section = createHeadingNode(headingTag: .h2)
                let sectionText = TextNode()
                try sectionText.setText("Section")
                try section.append([sectionText])
                try rootNode.append([section])
                
                // List
                let list = ListNode(listType: .bullet, start: 1)
                let item = ListItemNode()
                let itemText = TextNode()
                try itemText.setText("List item")
                try item.append([itemText])
                try list.append([item])
                try rootNode.append([list])
            }
            
            // Verify complex structure
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                let children = rootNode.getChildren()
                XCTAssertEqual(children.count, 4)
                
                // Check each element type
                XCTAssertTrue(children[0] is HeadingNode)
                XCTAssertTrue(children[1] is ParagraphNode)
                XCTAssertTrue(children[2] is HeadingNode)
                XCTAssertTrue(children[3] is ListNode)
                
                // Check content
                XCTAssertEqual(children[0].getTextContent(), "Document Title")
                XCTAssertEqual(children[1].getTextContent(), "This is an introduction paragraph.")
                XCTAssertEqual(children[2].getTextContent(), "Section")
                XCTAssertEqual(children[3].getTextContent(), "List item")
            }
        } catch {
            XCTFail("Failed to create complex document: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testEditorStateConsistency() {
        do {
            // Perform multiple operations
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else { return }
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let paragraph = ParagraphNode()
                let text = TextNode()
                try text.setText("Test content")
                try paragraph.append([text])
                try rootNode.append([paragraph])
            }
            
            // Verify state is consistent
            try editor.getEditorState().read {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                XCTAssertEqual(rootNode.getChildrenSize(), 1)
                XCTAssertEqual(rootNode.getTextContent(), "Test content")
            }
        } catch {
            XCTFail("Editor state inconsistency: \(error)")
        }
    }
}