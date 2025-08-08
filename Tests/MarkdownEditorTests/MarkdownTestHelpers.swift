import XCTest
import Lexical
import LexicalListPlugin
import LexicalLinkPlugin
import LexicalMarkdown
@testable import MarkdownEditor

// MARK: - Test Base Class

/// Base class for MarkdownEditor tests that provides common setup and utilities
open class MarkdownTestCase: XCTestCase {
    
    var markdownEditor: MarkdownEditorView!
    var lexicalView: LexicalView { markdownEditor.textView.superview as! LexicalView }
    var editor: Editor { lexicalView.editor }
    
    override open func setUp() {
        super.setUp()
        setupMarkdownEditor()
    }
    
    override open func tearDown() {
        markdownEditor = nil
        super.tearDown()
    }
    
    private func setupMarkdownEditor() {
        let config = MarkdownEditorConfiguration.default
        markdownEditor = MarkdownEditorView(configuration: config)
        
        // Ensure the view is properly initialized
        _ = markdownEditor.frame
    }
}

// MARK: - State Transition Testing Framework

extension MarkdownTestCase {
    
    /// Creates a test scenario starting with the given initial state
    func given(_ initialState: MarkdownTestState) -> MarkdownTestScenario {
        return MarkdownTestScenario(testCase: self, initialState: initialState)
    }
    
    /// Creates an empty document state
    var emptyDocument: MarkdownTestState {
        return MarkdownTestState { editor in
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node available")
                    return
                }
                
                // Clear all children
                try rootNode.getChildren().forEach { child in
                    try child.remove()
                }
                
                // Add a single empty paragraph
                let paragraph = ParagraphNode()
                try rootNode.append([paragraph])
            }
        }
    }
    
    /// Creates a document with a single paragraph containing the given text
    func paragraphDocument(_ text: String) -> MarkdownTestState {
        return MarkdownTestState { editor in
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node available")
                    return
                }
                
                // Clear all children
                try rootNode.getChildren().forEach { child in
                    try child.remove()
                }
                
                // Create paragraph with text
                let paragraph = ParagraphNode()
                let textNode = TextNode()
                try textNode.setText(text)
                try paragraph.append([textNode])
                try rootNode.append([paragraph])
            }
        }
    }
    
    /// Creates a document with a header of the specified level
    func headerDocument(_ level: MarkdownBlockType.HeadingLevel, _ text: String) -> MarkdownTestState {
        return MarkdownTestState { editor in
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node available")
                    return
                }
                
                // Clear all children
                try rootNode.getChildren().forEach { child in
                    try child.remove()
                }
                
                // Create header
                let header = createHeadingNode(headingTag: level.lexicalType)
                let textNode = TextNode()
                try textNode.setText(text)
                try header.append([textNode])
                try rootNode.append([header])
            }
        }
    }
}

// MARK: - Test State and Scenario

/// Represents a specific editor state for testing
struct MarkdownTestState {
    let setupBlock: (Editor) throws -> Void
    
    init(_ setupBlock: @escaping (Editor) throws -> Void) {
        self.setupBlock = setupBlock
    }
}

/// Represents a test scenario that can be executed with when/then assertions
class MarkdownTestScenario {
    private let testCase: MarkdownTestCase
    private let initialState: MarkdownTestState
    
    init(testCase: MarkdownTestCase, initialState: MarkdownTestState) {
        self.testCase = testCase
        self.initialState = initialState
    }
    
    /// Execute an action on the editor
    func when(_ action: MarkdownTestAction) -> MarkdownTestAssertion {
        do {
            // Setup initial state
            try initialState.setupBlock(testCase.editor)
            
            // Execute the action
            try action.execute(testCase.editor)
            
            return MarkdownTestAssertion(testCase: testCase)
        } catch {
            XCTFail("Failed to execute test scenario: \(error)")
            return MarkdownTestAssertion(testCase: testCase)
        }
    }
}

/// Represents an action that can be performed on the editor
struct MarkdownTestAction {
    let actionBlock: (Editor) throws -> Void
    
    init(_ actionBlock: @escaping (Editor) throws -> Void) {
        self.actionBlock = actionBlock
    }
    
    func execute(_ editor: Editor) throws {
        try actionBlock(editor)
    }
}

/// Handles assertions about the final state
class MarkdownTestAssertion {
    private let testCase: MarkdownTestCase
    
    init(testCase: MarkdownTestCase) {
        self.testCase = testCase
    }
    
    /// Assert that the final state matches expectations
    func then(_ expectation: MarkdownTestExpectation) {
        do {
            try testCase.editor.getEditorState().read {
                try expectation.assert()
            }
        } catch {
            XCTFail("Assertion failed: \(error)")
        }
    }
}

/// Represents an expectation about the editor state
struct MarkdownTestExpectation {
    let assertionBlock: () throws -> Void
    
    init(_ assertionBlock: @escaping () throws -> Void) {
        self.assertionBlock = assertionBlock
    }
    
    func assert() throws {
        try assertionBlock()
    }
}

// MARK: - Common Actions

extension MarkdownTestCase {
    
    /// User types the given text
    func userTypes(_ text: String) -> MarkdownTestAction {
        return MarkdownTestAction { editor in
            // First insert the raw text at the current selection
            try editor.update {
                if let selection = try getSelection() as? RangeSelection {
                    try selection.insertText(text)
                } else if let rootNode = getActiveEditorState()?.getRootNode(), let lastChild = rootNode.getLastChild(), let elementNode = lastChild as? ElementNode {
                    let point = Point(key: elementNode.key, offset: elementNode.getChildrenSize(), type: SelectionType.element)
                    let newSelection = RangeSelection(anchor: point, focus: point, format: TextFormat())
                    try newSelection.insertText(text)
                } else {
                    XCTFail("Cannot create selection")
                }
            }
            
            // Then re-import the entire document as markdown to apply block/inline transformations
            let markdown = try LexicalMarkdown.generateMarkdown(from: editor, selection: nil)
            try MarkdownImporter.importMarkdown(markdown, into: editor)
        }
    }
    
    /// User presses backspace
    var userPressesBackspace: MarkdownTestAction {
        return MarkdownTestAction { editor in
            try editor.update {
                guard let selection = try getSelection() as? RangeSelection else {
                    XCTFail("No selection available")
                    return
                }
                
                editor.dispatchCommand(type: .deleteCharacter, payload: true)
            }
        }
    }
    
    /// User presses backspace at the beginning of the current element
    var userPressesBackspaceAtBeginning: MarkdownTestAction {
        return MarkdownTestAction { editor in
            try editor.update {
                guard let selection = try getSelection() as? RangeSelection else {
                    XCTFail("No selection available")
                    return
                }
                
                // Move to beginning of current element
                let anchor = selection.anchor
                if let node = try? anchor.getNode() {
                    let newPoint = Point(key: node.key, offset: 0, type: anchor.type)
                    let newSelection = RangeSelection(anchor: newPoint, focus: newPoint, format: TextFormat())
                    getActiveEditorState()?.selection = newSelection
                    
                    editor.dispatchCommand(type: .deleteCharacter, payload: true)
                }
            }
        }
    }
    
    /// User selects all text
    var userSelectsAll: MarkdownTestAction {
        return MarkdownTestAction { editor in
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node")
                    return
                }
                
                let startPoint = Point(key: rootNode.key, offset: 0, type: SelectionType.element)
                let endPoint = Point(key: rootNode.key, offset: rootNode.getChildrenSize(), type: SelectionType.element)
                let selection = RangeSelection(anchor: startPoint, focus: endPoint, format: TextFormat())
                getActiveEditorState()?.selection = selection
            }
        }
    }
}

// MARK: - Common Expectations

extension MarkdownTestCase {
    
    /// Expect a paragraph node with the given text
    func expectParagraphNode(text: String) -> MarkdownTestExpectation {
        return MarkdownTestExpectation {
            guard let rootNode = getActiveEditorState()?.getRootNode(),
                  let firstChild = rootNode.getFirstChild() as? ParagraphNode else {
                XCTFail("Expected paragraph node as first child")
                return
            }
            
            let actualText = firstChild.getTextContent()
            XCTAssertEqual(actualText, text, "Paragraph text doesn't match")
        }
    }
    
    /// Expect a header node with the given level and text
    func expectHeaderNode(_ level: MarkdownBlockType.HeadingLevel, text: String) -> MarkdownTestExpectation {
        return MarkdownTestExpectation {
            guard let rootNode = getActiveEditorState()?.getRootNode(),
                  let firstChild = rootNode.getFirstChild() as? HeadingNode else {
                XCTFail("Expected heading node as first child")
                return
            }
            
            XCTAssertEqual(firstChild.getTag(), level.lexicalType, "Header level doesn't match")
            
            let actualText = firstChild.getTextContent()
            XCTAssertEqual(actualText, text, "Header text doesn't match")
        }
    }
    
    /// Expect a list node with the given type
    func expectListNode(type: ListType) -> MarkdownTestExpectation {
        return MarkdownTestExpectation {
            guard let rootNode = getActiveEditorState()?.getRootNode(),
                  let firstChild = rootNode.getFirstChild() as? ListNode else {
                XCTFail("Expected list node as first child")
                return
            }
            
            XCTAssertEqual(firstChild.getListType(), type, "List type doesn't match")
        }
    }
    
    /// Expect the document to be empty (only root node with empty paragraph)
    var expectEmptyDocument: MarkdownTestExpectation {
        return MarkdownTestExpectation {
            guard let rootNode = getActiveEditorState()?.getRootNode() else {
                XCTFail("No root node")
                return
            }
            
            let children = rootNode.getChildren()
            XCTAssertEqual(children.count, 1, "Expected exactly one child (empty paragraph)")
            
            if let paragraph = children.first as? ParagraphNode {
                XCTAssertTrue(paragraph.isEmpty(), "Expected empty paragraph")
            } else {
                XCTFail("Expected first child to be a paragraph")
            }
        }
    }
    
    /// Expect the root node to have a specific number of children
    func expectChildCount(_ count: Int) -> MarkdownTestExpectation {
        return MarkdownTestExpectation {
            guard let rootNode = getActiveEditorState()?.getRootNode() else {
                XCTFail("No root node")
                return
            }
            
            XCTAssertEqual(rootNode.getChildrenSize(), count, "Child count doesn't match")
        }
    }
    
    /// Expect text content to match across the entire document
    func expectDocumentText(_ expectedText: String) -> MarkdownTestExpectation {
        return MarkdownTestExpectation {
            guard let rootNode = getActiveEditorState()?.getRootNode() else {
                XCTFail("No root node")
                return
            }
            
            let actualText = rootNode.getTextContent()
            XCTAssertEqual(actualText, expectedText, "Document text doesn't match")
        }
    }
    
    /// Expect formatted text with specific properties
    func expectFormattedText(text: String, bold: Bool = false, italic: Bool = false) -> MarkdownTestExpectation {
        return MarkdownTestExpectation {
            guard let rootNode = getActiveEditorState()?.getRootNode() else {
                XCTFail("No root node")
                return
            }
            
            // Find all text nodes
            var foundMatch = false
            
            func searchNode(_ node: Node) {
                if let textNode = node as? TextNode {
                    if textNode.getTextContent() == text {
                        let format = textNode.getFormat()
                        if format.bold == bold && format.italic == italic {
                            foundMatch = true
                        }
                    }
                }
                
                if let elementNode = node as? ElementNode {
                    for child in elementNode.getChildren() {
                        searchNode(child)
                    }
                }
            }
            
            searchNode(rootNode)
            XCTAssertTrue(foundMatch, "Expected formatted text '\(text)' with bold=\(bold), italic=\(italic)")
        }
    }
    
    /// Expect a specific node structure using a validation closure
    func expectNodeStructure(_ validator: @escaping (RootNode) -> Bool, description: String) -> MarkdownTestExpectation {
        return MarkdownTestExpectation {
            guard let rootNode = getActiveEditorState()?.getRootNode() else {
                XCTFail("No root node")
                return
            }
            
            let isValid = validator(rootNode)
            XCTAssertTrue(isValid, description)
        }
    }
    
    /// Expect a code block with specific content and language
    func expectCodeBlock(code: String, language: String) -> MarkdownTestExpectation {
        return MarkdownTestExpectation {
            guard let rootNode = getActiveEditorState()?.getRootNode() else {
                XCTFail("No root node")
                return
            }
            
            // For now, this is a placeholder - code blocks might require specific plugin setup
            let children = rootNode.getChildren()
            let hasCodeBlock = children.contains { child in
                if let codeNode = child as? CodeNode {
                    return codeNode.getTextContent().contains(code)
                }
                return false
            }
            
            XCTAssertTrue(hasCodeBlock, "Expected code block with content: \(code)")
        }
    }
    
    /// Expect a quote block with specific content
    func expectQuoteBlock(text: String) -> MarkdownTestExpectation {
        return MarkdownTestExpectation {
            guard let rootNode = getActiveEditorState()?.getRootNode() else {
                XCTFail("No root node")
                return
            }
            
            // For now, this is a placeholder - quote blocks might require specific plugin setup
            let children = rootNode.getChildren()
            let hasQuoteBlock = children.contains { child in
                if let quoteNode = child as? QuoteNode {
                    return quoteNode.getTextContent().contains(text)
                }
                return false
            }
            
            XCTAssertTrue(hasQuoteBlock, "Expected quote block with content: \(text)")
        }
    }
}