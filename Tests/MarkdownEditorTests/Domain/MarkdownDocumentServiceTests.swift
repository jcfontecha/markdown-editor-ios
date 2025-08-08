/*
 * MarkdownDocumentServiceTests
 * 
 * Unit tests for the document service, focusing on markdown parsing,
 * generation, and document manipulation.
 */

import XCTest
@testable import MarkdownEditor

final class MarkdownDocumentServiceTests: XCTestCase {
    
    var documentService: MarkdownDocumentService!
    
    override func setUp() {
        super.setUp()
        documentService = DefaultMarkdownDocumentService()
    }
    
    // MARK: - Parsing Tests
    
    func testParseEmptyDocument() {
        // Given: Empty content
        let content = ""
        
        // When: Parse
        let parsed = documentService.parseMarkdown(content)
        
        // Then: For empty content, service returns a single empty paragraph block
        XCTAssertEqual(parsed.blocks.count, 1)
        if case .paragraph(let para) = parsed.blocks.first {
            XCTAssertEqual(para.text, "")
        } else {
            XCTFail("Expected paragraph block for empty content")
        }
    }
    
    func testParseSingleParagraph() {
        // Given: Single paragraph
        let content = "This is a paragraph."
        
        // When: Parse
        let parsed = documentService.parseMarkdown(content)
        
        // Then: Should have one paragraph block
        XCTAssertEqual(parsed.blocks.count, 1)
        if case .paragraph(let para) = parsed.blocks.first {
            XCTAssertEqual(para.text, content)
        } else {
            XCTFail("Expected paragraph block")
        }
    }
    
    func testParseHeadings() {
        // Given: Various heading levels
        let content = """
# H1 Title
## H2 Subtitle
### H3 Section
#### H4 Subsection
##### H5 Detail
###### H6 Note
"""
        
        // When: Parse
        let parsed = documentService.parseMarkdown(content)
        
        // Then: Should have 6 heading blocks
        XCTAssertEqual(parsed.blocks.count, 6)
        
        let expectedLevels: [MarkdownBlockType.HeadingLevel] = [.h1, .h2, .h3, .h4, .h5, .h6]
        for (index, expectedLevel) in expectedLevels.enumerated() {
            if case .heading(let heading) = parsed.blocks[index] {
                XCTAssertEqual(heading.level, expectedLevel)
            } else {
                XCTFail("Expected heading at index \(index)")
            }
        }
    }
    
    func testParseUnorderedList() {
        // Given: Unordered list
        let content = """
- First item
- Second item
- Third item
"""
        
        // When: Parse
        let parsed = documentService.parseMarkdown(content)
        
        // Then: Should have one list block with three items
        XCTAssertEqual(parsed.blocks.count, 1)
        if case .list(let list) = parsed.blocks.first {
            XCTAssertEqual(list.type, .bullet)
            XCTAssertEqual(list.items.count, 3)
            XCTAssertEqual(list.items[0].text, "First item")
            XCTAssertEqual(list.items[1].text, "Second item")
            XCTAssertEqual(list.items[2].text, "Third item")
        } else {
            XCTFail("Expected list block")
        }
    }
    
    func testParseOrderedList() {
        // Given: Ordered list
        let content = """
1. First step
2. Second step
3. Third step
"""
        
        // When: Parse
        let parsed = documentService.parseMarkdown(content)
        
        // Then: Should have one ordered list block
        XCTAssertEqual(parsed.blocks.count, 1)
        if case .list(let list) = parsed.blocks.first {
            if case .ordered(let start) = list.type {
                XCTAssertEqual(start, 1)
            } else {
                XCTFail("Expected ordered list")
            }
            XCTAssertEqual(list.items.count, 3)
        } else {
            XCTFail("Expected list block")
        }
    }
    
    func testParseCodeBlock() {
        // Given: Code block
        let content = """
```swift
func hello() {
    print("Hello, world!")
}
```
"""
        
        // When: Parse
        let parsed = documentService.parseMarkdown(content)
        
        // Then: Should have one code block
        XCTAssertEqual(parsed.blocks.count, 1)
        if case .codeBlock(let code) = parsed.blocks.first {
            XCTAssertEqual(code.language, "swift")
            XCTAssertTrue(code.content.contains("func hello()"))
        } else {
            XCTFail("Expected code block")
        }
    }
    
    func testParseQuote() {
        // Given: Quote block
        let content = "> This is a quote\n> With multiple lines"
        
        // When: Parse
        let parsed = documentService.parseMarkdown(content)
        
        // Then: Should have one quote block
        XCTAssertEqual(parsed.blocks.count, 1)
        if case .quote(let quote) = parsed.blocks.first {
            XCTAssertTrue(quote.text.contains("This is a quote"))
            XCTAssertTrue(quote.text.contains("With multiple lines"))
        } else {
            XCTFail("Expected quote block")
        }
    }
    
    func testParseMixedContent() {
        // Given: Mixed markdown content
        let content = """
# Document Title

This is a paragraph with **bold** and *italic* text.

## Section 1

- Item 1
- Item 2

```python
print("Hello")
```

> Quote text
"""
        
        // When: Parse
        let parsed = documentService.parseMarkdown(content)
        
        // Then: Should have correct block sequence
        XCTAssertEqual(parsed.blocks.count, 6)
        XCTAssertEqual(parsed.blocks[0].blockType, .heading(level: .h1))
        XCTAssertEqual(parsed.blocks[1].blockType, .paragraph)
        XCTAssertEqual(parsed.blocks[2].blockType, .heading(level: .h2))
        XCTAssertEqual(parsed.blocks[3].blockType, .unorderedList)
        XCTAssertEqual(parsed.blocks[4].blockType, .codeBlock)
        XCTAssertEqual(parsed.blocks[5].blockType, .quote)
    }
    
    // MARK: - Generation Tests
    
    func testGenerateFromParagraph() {
        // Given: Parsed document with paragraph
        let para = MarkdownParagraph(text: "Hello world")
        let parsed = ParsedMarkdownDocument(blocks: [.paragraph(para)])
        
        // When: Generate markdown
        let markdown = documentService.generateMarkdown(from: parsed)
        
        // Then: Should generate correct markdown
        XCTAssertEqual(markdown.trimmingCharacters(in: .whitespacesAndNewlines), "Hello world")
    }
    
    func testGenerateFromHeading() {
        // Given: Parsed document with headings
        let h1 = MarkdownHeading(level: .h1, text: "Title")
        let h2 = MarkdownHeading(level: .h2, text: "Subtitle")
        let parsed = ParsedMarkdownDocument(blocks: [
            .heading(h1),
            .heading(h2)
        ])
        
        // When: Generate markdown
        let markdown = documentService.generateMarkdown(from: parsed)
        
        // Then: Should have correct heading syntax
        XCTAssertTrue(markdown.contains("# Title"))
        XCTAssertTrue(markdown.contains("## Subtitle"))
    }
    
    func testGenerateFromList() {
        // Given: Parsed document with list
        let items = [
            MarkdownListItem(text: "First"),
            MarkdownListItem(text: "Second")
        ]
        let list = MarkdownList(type: .bullet, items: items)
        let parsed = ParsedMarkdownDocument(blocks: [.list(list)])
        
        // When: Generate markdown
        let markdown = documentService.generateMarkdown(from: parsed)
        
        // Then: Should have bullet points
        XCTAssertTrue(markdown.contains("- First"))
        XCTAssertTrue(markdown.contains("- Second"))
    }
    
    // MARK: - Document Manipulation Tests
    
    func testInsertTextAtBeginning() {
        // Given: Document content
        let content = "Hello world"
        
        // When: Insert text at beginning
        let result = documentService.insertText(
            "Greeting: ",
            at: DocumentPosition(blockIndex: 0, offset: 0),
            in: content
        )
        
        // Then: Should insert correctly
        switch result {
        case .success(let newContent):
            XCTAssertEqual(newContent, "Greeting: Hello world")
        case .failure(let error):
            XCTFail("Insert should succeed: \(error)")
        }
    }
    
    func testInsertTextInMiddle() {
        // Given: Document content
        let content = "Hello world"
        
        // When: Insert text in middle
        let result = documentService.insertText(
            " beautiful",
            at: DocumentPosition(blockIndex: 0, offset: 5),
            in: content
        )
        
        // Then: Should insert correctly
        switch result {
        case .success(let newContent):
            XCTAssertEqual(newContent, "Hello beautiful world")
        case .failure(let error):
            XCTFail("Insert should succeed: \(error)")
        }
    }
    
    func testDeleteTextRange() {
        // Given: Document content
        let content = "Hello beautiful world"
        
        // When: Delete range
        let range = TextRange(
            start: DocumentPosition(blockIndex: 0, offset: 5),
            end: DocumentPosition(blockIndex: 0, offset: 15)
        )
        let result = documentService.deleteText(in: range, from: content)
        
        // Then: Should delete correctly
        switch result {
        case .success(let newContent):
            XCTAssertEqual(newContent, "Hello world")
        case .failure(let error):
            XCTFail("Delete should succeed: \(error)")
        }
    }
    
    // MARK: - Validation Tests
    
    func testValidateValidDocument() {
        // Given: Valid markdown
        let content = "# Title\n\nParagraph text"
        
        // When: Validate
        let validation = documentService.validateDocument(content)
        
        // Then: Should be valid
        XCTAssertTrue(validation.isValid)
        XCTAssertEqual(validation.errors.count, 0)
    }
    
    func testValidatePosition() {
        // Given: Document content
        let content = "Hello\nWorld"
        
        // When: Validate various positions
        let validPosition = DocumentPosition(blockIndex: 0, offset: 3)
        let invalidPosition = DocumentPosition(blockIndex: 5, offset: 0)
        
        // Then: Should validate correctly
        let validResult = documentService.validatePosition(validPosition, in: content)
        let invalidResult = documentService.validatePosition(invalidPosition, in: content)
        
        switch validResult {
        case .success:
            XCTAssertTrue(true)
        case .failure:
            XCTFail("Valid position should pass")
        }
        
        switch invalidResult {
        case .success:
            XCTFail("Invalid position should fail")
        case .failure:
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Statistics Tests
    
    func testDocumentStats() {
        // Given: Document with various content
        let content = """
# Title

This is a paragraph with multiple words.

- List item one
- List item two
"""
        
        // When: Get stats
        let stats = documentService.getDocumentStats(content)
        
        // Then: Should have correct counts
        XCTAssertGreaterThan(stats.characterCount, 0)
        XCTAssertGreaterThan(stats.wordCount, 0)
        XCTAssertEqual(stats.headingCount, 1)
        XCTAssertEqual(stats.paragraphCount, 1)
        XCTAssertEqual(stats.listCount, 1)
    }
    
    // MARK: - Performance Tests
    
    func testParsingPerformance() {
        // Given: Large document
        let content = (0..<100).map { i in
            """
            # Section \(i)
            
            Paragraph \(i) with some text content.
            
            - Item \(i).1
            - Item \(i).2
            """
        }.joined(separator: "\n\n")
        
        // When/Then: Measure parsing
        measure {
            _ = documentService.parseMarkdown(content)
        }
    }
}