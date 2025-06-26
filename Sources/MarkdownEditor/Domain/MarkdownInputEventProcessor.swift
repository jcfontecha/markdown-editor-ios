/*
 * MarkdownInputEventProcessor
 * 
 * Service that translates input events into domain commands for unit testing.
 * Allows testing complex user input sequences without TextKit dependencies.
 */

import Foundation

// MARK: - Input Event Processor Protocol

/// Service for processing input events and converting them to domain commands
public protocol MarkdownInputEventProcessor {
    /// Process an input event and return the resulting state
    func processInputEvent(
        _ event: InputEvent,
        in state: MarkdownEditorState
    ) -> Result<MarkdownEditorState, DomainError>
    
    /// Process multiple input events in sequence
    func processInputEvents(
        _ events: [InputEvent],
        in state: MarkdownEditorState
    ) -> Result<MarkdownEditorState, DomainError>
}

// MARK: - Default Implementation

/// Default implementation of MarkdownInputEventProcessor
public class DefaultMarkdownInputEventProcessor: MarkdownInputEventProcessor {
    private let commandContext: MarkdownCommandContext
    private let commandHistory: MarkdownCommandHistory
    
    public init(
        commandContext: MarkdownCommandContext,
        commandHistory: MarkdownCommandHistory = MarkdownCommandHistory()
    ) {
        self.commandContext = commandContext
        self.commandHistory = commandHistory
    }
    
    public func processInputEvent(
        _ event: InputEvent,
        in state: MarkdownEditorState
    ) -> Result<MarkdownEditorState, DomainError> {
        
        let command = createCommand(for: event, in: state)
        return commandHistory.execute(command, on: state)
    }
    
    public func processInputEvents(
        _ events: [InputEvent],
        in state: MarkdownEditorState
    ) -> Result<MarkdownEditorState, DomainError> {
        
        var currentState = state
        
        for event in events {
            switch processInputEvent(event, in: currentState) {
            case .success(let newState):
                currentState = newState
            case .failure(let error):
                return .failure(error)
            }
        }
        
        return .success(currentState)
    }
    
    // MARK: - Command Creation
    
    private func createCommand(for event: InputEvent, in state: MarkdownEditorState) -> MarkdownCommand {
        switch event {
        case .keystroke(let character, let modifiers):
            return createKeystrokeCommand(character: character, modifiers: modifiers, state: state)
            
        case .backspace:
            return createBackspaceCommand(state: state)
            
        case .delete:
            return createDeleteCommand(state: state)
            
        case .enter:
            return createEnterCommand(state: state)
            
        case .tab:
            return createTabCommand(state: state)
            
        case .paste(let text):
            return createPasteCommand(text: text, state: state)
            
        case .cut:
            return createCutCommand(state: state)
            
        case .copy:
            return createCopyCommand(state: state)
        }
    }
    
    // MARK: - Specific Command Implementations
    
    private func createKeystrokeCommand(
        character: Character, 
        modifiers: KeyModifiers, 
        state: MarkdownEditorState
    ) -> MarkdownCommand {
        
        // Handle special formatting shortcuts
        if modifiers.contains(.command) {
            switch character {
            case "b", "B":
                return ApplyFormattingCommand(
                    formatting: [.bold],
                    to: state.selection,
                    operation: .toggle,
                    context: commandContext
                )
            case "i", "I":
                return ApplyFormattingCommand(
                    formatting: [.italic],
                    to: state.selection,
                    operation: .toggle,
                    context: commandContext
                )
            case "u", "U":
                return ApplyFormattingCommand(
                    formatting: [.strikethrough],
                    to: state.selection,
                    operation: .toggle,
                    context: commandContext
                )
            case "`":
                return ApplyFormattingCommand(
                    formatting: [.code],
                    to: state.selection,
                    operation: .toggle,
                    context: commandContext
                )
            default:
                break
            }
        }
        
        // Regular character insertion
        return InsertTextCommand(
            text: String(character),
            at: state.selection.start,
            context: commandContext
        )
    }
    
    private func createBackspaceCommand(state: MarkdownEditorState) -> MarkdownCommand {
        if state.selection.isCursor {
            // Delete character before cursor
            let position = state.selection.start
            if position.offset > 0 {
                let deleteRange = TextRange(
                    start: DocumentPosition(blockIndex: position.blockIndex, offset: position.offset - 1),
                    end: position
                )
                return DeleteTextCommand(range: deleteRange, context: commandContext)
            } else if position.blockIndex > 0 {
                // Backspace at beginning of line - merge with previous block
                return createBlockMergeCommand(state: state)
            }
        } else {
            // Delete selected text
            return DeleteTextCommand(range: state.selection, context: commandContext)
        }
        
        // No-op command
        return NoOpCommand()
    }
    
    private func createDeleteCommand(state: MarkdownEditorState) -> MarkdownCommand {
        if state.selection.isCursor {
            // Delete character after cursor
            let position = state.selection.start
            let currentBlock = commandContext.documentService.getBlock(at: position, in: state.content)
            let blockText = currentBlock?.textContent ?? ""
            
            if position.offset < blockText.count {
                let deleteRange = TextRange(
                    start: position,
                    end: DocumentPosition(blockIndex: position.blockIndex, offset: position.offset + 1)
                )
                return DeleteTextCommand(range: deleteRange, context: commandContext)
            }
        } else {
            // Delete selected text
            return DeleteTextCommand(range: state.selection, context: commandContext)
        }
        
        return NoOpCommand()
    }
    
    private func createEnterCommand(state: MarkdownEditorState) -> MarkdownCommand {
        let position = state.selection.start
        
        // Check if we're in a list - continue list
        let blockType = commandContext.formattingService.getBlockTypeAt(position: position, in: state)
        if case .unorderedList = blockType {
            return createListContinuationCommand(state: state, listType: .unorderedList)
        } else if case .orderedList = blockType {
            return createListContinuationCommand(state: state, listType: .orderedList)
        }
        
        // Regular paragraph break
        return InsertTextCommand(text: "\n", at: position, context: commandContext)
    }
    
    private func createTabCommand(state: MarkdownEditorState) -> MarkdownCommand {
        // Insert tab character or spaces
        return InsertTextCommand(text: "    ", at: state.selection.start, context: commandContext)
    }
    
    private func createPasteCommand(text: String, state: MarkdownEditorState) -> MarkdownCommand {
        if !state.selection.isCursor {
            // Replace selected text
            return CompositeCommand(
                commands: [
                    DeleteTextCommand(range: state.selection, context: commandContext),
                    InsertTextCommand(text: text, at: state.selection.start, context: commandContext)
                ],
                name: "Paste"
            )
        } else {
            // Insert at cursor
            return InsertTextCommand(text: text, at: state.selection.start, context: commandContext)
        }
    }
    
    private func createCutCommand(state: MarkdownEditorState) -> MarkdownCommand {
        if !state.selection.isCursor {
            // For now, just delete the selection (actual cut would copy to clipboard)
            return DeleteTextCommand(range: state.selection, context: commandContext)
        }
        return NoOpCommand()
    }
    
    private func createCopyCommand(state: MarkdownEditorState) -> MarkdownCommand {
        // Copy doesn't change state, so return no-op
        return NoOpCommand()
    }
    
    // MARK: - Helper Commands
    
    private func createBlockMergeCommand(state: MarkdownEditorState) -> MarkdownCommand {
        // Simplified block merge - just delete the newline between blocks
        let position = state.selection.start
        if position.blockIndex > 0 {
            let deleteRange = TextRange(
                start: DocumentPosition(blockIndex: position.blockIndex - 1, offset: Int.max), // End of previous block
                end: position
            )
            return DeleteTextCommand(range: deleteRange, context: commandContext)
        }
        return NoOpCommand()
    }
    
    private func createListContinuationCommand(state: MarkdownEditorState, listType: MarkdownBlockType) -> MarkdownCommand {
        let position = state.selection.start
        let currentBlock = commandContext.documentService.getBlock(at: position, in: state.content)
        let blockText = currentBlock?.textContent ?? ""
        
        // If current list item is empty, convert to paragraph
        if blockText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return SetBlockTypeCommand(blockType: .paragraph, at: position, context: commandContext)
        }
        
        // Create new list item
        let newItemText = listType == .unorderedList ? "\n- " : "\n1. "
        return InsertTextCommand(text: newItemText, at: position, context: commandContext)
    }
}

// MARK: - No-Op Command

/// Command that does nothing - used for events that don't change state
public struct NoOpCommand: MarkdownCommand {
    public init() {}
    
    public func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        return .success(state)
    }
    
    public func canExecute(on state: MarkdownEditorState) -> Bool {
        return true
    }
    
    public func createUndo(for state: MarkdownEditorState) -> MarkdownCommand? {
        return nil
    }
    
    public var description: String {
        return "No Operation"
    }
    
    public var isUndoable: Bool { return false }
}

// MARK: - Test Helpers

extension MarkdownInputEventProcessor {
    
    /// Simulate typing a string character by character
    public func simulateTyping(_ text: String, in state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        let events = text.map { InputEvent.keystroke(character: $0) }
        return processInputEvents(events, in: state)
    }
    
    /// Simulate a sequence of backspaces
    public func simulateBackspaces(_ count: Int, in state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        let events = Array(repeating: InputEvent.backspace, count: count)
        return processInputEvents(events, in: state)
    }
    
    /// Simulate typing with mixed input events
    public func simulateTextInput(_ text: String, withEvents events: [InputEvent], in state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        var allEvents: [InputEvent] = []
        
        // Add typing events
        allEvents.append(contentsOf: text.map { InputEvent.keystroke(character: $0) })
        
        // Add additional events
        allEvents.append(contentsOf: events)
        
        return processInputEvents(allEvents, in: state)
    }
}