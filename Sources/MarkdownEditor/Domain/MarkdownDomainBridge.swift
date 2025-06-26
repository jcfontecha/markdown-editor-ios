/*
 * MarkdownDomainBridge
 * 
 * Critical bridge between domain layer and Lexical.
 * Handles state synchronization, command translation, and business rule enforcement.
 */

import Foundation
import Lexical
import LexicalMarkdown
import LexicalListPlugin
import LexicalLinkPlugin

// MARK: - Domain Bridge

/// Bridges the domain layer with Lexical, enabling testable business logic
public class MarkdownDomainBridge {
    
    // MARK: - Properties
    
    private let stateService: MarkdownStateService
    private let documentService: MarkdownDocumentService
    private let formattingService: MarkdownFormattingService
    private var currentDomainState: MarkdownEditorState
    private weak var editor: Editor?
    
    // MARK: - Initialization
    
    public init(
        stateService: MarkdownStateService = DefaultMarkdownStateService(),
        documentService: MarkdownDocumentService = DefaultMarkdownDocumentService(),
        formattingService: MarkdownFormattingService = DefaultMarkdownFormattingService()
    ) {
        self.stateService = stateService
        self.documentService = documentService
        self.formattingService = formattingService
        self.currentDomainState = MarkdownEditorState.empty
    }
    
    /// Connect the bridge to a Lexical editor
    public func connect(to editor: Editor) {
        self.editor = editor
        syncFromLexical()
    }
    
    // MARK: - State Synchronization
    
    /// Synchronize domain state from current Lexical state
    public func syncFromLexical() {
        guard let editor = editor else { return }
        
        do {
            try editor.read {
                self.currentDomainState = self.extractState(from: editor)
            }
        } catch {
            // Log error but don't crash - maintain last known state
            print("[MarkdownDomainBridge] Failed to sync state from Lexical: \(error)")
        }
    }
    
    /// Get current domain state
    public func getCurrentState() -> MarkdownEditorState {
        return currentDomainState
    }
    
    // MARK: - Command Execution
    
    /// Execute a domain command and apply it to Lexical
    public func execute(_ command: MarkdownCommand) -> Result<Void, DomainError> {
        // First validate against domain rules
        guard command.canExecute(on: currentDomainState) else {
            return .failure(.commandValidationFailed(String(describing: command)))
        }
        
        // Execute in domain to get new state
        let executionResult = command.execute(on: currentDomainState)
        
        switch executionResult {
        case .success(let newState):
            // Apply changes to Lexical
            let applyResult = applyToLexical(command: command, newState: newState)
            
            switch applyResult {
            case .success:
                // Update domain state
                currentDomainState = newState
                return .success(())
            case .failure(let error):
                return .failure(error)
            }
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - Command Creation
    
    /// Create a formatting command for the given formatting
    public func createFormattingCommand(_ formatting: InlineFormatting) -> MarkdownCommand {
        // Get current selection from domain state
        let selection = currentDomainState.selection
        
        return ApplyFormattingCommand(
            formatting: formatting,
            to: selection,
            operation: .toggle, // Default to toggle for toolbar buttons
            context: MarkdownCommandContext(
                documentService: documentService,
                formattingService: formattingService,
                stateService: stateService
            )
        )
    }
    
    /// Create a block type command for the given block type
    public func createBlockTypeCommand(_ blockType: MarkdownBlockType) -> MarkdownCommand {
        return SetBlockTypeCommand(
            blockType: blockType,
            at: currentDomainState.selection.start,
            context: MarkdownCommandContext(
                documentService: documentService,
                formattingService: formattingService,
                stateService: stateService
            )
        )
    }
    
    // MARK: - Document Operations
    
    /// Parse and prepare a document for loading
    public func parseDocument(_ document: MarkdownDocument) -> Result<ParsedMarkdownDocument, DomainError> {
        let parsed = documentService.parseMarkdown(document.content)
        
        // Validate the parsed document
        let validation = documentService.validateDocument(document.content)
        if !validation.isValid {
            return .failure(.documentValidationFailed(validation.errors.first?.localizedDescription ?? "Unknown error"))
        }
        
        return .success(parsed)
    }
    
    /// Apply a parsed document to Lexical
    public func applyToLexical(_ parsed: ParsedMarkdownDocument, editor: Editor) -> Result<Void, DomainError> {
        do {
            try editor.update {
                // Clear existing content by removing all children
                guard let root = getRoot() else { return }
                let children = root.getChildren()
                for child in children {
                    try? child.remove()
                }
                
                // Add each block, or create a default paragraph if empty
                if parsed.blocks.isEmpty {
                    // Create a default paragraph node for empty documents
                    let defaultParagraph = createParagraphNode()
                    try? root.append([defaultParagraph])
                } else {
                for block in parsed.blocks {
                    let lexicalNode = self.createLexicalNode(from: block)
                    try? root.append([lexicalNode])
                    }
                }
            }
            
            // Sync state after applying
            syncFromLexical()
            return .success(())
            
        } catch {
            return .failure(.editorOperationFailed(error.localizedDescription))
        }
    }
    
    /// Export current state as a document
    public func exportDocument() -> Result<MarkdownDocument, DomainError> {
        guard let editor = editor else {
            return .failure(.editorNotConnected)
        }
        
        do {
            let markdownText = try LexicalMarkdown.generateMarkdown(
                from: editor,
                selection: nil
            )
            
            let document = MarkdownDocument(
                content: markdownText,
                metadata: DocumentMetadata(
                    createdAt: Date(),
                    modifiedAt: Date(),
                    version: "1.0"
                )
            )
            
            return .success(document)
        } catch {
            return .failure(.serializationFailed(error.localizedDescription))
        }
    }
    
    // MARK: - State Extraction
    
    private func extractState(from editor: Editor) -> MarkdownEditorState {
        // Get selection
        let selection = extractSelection(from: editor)
        
        // Get current block context
        let position = selection.start
        let blockType = detectBlockType(at: position, in: editor)
        
        // Get formatting at cursor
        let formatting = extractFormatting(at: position, in: editor)
        
        // Get document content
        let content = (try? LexicalMarkdown.generateMarkdown(from: editor, selection: nil)) ?? ""
        
        return MarkdownEditorState(
            content: content,
            selection: selection,
            currentFormatting: formatting,
            currentBlockType: blockType,
            hasUnsavedChanges: false,
            metadata: DocumentMetadata()
        )
    }
    
    private func extractSelection(from editor: Editor) -> TextRange {
        guard let lexicalSelection = try? getSelection() as? RangeSelection else {
            return TextRange(at: DocumentPosition(blockIndex: 0, offset: 0))
        }
        
        // Convert Lexical selection to domain TextRange
        // This is simplified - real implementation would map nodes to blocks
        let startOffset = lexicalSelection.anchor.offset
        let endOffset = lexicalSelection.focus.offset
        
        let start = DocumentPosition(blockIndex: 0, offset: startOffset)
        let end = DocumentPosition(blockIndex: 0, offset: endOffset)
        
        return TextRange(start: start, end: end)
    }
    
    private func detectBlockType(at position: DocumentPosition, in editor: Editor) -> MarkdownBlockType {
        guard let selection = try? getSelection() as? RangeSelection,
              let anchorNode = try? selection.anchor.getNode() else {
            return .paragraph
        }
        
        let element = isRootNode(node: anchorNode) ? anchorNode :
            findMatchingParent(startingNode: anchorNode) { e in
                let parent = e.getParent()
                return parent != nil && isRootNode(node: parent)
            }
        
        if let heading = element as? HeadingNode {
            let tagType = heading.getTag()
            let level: MarkdownBlockType.HeadingLevel
            switch tagType {
            case .h1: level = .h1
            case .h2: level = .h2
            case .h3: level = .h3
            case .h4: level = .h4
            case .h5: level = .h5
            }
            return .heading(level: level)
        } else if element is CodeNode {
            return .codeBlock
        } else if element is QuoteNode {
            return .quote
        } else if let listNode = element as? ListNode {
            return listNode.getListType() == .bullet ? .unorderedList : .orderedList
        } else if element is ListItemNode {
            if let parentList = element?.getParent() as? ListNode {
                return parentList.getListType() == .bullet ? .unorderedList : .orderedList
            }
        }
        
        return .paragraph
    }
    
    private func extractFormatting(at position: DocumentPosition, in editor: Editor) -> InlineFormatting {
        var formatting: InlineFormatting = []
        
        guard let selection = try? getSelection() as? RangeSelection else {
            return formatting
        }
        
        if selection.hasFormat(type: .bold) { formatting.insert(.bold) }
        if selection.hasFormat(type: .italic) { formatting.insert(.italic) }
        if selection.hasFormat(type: .strikethrough) { formatting.insert(.strikethrough) }
        if selection.hasFormat(type: .code) { formatting.insert(.code) }
        
        return formatting
    }
    
    // MARK: - Lexical Application
    
    private func applyToLexical(command: MarkdownCommand, newState: MarkdownEditorState) -> Result<Void, DomainError> {
        guard let editor = editor else {
            return .failure(.editorNotConnected)
        }
        
        do {
            try editor.update {
                // Translate domain command to Lexical operations
                self.translateAndApply(command, to: editor)
            }
            return .success(())
        } catch {
            return .failure(.editorOperationFailed(error.localizedDescription))
        }
    }
    
    private func translateAndApply(_ command: MarkdownCommand, to editor: Editor) {
        switch command {
        case let formatCommand as ApplyFormattingCommand:
            applyFormattingCommand(formatCommand, to: editor)
            
        case let blockCommand as SetBlockTypeCommand:
            applyBlockTypeCommand(blockCommand, to: editor)
            
        case let insertCommand as InsertTextCommand:
            applyInsertTextCommand(insertCommand, to: editor)
            
        default:
            print("[MarkdownDomainBridge] Unknown command type: \(type(of: command))")
        }
    }
    
    private func applyFormattingCommand(_ command: ApplyFormattingCommand, to editor: Editor) {
        let formatting = command.formatting
        
        if formatting.contains(.bold) {
            editor.dispatchCommand(type: .formatText, payload: TextFormatType.bold)
        }
        if formatting.contains(.italic) {
            editor.dispatchCommand(type: .formatText, payload: TextFormatType.italic)
        }
        if formatting.contains(.strikethrough) {
            editor.dispatchCommand(type: .formatText, payload: TextFormatType.strikethrough)
        }
        if formatting.contains(.code) {
            editor.dispatchCommand(type: .formatText, payload: TextFormatType.code)
        }
    }
    
    private func applyBlockTypeCommand(_ command: SetBlockTypeCommand, to editor: Editor) {
        guard let selection = try? getSelection() as? RangeSelection else { return }
        
        switch command.blockType {
        case .paragraph:
            setBlocksType(selection: selection) { createParagraphNode() }
        case .heading(let level):
            setBlocksType(selection: selection) { createHeadingNode(headingTag: level.lexicalType) }
        case .codeBlock:
            setBlocksType(selection: selection) { createCodeNode() }
        case .quote:
            setBlocksType(selection: selection) { createQuoteNode() }
        case .unorderedList:
            editor.dispatchCommand(type: .insertUnorderedList)
        case .orderedList:
            editor.dispatchCommand(type: .insertOrderedList)
        }
    }
    
    private func extractCurrentBlockType(from editor: Editor) -> MarkdownBlockType {
        guard let selection = try? getSelection() as? RangeSelection,
              let anchorNode = try? selection.anchor.getNode() else {
            return .paragraph
        }
        
        let element = isRootNode(node: anchorNode) ? anchorNode :
            findMatchingParent(startingNode: anchorNode) { e in
                let parent = e.getParent()
                return parent != nil && isRootNode(node: parent)
            }
        
        if let heading = element as? HeadingNode {
            let tagType = heading.getTag()
            let level: MarkdownBlockType.HeadingLevel
            switch tagType {
            case .h1: level = .h1
            case .h2: level = .h2
            case .h3: level = .h3
            case .h4: level = .h4
            case .h5: level = .h5
            }
            return .heading(level: level)
        } else if element is CodeNode {
            return .codeBlock
        } else if element is QuoteNode {
            return .quote
        } else if let listNode = element as? ListNode {
            return listNode.getListType() == .bullet ? .unorderedList : .orderedList
        } else if element is ListItemNode {
            if let parentList = element?.getParent() as? ListNode {
                return parentList.getListType() == .bullet ? .unorderedList : .orderedList
            }
        }
        
        return .paragraph
    }
    
    private func applyInsertTextCommand(_ command: InsertTextCommand, to editor: Editor) {
        guard let selection = try? getSelection() as? RangeSelection else { return }
        try? selection.insertText(command.text)
    }
    
    // MARK: - Node Creation
    
    private func createLexicalNode(from block: MarkdownBlock) -> Node {
        switch block {
        case .paragraph(let para):
            let node = createParagraphNode()
            if !para.text.isEmpty {
                let textNode = TextNode(text: para.text)
                try? node.append([textNode])
            }
            return node
            
        case .heading(let heading):
            let node = createHeadingNode(headingTag: heading.level.lexicalType)
            if !heading.text.isEmpty {
                let textNode = TextNode(text: heading.text)
                try? node.append([textNode])
            }
            return node
            
        case .codeBlock:
            let node = createCodeNode()
            // Code nodes handle their content differently
            // This would need proper implementation based on Lexical's code node API
            return node
            
        case .quote(let quote):
            let node = createQuoteNode()
            if !quote.text.isEmpty {
                let textNode = TextNode(text: quote.text)
                try? node.append([textNode])
            }
            return node
            
        case .list(let list):
            let listNode = ListNode(listType: list.type == .bullet ? .bullet : .number, start: 1)
            for item in list.items {
                let itemNode = ListItemNode()
                if !item.text.isEmpty {
                    let textNode = TextNode(text: item.text)
                    try? itemNode.append([textNode])
                }
                try? listNode.append([itemNode])
            }
            return listNode
        }
    }
}

// MARK: - Domain Error Extensions

extension DomainError {
    static let editorNotConnected = DomainError.unsupportedOperation("Editor not connected to bridge")
    static func editorOperationFailed(_ reason: String) -> DomainError {
        return DomainError.unsupportedOperation("Editor operation failed: \(reason)")
    }
    static let commandValidationFailed = { (command: String) in
        DomainError.unsupportedOperation("Command validation failed: \(command)")
    }
}