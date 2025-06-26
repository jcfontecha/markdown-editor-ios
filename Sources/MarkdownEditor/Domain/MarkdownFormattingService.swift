/*
 * MarkdownFormattingService
 * 
 * Domain service for markdown formatting operations.
 * Extracts formatting business logic from UI layer for testing.
 */

import Foundation

// MARK: - Formatting Service Protocol

/// Service for performing formatting operations on markdown content
public protocol MarkdownFormattingService {
    /// Apply inline formatting to a text range
    func applyInlineFormatting(
        _ formatting: InlineFormatting,
        to range: TextRange,
        in state: MarkdownEditorState,
        operation: FormattingOperation
    ) -> Result<MarkdownEditorState, DomainError>
    
    /// Change the block type at a specific position
    func setBlockType(
        _ blockType: MarkdownBlockType,
        at position: DocumentPosition,
        in state: MarkdownEditorState
    ) -> Result<MarkdownEditorState, DomainError>
    
    /// Get the current formatting at a position
    func getFormattingAt(
        position: DocumentPosition,
        in state: MarkdownEditorState
    ) -> InlineFormatting
    
    /// Get the current block type at a position
    func getBlockTypeAt(
        position: DocumentPosition,
        in state: MarkdownEditorState
    ) -> MarkdownBlockType
    
    /// Check if formatting can be applied to a range
    func canApplyFormatting(
        _ formatting: InlineFormatting,
        to range: TextRange,
        in state: MarkdownEditorState
    ) -> Bool
    
    /// Check if block type can be changed at a position
    func canSetBlockType(
        _ blockType: MarkdownBlockType,
        at position: DocumentPosition,
        in state: MarkdownEditorState
    ) -> Bool
    
    /// Get valid formatting combinations for current selection
    func getValidFormattingOptions(
        for range: TextRange,
        in state: MarkdownEditorState
    ) -> [InlineFormatting]
    
    /// Get valid block type options for current position
    func getValidBlockTypeOptions(
        for position: DocumentPosition,
        in state: MarkdownEditorState
    ) -> [MarkdownBlockType]
}

// MARK: - Formatting Operation Types

/// The type of formatting operation to perform
public enum FormattingOperation: CaseIterable {
    case apply
    case remove
    case toggle
    
    public var description: String {
        switch self {
        case .apply: return "apply"
        case .remove: return "remove"
        case .toggle: return "toggle"
        }
    }
}

// MARK: - Formatting Rules

/// Business rules for formatting operations
public struct FormattingRules {
    /// Formatting combinations that are not allowed
    public static let incompatibleCombinations: [(InlineFormatting, InlineFormatting)] = [
        // Code formatting cannot be combined with other formatting
        ([.code], [.bold]),
        ([.code], [.italic]),
        ([.code], [.strikethrough])
    ]
    
    /// Block types that don't support inline formatting
    public static let nonFormattableBlockTypes: Set<MarkdownBlockType> = [
        .codeBlock
    ]
    
    /// Block types that have restrictions on their content
    public static let restrictedBlockTypes: [MarkdownBlockType: [InlineFormatting]] = [
        .codeBlock: [] // Code blocks don't support any inline formatting
    ]
    
    /// Check if two formatting options are compatible
    public static func areCompatible(_ first: InlineFormatting, _ second: InlineFormatting) -> Bool {
        for (incompatible1, incompatible2) in incompatibleCombinations {
            if first.contains(incompatible1) && second.contains(incompatible2) {
                return false
            }
            if first.contains(incompatible2) && second.contains(incompatible1) {
                return false
            }
        }
        return true
    }
    
    /// Check if formatting is allowed for a block type
    public static func isFormattingAllowed(_ formatting: InlineFormatting, for blockType: MarkdownBlockType) -> Bool {
        if nonFormattableBlockTypes.contains(blockType) {
            return false
        }
        
        if let allowedFormats = restrictedBlockTypes[blockType] {
            return allowedFormats.contains(formatting)
        }
        
        return true
    }
}

// MARK: - Default Implementation

/// Default implementation of MarkdownFormattingService
public class DefaultMarkdownFormattingService: MarkdownFormattingService {
    private let documentService: MarkdownDocumentService
    
    public init(documentService: MarkdownDocumentService = DefaultMarkdownDocumentService()) {
        self.documentService = documentService
    }
    
    public func applyInlineFormatting(
        _ formatting: InlineFormatting,
        to range: TextRange,
        in state: MarkdownEditorState,
        operation: FormattingOperation = .toggle
    ) -> Result<MarkdownEditorState, DomainError> {
        
        // Validate range
        guard canApplyFormatting(formatting, to: range, in: state) else {
            return .failure(.unsupportedOperation("Cannot apply \(formatting) to range \(range)"))
        }
        
        // Get current block type to check compatibility
        let blockType = getBlockTypeAt(position: range.start, in: state)
        guard FormattingRules.isFormattingAllowed(formatting, for: blockType) else {
            return .failure(.unsupportedOperation("Formatting \(formatting) not allowed for block type \(blockType)"))
        }
        
        // For now, simulate the formatting application
        // In a real implementation, this would modify the document content with markdown syntax
        let currentFormatting = getFormattingAt(position: range.start, in: state)
        
        let newFormatting: InlineFormatting
        switch operation {
        case .apply:
            newFormatting = currentFormatting.union(formatting)
        case .remove:
            newFormatting = currentFormatting.subtracting(formatting)
        case .toggle:
            newFormatting = currentFormatting.symmetricDifference(formatting)
        }
        
        // Check compatibility of new formatting combination
        guard FormattingRules.areCompatible(newFormatting, []) else {
            return .failure(.unsupportedOperation("Incompatible formatting combination: \(newFormatting)"))
        }
        
        // Create new state with updated formatting
        let newState = MarkdownEditorState(
            content: state.content, // In real implementation, would update content with markdown syntax
            selection: range,
            currentFormatting: newFormatting,
            currentBlockType: state.currentBlockType,
            hasUnsavedChanges: true,
            metadata: state.metadata
        )
        
        return .success(newState)
    }
    
    public func setBlockType(
        _ blockType: MarkdownBlockType,
        at position: DocumentPosition,
        in state: MarkdownEditorState
    ) -> Result<MarkdownEditorState, DomainError> {
        
        guard canSetBlockType(blockType, at: position, in: state) else {
            return .failure(.unsupportedOperation("Cannot set block type \(blockType) at position \(position)"))
        }
        
        // Use document service to replace the block
        let replaceResult = documentService.replaceBlock(
            at: position.blockIndex,
            with: blockType,
            in: state.content
        )
        
        switch replaceResult {
        case .success(let newContent):
            let newState = MarkdownEditorState(
                content: newContent,
                selection: TextRange(at: position),
                currentFormatting: state.currentFormatting,
                currentBlockType: blockType,
                hasUnsavedChanges: true,
                metadata: state.metadata
            )
            return .success(newState)
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    public func getFormattingAt(position: DocumentPosition, in state: MarkdownEditorState) -> InlineFormatting {
        // In a real implementation, this would parse the markdown at the position
        // to determine the current formatting. For now, return the state's current formatting
        return state.currentFormatting
    }
    
    public func getBlockTypeAt(position: DocumentPosition, in state: MarkdownEditorState) -> MarkdownBlockType {
        guard let block = documentService.getBlock(at: position, in: state.content) else {
            return .paragraph
        }
        return block.blockType
    }
    
    public func canApplyFormatting(
        _ formatting: InlineFormatting,
        to range: TextRange,
        in state: MarkdownEditorState
    ) -> Bool {
        // Check if range is valid
        guard !range.isMultiBlock else {
            return false // Multi-block formatting not supported yet
        }
        
        // Check if formatting is compatible with current block type
        let blockType = getBlockTypeAt(position: range.start, in: state)
        guard FormattingRules.isFormattingAllowed(formatting, for: blockType) else {
            return false
        }
        
        // Check compatibility with current formatting
        let currentFormatting = getFormattingAt(position: range.start, in: state)
        return FormattingRules.areCompatible(currentFormatting, formatting)
    }
    
    public func canSetBlockType(
        _ blockType: MarkdownBlockType,
        at position: DocumentPosition,
        in state: MarkdownEditorState
    ) -> Bool {
        // Check if position is valid
        let lines = state.content.components(separatedBy: .newlines)
        guard position.blockIndex < lines.count else {
            return false
        }
        
        // Most block type changes are allowed, but some have restrictions
        switch blockType {
        case .codeBlock:
            // Code blocks can be created from any block type
            return true
        case .heading:
            // Headers can be created from any block type
            return true
        case .unorderedList, .orderedList:
            // Lists can be created from any block type
            return true
        case .paragraph:
            // Any block can be converted to paragraph
            return true
        case .quote:
            // Quotes can be created from any block type
            return true
        }
    }
    
    public func getValidFormattingOptions(
        for range: TextRange,
        in state: MarkdownEditorState
    ) -> [InlineFormatting] {
        let blockType = getBlockTypeAt(position: range.start, in: state)
        let currentFormatting = getFormattingAt(position: range.start, in: state)
        
        let allFormattingOptions: [InlineFormatting] = [
            [.bold],
            [.italic],
            [.strikethrough],
            [.code]
        ]
        
        return allFormattingOptions.filter { formatting in
            FormattingRules.isFormattingAllowed(formatting, for: blockType) &&
            FormattingRules.areCompatible(currentFormatting, formatting)
        }
    }
    
    public func getValidBlockTypeOptions(
        for position: DocumentPosition,
        in state: MarkdownEditorState
    ) -> [MarkdownBlockType] {
        // For now, all block types are valid options
        return [
            .paragraph,
            .heading(level: .h1),
            .heading(level: .h2),
            .heading(level: .h3),
            .heading(level: .h4),
            .heading(level: .h5),
            .heading(level: .h6),
            .unorderedList,
            .orderedList,
            .codeBlock,
            .quote
        ]
    }
}

// MARK: - Formatting Utilities

// Note: InlineFormatting extensions are defined in MarkdownConfiguration.swift to avoid duplication

extension MarkdownBlockType {
    /// Returns the markdown prefix for this block type
    public var markdownPrefix: String {
        switch self {
        case .paragraph:
            return ""
        case .heading(let level):
            return String(repeating: "#", count: level.rawValue) + " "
        case .unorderedList:
            return "- "
        case .orderedList:
            return "1. " // Simplified, real implementation would track number
        case .codeBlock:
            return "```\n"
        case .quote:
            return "> "
        }
    }
    
    /// Returns the markdown suffix for this block type
    public var markdownSuffix: String {
        switch self {
        case .codeBlock:
            return "\n```"
        default:
            return ""
        }
    }
}