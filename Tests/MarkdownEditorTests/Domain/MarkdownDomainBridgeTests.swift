/*
 * MarkdownDomainBridgeTests
 * 
 * Tests for the critical bridge between domain layer and Lexical.
 * Validates state synchronization, command translation, and business rule enforcement.
 */

import XCTest
@testable import MarkdownEditor
@testable import Lexical

final class MarkdownDomainBridgeTests: XCTestCase {
    
    var bridge: MarkdownDomainBridge!
    var editor: Editor!
    var view: MarkdownEditorView!
    
    override func setUp() {
        super.setUp()
        
        // Create a real editor view and extract its components
        view = MarkdownEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        
        // Access the editor through reflection for testing
        let mirror = Mirror(reflecting: view)
        if let lexicalView = mirror.children.first(where: { $0.label == "lexicalView" })?.value as? LexicalView {
            editor = lexicalView.editor
        }
        
        // Create bridge and connect
        bridge = MarkdownDomainBridge()
        bridge.connect(to: editor)
    }
    
    override func tearDown() {
        bridge = nil
        editor = nil
        view = nil
        super.tearDown()
    }
    
    // MARK: - State Synchronization Tests
    
    func testStateExtractionFromEmptyEditor() {
        // Given: Empty editor
        
        // When: Sync state
        bridge.syncFromLexical()
        let state = bridge.getCurrentState()
        
        // Then: State should reflect empty document
        XCTAssertEqual(state.content, "")
        XCTAssertEqual(state.selection, TextRange(at: .start))
        XCTAssertEqual(state.currentBlockType, .paragraph)
        XCTAssertTrue(state.currentFormatting.isEmpty)
    }
    
    func testStateExtractionWithContent() {
        // Given: Editor with content
        view.loadMarkdown(MarkdownDocument(content: "# Hello World\n\nThis is a paragraph."))
        
        // When: Sync state
        bridge.syncFromLexical()
        let state = bridge.getCurrentState()
        
        // Then: State should reflect document content
        XCTAssertTrue(state.content.contains("Hello World"))
        XCTAssertTrue(state.content.contains("This is a paragraph"))
    }
    
    func testFormattingStateExtraction() {
        // Given: Editor with formatted text
        view.loadMarkdown(MarkdownDocument(content: "**Bold** and *italic* text"))
        
        // When: Select bold text and sync
        // Note: This would require proper selection setup in Lexical
        bridge.syncFromLexical()
        let state = bridge.getCurrentState()
        
        // Then: Content should be preserved
        XCTAssertTrue(state.content.contains("Bold"))
        XCTAssertTrue(state.content.contains("italic"))
    }
    
    // MARK: - Command Execution Tests
    
    func testFormattingCommandExecution() {
        // Given: Editor with plain text
        view.loadMarkdown(MarkdownDocument(content: "Hello World"))
        
        // When: Create and execute bold command
        let command = bridge.createFormattingCommand(.bold)
        let result = bridge.execute(command)
        
        // Then: Command should succeed
        switch result {
        case .success:
            XCTAssertTrue(true, "Command executed successfully")
        case .failure(let error):
            XCTFail("Command failed: \(error.localizedDescription)")
        }
    }
    
    func testBlockTypeCommandExecution() {
        // Given: Editor with paragraph
        view.loadMarkdown(MarkdownDocument(content: "This is a paragraph"))
        
        // When: Convert to heading
        let command = bridge.createBlockTypeCommand(.heading(level: .h1))
        let result = bridge.execute(command)
        
        // Then: Command should succeed
        switch result {
        case .success:
            bridge.syncFromLexical()
            let newState = bridge.getCurrentState()
            XCTAssertTrue(newState.content.hasPrefix("#"), "Content should start with heading marker")
        case .failure(let error):
            XCTFail("Command failed: \(error.localizedDescription)")
        }
    }
    
    func testSmartListToggle() {
        // Given: Editor with unordered list
        view.loadMarkdown(MarkdownDocument(content: "- List item"))
        bridge.syncFromLexical()
        
        // When: Apply same list type (should toggle back to paragraph)
        let command = bridge.createBlockTypeCommand(.unorderedList)
        let result = bridge.execute(command)
        
        // Then: Should convert to paragraph
        switch result {
        case .success:
            bridge.syncFromLexical()
            let newState = bridge.getCurrentState()
            XCTAssertFalse(newState.content.hasPrefix("-"), "List marker should be removed")
            XCTAssertEqual(newState.currentBlockType, .paragraph)
        case .failure(let error):
            XCTFail("Command failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Document Operations Tests
    
    func testDocumentParsing() {
        // Given: Markdown document
        let document = MarkdownDocument(content: """
            # Title
            
            This is a paragraph with **bold** text.
            
            - Item 1
            - Item 2
            """)
        
        // When: Parse document
        let result = bridge.parseDocument(document)
        
        // Then: Should parse successfully
        switch result {
        case .success(let parsed):
            XCTAssertGreaterThan(parsed.blocks.count, 0, "Should have parsed blocks")
        case .failure(let error):
            XCTFail("Parsing failed: \(error.localizedDescription)")
        }
    }
    
    func testDocumentExport() {
        // Given: Editor with content
        view.loadMarkdown(MarkdownDocument(content: "# Test Document\n\nWith content"))
        
        // When: Export document
        let result = bridge.exportDocument()
        
        // Then: Should export successfully
        switch result {
        case .success(let document):
            XCTAssertTrue(document.content.contains("Test Document"))
            XCTAssertTrue(document.content.contains("With content"))
        case .failure(let error):
            XCTFail("Export failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Command Validation Tests
    
    func testCommandValidation() {
        // Given: Empty editor
        bridge.syncFromLexical()
        
        // When: Create formatting command
        let command = bridge.createFormattingCommand(.bold)
        
        // Then: Command should be valid for current state
        XCTAssertTrue(command.canExecute(on: bridge.getCurrentState()))
    }
    
    // MARK: - Error Handling Tests
    
    func testExecutionWithoutEditor() {
        // Given: Bridge without connected editor
        let isolatedBridge = MarkdownDomainBridge()
        
        // When: Try to execute command
        let command = isolatedBridge.createFormattingCommand(.bold)
        let result = isolatedBridge.execute(command)
        
        // Then: Should fail gracefully
        switch result {
        case .success:
            XCTFail("Should not succeed without editor")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("Editor not connected"))
        }
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndFormattingFlow() {
        // Given: Editor with text
        view.loadMarkdown(MarkdownDocument(content: "Plain text"))
        
        // When: Apply bold through view
        view.applyFormatting(.bold)
        
        // Then: Export should contain bold markdown
        let exported = view.exportMarkdown()
        switch exported {
        case .success(let document):
            XCTAssertTrue(document.content.contains("**"), "Should contain bold markers")
        case .failure:
            XCTFail("Export should succeed")
        }
    }
    
    func testEndToEndListToggleFlow() {
        // Given: Editor with paragraph
        view.loadMarkdown(MarkdownDocument(content: "Not a list"))
        
        // When: Convert to list and back
        view.setBlockType(.unorderedList)
        view.setBlockType(.unorderedList) // Toggle back
        
        // Then: Should be paragraph again
        let blockType = view.getCurrentBlockType()
        XCTAssertEqual(blockType, .paragraph)
    }
    
    // MARK: - Performance Tests
    
    func testStateSyncPerformance() {
        // Given: Editor with substantial content
        let largeContent = (0..<100).map { "Line \($0) with some text" }.joined(separator: "\n")
        view.loadMarkdown(MarkdownDocument(content: largeContent))
        
        // When/Then: Measure sync performance
        measure {
            bridge.syncFromLexical()
        }
    }
    
    func testCommandExecutionPerformance() {
        // Given: Editor with content
        view.loadMarkdown(MarkdownDocument(content: "Test content"))
        
        // When/Then: Measure command execution
        measure {
            let command = bridge.createFormattingCommand(.bold)
            _ = bridge.execute(command)
        }
    }
}

// MARK: - Test Helpers

extension MarkdownDomainBridgeTests {
    
    /// Helper to create a selection in the editor
    private func selectText(from start: Int, to end: Int) {
        // This would need proper Lexical selection API usage
        // Simplified for demonstration
        do {
            try editor.update {
                if let selection = try? getSelection() as? RangeSelection {
                    // Set selection range
                    // This is simplified - real implementation would need proper node traversal
                }
            }
        } catch {
            XCTFail("Failed to set selection: \(error)")
        }
    }
    
    /// Helper to verify document structure
    private func assertDocumentStructure(_ document: ParsedMarkdownDocument, expectedBlocks: [MarkdownBlock]) {
        XCTAssertEqual(document.blocks.count, expectedBlocks.count, "Block count mismatch")
        
        for (index, (actual, expected)) in zip(document.blocks, expectedBlocks).enumerated() {
            // Compare block types
            switch (actual, expected) {
            case (.paragraph, .paragraph),
                 (.heading, .heading),
                 (.list, .list),
                 (.codeBlock, .codeBlock),
                 (.quote, .quote):
                XCTAssertTrue(true, "Block \(index) types match")
            default:
                XCTFail("Block \(index) type mismatch")
            }
        }
    }
}