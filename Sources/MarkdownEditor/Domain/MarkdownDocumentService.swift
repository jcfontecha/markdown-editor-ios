/*
 * MarkdownDocumentService
 * 
 * Pure domain service for markdown document operations.
 * All operations are testable without Lexical dependencies.
 */

import Foundation

// MARK: - Document Service Protocol

/// Service for performing domain operations on markdown documents
public protocol MarkdownDocumentService {
    /// Parse markdown text into structured document representation
    func parseMarkdown(_ content: String) -> ParsedMarkdownDocument
    
    /// Generate markdown text from structured document
    func generateMarkdown(from document: ParsedMarkdownDocument) -> String
    
    /// Validate a document and return validation results
    func validateDocument(_ content: String) -> ValidationResult
    
    /// Apply a text insertion to document content
    func insertText(_ text: String, at position: DocumentPosition, in content: String) -> Result<String, DomainError>
    
    /// Apply a text deletion to document content
    func deleteText(in range: TextRange, from content: String) -> Result<String, DomainError>
    
    /// Get the block at a specific position
    func getBlock(at position: DocumentPosition, in content: String) -> MarkdownBlock?
    
    /// Replace a block with a new block type
    func replaceBlock(at blockIndex: Int, with newBlockType: MarkdownBlockType, in content: String) -> Result<String, DomainError>
    
    /// Get document statistics
    func getDocumentStats(_ content: String) -> DocumentStats
    
    /// Validate a position within the document structure
    func validatePosition(_ position: DocumentPosition, in content: String) -> Result<Void, DomainError>
}

// MARK: - Parsed Document Structure

/// Represents a parsed markdown document with structured blocks
public struct ParsedMarkdownDocument: Equatable {
    public let blocks: [MarkdownBlock]
    public let metadata: DocumentMetadata
    
    public init(blocks: [MarkdownBlock], metadata: DocumentMetadata = .default) {
        self.blocks = blocks
        self.metadata = metadata
    }
    
    /// Creates an empty document
    public static let empty = ParsedMarkdownDocument(blocks: [])
    
    /// Creates a document with a single paragraph
    public static func withParagraph(_ text: String) -> ParsedMarkdownDocument {
        return ParsedMarkdownDocument(blocks: [.paragraph(MarkdownParagraph(text: text))])
    }
    
    /// Total character count including markdown syntax
    public var characterCount: Int {
        return blocks.map(\.characterCount).reduce(0, +)
    }
    
    /// Word count across all blocks
    public var wordCount: Int {
        return blocks.map(\.wordCount).reduce(0, +)
    }
}

/// Represents a single block in a markdown document
public enum MarkdownBlock: Equatable {
    case paragraph(MarkdownParagraph)
    case heading(MarkdownHeading)
    case list(MarkdownList)
    case codeBlock(MarkdownCodeBlock)
    case quote(MarkdownQuote)
    
    /// The plain text content of this block
    public var textContent: String {
        switch self {
        case .paragraph(let para): return para.text
        case .heading(let heading): return heading.text
        case .list(let list): return list.items.map(\.text).joined(separator: "\n")
        case .codeBlock(let code): return code.content
        case .quote(let quote): return quote.text
        }
    }
    
    /// Character count including markdown syntax
    public var characterCount: Int {
        switch self {
        case .paragraph(let para): return para.text.count
        case .heading(let heading): return heading.level.rawValue + 1 + heading.text.count // "# " prefix
        case .list(let list): return list.items.map { $0.text.count + 2 }.reduce(0, +) // "- " prefix
        case .codeBlock(let code): return code.content.count + 8 // ``` fences
        case .quote(let quote): return quote.text.count + 2 // "> " prefix
        }
    }
    
    /// Word count in this block
    public var wordCount: Int {
        return textContent.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    /// The block type for this block
    public var blockType: MarkdownBlockType {
        switch self {
        case .paragraph: return .paragraph
        case .heading(let heading): return .heading(level: heading.level)
        case .list(let list): return list.type == .bullet ? .unorderedList : .orderedList
        case .codeBlock: return .codeBlock
        case .quote: return .quote
        }
    }
}

/// Represents a paragraph block
public struct MarkdownParagraph: Equatable {
    public let text: String
    public let formatting: [FormattedRange]
    
    public init(text: String, formatting: [FormattedRange] = []) {
        self.text = text
        self.formatting = formatting
    }
}

/// Represents a heading block
public struct MarkdownHeading: Equatable {
    public let level: MarkdownBlockType.HeadingLevel
    public let text: String
    public let formatting: [FormattedRange]
    
    public init(level: MarkdownBlockType.HeadingLevel, text: String, formatting: [FormattedRange] = []) {
        self.level = level
        self.text = text
        self.formatting = formatting
    }
}

/// Represents a list block
public struct MarkdownList: Equatable {
    public enum ListType: Equatable {
        case bullet
        case ordered(startNumber: Int)
    }
    
    public let type: ListType
    public let items: [MarkdownListItem]
    
    public init(type: ListType, items: [MarkdownListItem]) {
        self.type = type
        self.items = items
    }
}

/// Represents a list item
public struct MarkdownListItem: Equatable {
    public let text: String
    public let formatting: [FormattedRange]
    public let nestedItems: [MarkdownListItem]
    
    public init(text: String, formatting: [FormattedRange] = [], nestedItems: [MarkdownListItem] = []) {
        self.text = text
        self.formatting = formatting
        self.nestedItems = nestedItems
    }
}

/// Represents a code block
public struct MarkdownCodeBlock: Equatable {
    public let language: String?
    public let content: String
    
    public init(language: String? = nil, content: String) {
        self.language = language
        self.content = content
    }
}

/// Represents a quote block
public struct MarkdownQuote: Equatable {
    public let text: String
    public let formatting: [FormattedRange]
    
    public init(text: String, formatting: [FormattedRange] = []) {
        self.text = text
        self.formatting = formatting
    }
}

/// Represents formatted text within a block
public struct FormattedRange: Equatable {
    public let range: NSRange
    public let formatting: InlineFormatting
    
    public init(range: NSRange, formatting: InlineFormatting) {
        self.range = range
        self.formatting = formatting
    }
}

// MARK: - Document Statistics

/// Statistics about a markdown document
public struct DocumentStats: Equatable {
    public let characterCount: Int
    public let wordCount: Int
    public let paragraphCount: Int
    public let headingCount: Int
    public let listCount: Int
    public let codeBlockCount: Int
    public let quoteCount: Int
    
    public init(
        characterCount: Int,
        wordCount: Int,
        paragraphCount: Int,
        headingCount: Int,
        listCount: Int,
        codeBlockCount: Int,
        quoteCount: Int
    ) {
        self.characterCount = characterCount
        self.wordCount = wordCount
        self.paragraphCount = paragraphCount
        self.headingCount = headingCount
        self.listCount = listCount
        self.codeBlockCount = codeBlockCount
        self.quoteCount = quoteCount
    }
}

// MARK: - Default Implementation

/// Default implementation of MarkdownDocumentService
public class DefaultMarkdownDocumentService: MarkdownDocumentService {
    
    public init() {}
    
    public func parseMarkdown(_ content: String) -> ParsedMarkdownDocument {
        let lines = content.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var currentIndex = 0
        
        while currentIndex < lines.count {
            let line = lines[currentIndex]
            
            if line.isEmpty {
                currentIndex += 1
                continue
            }
            
            // Parse heading
            if line.hasPrefix("#") {
                if let heading = parseHeading(line) {
                    blocks.append(.heading(heading))
                }
                currentIndex += 1
                continue
            }
            
            // Parse list item
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                let (listBlock, nextIndex) = parseList(from: lines, startingAt: currentIndex)
                blocks.append(.list(listBlock))
                currentIndex = nextIndex
                continue
            }
            
            // Parse code block
            if line.hasPrefix("```") {
                let (codeBlock, nextIndex) = parseCodeBlock(from: lines, startingAt: currentIndex)
                blocks.append(.codeBlock(codeBlock))
                currentIndex = nextIndex
                continue
            }
            
            // Parse quote
            if line.hasPrefix("> ") {
                let (quote, nextIndex) = parseQuote(from: lines, startingAt: currentIndex)
                blocks.append(.quote(quote))
                currentIndex = nextIndex
                continue
            }
            
            // Default to paragraph
            let (paragraph, nextIndex) = parseParagraph(from: lines, startingAt: currentIndex)
            blocks.append(.paragraph(paragraph))
            currentIndex = nextIndex
        }
        
        // Ensure we always have at least one block (empty paragraph) for empty documents
        if blocks.isEmpty {
            blocks.append(.paragraph(MarkdownParagraph(text: "")))
        }
        
        return ParsedMarkdownDocument(blocks: blocks)
    }
    
    public func generateMarkdown(from document: ParsedMarkdownDocument) -> String {
        return document.blocks.map { block in
            switch block {
            case .paragraph(let para):
                return para.text
            case .heading(let heading):
                return String(repeating: "#", count: heading.level.rawValue) + " " + heading.text
            case .list(let list):
                return list.items.enumerated().map { index, item in
                    switch list.type {
                    case .bullet:
                        return "- " + item.text
                    case .ordered(let startNumber):
                        return "\(startNumber + index). " + item.text
                    }
                }.joined(separator: "\n")
            case .codeBlock(let code):
                let language = code.language ?? ""
                return "```\(language)\n\(code.content)\n```"
            case .quote(let quote):
                return "> " + quote.text
            }
        }.joined(separator: "\n\n")
    }
    
    public func validateDocument(_ content: String) -> ValidationResult {
        let document = parseMarkdown(content)
        var errors: [DomainError] = []
        var warnings: [String] = []
        
        // Basic validation rules
        for (index, block) in document.blocks.enumerated() {
            switch block {
            case .heading(let heading):
                if heading.text.isEmpty {
                    warnings.append("Empty heading at block \(index)")
                }
            case .list(let list):
                if list.items.isEmpty {
                    errors.append(.documentValidationFailed("Empty list at block \(index)"))
                }
            case .codeBlock(let code):
                if code.content.isEmpty {
                    warnings.append("Empty code block at block \(index)")
                }
            default:
                break
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    public func insertText(_ text: String, at position: DocumentPosition, in content: String) -> Result<String, DomainError> {
        guard var lines = rawLines(from: content) else {
            return .failure(.invalidPosition(position))
        }

        guard position.blockIndex >= 0, position.blockIndex < lines.count else {
            return .failure(.invalidPosition(position))
        }

        let line = lines[position.blockIndex]
        guard let insertIndex = index(in: line, offset: position.offset) else {
            return .failure(.invalidPosition(position))
        }

        lines[position.blockIndex] = String(line[..<insertIndex]) + text + String(line[insertIndex...])
        return .success(lines.joined(separator: "\n"))
    }
    
    public func deleteText(in range: TextRange, from content: String) -> Result<String, DomainError> {
        guard var lines = rawLines(from: content) else {
            return .failure(.invalidRange(range))
        }

        guard range.start.blockIndex >= 0,
              range.end.blockIndex >= 0,
              range.start.blockIndex < lines.count,
              range.end.blockIndex < lines.count else {
            return .failure(.invalidRange(range))
        }

        if range.isMultiBlock {
            let startLine = lines[range.start.blockIndex]
            let endLine = lines[range.end.blockIndex]

            guard let startIndex = index(in: startLine, offset: range.start.offset),
                  let endIndex = index(in: endLine, offset: range.end.offset) else {
                return .failure(.invalidRange(range))
            }

            let prefix = String(startLine[..<startIndex])
            let suffix = String(endLine[endIndex...])
            lines[range.start.blockIndex] = prefix + suffix
            lines.removeSubrange((range.start.blockIndex + 1)...range.end.blockIndex)
            return .success(lines.joined(separator: "\n"))
        }

        let line = lines[range.start.blockIndex]
        guard let startIndex = index(in: line, offset: range.start.offset),
              let endIndex = index(in: line, offset: range.end.offset),
              startIndex <= endIndex else {
            return .failure(.invalidRange(range))
        }

        lines[range.start.blockIndex] = String(line[..<startIndex]) + String(line[endIndex...])
        return .success(lines.joined(separator: "\n"))
    }
    
    public func getBlock(at position: DocumentPosition, in content: String) -> MarkdownBlock? {
        if let lines = rawLines(from: content),
           position.blockIndex >= 0,
           position.blockIndex < lines.count {
            return parseLineAsBlock(lines[position.blockIndex])
        }

        let document = parseMarkdown(content)
        guard position.blockIndex < document.blocks.count else { return nil }
        return document.blocks[position.blockIndex]
    }
    
    public func replaceBlock(at blockIndex: Int, with newBlockType: MarkdownBlockType, in content: String) -> Result<String, DomainError> {
        let document = parseMarkdown(content)
        guard blockIndex < document.blocks.count else {
            return .failure(.invalidPosition(DocumentPosition(blockIndex: blockIndex, offset: 0)))
        }
        
        let currentBlock = document.blocks[blockIndex]
        let text = currentBlock.textContent
        
        let newBlock: MarkdownBlock
        switch newBlockType {
        case .paragraph:
            newBlock = .paragraph(MarkdownParagraph(text: text))
        case .heading(let level):
            newBlock = .heading(MarkdownHeading(level: level, text: text))
        case .unorderedList:
            newBlock = .list(MarkdownList(type: .bullet, items: [MarkdownListItem(text: text)]))
        case .orderedList:
            newBlock = .list(MarkdownList(type: .ordered(startNumber: 1), items: [MarkdownListItem(text: text)]))
        case .codeBlock:
            newBlock = .codeBlock(MarkdownCodeBlock(content: text))
        case .quote:
            newBlock = .quote(MarkdownQuote(text: text))
        }
        
        var newBlocks = document.blocks
        newBlocks[blockIndex] = newBlock
        let newDocument = ParsedMarkdownDocument(blocks: newBlocks, metadata: document.metadata)
        
        return .success(generateMarkdown(from: newDocument))
    }
    
    public func getDocumentStats(_ content: String) -> DocumentStats {
        let document = parseMarkdown(content)
        
        let paragraphCount = document.blocks.filter { if case .paragraph = $0 { return true }; return false }.count
        let headingCount = document.blocks.filter { if case .heading = $0 { return true }; return false }.count
        let listCount = document.blocks.filter { if case .list = $0 { return true }; return false }.count
        let codeBlockCount = document.blocks.filter { if case .codeBlock = $0 { return true }; return false }.count
        let quoteCount = document.blocks.filter { if case .quote = $0 { return true }; return false }.count
        
        return DocumentStats(
            characterCount: document.characterCount,
            wordCount: document.wordCount,
            paragraphCount: paragraphCount,
            headingCount: headingCount,
            listCount: listCount,
            codeBlockCount: codeBlockCount,
            quoteCount: quoteCount
        )
    }
    
    public func validatePosition(_ position: DocumentPosition, in content: String) -> Result<Void, DomainError> {
        guard let lines = rawLines(from: content),
              position.blockIndex >= 0,
              position.blockIndex < lines.count else {
            return .failure(.invalidPosition(position))
        }

        guard position.offset >= 0, position.offset <= lines[position.blockIndex].count else {
            return .failure(.invalidPosition(position))
        }

        return .success(())
    }
    
    // MARK: - Private Parsing Helpers
    
    private func parseHeading(_ line: String) -> MarkdownHeading? {
        let pattern = #"^(#{1,6})\s*(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }
        
        guard let levelRange = Range(match.range(at: 1), in: line),
              let textRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let levelString = String(line[levelRange])
        let text = String(line[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let level = MarkdownBlockType.HeadingLevel(rawValue: levelString.count) else { return nil }
        
        return MarkdownHeading(level: level, text: text)
    }
    
    private func parseList(from lines: [String], startingAt index: Int) -> (MarkdownList, Int) {
        var items: [MarkdownListItem] = []
        var currentIndex = index
        var listType: MarkdownList.ListType?

        func stripTaskListMarker(from text: String) -> String {
            if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") || text.hasPrefix("[ ] ") {
                return String(text.dropFirst(4))
            }
            return text
        }
        
        while currentIndex < lines.count {
            let line = lines[currentIndex]
            
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                if listType == nil { listType = .bullet }
                let rawText = String(line.dropFirst(2))
                let text = stripTaskListMarker(from: rawText)
                items.append(MarkdownListItem(text: text))
                currentIndex += 1
            } else if let regex = try? NSRegularExpression(pattern: #"^(\d+)\.\s?(.*)$"#),
                      let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                      let contentRange = Range(match.range(at: 2), in: line) {
                if listType == nil { listType = .ordered(startNumber: 1) }
                let rawText = String(line[contentRange])
                let text = stripTaskListMarker(from: rawText)
                items.append(MarkdownListItem(text: text))
                currentIndex += 1
            } else {
                break
            }
        }
        
        let finalListType = listType ?? .bullet
        return (MarkdownList(type: finalListType, items: items), currentIndex)
    }
    
    private func parseCodeBlock(from lines: [String], startingAt index: Int) -> (MarkdownCodeBlock, Int) {
        let firstLine = lines[index]
        let language = String(firstLine.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        var content: [String] = []
        var currentIndex = index + 1
        
        while currentIndex < lines.count {
            let line = lines[currentIndex]
            if line == "```" {
                currentIndex += 1
                break
            }
            content.append(line)
            currentIndex += 1
        }
        
        return (MarkdownCodeBlock(language: language.isEmpty ? nil : language, content: content.joined(separator: "\n")), currentIndex)
    }
    
    private func parseQuote(from lines: [String], startingAt index: Int) -> (MarkdownQuote, Int) {
        var content: [String] = []
        var currentIndex = index
        
        while currentIndex < lines.count {
            let line = lines[currentIndex]
            if line.hasPrefix("> ") {
                content.append(String(line.dropFirst(2)))
                currentIndex += 1
            } else {
                break
            }
        }
        
        return (MarkdownQuote(text: content.joined(separator: "\n")), currentIndex)
    }
    
    private func parseParagraph(from lines: [String], startingAt index: Int) -> (MarkdownParagraph, Int) {
        var content: [String] = []
        var currentIndex = index
        
        while currentIndex < lines.count {
            let line = lines[currentIndex]
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("- ") || line.hasPrefix("* ") || 
               line.hasPrefix("> ") || line.hasPrefix("```") || line.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                break
            }
            content.append(line)
            currentIndex += 1
        }
        
        return (MarkdownParagraph(text: content.joined(separator: " ")), currentIndex)
    }

    private func rawLines(from content: String) -> [String]? {
        if content.isEmpty {
            return [""]
        }
        return content.components(separatedBy: .newlines)
    }

    private func index(in text: String, offset: Int) -> String.Index? {
        guard offset >= 0, offset <= text.count else { return nil }
        return text.index(text.startIndex, offsetBy: offset)
    }

    private func parseLineAsBlock(_ line: String) -> MarkdownBlock {
        if let heading = parseHeading(line) {
            return .heading(heading)
        }

        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
            let (list, _) = parseList(from: [line], startingAt: 0)
            return .list(list)
        }

        if line.hasPrefix("> ") {
            return .quote(MarkdownQuote(text: String(line.dropFirst(2))))
        }

        if line.hasPrefix("```") {
            return .codeBlock(MarkdownCodeBlock(content: line.replacingOccurrences(of: "```", with: "")))
        }

        return .paragraph(MarkdownParagraph(text: line))
    }
}
