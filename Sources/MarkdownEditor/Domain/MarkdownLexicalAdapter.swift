/*
 * MarkdownLexicalAdapter
 * 
 * Bridges the domain layer with Lexical editor integration.
 * Translates domain operations into Lexical API calls.
 */

import Foundation
import Lexical
import LexicalListPlugin
import LexicalLinkPlugin
import LexicalMarkdown

// MARK: - Lexical Adapter Protocol

/// Adapter that bridges domain services with Lexical editor
public protocol MarkdownLexicalAdapter {
    /// Convert domain state to Lexical editor state
    func applyDomainState(_ state: MarkdownEditorState, to editor: Editor) throws
    
    /// Extract domain state from Lexical editor
    func extractDomainState(from editor: Editor) throws -> MarkdownEditorState
    
    /// Execute a domain command via Lexical operations
    func execute(command: MarkdownCommand, on editor: Editor) throws -> MarkdownEditorState
    
    /// Convert domain position to Lexical Point
    func convertToLexicalPoint(_ position: DocumentPosition, in editor: Editor) throws -> Point
    
    /// Convert Lexical Point to domain position
    func convertToDomainPosition(_ point: Point, in editor: Editor) throws -> DocumentPosition
    
    /// Convert domain range to Lexical RangeSelection
    func convertToLexicalSelection(_ range: TextRange, in editor: Editor) throws -> RangeSelection
    
    /// Convert Lexical RangeSelection to domain range
    func convertToDomainRange(_ selection: RangeSelection, in editor: Editor) throws -> TextRange
    
    /// Apply domain formatting to Lexical nodes
    func applyFormatting(_ formatting: InlineFormatting, to selection: RangeSelection, in editor: Editor) throws
    
    /// Create Lexical node from domain block
    func createLexicalNode(from block: MarkdownBlock) throws -> ElementNode
    
    /// Extract domain block from Lexical node
    func extractDomainBlock(from node: ElementNode) -> MarkdownBlock?
}

// MARK: - Default Implementation

/// Default implementation of MarkdownLexicalAdapter
public class DefaultMarkdownLexicalAdapter: MarkdownLexicalAdapter {
    private let documentService: MarkdownDocumentService
    private let stateService: MarkdownStateService
    
    public init(
        documentService: MarkdownDocumentService = DefaultMarkdownDocumentService(),
        stateService: MarkdownStateService? = nil
    ) {
        self.documentService = documentService
        self.stateService = stateService ?? DefaultMarkdownStateService(documentService: documentService)
    }
    
    public func applyDomainState(_ state: MarkdownEditorState, to editor: Editor) throws {
        try editor.update {
            guard let rootNode = getActiveEditorState()?.getRootNode() else {
                throw DomainError.unsupportedOperation("No root node available")
            }
            
            // Clear existing content
            try rootNode.getChildren().forEach { try $0.remove() }
            
            // Parse domain content and create Lexical nodes
            let document = documentService.parseMarkdown(state.content)
            
            for block in document.blocks {
                let lexicalNode = try createLexicalNode(from: block)
                try rootNode.append([lexicalNode])
            }
            
            // Set selection
            let lexicalSelection = try convertToLexicalSelection(state.selection, in: editor)
            getActiveEditorState()?.selection = lexicalSelection
        }
    }
    
    public func extractDomainState(from editor: Editor) throws -> MarkdownEditorState {
        return try editor.getEditorState().read {
            guard let rootNode = getActiveEditorState()?.getRootNode() else {
                throw DomainError.unsupportedOperation("No root node available")
            }
            
            // Generate markdown content from Lexical nodes
            let markdownContent = try LexicalMarkdown.generateMarkdown(from: editor, selection: nil)
            
            // Extract selection
            let selection: TextRange
            if let lexicalSelection = try getSelection() as? RangeSelection {
                selection = try convertToDomainRange(lexicalSelection, in: editor)
            } else {
                selection = TextRange(at: .start)
            }
            
            // Create domain state
            return try stateService.createState(from: markdownContent, cursorAt: selection.start).get()
        }
    }
    
    public func execute(command: MarkdownCommand, on editor: Editor) throws -> MarkdownEditorState {
        // Extract current domain state
        let currentState = try extractDomainState(from: editor)
        
        // Execute command in domain
        let newState = try command.execute(on: currentState).get()
        
        // Apply new state to Lexical
        try applyDomainState(newState, to: editor)
        
        return newState
    }
    
    public func convertToLexicalPoint(_ position: DocumentPosition, in editor: Editor) throws -> Point {
        return try editor.getEditorState().read {
            guard let rootNode = getActiveEditorState()?.getRootNode() else {
                throw DomainError.unsupportedOperation("No root node available")
            }
            
            let children = rootNode.getChildren()
            guard position.blockIndex < children.count else {
                throw DomainError.invalidPosition(position)
            }
            
            let targetNode = children[position.blockIndex]
            
            // For element nodes, use element selection
            if let elementNode = targetNode as? ElementNode {
                let clampedOffset = min(position.offset, elementNode.getChildrenSize())
                return Point(key: elementNode.key, offset: clampedOffset, type: .element)
            }
            
            // For text nodes, use text selection
            if let textNode = targetNode as? TextNode {
                let clampedOffset = min(position.offset, textNode.getTextPart().count)
                return Point(key: textNode.key, offset: clampedOffset, type: .text)
            }
            
            // Default to element selection
            return Point(key: targetNode.key, offset: 0, type: .element)
        }
    }
    
    public func convertToDomainPosition(_ point: Point, in editor: Editor) throws -> DocumentPosition {
        return try editor.getEditorState().read {
            guard let node = try? point.getNode(),
                  let rootNode = getActiveEditorState()?.getRootNode() else {
                throw DomainError.unsupportedOperation("Cannot resolve point node")
            }
            
            // Find the block index by traversing up to root
            var currentNode = node
            var blockIndex = 0
            
            while let parent = currentNode.getParent() {
                if parent.key == rootNode.key {
                    // Found the direct child of root
                    let siblings = parent.getChildren()
                    if let index = siblings.firstIndex(where: { $0.key == currentNode.key }) {
                        blockIndex = index
                    }
                    break
                }
                currentNode = parent
            }
            
            return DocumentPosition(blockIndex: blockIndex, offset: point.offset)
        }
    }
    
    public func convertToLexicalSelection(_ range: TextRange, in editor: Editor) throws -> RangeSelection {
        let anchorPoint = try convertToLexicalPoint(range.start, in: editor)
        let focusPoint = try convertToLexicalPoint(range.end, in: editor)
        
        return RangeSelection(anchor: anchorPoint, focus: focusPoint, format: TextFormat())
    }
    
    public func convertToDomainRange(_ selection: RangeSelection, in editor: Editor) throws -> TextRange {
        let startPosition = try convertToDomainPosition(selection.anchor, in: editor)
        let endPosition = try convertToDomainPosition(selection.focus, in: editor)
        
        return TextRange(start: startPosition, end: endPosition)
    }
    
    public func applyFormatting(_ formatting: InlineFormatting, to selection: RangeSelection, in editor: Editor) throws {
        // Apply formatting using existing Lexical APIs
        // Note: This is a placeholder implementation. In a real implementation,
        // we would either use the internal formatText method or modify the Lexical fork
        // to expose the necessary public APIs for formatting operations.
        
        // For now, we'll just update the selection's format property
        var newFormat = selection.format
        if formatting.contains(.bold) {
            newFormat.bold = true
        }
        if formatting.contains(.italic) {
            newFormat.italic = true
        }
        if formatting.contains(.strikethrough) {
            newFormat.strikethrough = true
        }
        if formatting.contains(.code) {
            newFormat.code = true
        }
        
        // This would need to be replaced with proper Lexical API calls
        // when we have access to the formatting methods
    }
    
    public func createLexicalNode(from block: MarkdownBlock) throws -> ElementNode {
        switch block {
        case .paragraph(let paragraph):
            let paragraphNode = ParagraphNode()
            try addTextContent(paragraph.text, to: paragraphNode, withFormatting: paragraph.formatting)
            return paragraphNode
            
        case .heading(let heading):
            let headingNode = createHeadingNode(headingTag: heading.level.lexicalType)
            try addTextContent(heading.text, to: headingNode, withFormatting: heading.formatting)
            return headingNode
            
        case .list(let list):
            let listNode = ListNode(listType: list.type.lexicalType, start: list.type.startNumber)
            
            for item in list.items {
                let listItemNode = ListItemNode()
                try addTextContent(item.text, to: listItemNode, withFormatting: item.formatting)
                try listNode.append([listItemNode])
            }
            
            return listNode
            
        case .codeBlock(let codeBlock):
            let codeNode = CodeNode()
            let textNode = TextNode()
            try textNode.setText(codeBlock.content)
            try codeNode.append([textNode])
            return codeNode
            
        case .quote(let quote):
            let quoteNode = QuoteNode()
            try addTextContent(quote.text, to: quoteNode, withFormatting: quote.formatting)
            return quoteNode
        }
    }
    
    public func extractDomainBlock(from node: ElementNode) -> MarkdownBlock? {
        if let paragraphNode = node as? ParagraphNode {
            let text = paragraphNode.getTextContent()
            let formatting = extractFormatting(from: paragraphNode)
            return .paragraph(MarkdownParagraph(text: text, formatting: formatting))
        }
        
        if let headingNode = node as? HeadingNode {
            let text = headingNode.getTextContent()
            let formatting = extractFormatting(from: headingNode)
            if let level = MarkdownBlockType.HeadingLevel.fromLexicalType(headingNode.getTag()) {
                return .heading(MarkdownHeading(level: level, text: text, formatting: formatting))
            }
        }
        
        if let listNode = node as? ListNode {
            let items = listNode.getChildren().compactMap { child -> MarkdownListItem? in
                guard let listItemNode = child as? ListItemNode else { return nil }
                let text = listItemNode.getTextContent()
                let formatting = extractFormatting(from: listItemNode)
                return MarkdownListItem(text: text, formatting: formatting)
            }
            
            let listType: MarkdownList.ListType = listNode.getListType() == .bullet ? 
                .bullet : .ordered(startNumber: listNode.getStart())
            
            return .list(MarkdownList(type: listType, items: items))
        }
        
        if let codeNode = node as? CodeNode {
            let content = codeNode.getTextContent()
            return .codeBlock(MarkdownCodeBlock(content: content))
        }
        
        if let quoteNode = node as? QuoteNode {
            let text = quoteNode.getTextContent()
            let formatting = extractFormatting(from: quoteNode)
            return .quote(MarkdownQuote(text: text, formatting: formatting))
        }
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func addTextContent(_ text: String, to elementNode: ElementNode, withFormatting formatting: [FormattedRange]) throws {
        if formatting.isEmpty {
            // Simple case: no formatting
            let textNode = TextNode()
            try textNode.setText(text)
            try elementNode.append([textNode])
        } else {
            // Complex case: apply formatting ranges
            var lastOffset = 0
            
            for formattedRange in formatting.sorted(by: { $0.range.location < $1.range.location }) {
                // Add unformatted text before this range
                if formattedRange.range.location > lastOffset {
                    let unformattedText = (text as NSString).substring(with: NSRange(
                        location: lastOffset,
                        length: formattedRange.range.location - lastOffset
                    ))
                    let textNode = TextNode()
                    try textNode.setText(unformattedText)
                    try elementNode.append([textNode])
                }
                
                // Add formatted text
                let formattedText = (text as NSString).substring(with: formattedRange.range)
                let textNode = TextNode()
                try textNode.setText(formattedText)
                
                var format = TextFormat()
                if formattedRange.formatting.contains(.bold) { format.bold = true }
                if formattedRange.formatting.contains(.italic) { format.italic = true }
                if formattedRange.formatting.contains(.strikethrough) { format.strikethrough = true }
                if formattedRange.formatting.contains(.code) { format.code = true }
                
                try textNode.setFormat(format: format)
                try elementNode.append([textNode])
                
                lastOffset = formattedRange.range.location + formattedRange.range.length
            }
            
            // Add remaining unformatted text
            if lastOffset < text.count {
                let remainingText = (text as NSString).substring(from: lastOffset)
                let textNode = TextNode()
                try textNode.setText(remainingText)
                try elementNode.append([textNode])
            }
        }
    }
    
    private func extractFormatting(from elementNode: ElementNode) -> [FormattedRange] {
        var formatting: [FormattedRange] = []
        var currentOffset = 0
        
        for child in elementNode.getChildren() {
            if let textNode = child as? TextNode {
                let text = textNode.getTextContent()
                let textLength = text.count
                let format = textNode.getFormat()
                
                var inlineFormatting: InlineFormatting = []
                if format.bold { inlineFormatting.insert(.bold) }
                if format.italic { inlineFormatting.insert(.italic) }
                if format.strikethrough { inlineFormatting.insert(.strikethrough) }
                if format.code { inlineFormatting.insert(.code) }
                
                if !inlineFormatting.isEmpty {
                    formatting.append(FormattedRange(
                        range: NSRange(location: currentOffset, length: textLength),
                        formatting: inlineFormatting
                    ))
                }
                
                currentOffset += textLength
            }
        }
        
        return formatting
    }
}

// MARK: - Extensions for Type Conversion

extension MarkdownList.ListType {
    var lexicalType: ListType {
        switch self {
        case .bullet:
            return .bullet
        case .ordered:
            return .number
        }
    }
    
    var startNumber: Int {
        switch self {
        case .bullet:
            return 1
        case .ordered(let startNumber):
            return startNumber
        }
    }
}

extension MarkdownBlockType.HeadingLevel {
    static func fromLexicalType(_ lexicalType: HeadingTagType) -> MarkdownBlockType.HeadingLevel? {
        switch lexicalType {
        case .h1: return .h1
        case .h2: return .h2
        case .h3: return .h3
        case .h4: return .h4
        case .h5: return .h5
        // case .h6: return .h5  // HeadingTagType doesn't include h6
        }
    }
}

// MARK: - Error Extensions

extension Result where Failure == DomainError {
    func get() throws -> Success {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}