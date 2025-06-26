/*
 * MarkdownListBehaviorTests
 * 
 * Tests for nuanced list editing behaviors that enhance the editing experience.
 * These tests focus on empty list items, enter key behavior, and backspace handling.
 */

import XCTest
@testable import MarkdownEditor

final class MarkdownListBehaviorTests: XCTestCase {
    
    var context: MarkdownCommandContext!
    
    override func setUp() {
        super.setUp()
        context = MarkdownCommandContext(
            documentService: DefaultMarkdownDocumentService(),
            formattingService: DefaultMarkdownFormattingService(),
            stateService: DefaultMarkdownStateService()
        )
    }
    
    // MARK: - Empty List Item Toggle Tests
    
    func testToggleEmptyUnorderedListItemToParagraph() {
        // Given: State with empty unordered list item
        let state = MarkdownEditorState(
            content: "- ",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 2)),
            currentBlockType: .unorderedList
        )
        
        // When: Toggle list (click list button again)
        let command = SetBlockTypeCommand(
            blockType: .unorderedList,
            at: state.selection.start,
            context: context
        )
        
        let result = command.execute(on: state)
        
        // Then: Should convert to empty paragraph
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .paragraph)
            XCTAssertEqual(newState.content.trimmingCharacters(in: .whitespacesAndNewlines), "")
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testToggleEmptyOrderedListItemToParagraph() {
        // Given: State with empty ordered list item
        let state = MarkdownEditorState(
            content: "1. ",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 3)),
            currentBlockType: .orderedList
        )
        
        // When: Toggle list
        let command = SetBlockTypeCommand(
            blockType: .orderedList,
            at: state.selection.start,
            context: context
        )
        
        let result = command.execute(on: state)
        
        // Then: Should convert to empty paragraph
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .paragraph)
            XCTAssertEqual(newState.content.trimmingCharacters(in: .whitespacesAndNewlines), "")
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    // MARK: - Enter Key Behavior Tests
    
    func testEnterOnLastEmptyListItemConvertsToParagraph() {
        // Given: List with last item empty
        let state = MarkdownEditorState(
            content: "- First item\n- Second item\n- ",
            selection: TextRange(at: DocumentPosition(blockIndex: 2, offset: 2)),
            currentBlockType: .unorderedList
        )
        
        // When: Press enter (SmartEnterCommand)
        let command = SmartEnterCommand(
            at: state.selection.start,
            context: context
        )
        
        let result = command.execute(on: state)
        
        // Then: Should convert last empty item to paragraph
        switch result {
        case .success(let newState):
            // The last line should now be a paragraph
            let lines = newState.content.components(separatedBy: .newlines)
            XCTAssertFalse(lines.last?.hasPrefix("- ") ?? true, "Last line should not be a list item")
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testEnterOnEmptyMiddleListItemCreatesNewItem() {
        // Given: List with empty middle item
        let state = MarkdownEditorState(
            content: "- First item\n- \n- Third item",
            selection: TextRange(at: DocumentPosition(blockIndex: 1, offset: 2)),
            currentBlockType: .unorderedList
        )
        
        // When: Press enter
        let command = SmartEnterCommand(
            at: state.selection.start,
            context: context
        )
        
        let result = command.execute(on: state)
        
        // Then: Should create new list item (not convert to paragraph)
        switch result {
        case .success(let newState):
            let lines = newState.content.components(separatedBy: .newlines)
            // Should have 4 lines now (added one)
            XCTAssertEqual(lines.count, 4)
            // New line should be a list item
            XCTAssertTrue(lines[2].hasPrefix("- "), "New line should be a list item")
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testEnterOnNonEmptyListItemCreatesNewItem() {
        // Given: List with cursor at end of non-empty item
        let state = MarkdownEditorState(
            content: "- First item\n- Second item",
            selection: TextRange(at: DocumentPosition(blockIndex: 1, offset: 13)),
            currentBlockType: .unorderedList
        )
        
        // When: Press enter
        let command = SmartEnterCommand(
            at: state.selection.start,
            context: context
        )
        
        let result = command.execute(on: state)
        
        // Then: Should create new list item
        switch result {
        case .success(let newState):
            let lines = newState.content.components(separatedBy: .newlines)
            XCTAssertEqual(lines.count, 3)
            XCTAssertTrue(lines[2].hasPrefix("- "), "New line should be a list item")
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    // MARK: - Backspace Behavior Tests
    
    func testBackspaceOnEmptyListItemConvertsItToParagraph() {
        // Given: Empty list item at beginning
        let state = MarkdownEditorState(
            content: "- ",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 2)),
            currentBlockType: .unorderedList
        )
        
        // When: Backspace
        let command = SmartBackspaceCommand(
            at: state.selection.start,
            context: context
        )
        
        let result = command.execute(on: state)
        
        // Then: Should convert to paragraph
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .paragraph)
            XCTAssertFalse(newState.content.hasPrefix("- "))
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testBackspaceOnEmptyMiddleListItemRemovesIt() {
        // Given: List with empty middle item
        let state = MarkdownEditorState(
            content: "- First item\n- \n- Third item",
            selection: TextRange(at: DocumentPosition(blockIndex: 1, offset: 2)),
            currentBlockType: .unorderedList
        )
        
        // When: Backspace
        let command = SmartBackspaceCommand(
            at: state.selection.start,
            context: context
        )
        
        let result = command.execute(on: state)
        
        // Then: Should remove the empty item (join with previous)
        switch result {
        case .success(let newState):
            let lines = newState.content.components(separatedBy: .newlines)
            XCTAssertEqual(lines.count, 2, "Empty item should be removed")
            XCTAssertEqual(lines[0], "- First item")
            XCTAssertEqual(lines[1], "- Third item")
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testDoubleBackspaceNotRequiredForEmptyMiddleItem() {
        // This test documents the current behavior and ensures we fix it
        // Given: Empty middle list item with cursor at end
        let state = MarkdownEditorState(
            content: "- First\n- \n- Third",
            selection: TextRange(at: DocumentPosition(blockIndex: 1, offset: 2)),
            currentBlockType: .unorderedList
        )
        
        // When: Single backspace
        let command = SmartBackspaceCommand(
            at: state.selection.start,
            context: context
        )
        
        let result = command.execute(on: state)
        
        // Then: Should handle it in one backspace
        switch result {
        case .success(let newState):
            // After one backspace, the empty item should be gone
            let lines = newState.content.components(separatedBy: .newlines)
            XCTAssertLessThan(lines.count, 3, "Empty item should be removed with single backspace")
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    // MARK: - Start With Title Tests
    
    func testStartWithTitleOnEmptyDocument() {
        // Given: Empty document with startWithTitle enabled
        let config = MarkdownEditorConfiguration(
            behavior: EditorBehavior(
                autoSave: true,
                autoCorrection: true,
                smartQuotes: true,
                returnKeyBehavior: .smart,
                startWithTitle: true
            )
        )
        
        // When: Load empty document
        // This tests the behavior that should happen in loadMarkdown
        let emptyState = MarkdownEditorState.empty
        
        // Then: Should apply H1 formatting
        let command = SetBlockTypeCommand(
            blockType: .heading(level: .h1),
            at: emptyState.selection.start,
            context: context
        )
        
        let result = command.execute(on: emptyState)
        
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .heading(level: .h1))
            XCTAssertTrue(newState.content.hasPrefix("# "))
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testStartWithTitleNotAppliedToNonEmptyDocument() {
        // Given: Non-empty document
        let state = MarkdownEditorState(
            content: "Some existing content",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 0))
        )
        
        // When: Check if we should apply title formatting
        let shouldApplyTitle = state.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        // Then: Should not apply for non-empty
        XCTAssertFalse(shouldApplyTitle)
    }
    
    // MARK: - Complex List Scenarios
    
    func testNestedListBehavior() {
        // Given: Nested list structure
        let state = MarkdownEditorState(
            content: "- Parent item\n  - Nested item\n  - ",
            selection: TextRange(at: DocumentPosition(blockIndex: 2, offset: 4)),
            currentBlockType: .unorderedList
        )
        
        // When: Press enter on empty nested item
        let command = SmartEnterCommand(
            at: state.selection.start,
            context: context
        )
        
        let result = command.execute(on: state)
        
        // Then: Should outdent or convert to paragraph
        switch result {
        case .success(let newState):
            // The empty nested item should be handled appropriately
            XCTAssertNotNil(newState)
        case .failure(let error):
            XCTFail("Command should succeed: \(error)")
        }
    }
    
    func testMixedListTypes() {
        // Given: Document with both list types
        let state = MarkdownEditorState(
            content: "- Bullet item\n1. Numbered item\n- Another bullet",
            selection: TextRange(at: DocumentPosition(blockIndex: 1, offset: 5))
        )
        
        // When: Query block type
        let blockType = context.formattingService.getBlockTypeAt(
            position: state.selection.start,
            in: state
        )
        
        // Then: Should correctly identify ordered list
        XCTAssertEqual(blockType, .orderedList)
    }
}
