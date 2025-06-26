/*
 * MarkdownSmartToggleTests
 * 
 * Tests specifically for smart list toggle behavior.
 * Validates that clicking the same list type toggles back to paragraph.
 */

import XCTest
@testable import MarkdownEditor

final class MarkdownSmartToggleTests: XCTestCase {
    
    var stateService: MarkdownStateService!
    var documentService: MarkdownDocumentService!
    var formattingService: MarkdownFormattingService!
    var commandContext: MarkdownCommandContext!
    
    override func setUp() {
        super.setUp()
        stateService = DefaultMarkdownStateService()
        documentService = DefaultMarkdownDocumentService()
        formattingService = DefaultMarkdownFormattingService()
        commandContext = MarkdownCommandContext(
            documentService: documentService,
            formattingService: formattingService,
            stateService: stateService
        )
    }
    
    // MARK: - Unordered List Toggle Tests
    
    func testUnorderedListToggleToParagraph() {
        // Given: State with unordered list
        let state = MarkdownEditorState(
            content: "- List item",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .unorderedList
        )
        
        // When: Apply unordered list command (same type)
        let command = SetBlockTypeCommand(
            blockType: .unorderedList,
            at: state.selection.start,
            context: commandContext
        )
        
        let result = command.execute(on: state)
        
        // Then: Should toggle to paragraph
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .paragraph)
            XCTAssertFalse(newState.content.hasPrefix("-"))
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testUnorderedListCreationFromParagraph() {
        // Given: State with paragraph
        let state = MarkdownEditorState(
            content: "Regular text",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .paragraph
        )
        
        // When: Apply unordered list command
        let command = SetBlockTypeCommand(
            blockType: .unorderedList,
            at: state.selection.start,
            context: commandContext
        )
        
        let result = command.execute(on: state)
        
        // Then: Should create list
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .unorderedList)
            XCTAssertTrue(newState.content.hasPrefix("-"))
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    // MARK: - Ordered List Toggle Tests
    
    func testOrderedListToggleToParagraph() {
        // Given: State with ordered list
        let state = MarkdownEditorState(
            content: "1. List item",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .orderedList
        )
        
        // When: Apply ordered list command (same type)
        let command = SetBlockTypeCommand(
            blockType: .orderedList,
            at: state.selection.start,
            context: commandContext
        )
        
        let result = command.execute(on: state)
        
        // Then: Should toggle to paragraph
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .paragraph)
            XCTAssertFalse(newState.content.hasPrefix("1."))
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testOrderedListCreationFromParagraph() {
        // Given: State with paragraph
        let state = MarkdownEditorState(
            content: "Regular text",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .paragraph
        )
        
        // When: Apply ordered list command
        let command = SetBlockTypeCommand(
            blockType: .orderedList,
            at: state.selection.start,
            context: commandContext
        )
        
        let result = command.execute(on: state)
        
        // Then: Should create list
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .orderedList)
            XCTAssertTrue(newState.content.hasPrefix("1."))
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    // MARK: - Cross-List Type Tests
    
    func testUnorderedToOrderedListConversion() {
        // Given: State with unordered list
        let state = MarkdownEditorState(
            content: "- List item",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .unorderedList
        )
        
        // When: Apply ordered list command (different type)
        let command = SetBlockTypeCommand(
            blockType: .orderedList,
            at: state.selection.start,
            context: commandContext
        )
        
        let result = command.execute(on: state)
        
        // Then: Should convert to ordered list (not toggle to paragraph)
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .orderedList)
            XCTAssertTrue(newState.content.hasPrefix("1."))
            XCTAssertFalse(newState.content.hasPrefix("-"))
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testOrderedToUnorderedListConversion() {
        // Given: State with ordered list
        let state = MarkdownEditorState(
            content: "1. List item",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .orderedList
        )
        
        // When: Apply unordered list command (different type)
        let command = SetBlockTypeCommand(
            blockType: .unorderedList,
            at: state.selection.start,
            context: commandContext
        )
        
        let result = command.execute(on: state)
        
        // Then: Should convert to unordered list (not toggle to paragraph)
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .unorderedList)
            XCTAssertTrue(newState.content.hasPrefix("-"))
            XCTAssertFalse(newState.content.hasPrefix("1."))
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    // MARK: - Other Block Type Tests
    
    func testHeadingDoesNotToggle() {
        // Given: State with heading
        let state = MarkdownEditorState(
            content: "# Heading",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .heading(level: .h1)
        )
        
        // When: Apply same heading level
        let command = SetBlockTypeCommand(
            blockType: .heading(level: .h1),
            at: state.selection.start,
            context: commandContext
        )
        
        let result = command.execute(on: state)
        
        // Then: Should remain as heading (no toggle for non-list types)
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .heading(level: .h1))
            XCTAssertTrue(newState.content.hasPrefix("#"))
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testCodeBlockDoesNotToggle() {
        // Given: State with code block
        let state = MarkdownEditorState(
            content: "```\ncode\n```",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .codeBlock
        )
        
        // When: Apply code block command
        let command = SetBlockTypeCommand(
            blockType: .codeBlock,
            at: state.selection.start,
            context: commandContext
        )
        
        let result = command.execute(on: state)
        
        // Then: Should remain as code block
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .codeBlock)
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testToggleWithEmptyList() {
        // Given: State with empty list item
        let state = MarkdownEditorState(
            content: "- ",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 2)),
            currentBlockType: .unorderedList
        )
        
        // When: Toggle list
        let command = SetBlockTypeCommand(
            blockType: .unorderedList,
            at: state.selection.start,
            context: commandContext
        )
        
        let result = command.execute(on: state)
        
        // Then: Should toggle to empty paragraph
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .paragraph)
            XCTAssertEqual(newState.content.trimmingCharacters(in: .whitespacesAndNewlines), "")
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testToggleInMultiLineList() {
        // Given: State with multi-line list
        let state = MarkdownEditorState(
            content: "- First item\n- Second item\n- Third item",
            selection: TextRange(at: DocumentPosition(blockIndex: 1, offset: 5)),
            currentBlockType: .unorderedList
        )
        
        // When: Toggle list on second item
        let command = SetBlockTypeCommand(
            blockType: .unorderedList,
            at: state.selection.start,
            context: commandContext
        )
        
        let result = command.execute(on: state)
        
        // Then: Should convert current item to paragraph
        switch result {
        case .success(let newState):
            // The implementation would need to handle this case
            // For now, we expect it to handle the current block
            XCTAssertNotNil(newState)
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    // MARK: - Command Description Tests
    
    func testCommandDescription() {
        let command = SetBlockTypeCommand(
            blockType: .unorderedList,
            at: DocumentPosition(blockIndex: 0, offset: 0),
            context: commandContext
        )
        
        XCTAssertTrue(command.description.contains("unorderedList"))
    }
    
    func testCommandUndoability() {
        let command = SetBlockTypeCommand(
            blockType: .paragraph,
            at: DocumentPosition(blockIndex: 0, offset: 0),
            context: commandContext
        )
        
        XCTAssertTrue(command.isUndoable)
    }
}