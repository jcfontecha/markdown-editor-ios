/*
 * MarkdownCommands
 * 
 * Command pattern implementation for testable markdown operations.
 * Each command encapsulates a specific operation that can be executed, undone, and tested.
 */

import Foundation

// MARK: - Command Protocol

/// Base protocol for all markdown editor commands
public protocol MarkdownCommand {
    /// Execute this command on the given state
    func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError>
    
    /// Check if this command can be executed on the given state
    func canExecute(on state: MarkdownEditorState) -> Bool
    
    /// Create the inverse command that can undo this operation
    func createUndo(for state: MarkdownEditorState) -> MarkdownCommand?
    
    /// A description of this command for debugging/logging
    var description: String { get }
    
    /// Whether this command should be recorded in undo history
    var isUndoable: Bool { get }
}

// MARK: - Command Execution Context

/// Context for executing commands with services
public class MarkdownCommandContext {
    public let documentService: MarkdownDocumentService
    public let formattingService: MarkdownFormattingService
    public let stateService: MarkdownStateService
    
    public init(
        documentService: MarkdownDocumentService = DefaultMarkdownDocumentService(),
        formattingService: MarkdownFormattingService? = nil,
        stateService: MarkdownStateService? = nil
    ) {
        self.documentService = documentService
        self.formattingService = formattingService ?? DefaultMarkdownFormattingService(documentService: documentService)
        self.stateService = stateService ?? DefaultMarkdownStateService(
            documentService: documentService,
            formattingService: self.formattingService
        )
    }
}

// MARK: - Text Commands

/// Command to insert text at a specific position
public struct InsertTextCommand: MarkdownCommand {
    public let text: String
    public let position: DocumentPosition
    private let context: MarkdownCommandContext
    
    public init(text: String, at position: DocumentPosition, context: MarkdownCommandContext) {
        self.text = text
        self.position = position
        self.context = context
    }
    
    public func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        let insertResult = context.documentService.insertText(text, at: position, in: state.content)
        
        switch insertResult {
        case .success(let newContent):
            // Parse the new content to find the correct cursor position
            let document = context.documentService.parseMarkdown(newContent)
            
            if document.blocks.isEmpty {
                // Empty document - cursor at start
                return context.stateService.createState(from: newContent, cursorAt: DocumentPosition(blockIndex: 0, offset: 0))
            } else {
                // Put cursor at end of the target block
                let targetBlock = document.blocks[min(position.blockIndex, document.blocks.count - 1)]
                let endPosition = DocumentPosition(
                    blockIndex: min(position.blockIndex, document.blocks.count - 1),
                    offset: targetBlock.textContent.count
                )
                return context.stateService.createState(from: newContent, cursorAt: endPosition)
            }
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    public func canExecute(on state: MarkdownEditorState) -> Bool {
        let lines = state.content.components(separatedBy: .newlines)
        return position.blockIndex < lines.count &&
               position.offset <= lines[position.blockIndex].count
    }
    
    public func createUndo(for state: MarkdownEditorState) -> MarkdownCommand? {
        let endPosition = DocumentPosition(
            blockIndex: position.blockIndex,
            offset: position.offset + text.count
        )
        let range = TextRange(start: position, end: endPosition)
        return DeleteTextCommand(range: range, context: context)
    }
    
    public var description: String {
        return "Insert '\(text)' at \(position)"
    }
    
    public var isUndoable: Bool { return true }
}

/// Command to delete text in a range
public struct DeleteTextCommand: MarkdownCommand {
    public let range: TextRange
    private let context: MarkdownCommandContext
    
    public init(range: TextRange, context: MarkdownCommandContext) {
        self.range = range
        self.context = context
    }
    
    public func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        let deleteResult = context.documentService.deleteText(in: range, from: state.content)
        
        switch deleteResult {
        case .success(let newContent):
            return context.stateService.createState(from: newContent, cursorAt: range.start)
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    public func canExecute(on state: MarkdownEditorState) -> Bool {
        let lines = state.content.components(separatedBy: .newlines)
        return range.start.blockIndex < lines.count &&
               range.end.blockIndex < lines.count &&
               range.start.offset <= lines[range.start.blockIndex].count &&
               range.end.offset <= lines[range.end.blockIndex].count
    }
    
    public func createUndo(for state: MarkdownEditorState) -> MarkdownCommand? {
        // Extract the text that would be deleted
        if range.start.blockIndex == range.end.blockIndex {
            let lines = state.content.components(separatedBy: .newlines)
            let line = lines[range.start.blockIndex]
            let startIndex = line.index(line.startIndex, offsetBy: range.start.offset)
            let endIndex = line.index(line.startIndex, offsetBy: range.end.offset)
            let deletedText = String(line[startIndex..<endIndex])
            
            return InsertTextCommand(text: deletedText, at: range.start, context: context)
        }
        
        // Multi-line deletion is more complex - for now, return nil
        return nil
    }
    
    public var description: String {
        return "Delete text in range \(range)"
    }
    
    public var isUndoable: Bool { return true }
}

// MARK: - Formatting Commands

/// Command to apply inline formatting
public struct ApplyFormattingCommand: MarkdownCommand {
    public let formatting: InlineFormatting
    public let range: TextRange
    public let operation: FormattingOperation
    private let context: MarkdownCommandContext
    
    public init(
        formatting: InlineFormatting,
        to range: TextRange,
        operation: FormattingOperation = .toggle,
        context: MarkdownCommandContext
    ) {
        self.formatting = formatting
        self.range = range
        self.operation = operation
        self.context = context
    }
    
    public func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        return context.formattingService.applyInlineFormatting(
            formatting,
            to: range,
            in: state,
            operation: operation
        )
    }
    
    public func canExecute(on state: MarkdownEditorState) -> Bool {
        return context.formattingService.canApplyFormatting(formatting, to: range, in: state)
    }
    
    public func createUndo(for state: MarkdownEditorState) -> MarkdownCommand? {
        let undoOperation: FormattingOperation
        switch operation {
        case .apply:
            undoOperation = .remove
        case .remove:
            undoOperation = .apply
        case .toggle:
            undoOperation = .toggle // Toggle is its own inverse
        }
        
        return ApplyFormattingCommand(
            formatting: formatting,
            to: range,
            operation: undoOperation,
            context: context
        )
    }
    
    public var description: String {
        return "\(operation) \(formatting) to range \(range)"
    }
    
    public var isUndoable: Bool { return true }
}

/// Command to set block type with smart list toggle logic
public struct SetBlockTypeCommand: MarkdownCommand {
    public let blockType: MarkdownBlockType
    public let position: DocumentPosition
    private let context: MarkdownCommandContext
    
    public init(blockType: MarkdownBlockType, at position: DocumentPosition, context: MarkdownCommandContext) {
        self.blockType = blockType
        self.position = position
        self.context = context
    }
    
    public func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        // Get current block type to check for toggle behavior
        let currentBlockType = context.formattingService.getBlockTypeAt(position: position, in: state)
        
        // Apply smart list toggle logic
        let targetBlockType: MarkdownBlockType
        switch (currentBlockType, blockType) {
        case (.unorderedList, .unorderedList):
            // Toggle unordered list back to paragraph
            targetBlockType = .paragraph
        case (.orderedList, .orderedList):
            // Toggle ordered list back to paragraph
            targetBlockType = .paragraph
        default:
            // Normal conversion
            targetBlockType = blockType
        }
        
        return context.formattingService.setBlockType(targetBlockType, at: position, in: state)
    }
    
    public func canExecute(on state: MarkdownEditorState) -> Bool {
        return context.formattingService.canSetBlockType(blockType, at: position, in: state)
    }
    
    public func createUndo(for state: MarkdownEditorState) -> MarkdownCommand? {
        let currentBlockType = context.formattingService.getBlockTypeAt(position: position, in: state)
        return SetBlockTypeCommand(blockType: currentBlockType, at: position, context: context)
    }
    
    public var description: String {
        return "Set block type to \(blockType) at \(position)"
    }
    
    public var isUndoable: Bool { return true }
}

// MARK: - Selection Commands

/// Command to update selection
public struct UpdateSelectionCommand: MarkdownCommand {
    public let newSelection: TextRange
    private let context: MarkdownCommandContext
    
    public init(selection: TextRange, context: MarkdownCommandContext) {
        self.newSelection = selection
        self.context = context
    }
    
    public func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        return context.stateService.updateSelection(to: newSelection, in: state)
    }
    
    public func canExecute(on state: MarkdownEditorState) -> Bool {
        let lines = state.content.components(separatedBy: .newlines)
        return newSelection.start.blockIndex < lines.count &&
               newSelection.end.blockIndex < lines.count &&
               newSelection.start.offset <= lines[newSelection.start.blockIndex].count &&
               newSelection.end.offset <= lines[newSelection.end.blockIndex].count
    }
    
    public func createUndo(for state: MarkdownEditorState) -> MarkdownCommand? {
        return UpdateSelectionCommand(selection: state.selection, context: context)
    }
    
    public var description: String {
        return "Update selection to \(newSelection)"
    }
    
    public var isUndoable: Bool { return false } // Selection changes are not typically undoable
}

// MARK: - Composite Commands

/// Command that executes multiple commands as a single operation
public struct CompositeCommand: MarkdownCommand {
    public let commands: [MarkdownCommand]
    public let name: String
    
    public init(commands: [MarkdownCommand], name: String) {
        self.commands = commands
        self.name = name
    }
    
    public func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        var currentState = state
        
        for command in commands {
            switch command.execute(on: currentState) {
            case .success(let newState):
                currentState = newState
            case .failure(let error):
                return .failure(error)
            }
        }
        
        return .success(currentState)
    }
    
    public func canExecute(on state: MarkdownEditorState) -> Bool {
        var currentState = state
        
        for command in commands {
            if !command.canExecute(on: currentState) {
                return false
            }
            
            // Simulate execution to check if subsequent commands can execute
            switch command.execute(on: currentState) {
            case .success(let newState):
                currentState = newState
            case .failure:
                return false
            }
        }
        
        return true
    }
    
    public func createUndo(for state: MarkdownEditorState) -> MarkdownCommand? {
        var undoCommands: [MarkdownCommand] = []
        var currentState = state
        
        // Execute all commands to build undo sequence
        for command in commands {
            if let undoCommand = command.createUndo(for: currentState) {
                undoCommands.insert(undoCommand, at: 0) // Insert at beginning to reverse order
            }
            
            // Update state for next command
            switch command.execute(on: currentState) {
            case .success(let newState):
                currentState = newState
            case .failure:
                return nil
            }
        }
        
        return undoCommands.isEmpty ? nil : CompositeCommand(commands: undoCommands, name: "Undo \(name)")
    }
    
    public var description: String {
        return "Composite: \(name) (\(commands.count) commands)"
    }
    
    public var isUndoable: Bool {
        return commands.allSatisfy { $0.isUndoable }
    }
}

// MARK: - Command Builder

/// Utility for building common command sequences
public struct MarkdownCommandBuilder {
    private let context: MarkdownCommandContext
    
    public init(context: MarkdownCommandContext) {
        self.context = context
    }
    
    /// Create a command to replace text in a range
    public func replaceText(in range: TextRange, with newText: String) -> MarkdownCommand {
        return CompositeCommand(
            commands: [
                DeleteTextCommand(range: range, context: context),
                InsertTextCommand(text: newText, at: range.start, context: context)
            ],
            name: "Replace Text"
        )
    }
    
    /// Create a command to wrap text with formatting
    public func wrapWithFormatting(_ formatting: InlineFormatting, range: TextRange) -> MarkdownCommand {
        let syntax = formatting.markdownSyntax
        
        return CompositeCommand(
            commands: [
                InsertTextCommand(text: syntax.suffix, at: range.end, context: context),
                InsertTextCommand(text: syntax.prefix, at: range.start, context: context),
                UpdateSelectionCommand(
                    selection: TextRange(
                        start: DocumentPosition(
                            blockIndex: range.start.blockIndex,
                            offset: range.start.offset + syntax.prefix.count
                        ),
                        end: DocumentPosition(
                            blockIndex: range.end.blockIndex,
                            offset: range.end.offset + syntax.prefix.count
                        )
                    ),
                    context: context
                )
            ],
            name: "Wrap with \(formatting.description)"
        )
    }
    
    /// Create a command to convert a paragraph to a header
    public func convertToHeader(_ level: MarkdownBlockType.HeadingLevel, at position: DocumentPosition) -> MarkdownCommand {
        return SetBlockTypeCommand(blockType: .heading(level: level), at: position, context: context)
    }
    
    /// Create a command to convert a paragraph to a list item
    public func convertToListItem(type: MarkdownBlockType, at position: DocumentPosition) -> MarkdownCommand {
        return SetBlockTypeCommand(blockType: type, at: position, context: context)
    }
}

// MARK: - Command History

/// Manages command execution history for undo/redo functionality
public class MarkdownCommandHistory {
    private var undoStack: [MarkdownCommand] = []
    private var redoStack: [MarkdownCommand] = []
    private let maxHistorySize: Int
    
    public init(maxHistorySize: Int = 100) {
        self.maxHistorySize = maxHistorySize
    }
    
    /// Execute a command and add it to history if undoable
    public func execute(
        _ command: MarkdownCommand,
        on state: MarkdownEditorState
    ) -> Result<MarkdownEditorState, DomainError> {
        
        let result = command.execute(on: state)
        
        if case .success(let newState) = result, command.isUndoable {
            if let undoCommand = command.createUndo(for: state) {
                undoStack.append(undoCommand)
                
                // Limit history size
                if undoStack.count > maxHistorySize {
                    undoStack.removeFirst()
                }
                
                // Clear redo stack when new command is executed
                redoStack.removeAll()
            }
        }
        
        return result
    }
    
    /// Undo the last command
    public func undo(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError>? {
        guard let undoCommand = undoStack.popLast() else { return nil }
        
        let result = undoCommand.execute(on: state)
        
        if case .success(let newState) = result {
            if let redoCommand = undoCommand.createUndo(for: state) {
                redoStack.append(redoCommand)
            }
        }
        
        return result
    }
    
    /// Redo the last undone command
    public func redo(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError>? {
        guard let redoCommand = redoStack.popLast() else { return nil }
        
        let result = redoCommand.execute(on: state)
        
        if case .success(let newState) = result {
            if let undoCommand = redoCommand.createUndo(for: state) {
                undoStack.append(undoCommand)
            }
        }
        
        return result
    }
    
    /// Whether undo is available
    public var canUndo: Bool {
        return !undoStack.isEmpty
    }
    
    /// Whether redo is available
    public var canRedo: Bool {
        return !redoStack.isEmpty
    }
    
    /// Clear all history
    public func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}

// MARK: - Smart Commands

/// Command for smart enter key behavior in lists
public struct SmartEnterCommand: MarkdownCommand {
    public let position: DocumentPosition
    private let context: MarkdownCommandContext
    
    public init(at position: DocumentPosition, context: MarkdownCommandContext) {
        self.position = position
        self.context = context
    }
    
    public func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        let currentBlockType = context.formattingService.getBlockTypeAt(position: position, in: state)
        
        // Handle list-specific enter behavior
        switch currentBlockType {
        case .unorderedList, .orderedList:
            // Check if current line is empty list item
            let lines = state.content.components(separatedBy: .newlines)
            guard position.blockIndex < lines.count else {
                return .failure(.invalidPosition(position))
            }
            
            let currentLine = lines[position.blockIndex]
            
            let isEmptyListItem = currentLine.trimmingCharacters(in: .whitespaces) == "-" ||
                                  currentLine.range(of: #"^\s*\d+\.\s*$"#, options: .regularExpression) != nil
            
            if isEmptyListItem {
                // Check if it's the last item
                let isLastItem = position.blockIndex == lines.count - 1
                
                if isLastItem {
                    // Convert to paragraph
                    return context.formattingService.setBlockType(.paragraph, at: position, in: state)
                } else {
                    // Create new list item
                    let prefix = currentBlockType == .unorderedList ? "- " : "\(position.blockIndex + 2). "
                    return context.documentService.insertText("\n\(prefix)", at: position, in: state.content)
                        .flatMap { newContent in
                            context.stateService.createState(from: newContent, cursorAt: DocumentPosition(blockIndex: position.blockIndex + 1, offset: prefix.count))
                        }
                }
            } else {
                // Normal enter - create new list item
                let prefix = currentBlockType == .unorderedList ? "\n- " : "\n\(position.blockIndex + 2). "
                return context.documentService.insertText(prefix, at: position, in: state.content)
                    .flatMap { newContent in
                        context.stateService.createState(from: newContent, cursorAt: DocumentPosition(blockIndex: position.blockIndex + 1, offset: prefix.count - 1))
                    }
            }
            
        default:
            // Normal paragraph behavior
            return context.documentService.insertText("\n", at: position, in: state.content)
                .flatMap { newContent in
                    context.stateService.createState(from: newContent, cursorAt: DocumentPosition(blockIndex: position.blockIndex + 1, offset: 0))
                }
        }
    }
    
    public func canExecute(on state: MarkdownEditorState) -> Bool {
        return true
    }
    
    public func createUndo(for state: MarkdownEditorState) -> MarkdownCommand? {
        // Undo would be a delete command
        return nil
    }
    
    public var description: String {
        return "Smart enter at \(position)"
    }
    
    public var isUndoable: Bool { return true }
}

/// Command for smart backspace behavior in lists
public struct SmartBackspaceCommand: MarkdownCommand {
    public let position: DocumentPosition
    private let context: MarkdownCommandContext
    
    public init(at position: DocumentPosition, context: MarkdownCommandContext) {
        self.position = position
        self.context = context
    }
    
    public func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        let currentBlockType = context.formattingService.getBlockTypeAt(position: position, in: state)
        
        // Handle list-specific backspace behavior
        switch currentBlockType {
        case .unorderedList, .orderedList:
            let lines = state.content.components(separatedBy: .newlines)
            guard position.blockIndex < lines.count else {
                return .failure(.invalidPosition(position))
            }
            
            let currentLine = lines[position.blockIndex]
            print("[SmartBackspaceCommand] Current line: '\(currentLine)'")
            
            // Check for list prefix
            let isAtListMarker = position.offset <= 2 && (
                currentLine.hasPrefix("- ") ||
                currentLine.range(of: #"^\d+\. "#, options: .regularExpression) != nil
            )
            
            // Check if we're at the beginning of a list item
            if isAtListMarker { // At or near the list marker
                let isEmptyListItem = currentLine.trimmingCharacters(in: .whitespaces) == "-" ||
                                      currentLine.range(of: #"^\s*\d+\.\s*$"#, options: .regularExpression) != nil
                
                if isEmptyListItem {
                    if position.blockIndex == 0 {
                        // First item - convert to paragraph
                        return context.formattingService.setBlockType(.paragraph, at: position, in: state)
                    } else {
                        // Middle item - remove it
                        let range = TextRange(
                            start: DocumentPosition(blockIndex: position.blockIndex - 1, offset: lines[position.blockIndex - 1].count),
                            end: DocumentPosition(blockIndex: position.blockIndex, offset: currentLine.count)
                        )
                        return context.documentService.deleteText(in: range, from: state.content)
                            .flatMap { newContent in
                                context.stateService.createState(
                                    from: newContent,
                                    cursorAt: DocumentPosition(blockIndex: position.blockIndex - 1, offset: lines[position.blockIndex - 1].count)
                                )
                            }
                    }
                }
            }
            
            // Normal backspace
            if position.offset > 0 {
                let deleteRange = TextRange(
                    start: DocumentPosition(blockIndex: position.blockIndex, offset: position.offset - 1),
                    end: position
                )
                return context.documentService.deleteText(in: deleteRange, from: state.content)
                    .flatMap { newContent in
                        context.stateService.createState(from: newContent, cursorAt: DocumentPosition(blockIndex: position.blockIndex, offset: position.offset - 1))
                    }
            }
            
        default:
            break
        }
        
        // Normal backspace behavior
        if position.offset > 0 {
            let deleteRange = TextRange(
                start: DocumentPosition(blockIndex: position.blockIndex, offset: position.offset - 1),
                end: position
            )
            return context.documentService.deleteText(in: deleteRange, from: state.content)
                .flatMap { newContent in
                    context.stateService.createState(from: newContent, cursorAt: DocumentPosition(blockIndex: position.blockIndex, offset: position.offset - 1))
                }
        } else if position.blockIndex > 0 {
            // Join with previous line
            let lines = state.content.components(separatedBy: .newlines)
            let prevLineLength = lines[position.blockIndex - 1].count
            let deleteRange = TextRange(
                start: DocumentPosition(blockIndex: position.blockIndex - 1, offset: prevLineLength),
                end: position
            )
            return context.documentService.deleteText(in: deleteRange, from: state.content)
                .flatMap { newContent in
                    context.stateService.createState(from: newContent, cursorAt: DocumentPosition(blockIndex: position.blockIndex - 1, offset: prevLineLength))
                }
        }
        
        return .success(state) // Nothing to delete
    }
    
    public func canExecute(on state: MarkdownEditorState) -> Bool {
        return true
    }
    
    public func createUndo(for state: MarkdownEditorState) -> MarkdownCommand? {
        return nil
    }
    
    public var description: String {
        return "Smart backspace at \(position)"
    }
    
    public var isUndoable: Bool { return true }
}