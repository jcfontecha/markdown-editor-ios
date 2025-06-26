/*
 * MarkdownEditor Domain Models
 * 
 * Core domain abstractions for unit-testable markdown operations.
 * These models are independent of Lexical and UI concerns.
 */

import Foundation

// MARK: - Document Position and Range

/// Represents a position within a markdown document
public struct DocumentPosition: Equatable {
    /// The paragraph/block index (0-based)
    public let blockIndex: Int
    /// The character offset within the block (0-based)
    public let offset: Int
    
    public init(blockIndex: Int, offset: Int) {
        self.blockIndex = blockIndex
        self.offset = offset
    }
    
    /// Creates a position at the beginning of the document
    public static let start = DocumentPosition(blockIndex: 0, offset: 0)
}

/// Represents a range of text within a markdown document
public struct TextRange: Equatable {
    /// The start position of the range
    public let start: DocumentPosition
    /// The end position of the range
    public let end: DocumentPosition
    
    public init(start: DocumentPosition, end: DocumentPosition) {
        self.start = start
        self.end = end
    }
    
    /// Creates a range that represents just a cursor position
    public init(at position: DocumentPosition) {
        self.start = position
        self.end = position
    }
    
    /// Whether this range represents just a cursor position (no selection)
    public var isCursor: Bool {
        return start == end
    }
    
    /// Whether this range spans multiple blocks
    public var isMultiBlock: Bool {
        return start.blockIndex != end.blockIndex
    }
}

// MARK: - Editor State

/// Represents the complete state of a markdown editor at a point in time
public struct MarkdownEditorState: Equatable {
    /// The complete document content as markdown text
    public let content: String
    /// The current cursor position or selection
    public let selection: TextRange
    /// The formatting applied at the current position
    public let currentFormatting: InlineFormatting
    /// The block type at the current position
    public let currentBlockType: MarkdownBlockType
    /// Whether the document has unsaved changes
    public let hasUnsavedChanges: Bool
    /// Document metadata
    public let metadata: DocumentMetadata
    
    public init(
        content: String,
        selection: TextRange,
        currentFormatting: InlineFormatting = [],
        currentBlockType: MarkdownBlockType = .paragraph,
        hasUnsavedChanges: Bool = false,
        metadata: DocumentMetadata = .default
    ) {
        self.content = content
        self.selection = selection
        self.currentFormatting = currentFormatting
        self.currentBlockType = currentBlockType
        self.hasUnsavedChanges = hasUnsavedChanges
        self.metadata = metadata
    }
    
    /// Creates an empty editor state
    public static let empty = MarkdownEditorState(
        content: "",
        selection: TextRange(at: .start)
    )
    
    /// Creates an editor state with a single paragraph
    public static func withParagraph(_ text: String) -> MarkdownEditorState {
        return MarkdownEditorState(
            content: text,
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: text.count))
        )
    }
    
    /// Creates an editor state with a header
    public static func withHeader(_ level: MarkdownBlockType.HeadingLevel, text: String) -> MarkdownEditorState {
        let prefix = String(repeating: "#", count: level.rawValue) + " "
        let content = prefix + text
        return MarkdownEditorState(
            content: content,
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: content.count)),
            currentBlockType: .heading(level: level)
        )
    }
}

// MARK: - State Changes

/// Represents a change that can be applied to editor state
public protocol StateChange {
    /// Apply this change to the given state, returning the new state
    func apply(to state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError>
    
    /// Whether this change can be applied to the given state
    func canApply(to state: MarkdownEditorState) -> Bool
    
    /// A description of this change for debugging/logging
    var description: String { get }
}

/// Represents a text insertion change
public struct TextInsertionChange: StateChange {
    public let text: String
    public let position: DocumentPosition
    
    public init(text: String, at position: DocumentPosition) {
        self.text = text
        self.position = position
    }
    
    public func apply(to state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        // Implementation will be added when we build the document service
        return .failure(DomainError.notImplemented("TextInsertionChange.apply"))
    }
    
    public func canApply(to state: MarkdownEditorState) -> Bool {
        return position.blockIndex >= 0 && position.offset >= 0
    }
    
    public var description: String {
        return "Insert '\(text)' at \(position)"
    }
}

/// Represents a formatting change
public struct FormattingChange: StateChange, Equatable {
    public let formatting: InlineFormatting
    public let range: TextRange
    public let operation: FormattingOperation
    
    public init(formatting: InlineFormatting, range: TextRange, operation: FormattingOperation = .toggle) {
        self.formatting = formatting
        self.range = range
        self.operation = operation
    }
    
    public func apply(to state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        // Implementation will be added when we build the formatting service
        return .failure(DomainError.notImplemented("FormattingChange.apply"))
    }
    
    public func canApply(to state: MarkdownEditorState) -> Bool {
        return !range.isMultiBlock // For now, only support single-block formatting
    }
    
    public var description: String {
        return "\(operation) \(formatting) on \(range)"
    }
}

/// Represents a block type change
public struct BlockTypeStateChange: StateChange {
    public let blockType: MarkdownBlockType
    public let position: DocumentPosition
    
    public init(blockType: MarkdownBlockType, at position: DocumentPosition) {
        self.blockType = blockType
        self.position = position
    }
    
    public func apply(to state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        // Implementation will be added when we build the document service
        return .failure(DomainError.notImplemented("BlockTypeStateChange.apply"))
    }
    
    public func canApply(to state: MarkdownEditorState) -> Bool {
        return position.blockIndex >= 0
    }
    
    public var description: String {
        return "Change block at \(position) to \(blockType)"
    }
}

// MARK: - Domain Errors

/// Errors that can occur in the domain layer
public enum DomainError: Error {
    case invalidPosition(DocumentPosition)
    case invalidRange(TextRange)
    case invalidBlockType(MarkdownBlockType)
    case unsupportedOperation(String)
    case documentValidationFailed(String)
    case notImplemented(String)
    case serializationFailed(String)
    case stateError(String)
    case undoFailed(String)
    
    public var localizedDescription: String {
        switch self {
        case .invalidPosition(let position):
            return "Invalid document position: \(position)"
        case .invalidRange(let range):
            return "Invalid text range: \(range)"
        case .invalidBlockType(let blockType):
            return "Invalid block type: \(blockType)"
        case .unsupportedOperation(let operation):
            return "Unsupported operation: \(operation)"
        case .documentValidationFailed(let reason):
            return "Document validation failed: \(reason)"
        case .notImplemented(let feature):
            return "Not implemented: \(feature)"
        case .serializationFailed(let reason):
            return "Serialization failed: \(reason)"
        case .stateError(let reason):
            return "State error: \(reason)"
        case .undoFailed(let reason):
            return "Undo failed: \(reason)"
        }
    }
}

// MARK: - Validation Results

/// Result of validating a document or operation
public struct ValidationResult {
    public let isValid: Bool
    public let errors: [DomainError]
    public let warnings: [String]
    
    public init(isValid: Bool, errors: [DomainError] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
    
    public static let valid = ValidationResult(isValid: true)
    
    public static func invalid(errors: [DomainError]) -> ValidationResult {
        return ValidationResult(isValid: false, errors: errors)
    }
    
    public static func invalid(error: DomainError) -> ValidationResult {
        return ValidationResult(isValid: false, errors: [error])
    }
}

// MARK: - Document Metadata

/// Metadata associated with a markdown document
public struct DocumentMetadata: Equatable {
    public let createdAt: Date
    public let modifiedAt: Date
    public let version: String
    
    public init(createdAt: Date = Date(), modifiedAt: Date = Date(), version: String = "1.0") {
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.version = version
    }
    
    public static let `default` = DocumentMetadata()
}

// MARK: - Input Event Abstractions

/// Represents user input events that can be unit tested without TextKit dependencies
public enum InputEvent: Equatable {
    case keystroke(character: Character, modifiers: KeyModifiers = [])
    case backspace
    case delete
    case enter
    case tab
    case paste(text: String)
    case cut
    case copy
    
    public var description: String {
        switch self {
        case .keystroke(let character, let modifiers):
            let modifierString = modifiers.isEmpty ? "" : "\(modifiers) + "
            return "\(modifierString)'\(character)'"
        case .backspace:
            return "Backspace"
        case .delete:
            return "Delete"
        case .enter:
            return "Enter"
        case .tab:
            return "Tab"
        case .paste(let text):
            return "Paste '\(text)'"
        case .cut:
            return "Cut"
        case .copy:
            return "Copy"
        }
    }
}

/// Keyboard modifiers for input events
public struct KeyModifiers: OptionSet, Equatable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let shift = KeyModifiers(rawValue: 1 << 0)
    public static let command = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let control = KeyModifiers(rawValue: 1 << 3)
}

extension KeyModifiers: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        if contains(.command) { parts.append("Cmd") }
        if contains(.shift) { parts.append("Shift") }
        if contains(.option) { parts.append("Option") }
        if contains(.control) { parts.append("Ctrl") }
        return parts.joined(separator: "+")
    }
}