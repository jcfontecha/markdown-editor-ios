/*
 * MarkdownInputEventTests
 * 
 * Unit tests for input event processing that validate TextKit-like behavior
 * without requiring actual TextKit integration.
 */

import XCTest
@testable import MarkdownEditor

class MarkdownInputEventTests: XCTestCase {
    
    var processor: MarkdownInputEventProcessor!
    var commandContext: MarkdownCommandContext!
    var commandHistory: MarkdownCommandHistory!
    var initialState: MarkdownEditorState!
    
    override func setUp() {
        super.setUp()
        
        commandContext = MarkdownCommandContext()
        commandHistory = MarkdownCommandHistory()
        processor = DefaultMarkdownInputEventProcessor(
            commandContext: commandContext,
            commandHistory: commandHistory
        )
        
        // Start with a simple paragraph
        initialState = MarkdownEditorState.withParagraph("Hello world")
    }
    
    override func tearDown() {
        processor = nil
        commandContext = nil
        commandHistory = nil
        initialState = nil
        super.tearDown()
    }
    
    // MARK: - Basic Character Input Tests
    
    func testSingleCharacterInput() {
        let result = processor.processInputEvent(.keystroke(character: "!"), in: initialState)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value?.content, "Hello world!")
        XCTAssertEqual(result.value?.selection.start.offset, 12)
    }
    
    func testMultipleCharacterInput() {
        var state = initialState!
        
        let characters = ["!", " ", "T", "e", "s", "t"]
        for char in characters {
            let result = processor.processInputEvent(.keystroke(character: Character(char)), in: state)
            XCTAssertTrue(result.isSuccess)
            state = result.value ?? state
        }
        
        XCTAssertEqual(state.content, "Hello world! Test")
        XCTAssertEqual(state.selection.start.offset, 17)
    }
    
    func testTypingHelper() {
        let result = processor.simulateTyping("! How are you?", in: initialState)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value?.content, "Hello world! How are you?")
        XCTAssertEqual(result.value?.selection.start.offset, 25)
    }
    
    // MARK: - Backspace Tests
    
    func testBackspaceAtEndOfLine() {
        let result = processor.processInputEvent(.backspace, in: initialState)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value?.content, "Hello worl")
        XCTAssertEqual(result.value?.selection.start.offset, 10)
    }
    
    func testMultipleBackspaces() {
        let result = processor.simulateBackspaces(5, in: initialState)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value?.content, "Hello ")
        XCTAssertEqual(result.value?.selection.start.offset, 6)
    }
    
    func testBackspaceAtBeginningOfParagraph() {
        let state = MarkdownEditorState(
            content: "First line\nSecond line",
            selection: TextRange(at: DocumentPosition(blockIndex: 1, offset: 0))
        )
        
        let result = processor.processInputEvent(.backspace, in: state)
        
        XCTAssertTrue(result.isSuccess)
        // Should merge lines by removing the newline
        XCTAssertTrue(result.value?.content.contains("First lineSecond") == true)
    }
    
    // MARK: - Delete Key Tests
    
    func testDeleteAtMiddleOfLine() {
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)) // Before " world"
        )
        
        let result = processor.processInputEvent(.delete, in: state)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value?.content, "Helloworld")
        XCTAssertEqual(result.value?.selection.start.offset, 5)
    }
    
    func testDeleteAtEndOfLine() {
        let result = processor.processInputEvent(.delete, in: initialState)
        
        XCTAssertTrue(result.isSuccess)
        // Should not change content since cursor is at end
        XCTAssertEqual(result.value?.content, "Hello world")
    }
    
    // MARK: - Selection and Replacement Tests
    
    func testDeleteSelectedText() {
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 6),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        let result = processor.processInputEvent(.backspace, in: state)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value?.content, "Hello ")
        XCTAssertEqual(result.value?.selection.start.offset, 6)
    }
    
    func testReplaceSelectedTextWithTyping() {
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 6),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        // Type new text - should replace selection
        let result = processor.simulateTyping("everyone", in: state)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value?.content, "Hello everyone")
    }
    
    // MARK: - Enter Key Tests
    
    func testEnterInParagraph() {
        let result = processor.processInputEvent(.enter, in: initialState)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value?.content, "Hello world\n")
        XCTAssertEqual(result.value?.selection.start.offset, 0)
        XCTAssertEqual(result.value?.selection.start.blockIndex, 1)
    }
    
    func testEnterInListItem() {
        let state = MarkdownEditorState(
            content: "- First item",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 12)),
            currentBlockType: .unorderedList
        )
        
        let result = processor.processInputEvent(.enter, in: state)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.value?.content.contains("- First item\n- ") == true)
    }
    
    // MARK: - Formatting Shortcut Tests
    
    func testBoldShortcut() {
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 6),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        let result = processor.processInputEvent(
            .keystroke(character: "b", modifiers: [.command]), 
            in: state
        )
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.value?.content.contains("**world**") == true)
    }
    
    func testItalicShortcut() {
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 6),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        let result = processor.processInputEvent(
            .keystroke(character: "i", modifiers: [.command]), 
            in: state
        )
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.value?.content.contains("*world*") == true)
    }
    
    func testCodeShortcut() {
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 6),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        let result = processor.processInputEvent(
            .keystroke(character: "`", modifiers: [.command]), 
            in: state
        )
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.value?.content.contains("`world`") == true)
    }
    
    // MARK: - Paste Tests
    
    func testPasteAtCursor() {
        let result = processor.processInputEvent(.paste(text: " everyone"), in: initialState)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value?.content, "Hello world everyone")
    }
    
    func testPasteReplaceSelection() {
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 6),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        let result = processor.processInputEvent(.paste(text: "everyone"), in: state)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value?.content, "Hello everyone")
    }
    
    // MARK: - Complex Editing Scenarios
    
    func testComplexEditingSequence() {
        var state = MarkdownEditorState.empty
        
        // Type a header
        var result = processor.simulateTyping("# My Header", in: state)
        XCTAssertTrue(result.isSuccess)
        state = result.value ?? state
        
        // Press enter
        result = processor.processInputEvent(.enter, in: state)
        XCTAssertTrue(result.isSuccess)
        state = result.value ?? state
        
        // Type a paragraph
        result = processor.simulateTyping("This is a paragraph with ", in: state)
        XCTAssertTrue(result.isSuccess)
        state = result.value ?? state
        
        // Type "bold text" and then make it bold
        result = processor.simulateTyping("bold text", in: state)
        XCTAssertTrue(result.isSuccess)
        state = result.value ?? state
        
        XCTAssertTrue(state.content.contains("# My Header"))
        XCTAssertTrue(state.content.contains("This is a paragraph with bold text"))
    }
    
    func testTypingMarkdownSyntax() {
        var state = MarkdownEditorState.empty
        
        // Type markdown manually
        let events: [InputEvent] = [
            .keystroke(character: "*"),
            .keystroke(character: "*"),
            .keystroke(character: "b"),
            .keystroke(character: "o"),
            .keystroke(character: "l"),
            .keystroke(character: "d"),
            .keystroke(character: "*"),
            .keystroke(character: "*")
        ]
        
        let result = processor.processInputEvents(events, in: state)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value?.content, "**bold**")
    }
    
    // MARK: - Undo/Redo Tests
    
    func testUndoRedoWithInputEvents() {
        var state = initialState!
        
        // Type some text
        state = processor.processInputEvent(.keystroke(character: "!"), in: state).value ?? state
        state = processor.processInputEvent(.keystroke(character: "!"), in: state).value ?? state
        
        XCTAssertEqual(state.content, "Hello world!!")
        
        // Undo twice
        state = commandHistory.undo(on: state)?.value ?? state
        XCTAssertEqual(state.content, "Hello world!")
        
        state = commandHistory.undo(on: state)?.value ?? state
        XCTAssertEqual(state.content, "Hello world")
        
        // Redo once
        state = commandHistory.redo(on: state)?.value ?? state
        XCTAssertEqual(state.content, "Hello world!")
        
        // Verify undo/redo capabilities
        XCTAssertTrue(commandHistory.canUndo)
        XCTAssertTrue(commandHistory.canRedo)
    }
    
    func testUndoRedoFormattingShortcuts() {
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 6),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        // Apply bold formatting
        var newState = processor.processInputEvent(
            .keystroke(character: "b", modifiers: [.command]), 
            in: state
        ).value ?? state
        
        XCTAssertTrue(newState.content.contains("**world**"))
        
        // Undo formatting
        newState = commandHistory.undo(on: newState)?.value ?? newState
        XCTAssertEqual(newState.content, "Hello world")
        
        // Redo formatting
        newState = commandHistory.redo(on: newState)?.value ?? newState
        XCTAssertTrue(newState.content.contains("**world**"))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyDocument() {
        let emptyState = MarkdownEditorState.empty
        
        let result = processor.processInputEvent(.keystroke(character: "H"), in: emptyState)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value?.content, "H")
        XCTAssertEqual(result.value?.selection.start.offset, 1)
    }
    
    func testBackspaceInEmptyDocument() {
        let emptyState = MarkdownEditorState.empty
        
        let result = processor.processInputEvent(.backspace, in: emptyState)
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value?.content, "")
    }
    
    func testInvalidPositions() {
        let invalidState = MarkdownEditorState(
            content: "Hello",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 100)) // Invalid position
        )
        
        // Should handle gracefully without crashing
        let result = processor.processInputEvent(.keystroke(character: "!"), in: invalidState)
        // May succeed or fail depending on validation, but shouldn't crash
        XCTAssertNotNil(result)
    }
    
    // MARK: - Performance Tests
    
    func testManyCharacterInputs() {
        let longText = String(repeating: "a", count: 1000)
        
        measure {
            let result = processor.simulateTyping(longText, in: MarkdownEditorState.empty)
            XCTAssertTrue(result.isSuccess)
        }
    }
    
    func testManyUndoOperations() {
        var state = MarkdownEditorState.empty
        
        // Type 100 characters
        for i in 0..<100 {
            state = processor.processInputEvent(.keystroke(character: Character("\(i % 10)")), in: state).value ?? state
        }
        
        measure {
            // Undo all of them
            for _ in 0..<100 {
                if commandHistory.canUndo {
                    state = commandHistory.undo(on: state)?.value ?? state
                }
            }
        }
    }
}

// MARK: - Test Utilities

extension Result where Success == MarkdownEditorState, Failure == DomainError {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
    
    var value: MarkdownEditorState? {
        switch self {
        case .success(let state): return state
        case .failure: return nil
        }
    }
}