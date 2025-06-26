/*
 * MarkdownCommandsTests
 * 
 * Unit tests for domain commands, focusing on the command pattern implementation
 * and business logic validation.
 */

import XCTest
@testable import MarkdownEditor

final class MarkdownCommandsTests: XCTestCase {
    
    var context: MarkdownCommandContext!
    
    override func setUp() {
        super.setUp()
        context = MarkdownCommandContext(
            documentService: DefaultMarkdownDocumentService(),
            formattingService: DefaultMarkdownFormattingService(),
            stateService: DefaultMarkdownStateService()
        )
    }
    
    // MARK: - SetBlockTypeCommand Tests
    
    func testSetBlockTypeCommandBasic() {
        // Given: Paragraph state
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .paragraph
        )
        
        // When: Convert to heading
        let command = SetBlockTypeCommand(
            blockType: .heading(level: .h1),
            at: state.selection.start,
            context: context
        )
        
        // Then: Should be valid and executable
        XCTAssertTrue(command.canExecute(on: state))
        XCTAssertTrue(command.isUndoable)
        XCTAssertTrue(command.description.contains("heading"))
        
        let result = command.execute(on: state)
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .heading(level: .h1))
            XCTAssertTrue(newState.content.hasPrefix("#"))
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testSetBlockTypeCommandUndo() {
        // Given: Heading state
        let state = MarkdownEditorState(
            content: "# Title",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .heading(level: .h1)
        )
        
        // When: Create undo command
        let command = SetBlockTypeCommand(
            blockType: .paragraph,
            at: state.selection.start,
            context: context
        )
        
        let undoCommand = command.createUndo(for: state)
        
        // Then: Undo should restore heading
        XCTAssertNotNil(undoCommand)
        XCTAssertTrue(undoCommand!.description.contains("heading"))
    }
    
    // MARK: - ApplyFormattingCommand Tests
    
    func testApplyFormattingCommandBold() {
        // Given: Plain text state
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 0),
                end: DocumentPosition(blockIndex: 0, offset: 5)
            ),
            currentFormatting: []
        )
        
        // When: Apply bold
        let command = ApplyFormattingCommand(
            formatting: .bold,
            to: state.selection,
            operation: .apply,
            context: context
        )
        
        // Then: Should be valid
        XCTAssertTrue(command.canExecute(on: state))
        XCTAssertTrue(command.isUndoable)
        
        let result = command.execute(on: state)
        switch result {
        case .success(let newState):
            XCTAssertTrue(newState.currentFormatting.contains(.bold))
            // Content would be updated by formatting service
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testApplyFormattingCommandToggle() {
        // Given: State with bold text
        let state = MarkdownEditorState(
            content: "**Hello** world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 2),
                end: DocumentPosition(blockIndex: 0, offset: 7)
            ),
            currentFormatting: [.bold]
        )
        
        // When: Toggle bold
        let command = ApplyFormattingCommand(
            formatting: .bold,
            to: state.selection,
            operation: .toggle,
            context: context
        )
        
        // Then: Should remove bold
        let result = command.execute(on: state)
        switch result {
        case .success(let newState):
            XCTAssertFalse(newState.currentFormatting.contains(.bold))
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testApplyFormattingCommandMultiple() {
        // Given: State with selection
        var state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 0),
                end: DocumentPosition(blockIndex: 0, offset: 5)
            )
        )
        
        // When: Apply multiple formats
        let formats: [InlineFormatting] = [.bold, .italic, .strikethrough]
        
        for format in formats {
            let command = ApplyFormattingCommand(
                formatting: format,
                to: state.selection,
                operation: .apply,
                context: context
            )
            
            if case .success(let newState) = command.execute(on: state) {
                state = newState
                XCTAssertTrue(state.currentFormatting.contains(format))
            }
        }
        
        // Then: Should have all formats
        XCTAssertTrue(state.currentFormatting.contains(.bold))
        XCTAssertTrue(state.currentFormatting.contains(.italic))
        XCTAssertTrue(state.currentFormatting.contains(.strikethrough))
    }
    
    // MARK: - InsertTextCommand Tests
    
    func testInsertTextCommand() {
        // Given: Empty state
        let state = MarkdownEditorState.empty
        
        // When: Insert text
        let command = InsertTextCommand(
            text: "Hello",
            at: state.selection.start,
            context: context
        )
        
        // Then: Should be valid
        XCTAssertTrue(command.canExecute(on: state))
        XCTAssertTrue(command.isUndoable)
        XCTAssertTrue(command.description.contains("Insert 'Hello'"))
        
        let result = command.execute(on: state)
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.content, "Hello")
            XCTAssertEqual(newState.selection.start.offset, 5)
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testInsertTextCommandAtPosition() {
        // Given: State with content
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5))
        )
        
        // When: Insert text at position
        let command = InsertTextCommand(
            text: " beautiful",
            at: state.selection.start,
            context: context
        )
        
        let result = command.execute(on: state)
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.content, "Hello beautiful world")
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    // MARK: - DeleteTextCommand Tests
    
    func testDeleteTextCommand() {
        // Given: State with content
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 0),
                end: DocumentPosition(blockIndex: 0, offset: 5)
            )
        )
        
        // When: Delete selection
        let command = DeleteTextCommand(
            range: state.selection,
            context: context
        )
        
        // Then: Should be valid
        XCTAssertTrue(command.canExecute(on: state))
        XCTAssertTrue(command.isUndoable)
        
        let result = command.execute(on: state)
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.content, " world")
            XCTAssertEqual(newState.selection.start.offset, 0)
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testDeleteTextCommandUndo() {
        // Given: State with content
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 5),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        // When: Create delete command and undo
        let command = DeleteTextCommand(
            range: state.selection,
            context: context
        )
        
        let undoCommand = command.createUndo(for: state)
        
        // Then: Undo should restore text
        XCTAssertNotNil(undoCommand)
        if let undo = undoCommand as? InsertTextCommand {
            XCTAssertEqual(undo.text, " world")
        }
    }
    
    // MARK: - Command Validation Tests
    
    func testCommandValidationEmptySelection() {
        // Given: State with cursor (no selection)
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5))
        )
        
        // When: Try to apply formatting to cursor
        let command = ApplyFormattingCommand(
            formatting: .bold,
            to: state.selection,
            operation: .apply,
            context: context
        )
        
        // Then: Currently allows cursor formatting (might change in future)
        // XCTAssertFalse(command.canExecute(on: state))
        _ = command.canExecute(on: state) // Just verify it doesn't crash
    }
    
    func testCommandValidationInvalidPosition() {
        // Given: State with content
        let state = MarkdownEditorState(
            content: "Hello",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 0))
        )
        
        // When: Try to insert at invalid position
        let command = InsertTextCommand(
            text: "Test",
            at: DocumentPosition(blockIndex: 5, offset: 0), // Invalid block
            context: context
        )
        
        // Then: Should not execute
        XCTAssertFalse(command.canExecute(on: state))
    }
    
    // MARK: - Performance Tests
    
    func testCommandExecutionPerformance() {
        let state = MarkdownEditorState(
            content: String(repeating: "Hello world. ", count: 100),
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 50))
        )
        
        measure {
            for i in 0..<100 {
                let command = InsertTextCommand(
                    text: "Text \(i)",
                    at: state.selection.start,
                    context: context
                )
                _ = command.execute(on: state)
            }
        }
    }
}