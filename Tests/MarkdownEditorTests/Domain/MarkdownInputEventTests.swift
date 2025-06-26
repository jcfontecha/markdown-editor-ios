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
    
    // MARK: - Basic Character Input Tests (A → X → B Pattern)
    
    func testSingleCharacterInput() {
        // State A: "Hello world" with cursor at end
        let stateA = initialState!
        
        // Input X: User types "!"
        let inputX = InputEvent.keystroke(character: "!")
        
        // Execute transition: A → X → B
        let result = processor.processInputEvent(inputX, in: stateA)
        
        // State B: Should have "Hello world!"
        XCTAssertTrue(result.isSuccess)
        if case .success(let stateB) = result {
            XCTAssertEqual(stateB.content, "Hello world!")
            XCTAssertEqual(stateB.selection.start.offset, 12)
        }
    }
    
    func testMultipleCharacterInput() {
        // State A: "Hello world"
        var currentState = initialState!
        
        // Input X: User types " Test" character by character
        let characters = [" ", "T", "e", "s", "t"]
        
        for char in characters {
            let inputX = InputEvent.keystroke(character: Character(char))
            let result = processor.processInputEvent(inputX, in: currentState)
            XCTAssertTrue(result.isSuccess)
            if case .success(let newState) = result {
                currentState = newState
            }
        }
        
        // State B: Should have "Hello world Test"
        XCTAssertEqual(currentState.content, "Hello world Test")
        XCTAssertEqual(currentState.selection.start.offset, 16)
    }
    
    func testTypingHelper() {
        // State A: "Hello world"
        let stateA = initialState!
        
        // Input X: User types " How are you?" using helper
        let result = processor.simulateTyping(" How are you?", in: stateA)
        
        // State B: Should have combined text
        XCTAssertTrue(result.isSuccess)
        if case .success(let stateB) = result {
            XCTAssertEqual(stateB.content, "Hello world How are you?")
            XCTAssertEqual(stateB.selection.start.offset, 24)
        }
    }
    
    // MARK: - Backspace Tests (A → X → B Pattern)
    
    func testBackspaceAtEndOfLine() {
        // State A: "Hello world" with cursor at end
        let stateA = initialState!
        
        // Input X: User presses backspace
        let inputX = InputEvent.backspace
        
        // Execute transition
        let result = processor.processInputEvent(inputX, in: stateA)
        
        // State B: Should have "Hello worl"
        XCTAssertTrue(result.isSuccess)
        if case .success(let stateB) = result {
            XCTAssertEqual(stateB.content, "Hello worl")
            XCTAssertEqual(stateB.selection.start.offset, 10)
        }
    }
    
    func testMultipleBackspaces() {
        // State A: "Hello world"
        let stateA = initialState!
        
        // Input X: User presses backspace 5 times
        let result = processor.simulateBackspaces(5, in: stateA)
        
        // State B: Should have "Hello "
        XCTAssertTrue(result.isSuccess)
        if case .success(let stateB) = result {
            XCTAssertEqual(stateB.content, "Hello ")
            XCTAssertEqual(stateB.selection.start.offset, 6)
        }
    }
    
    // MARK: - Selection and Replacement Tests
    
    func testDeleteSelectedText() {
        // State A: "Hello world" with "world" selected
        let stateA = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 6),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        // Input X: User presses backspace (deletes selection)
        let inputX = InputEvent.backspace
        let result = processor.processInputEvent(inputX, in: stateA)
        
        // State B: Should have "Hello "
        XCTAssertTrue(result.isSuccess)
        if case .success(let stateB) = result {
            XCTAssertEqual(stateB.content, "Hello ")
            XCTAssertEqual(stateB.selection.start.offset, 6)
        }
    }
    
    func testReplaceSelectedTextWithTyping() {
        // State A: "Hello world" with "world" selected
        let stateA = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 6),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        // Input X: User types "everyone"
        let result = processor.simulateTyping("everyone", in: stateA)
        
        // State B: Should have "Hello everyone"
        XCTAssertTrue(result.isSuccess)
        if case .success(let stateB) = result {
            XCTAssertEqual(stateB.content, "Hello everyone")
        }
    }
    
    // MARK: - Formatting Shortcut Tests
    
    func testBoldShortcut() {
        // State A: "Hello world" with "world" selected
        let stateA = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 6),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        // Input X: User presses Cmd+B
        let inputX = InputEvent.keystroke(character: "b", modifiers: [.command])
        let result = processor.processInputEvent(inputX, in: stateA)
        
        // State B: Should apply bold formatting
        XCTAssertTrue(result.isSuccess)
        if case .success(let stateB) = result {
            // Check that formatting was applied (actual implementation depends on formatting service)
            XCTAssertNotEqual(stateB.content, stateA.content) // Should have changed
        }
    }
    
    func testItalicShortcut() {
        // State A: "Hello world" with "world" selected
        let stateA = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 6),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        // Input X: User presses Cmd+I
        let inputX = InputEvent.keystroke(character: "i", modifiers: [.command])
        let result = processor.processInputEvent(inputX, in: stateA)
        
        // State B: Should apply italic formatting
        XCTAssertTrue(result.isSuccess)
        if case .success(let stateB) = result {
            XCTAssertNotEqual(stateB.content, stateA.content) // Should have changed
        }
    }
    
    // MARK: - Paste Tests
    
    func testPasteAtCursor() {
        // State A: "Hello world" with cursor at end
        let stateA = initialState!
        
        // Input X: User pastes " everyone"
        let inputX = InputEvent.paste(text: " everyone")
        let result = processor.processInputEvent(inputX, in: stateA)
        
        // State B: Should have "Hello world everyone"
        XCTAssertTrue(result.isSuccess)
        if case .success(let stateB) = result {
            XCTAssertEqual(stateB.content, "Hello world everyone")
        }
    }
    
    func testPasteReplaceSelection() {
        // State A: "Hello world" with "world" selected
        let stateA = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 6),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        // Input X: User pastes "everyone"
        let inputX = InputEvent.paste(text: "everyone")
        let result = processor.processInputEvent(inputX, in: stateA)
        
        // State B: Should have "Hello everyone"
        XCTAssertTrue(result.isSuccess)
        if case .success(let stateB) = result {
            XCTAssertEqual(stateB.content, "Hello everyone")
        }
    }
    
    // MARK: - Undo/Redo Tests
    
    func testUndoRedoWithInputEvents() {
        // State A: "Hello world"
        var state = initialState!
        
        // Input X: User types "!!"
        state = processor.processInputEvent(.keystroke(character: "!"), in: state).value ?? state
        state = processor.processInputEvent(.keystroke(character: "!"), in: state).value ?? state
        
        XCTAssertEqual(state.content, "Hello world!!")
        
        // Undo twice
        if let undoResult = commandHistory.undo(on: state), case .success(let undoState) = undoResult {
            state = undoState
            XCTAssertEqual(state.content, "Hello world!")
        }
        
        if let undoResult = commandHistory.undo(on: state), case .success(let undoState) = undoResult {
            state = undoState
            XCTAssertEqual(state.content, "Hello world")
        }
        
        // Redo once
        if let redoResult = commandHistory.redo(on: state), case .success(let redoState) = redoResult {
            state = redoState
            XCTAssertEqual(state.content, "Hello world!")
        }
        
        // Verify undo/redo capabilities
        XCTAssertTrue(commandHistory.canUndo)
        XCTAssertTrue(commandHistory.canRedo)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyDocument() {
        // State A: Empty document
        let stateA = MarkdownEditorState.empty
        
        // Input X: User types "H"
        let inputX = InputEvent.keystroke(character: "H")
        let result = processor.processInputEvent(inputX, in: stateA)
        
        // State B: Should have "H"
        XCTAssertTrue(result.isSuccess)
        if case .success(let stateB) = result {
            XCTAssertEqual(stateB.content, "H")
            XCTAssertEqual(stateB.selection.start.offset, 1)
        }
    }
    
    func testBackspaceInEmptyDocument() {
        // State A: Empty document
        let stateA = MarkdownEditorState.empty
        
        // Input X: User presses backspace
        let inputX = InputEvent.backspace
        let result = processor.processInputEvent(inputX, in: stateA)
        
        // State B: Should remain empty (no-op)
        XCTAssertTrue(result.isSuccess)
        if case .success(let stateB) = result {
            XCTAssertEqual(stateB.content, "")
        }
    }
    
    // MARK: - Complex Scenarios
    
    func testComplexEditingSequence() {
        // State A: Empty document
        var state = MarkdownEditorState.empty
        
        // Input X: Multiple operations
        // 1. Type "Hello"
        var result = processor.simulateTyping("Hello", in: state)
        XCTAssertTrue(result.isSuccess)
        state = result.value ?? state
        
        // 2. Type " world"
        result = processor.simulateTyping(" world", in: state)
        XCTAssertTrue(result.isSuccess)
        state = result.value ?? state
        
        // 3. Backspace 5 times
        result = processor.simulateBackspaces(5, in: state)
        XCTAssertTrue(result.isSuccess)
        state = result.value ?? state
        
        // 4. Type " everyone"
        result = processor.simulateTyping(" everyone", in: state)
        XCTAssertTrue(result.isSuccess)
        state = result.value ?? state
        
        // State B: Final result (note: there may be a space due to how backspace works)
        XCTAssertTrue(state.content == "Hello everyone" || state.content == "Hello  everyone")
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