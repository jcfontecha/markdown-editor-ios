/*
 * MarkdownStateService
 * 
 * Domain service for editor state management operations.
 * Handles state queries and transformations without UI dependencies.
 */

import Foundation

// MARK: - State Service Protocol

/// Service for managing markdown editor state operations
public protocol MarkdownStateService {
    /// Apply a state change and return the new state
    func applyChange(
        _ change: StateChange,
        to state: MarkdownEditorState
    ) -> Result<MarkdownEditorState, DomainError>
    
    /// Apply multiple state changes atomically
    func applyChanges(
        _ changes: [StateChange],
        to state: MarkdownEditorState
    ) -> Result<MarkdownEditorState, DomainError>
    
    /// Validate that a state is consistent and valid
    func validateState(_ state: MarkdownEditorState) -> ValidationResult
    
    /// Create a new state from markdown content
    func createState(
        from content: String,
        cursorAt position: DocumentPosition
    ) -> Result<MarkdownEditorState, DomainError>
    
    /// Update the selection in a state
    func updateSelection(
        to range: TextRange,
        in state: MarkdownEditorState
    ) -> Result<MarkdownEditorState, DomainError>
    
    /// Get state information at a specific position
    func getStateInfo(
        at position: DocumentPosition,
        in state: MarkdownEditorState
    ) -> StateInfo
    
    /// Check if two states are equivalent (ignoring metadata like timestamps)
    func areStatesEquivalent(_ state1: MarkdownEditorState, _ state2: MarkdownEditorState) -> Bool
    
    /// Create a diff between two states
    func createDiff(from oldState: MarkdownEditorState, to newState: MarkdownEditorState) -> StateDiff
}

// MARK: - State Information

/// Information about the editor state at a specific position
public struct StateInfo: Equatable {
    /// The block at this position
    public let currentBlock: MarkdownBlock?
    /// The formatting at this position
    public let formatting: InlineFormatting
    /// The block type at this position
    public let blockType: MarkdownBlockType
    /// Whether the position is at the start of a block
    public let isAtBlockStart: Bool
    /// Whether the position is at the end of a block
    public let isAtBlockEnd: Bool
    /// The word at this position (if any)
    public let currentWord: String?
    /// The line number (1-based)
    public let lineNumber: Int
    /// The column number (1-based)
    public let columnNumber: Int
    
    public init(
        currentBlock: MarkdownBlock?,
        formatting: InlineFormatting,
        blockType: MarkdownBlockType,
        isAtBlockStart: Bool,
        isAtBlockEnd: Bool,
        currentWord: String?,
        lineNumber: Int,
        columnNumber: Int
    ) {
        self.currentBlock = currentBlock
        self.formatting = formatting
        self.blockType = blockType
        self.isAtBlockStart = isAtBlockStart
        self.isAtBlockEnd = isAtBlockEnd
        self.currentWord = currentWord
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
    }
}

// MARK: - State Diff

/// Represents the difference between two editor states
public struct StateDiff {
    /// Changes in content
    public let contentChanges: [ContentChange]
    /// Change in selection
    public let selectionChange: SelectionChange?
    /// Change in formatting
    public let formattingChange: FormattingChange?
    /// Change in block type
    public let blockTypeChange: BlockTypeDiffChange?
    /// Whether this represents a significant change (for auto-save, etc.)
    public let isSignificant: Bool
    
    public init(
        contentChanges: [ContentChange] = [],
        selectionChange: SelectionChange? = nil,
        formattingChange: FormattingChange? = nil,
        blockTypeChange: BlockTypeDiffChange? = nil,
        isSignificant: Bool = false
    ) {
        self.contentChanges = contentChanges
        self.selectionChange = selectionChange
        self.formattingChange = formattingChange
        self.blockTypeChange = blockTypeChange
        self.isSignificant = isSignificant
    }
    
    /// An empty diff representing no changes
    public static let empty = StateDiff()
}

/// Represents a content change
public struct ContentChange: Equatable {
    public enum ChangeType {
        case insertion
        case deletion
        case replacement
    }
    
    public let type: ChangeType
    public let range: TextRange
    public let oldText: String
    public let newText: String
    
    public init(type: ChangeType, range: TextRange, oldText: String, newText: String) {
        self.type = type
        self.range = range
        self.oldText = oldText
        self.newText = newText
    }
}

/// Represents a selection change
public struct SelectionChange: Equatable {
    public let oldSelection: TextRange
    public let newSelection: TextRange
    
    public init(from oldSelection: TextRange, to newSelection: TextRange) {
        self.oldSelection = oldSelection
        self.newSelection = newSelection
    }
}

/// Represents a block type change in a diff
public struct BlockTypeDiffChange: Equatable {
    public let position: DocumentPosition
    public let oldBlockType: MarkdownBlockType
    public let newBlockType: MarkdownBlockType
    
    public init(at position: DocumentPosition, from oldType: MarkdownBlockType, to newType: MarkdownBlockType) {
        self.position = position
        self.oldBlockType = oldType
        self.newBlockType = newType
    }
}

// MARK: - Default Implementation

/// Default implementation of MarkdownStateService
public class DefaultMarkdownStateService: MarkdownStateService {
    private let documentService: MarkdownDocumentService
    private let formattingService: MarkdownFormattingService
    
    public init(
        documentService: MarkdownDocumentService = DefaultMarkdownDocumentService(),
        formattingService: MarkdownFormattingService? = nil
    ) {
        self.documentService = documentService
        self.formattingService = formattingService ?? DefaultMarkdownFormattingService(documentService: documentService)
    }
    
    public func applyChange(
        _ change: StateChange,
        to state: MarkdownEditorState
    ) -> Result<MarkdownEditorState, DomainError> {
        
        guard change.canApply(to: state) else {
            return .failure(.unsupportedOperation("Change cannot be applied: \(change.description)"))
        }
        
        return change.apply(to: state)
    }
    
    public func applyChanges(
        _ changes: [StateChange],
        to state: MarkdownEditorState
    ) -> Result<MarkdownEditorState, DomainError> {
        
        var currentState = state
        
        for change in changes {
            switch applyChange(change, to: currentState) {
            case .success(let newState):
                currentState = newState
            case .failure(let error):
                return .failure(error)
            }
        }
        
        return .success(currentState)
    }
    
    public func validateState(_ state: MarkdownEditorState) -> ValidationResult {
        var errors: [DomainError] = []
        var warnings: [String] = []
        
        // Validate document content
        let documentValidation = documentService.validateDocument(state.content)
        errors.append(contentsOf: documentValidation.errors)
        warnings.append(contentsOf: documentValidation.warnings)
        
        // Validate selection using document service
        switch documentService.validatePosition(state.selection.start, in: state.content) {
        case .success:
            break
        case .failure(let error):
            errors.append(error)
        }
        
        switch documentService.validatePosition(state.selection.end, in: state.content) {
        case .success:
            break
        case .failure(let error):
            errors.append(error)
        }
        
        // Validate formatting compatibility with block type
        if !formattingService.canApplyFormatting(
            state.currentFormatting,
            to: state.selection,
            in: state
        ) {
            warnings.append("Current formatting may not be compatible with block type")
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    public func createState(
        from content: String,
        cursorAt position: DocumentPosition
    ) -> Result<MarkdownEditorState, DomainError> {
        
        // Validate position using document service
        switch documentService.validatePosition(position, in: content) {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }
        
        // Get formatting and block type at position
        let blockType = formattingService.getBlockTypeAt(position: position, in: MarkdownEditorState(
            content: content,
            selection: TextRange(at: position)
        ))
        
        let formatting = formattingService.getFormattingAt(position: position, in: MarkdownEditorState(
            content: content,
            selection: TextRange(at: position)
        ))
        
        let state = MarkdownEditorState(
            content: content,
            selection: TextRange(at: position),
            currentFormatting: formatting,
            currentBlockType: blockType,
            hasUnsavedChanges: false,
            metadata: .default
        )
        
        return .success(state)
    }
    
    public func updateSelection(
        to range: TextRange,
        in state: MarkdownEditorState
    ) -> Result<MarkdownEditorState, DomainError> {
        
        // Validate new selection using document service
        switch documentService.validatePosition(range.start, in: state.content) {
        case .success:
            break
        case .failure:
            return .failure(.invalidRange(range))
        }
        
        switch documentService.validatePosition(range.end, in: state.content) {
        case .success:
            break
        case .failure:
            return .failure(.invalidRange(range))
        }
        
        // Update formatting and block type based on new selection
        let newFormatting = formattingService.getFormattingAt(position: range.start, in: state)
        let newBlockType = formattingService.getBlockTypeAt(position: range.start, in: state)
        
        let newState = MarkdownEditorState(
            content: state.content,
            selection: range,
            currentFormatting: newFormatting,
            currentBlockType: newBlockType,
            hasUnsavedChanges: state.hasUnsavedChanges,
            metadata: state.metadata
        )
        
        return .success(newState)
    }
    
    public func getStateInfo(
        at position: DocumentPosition,
        in state: MarkdownEditorState
    ) -> StateInfo {
        
        // Check if position is valid
        switch documentService.validatePosition(position, in: state.content) {
        case .success:
            break
        case .failure:
            return StateInfo(
                currentBlock: nil,
                formatting: [],
                blockType: .paragraph,
                isAtBlockStart: false,
                isAtBlockEnd: false,
                currentWord: nil,
                lineNumber: position.blockIndex + 1,
                columnNumber: position.offset + 1
            )
        }
        
        let currentBlock = documentService.getBlock(at: position, in: state.content)
        let formatting = formattingService.getFormattingAt(position: position, in: state)
        let blockType = formattingService.getBlockTypeAt(position: position, in: state)
        
        let blockText = currentBlock?.textContent ?? ""
        let isAtBlockStart = position.offset == 0
        let isAtBlockEnd = position.offset == blockText.count
        
        // Find current word
        let currentWord = getCurrentWord(at: position.offset, in: blockText)
        
        return StateInfo(
            currentBlock: currentBlock,
            formatting: formatting,
            blockType: blockType,
            isAtBlockStart: isAtBlockStart,
            isAtBlockEnd: isAtBlockEnd,
            currentWord: currentWord,
            lineNumber: position.blockIndex + 1,
            columnNumber: position.offset + 1
        )
    }
    
    public func areStatesEquivalent(_ state1: MarkdownEditorState, _ state2: MarkdownEditorState) -> Bool {
        return state1.content == state2.content &&
               state1.selection == state2.selection &&
               state1.currentFormatting == state2.currentFormatting &&
               state1.currentBlockType == state2.currentBlockType
        // Deliberately ignore hasUnsavedChanges and metadata for equivalence
    }
    
    public func createDiff(from oldState: MarkdownEditorState, to newState: MarkdownEditorState) -> StateDiff {
        var contentChanges: [ContentChange] = []
        var selectionChange: SelectionChange?
        var formattingChange: FormattingChange?
        var blockTypeChange: BlockTypeDiffChange?
        
        // Check for content changes
        if oldState.content != newState.content {
            // For now, create a simple replacement change
            // In a real implementation, this would use a proper diff algorithm
            contentChanges.append(ContentChange(
                type: .replacement,
                range: TextRange(
                    start: DocumentPosition(blockIndex: 0, offset: 0),
                    end: DocumentPosition(blockIndex: Int.max, offset: Int.max)
                ),
                oldText: oldState.content,
                newText: newState.content
            ))
        }
        
        // Check for selection changes
        if oldState.selection != newState.selection {
            selectionChange = SelectionChange(from: oldState.selection, to: newState.selection)
        }
        
        // Check for formatting changes
        if oldState.currentFormatting != newState.currentFormatting {
            formattingChange = FormattingChange(
                formatting: newState.currentFormatting,
                range: newState.selection,
                operation: .apply
            )
        }
        
        // Check for block type changes
        if oldState.currentBlockType != newState.currentBlockType {
            blockTypeChange = BlockTypeDiffChange(
                at: newState.selection.start,
                from: oldState.currentBlockType,
                to: newState.currentBlockType
            )
        }
        
        // Determine if this is a significant change
        let isSignificant = !contentChanges.isEmpty || 
                           formattingChange != nil || 
                           blockTypeChange != nil
        
        return StateDiff(
            contentChanges: contentChanges,
            selectionChange: selectionChange,
            formattingChange: formattingChange,
            blockTypeChange: blockTypeChange,
            isSignificant: isSignificant
        )
    }
    
    // MARK: - Private Helpers
    
    private func getCurrentWord(at offset: Int, in line: String) -> String? {
        guard !line.isEmpty && offset <= line.count else { return nil }
        
        let safeOffset = min(offset, line.count - 1)
        let characters = Array(line)
        
        // Find word boundaries
        var start = safeOffset
        var end = safeOffset
        
        // Move start backwards to find word start
        while start > 0 && characters[start - 1].isLetter {
            start -= 1
        }
        
        // Move end forwards to find word end
        while end < characters.count && characters[end].isLetter {
            end += 1
        }
        
        // Extract word if we found one
        if start < end && start < characters.count {
            let wordCharacters = characters[start..<end]
            let word = String(wordCharacters)
            return word.isEmpty ? nil : word
        }
        
        return nil
    }
}