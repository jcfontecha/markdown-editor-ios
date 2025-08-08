import Foundation
import Lexical
import LexicalListPlugin

// MARK: - Markdown Import

struct MarkdownImporter {
    
    static func importMarkdown(_ markdown: String, into editor: Editor) throws {
        try editor.update {
            guard let root = getRoot() else {
                throw LexicalError.invariantViolation("Could not get root node")
            }
            
            // Clear existing content
            let children = root.getChildren()
            for child in children {
                try child.remove()
            }
            let lines = markdown.components(separatedBy: .newlines)
            var currentIndex = 0
            
            while currentIndex < lines.count {
                let line = lines[currentIndex].trimmingCharacters(in: .whitespaces)
                
                if line.isEmpty {
                    // Skip empty lines, they create natural spacing
                    currentIndex += 1
                    continue
                }
                
                // Parse different markdown elements
                if let node = parseHeading(line) {
                    try root.append([node])
                } else if let (listNode, consumedLines) = parseList(lines: lines, startIndex: currentIndex) {
                    try root.append([listNode])
                    currentIndex += consumedLines - 1
                } else if let node = parseQuote(line) {
                    try root.append([node])
                } else if let (codeNode, consumedLines) = parseCodeBlock(lines: lines, startIndex: currentIndex) {
                    try root.append([codeNode])
                    currentIndex += consumedLines - 1
                } else {
                    // Regular paragraph
                    let paragraph = createParagraphNode()
                    let textNodes = parseInlineFormatting(line)
                    try paragraph.append(textNodes)
                    try root.append([paragraph])
                }
                
                currentIndex += 1
            }
            
            // Ensure at least one paragraph exists for empty documents
            if root.getChildren().isEmpty {
                let paragraph = createParagraphNode()
                try root.append([paragraph])
            }
        }
    }
    
    // MARK: - Block Parsing
    
    private static func parseHeading(_ line: String) -> HeadingNode? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if trimmed.hasPrefix("# ") {
            let text = String(trimmed.dropFirst(2))
            let heading = createHeadingNode(headingTag: .h1)
            let textNode = createTextNode(text: text)
            try? heading.append([textNode])
            return heading
        } else if trimmed.hasPrefix("## ") {
            let text = String(trimmed.dropFirst(3))
            let heading = createHeadingNode(headingTag: .h2)
            let textNode = createTextNode(text: text)
            try? heading.append([textNode])
            return heading
        } else if trimmed.hasPrefix("### ") {
            let text = String(trimmed.dropFirst(4))
            let heading = createHeadingNode(headingTag: .h3)
            let textNode = createTextNode(text: text)
            try? heading.append([textNode])
            return heading
        } else if trimmed.hasPrefix("#### ") {
            let text = String(trimmed.dropFirst(5))
            let heading = createHeadingNode(headingTag: .h4)
            let textNode = createTextNode(text: text)
            try? heading.append([textNode])
            return heading
        } else if trimmed.hasPrefix("##### ") {
            let text = String(trimmed.dropFirst(6))
            let heading = createHeadingNode(headingTag: .h5)
            let textNode = createTextNode(text: text)
            try? heading.append([textNode])
            return heading
        } else if trimmed.hasPrefix("###### ") {
            // Map h6 to h5 since HeadingTagType goes to h5
            let text = String(trimmed.dropFirst(7))
            let heading = createHeadingNode(headingTag: .h5)
            let textNode = createTextNode(text: text)
            try? heading.append([textNode])
            return heading
        }
        
        return nil
    }
    
    private static func parseList(lines: [String], startIndex: Int) -> (ListNode, Int)? {
        guard startIndex < lines.count else { return nil }
        
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let isUnordered = firstLine.hasPrefix("- ") || firstLine.hasPrefix("* ") || firstLine.hasPrefix("+ ")
        let isOrdered = firstLine.range(of: "^\\d+\\. ", options: .regularExpression) != nil
        
        guard isUnordered || isOrdered else { return nil }
        
        let listType: ListType = isUnordered ? .bullet : .number
        let list = ListNode(listType: listType, start: 1)
        
        var currentIndex = startIndex
        var consumedLines = 0
        
        while currentIndex < lines.count {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespaces)
            
            if line.isEmpty {
                currentIndex += 1
                consumedLines += 1
                continue
            }
            
            let isCurrentUnordered = line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
            let isCurrentOrdered = line.range(of: "^\\d+\\. ", options: .regularExpression) != nil
            
            if (isUnordered && isCurrentUnordered) || (isOrdered && isCurrentOrdered) {
                let listItem = ListItemNode()
                
                let text: String
                if isCurrentUnordered {
                    text = String(line.dropFirst(2))
                } else {
                    // Remove number and period
                    if let range = line.range(of: "^\\d+\\. ", options: .regularExpression) {
                        text = String(line[range.upperBound...])
                    } else {
                        text = line
                    }
                }
                
                let textNodes = parseInlineFormatting(text)
                try? listItem.append(textNodes)
                try? list.append([listItem])
                
                currentIndex += 1
                consumedLines += 1
            } else {
                break
            }
        }
        
        return consumedLines > 0 ? (list, consumedLines) : nil
    }
    
    private static func parseQuote(_ line: String) -> QuoteNode? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if trimmed.hasPrefix("> ") {
            let text = String(trimmed.dropFirst(2))
            let quote = createQuoteNode()
            let textNodes = parseInlineFormatting(text)
            try? quote.append(textNodes)
            return quote
        }
        
        return nil
    }
    
    private static func parseCodeBlock(lines: [String], startIndex: Int) -> (CodeNode, Int)? {
        guard startIndex < lines.count else { return nil }
        
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        guard firstLine.hasPrefix("```") else { return nil }
        
        var codeContent: [String] = []
        var currentIndex = startIndex + 1
        var foundClosing = false
        
        while currentIndex < lines.count {
            let line = lines[currentIndex]
            if line.trimmingCharacters(in: .whitespaces) == "```" {
                foundClosing = true
                break
            }
            codeContent.append(line)
            currentIndex += 1
        }
        
        if foundClosing {
            let code = createCodeNode()
            let codeText = codeContent.joined(separator: "\n")
            let textNode = createTextNode(text: codeText)
            try? code.append([textNode])
            return (code, currentIndex - startIndex + 1)
        }
        
        return nil
    }
    
    // MARK: - Inline Formatting
    
    private static func parseInlineFormatting(_ text: String) -> [Node] {
        var nodes: [Node] = []
        let currentText = text
        
        // Simple regex-based parsing for inline formatting
        // This is a basic implementation - could be enhanced with proper markdown parsing
        
        let patterns: [(NSRegularExpression, TextFormatType)] = [
            (try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*"), .bold),
            (try! NSRegularExpression(pattern: "\\*(.+?)\\*"), .italic),
            (try! NSRegularExpression(pattern: "~~(.+?)~~"), .strikethrough),
            (try! NSRegularExpression(pattern: "`(.+?)`"), .code)
        ]
        
        var processedRanges: [NSRange] = []
        var formatRanges: [(NSRange, TextFormatType, String)] = []
        
        // Find all formatting ranges
        for (regex, format) in patterns {
            let matches = regex.matches(in: currentText, range: NSRange(currentText.startIndex..., in: currentText))
            for match in matches {
                let fullRange = match.range
                let contentRange = match.range(at: 1)
                
                // Check if this range overlaps with already processed ranges
                let overlaps = processedRanges.contains { existing in
                    NSIntersectionRange(existing, fullRange).length > 0
                }
                
                if !overlaps {
                    processedRanges.append(fullRange)
                    let content = String(currentText[Range(contentRange, in: currentText)!])
                    formatRanges.append((fullRange, format, content))
                }
            }
        }
        
        // Sort by position
        formatRanges.sort { $0.0.location < $1.0.location }
        
        var lastIndex = 0
        
        for (range, format, content) in formatRanges {
            // Add text before this formatting
            if range.location > lastIndex {
                let beforeRange = NSRange(location: lastIndex, length: range.location - lastIndex)
                let beforeText = String(currentText[Range(beforeRange, in: currentText)!])
                if !beforeText.isEmpty {
                    nodes.append(createTextNode(text: beforeText))
                }
            }
            
            // Add formatted text
            let formattedNode = createTextNode(text: content)
            var textFormat = TextFormat()
            
            switch format {
            case .bold:
                textFormat.bold = true
            case .italic:
                textFormat.italic = true
            case .strikethrough:
                textFormat.strikethrough = true
            case .code:
                textFormat.code = true
            default:
                break
            }
            
            _ = try? formattedNode.setFormat(format: textFormat)
            nodes.append(formattedNode)
            
            lastIndex = range.location + range.length
        }
        
        // Add remaining text
        if lastIndex < currentText.count {
            let remainingRange = NSRange(location: lastIndex, length: currentText.count - lastIndex)
            let remainingText = String(currentText[Range(remainingRange, in: currentText)!])
            if !remainingText.isEmpty {
                nodes.append(createTextNode(text: remainingText))
            }
        }
        
        // If no formatting was found, just return the plain text
        if nodes.isEmpty {
            nodes.append(createTextNode(text: text))
        }
        
        return nodes
    }
}