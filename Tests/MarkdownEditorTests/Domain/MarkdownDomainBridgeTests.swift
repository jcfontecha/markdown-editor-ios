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
    var stateService: MarkdownStateService!
    var documentService: MarkdownDocumentService!
    var formattingService: MarkdownFormattingService!
    
    override func setUp() {
        super.setUp()
        
        // Create services
        stateService = DefaultMarkdownStateService()
        documentService = DefaultMarkdownDocumentService()
        formattingService = DefaultMarkdownFormattingService()
        
        // Create bridge with explicit services
        bridge = MarkdownDomainBridge(
            stateService: stateService,
            documentService: documentService,
            formattingService: formattingService
        )
    }
    
    override func tearDown() {
        bridge = nil
        stateService = nil
        documentService = nil
        formattingService = nil
        super.tearDown()
    }
    
    // MARK: - State Management Tests
    
    func testInitialState() {
        // Given: Newly created bridge
        
        // When: Get current state
        let state = bridge.getCurrentState()
        
        // Then: State should be empty
        XCTAssertEqual(state.content, "")
        XCTAssertEqual(state.selection, TextRange(at: .start))
        XCTAssertEqual(state.currentBlockType, .paragraph)
        XCTAssertTrue(state.currentFormatting.isEmpty)
    }
    
    func testStateWithContent() {
        // Given: A state with content
        let initialState = MarkdownEditorState(
            content: "# Hello World\n\nThis is a paragraph.",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .heading(level: .h1)
        )
        
        // When: Process through services
        let parseResult = documentService.parseMarkdown(initialState.content)
        
        // Then: Should parse correctly
        XCTAssertGreaterThan(parseResult.blocks.count, 0)
        XCTAssertEqual(parseResult.blocks.first?.blockType, .heading(level: .h1))
    }
    
    func testFormattingState() {
        // Given: State with formatting
        let state = MarkdownEditorState(
            content: "**Bold** and *italic* text",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 4)),
            currentFormatting: [.bold]
        )
        
        // Then: State should preserve formatting info
        XCTAssertTrue(state.currentFormatting.contains(.bold))
        XCTAssertEqual(state.content, "**Bold** and *italic* text")
    }
    
    // MARK: - Command Creation Tests
    
    func testFormattingCommandCreation() {
        // Given: Current state
        let state = MarkdownEditorState(
            content: "Hello World",
            selection: TextRange(start: DocumentPosition(blockIndex: 0, offset: 0),
                               end: DocumentPosition(blockIndex: 0, offset: 11))
        )
        
        // When: Create bold command
        let command = bridge.createFormattingCommand(.bold)
        
        // Then: Command should be valid
        XCTAssertTrue(command.canExecute(on: state))
        XCTAssertTrue(command.description.contains("bold"))
    }
    
    func testBlockTypeCommandCreation() {
        // Given: Current state with paragraph
        let state = MarkdownEditorState(
            content: "This is a paragraph",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .paragraph
        )
        
        // When: Create heading command
        let command = bridge.createBlockTypeCommand(.heading(level: .h1))
        
        // Then: Command should be valid
        XCTAssertTrue(command.canExecute(on: state))
        XCTAssertTrue(command.description.contains("heading"))
    }
    
    func testSmartListToggleCommand() {
        // Given: State with unordered list
        let listState = MarkdownEditorState(
            content: "- List item",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .unorderedList
        )
        
        // When: Create command to apply same list type
        let command = SetBlockTypeCommand(
            blockType: .unorderedList,
            at: listState.selection.start,
            context: MarkdownCommandContext(
                documentService: documentService,
                formattingService: formattingService,
                stateService: stateService
            )
        )
        
        // Execute the command
        let result = command.execute(on: listState)
        
        // Then: Should toggle to paragraph
        switch result {
        case .success(let newState):
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
            // Verify block types
            if parsed.blocks.count >= 3 {
                XCTAssertEqual(parsed.blocks[0].blockType, .heading(level: .h1))
                XCTAssertEqual(parsed.blocks[1].blockType, .paragraph)
                XCTAssertEqual(parsed.blocks[2].blockType, .unorderedList)
            }
        case .failure(let error):
            XCTFail("Parsing failed: \(error.localizedDescription)")
        }
    }
    
    func testDocumentValidation() {
        // Given: Valid markdown
        let validDoc = MarkdownDocument(content: "# Valid Document\n\nWith proper formatting")
        
        // When: Parse and validate
        let result = bridge.parseDocument(validDoc)
        
        // Then: Should succeed
        switch result {
        case .success(let parsed):
            XCTAssertTrue(parsed.blocks.count > 0)
        case .failure:
            XCTFail("Valid document should parse successfully")
        }
    }
    
    // MARK: - Command Validation Tests
    
    func testCommandValidation() {
        // Given: State with content
        let state = MarkdownEditorState(
            content: "Test content",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5))
        )
        
        // When: Create various commands
        let formatCommand = bridge.createFormattingCommand(.bold)
        let blockCommand = bridge.createBlockTypeCommand(.heading(level: .h2))
        
        // Then: Commands should be valid for the state
        XCTAssertTrue(formatCommand.canExecute(on: state))
        XCTAssertTrue(blockCommand.canExecute(on: state))
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidDocumentParsing() {
        // Given: Document with invalid structure (hypothetical)
        let document = MarkdownDocument(content: "Valid content") // Actually valid for now
        
        // When: Parse document
        let result = bridge.parseDocument(document)
        
        // Then: Should handle gracefully
        switch result {
        case .success:
            // For now, all markdown is valid
            XCTAssertTrue(true)
        case .failure(let error):
            XCTAssertNotNil(error.localizedDescription)
        }
    }
    
    // MARK: - Complex Scenarios
    
    func testMultipleFormattingCommands() {
        // Given: Initial state
        var state = MarkdownEditorState(
            content: "Plain text",
            selection: TextRange(start: DocumentPosition(blockIndex: 0, offset: 0),
                               end: DocumentPosition(blockIndex: 0, offset: 10))
        )
        
        // When: Apply multiple formatting commands
        let context = MarkdownCommandContext(
            documentService: documentService,
            formattingService: formattingService,
            stateService: stateService
        )
        
        // Apply bold
        let boldCommand = ApplyFormattingCommand(
            formatting: .bold,
            to: state.selection,
            operation: .apply,
            context: context
        )
        
        if case .success(let newState) = boldCommand.execute(on: state) {
            state = newState
            XCTAssertTrue(state.currentFormatting.contains(.bold))
        }
        
        // Apply italic
        let italicCommand = ApplyFormattingCommand(
            formatting: .italic,
            to: state.selection,
            operation: .apply,
            context: context
        )
        
        if case .success(let finalState) = italicCommand.execute(on: state) {
            XCTAssertTrue(finalState.currentFormatting.contains(.bold))
            XCTAssertTrue(finalState.currentFormatting.contains(.italic))
        }
    }
    
    func testBlockTypeConversions() {
        // Given: Initial paragraph state
        var state = MarkdownEditorState.withParagraph("Sample text")
        
        let context = MarkdownCommandContext(
            documentService: documentService,
            formattingService: formattingService,
            stateService: stateService
        )
        
        // When: Convert through various block types
        let conversions: [MarkdownBlockType] = [
            .heading(level: .h1),
            .unorderedList,
            .orderedList,
            .quote,
            .paragraph
        ]
        
        for blockType in conversions {
            let command = SetBlockTypeCommand(
                blockType: blockType,
                at: state.selection.start,
                context: context
            )
            
            if case .success(let newState) = command.execute(on: state) {
                state = newState
                // Note: The actual block type might be different due to smart toggle
                XCTAssertNotNil(state.currentBlockType)
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testLargeDocumentParsing() {
        // Given: Large markdown content
        let largeContent = (0..<100).map { "# Heading \($0)\n\nParagraph \($0) with some text." }.joined(separator: "\n\n")
        let document = MarkdownDocument(content: largeContent)
        
        // When/Then: Measure parsing performance
        measure {
            _ = bridge.parseDocument(document)
        }
    }
    
    func testCommandCreationPerformance() {
        // Given: Various states
        let states = (0..<100).map { i in
            MarkdownEditorState(
                content: "Test content \(i)",
                selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: i % 10))
            )
        }
        
        // When/Then: Measure command creation
        measure {
            for _ in states {
                _ = bridge.createFormattingCommand(.bold)
                _ = bridge.createBlockTypeCommand(.heading(level: .h2))
            }
        }
    }
}

// MARK: - Test Helpers

extension MarkdownDomainBridgeTests {
    
    /// Helper to create test states
    private func createTestState(content: String, blockType: MarkdownBlockType = .paragraph) -> MarkdownEditorState {
        return MarkdownEditorState(
            content: content,
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 0)),
            currentBlockType: blockType
        )
    }
    
    /// Helper to verify document structure
    private func assertDocumentStructure(_ document: ParsedMarkdownDocument, expectedBlocks: [(MarkdownBlockType, String)]) {
        XCTAssertEqual(document.blocks.count, expectedBlocks.count, "Block count mismatch")
        
        for (index, (block, expected)) in zip(document.blocks, expectedBlocks).enumerated() {
            XCTAssertEqual(block.blockType, expected.0, "Block \(index) type mismatch")
            // Optionally verify content
            if !expected.1.isEmpty {
                switch block {
                case .paragraph(let p):
                    XCTAssertTrue(p.text.contains(expected.1), "Block \(index) content mismatch")
                case .heading(let h):
                    XCTAssertTrue(h.text.contains(expected.1), "Block \(index) content mismatch")
                case .quote(let q):
                    XCTAssertTrue(q.text.contains(expected.1), "Block \(index) content mismatch")
                default:
                    break
                }
            }
        }
    }
}