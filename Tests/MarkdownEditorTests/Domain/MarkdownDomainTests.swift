/*
 * MarkdownDomainTests
 * 
 * Unit tests for the markdown domain layer.
 * These tests are pure Swift with no Lexical dependencies.
 */

import XCTest
@testable import MarkdownEditor

class MarkdownDomainTests: XCTestCase {
    
    // MARK: - Document Position and Range Tests
    
    func testDocumentPositionEquality() {
        let pos1 = DocumentPosition(blockIndex: 0, offset: 5)
        let pos2 = DocumentPosition(blockIndex: 0, offset: 5)
        let pos3 = DocumentPosition(blockIndex: 1, offset: 5)
        
        XCTAssertEqual(pos1, pos2)
        XCTAssertNotEqual(pos1, pos3)
    }
    
    func testTextRangeProperties() {
        let cursorPosition = DocumentPosition(blockIndex: 0, offset: 5)
        let cursorRange = TextRange(at: cursorPosition)
        
        XCTAssertTrue(cursorRange.isCursor)
        XCTAssertFalse(cursorRange.isMultiBlock)
        
        let multiBlockRange = TextRange(
            start: DocumentPosition(blockIndex: 0, offset: 5),
            end: DocumentPosition(blockIndex: 1, offset: 3)
        )
        
        XCTAssertFalse(multiBlockRange.isCursor)
        XCTAssertTrue(multiBlockRange.isMultiBlock)
    }
    
    // MARK: - Editor State Tests
    
    func testEmptyEditorState() {
        let emptyState = MarkdownEditorState.empty
        
        XCTAssertEqual(emptyState.content, "")
        XCTAssertEqual(emptyState.selection, TextRange(at: .start))
        XCTAssertEqual(emptyState.currentFormatting, [])
        XCTAssertEqual(emptyState.currentBlockType, .paragraph)
        XCTAssertFalse(emptyState.hasUnsavedChanges)
    }
    
    func testEditorStateWithParagraph() {
        let text = "Hello, world!"
        let state = MarkdownEditorState.withParagraph(text)
        
        XCTAssertEqual(state.content, text)
        XCTAssertEqual(state.selection.start.blockIndex, 0)
        XCTAssertEqual(state.selection.start.offset, text.count)
        XCTAssertEqual(state.currentBlockType, .paragraph)
    }
    
    func testEditorStateWithHeader() {
        let headerText = "My Header"
        let state = MarkdownEditorState.withHeader(.h1, text: headerText)
        
        XCTAssertEqual(state.content, "# \(headerText)")
        XCTAssertEqual(state.currentBlockType, .heading(level: .h1))
        XCTAssertEqual(state.selection.start.offset, state.content.count)
    }
    
    // MARK: - Document Service Tests
    
    func testDocumentServiceParsing() {
        let service = DefaultMarkdownDocumentService()
        let markdown = """
        # Header 1
        
        This is a paragraph.
        
        ## Header 2
        
        - List item 1
        - List item 2
        
        ```swift
        let code = "example"
        ```
        
        > This is a quote
        """
        
        let document = service.parseMarkdown(markdown)
        
        XCTAssertEqual(document.blocks.count, 6)
        
        // Check header
        guard case .heading(let h1) = document.blocks[0] else {
            XCTFail("Expected heading block")
            return
        }
        XCTAssertEqual(h1.level, .h1)
        XCTAssertEqual(h1.text, "Header 1")
        
        // Check paragraph
        guard case .paragraph(let para) = document.blocks[1] else {
            XCTFail("Expected paragraph block")
            return
        }
        XCTAssertEqual(para.text, "This is a paragraph.")
        
        // Check second header
        guard case .heading(let h2) = document.blocks[2] else {
            XCTFail("Expected heading block")
            return
        }
        XCTAssertEqual(h2.level, .h2)
        XCTAssertEqual(h2.text, "Header 2")
        
        // Check list
        guard case .list(let list) = document.blocks[3] else {
            XCTFail("Expected list block")
            return
        }
        XCTAssertEqual(list.items.count, 2)
        XCTAssertEqual(list.items[0].text, "List item 1")
        XCTAssertEqual(list.items[1].text, "List item 2")
        
        // Check code block
        guard case .codeBlock(let code) = document.blocks[4] else {
            XCTFail("Expected code block")
            return
        }
        XCTAssertEqual(code.language, "swift")
        XCTAssertEqual(code.content, "let code = \"example\"")
        
        // Check quote
        guard case .quote(let quote) = document.blocks[5] else {
            XCTFail("Expected quote block")
            return
        }
        XCTAssertEqual(quote.text, "This is a quote")
    }
    
    func testDocumentServiceGeneration() {
        let service = DefaultMarkdownDocumentService()
        let document = ParsedMarkdownDocument(blocks: [
            .heading(MarkdownHeading(level: .h1, text: "Title")),
            .paragraph(MarkdownParagraph(text: "Content")),
            .list(MarkdownList(type: .bullet, items: [
                MarkdownListItem(text: "Item 1"),
                MarkdownListItem(text: "Item 2")
            ]))
        ])
        
        let markdown = service.generateMarkdown(from: document)
        let expectedMarkdown = """
        # Title

        Content

        - Item 1
        - Item 2
        """
        
        XCTAssertEqual(markdown, expectedMarkdown)
    }
    
    func testDocumentValidation() {
        let service = DefaultMarkdownDocumentService()
        
        // Valid document
        let validMarkdown = "# Title\n\nContent"
        let validResult = service.validateDocument(validMarkdown)
        XCTAssertTrue(validResult.isValid)
        XCTAssertTrue(validResult.errors.isEmpty)
        
        // Document with empty heading (warning)
        let warningMarkdown = "# \n\nContent"
        let warningResult = service.validateDocument(warningMarkdown)
        XCTAssertTrue(warningResult.isValid)
        XCTAssertFalse(warningResult.warnings.isEmpty)
    }
    
    func testTextInsertion() {
        let service = DefaultMarkdownDocumentService()
        let content = "Hello world"
        let position = DocumentPosition(blockIndex: 0, offset: 6)
        
        let result = service.insertText("amazing ", at: position, in: content)
        
        XCTAssertEqual(try result.get(), "Hello amazing world")
    }
    
    func testTextDeletion() {
        let service = DefaultMarkdownDocumentService()
        let content = "Hello amazing world"
        let range = TextRange(
            start: DocumentPosition(blockIndex: 0, offset: 6),
            end: DocumentPosition(blockIndex: 0, offset: 14)
        )
        
        let result = service.deleteText(in: range, from: content)
        
        XCTAssertEqual(try result.get(), "Hello world")
    }
    
    func testBlockReplacement() {
        let service = DefaultMarkdownDocumentService()
        let content = "This is a paragraph"
        
        let result = service.replaceBlock(at: 0, with: .heading(level: .h1), in: content)
        
        XCTAssertEqual(try result.get(), "# This is a paragraph")
    }
    
    // MARK: - Formatting Service Tests
    
    func testFormattingCompatibility() {
        XCTAssertTrue(FormattingRules.areCompatible([.bold], [.italic]))
        XCTAssertFalse(FormattingRules.areCompatible([.code], [.bold]))
        XCTAssertFalse(FormattingRules.areCompatible([.code], [.italic]))
    }
    
    func testFormattingAllowedForBlockType() {
        XCTAssertTrue(FormattingRules.isFormattingAllowed([.bold], for: .paragraph))
        XCTAssertTrue(FormattingRules.isFormattingAllowed([.italic], for: .heading(level: .h1)))
        XCTAssertFalse(FormattingRules.isFormattingAllowed([.bold], for: .codeBlock))
    }
    
    func testFormattingService() {
        let documentService = DefaultMarkdownDocumentService()
        let formattingService = DefaultMarkdownFormattingService(documentService: documentService)
        
        let state = MarkdownEditorState.withParagraph("Hello world")
        let range = TextRange(
            start: DocumentPosition(blockIndex: 0, offset: 0),
            end: DocumentPosition(blockIndex: 0, offset: 5)
        )
        
        // Test that formatting can be applied to paragraph
        XCTAssertTrue(formattingService.canApplyFormatting([.bold], to: range, in: state))
        
        // Test formatting application
        let result = formattingService.applyInlineFormatting([.bold], to: range, in: state)
        
        switch result {
        case .success(let newState):
            XCTAssertTrue(newState.currentFormatting.contains(.bold))
            XCTAssertTrue(newState.hasUnsavedChanges)
        case .failure(let error):
            XCTFail("Formatting failed: \(error)")
        }
    }
    
    func testBlockTypeChange() {
        let documentService = DefaultMarkdownDocumentService()
        let formattingService = DefaultMarkdownFormattingService(documentService: documentService)
        
        let state = MarkdownEditorState.withParagraph("Title")
        let position = DocumentPosition(blockIndex: 0, offset: 0)
        
        // Test block type change
        let result = formattingService.setBlockType(.heading(level: .h1), at: position, in: state)
        
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .heading(level: .h1))
            XCTAssertEqual(newState.content, "# Title")
            XCTAssertTrue(newState.hasUnsavedChanges)
        case .failure(let error):
            XCTFail("Block type change failed: \(error)")
        }
    }
    
    // MARK: - State Service Tests
    
    func testStateServiceValidation() {
        let stateService = DefaultMarkdownStateService()
        
        // Valid state
        let validState = MarkdownEditorState.withParagraph("Hello")
        let validResult = stateService.validateState(validState)
        XCTAssertTrue(validResult.isValid)
        
        // Invalid state with out-of-bounds position
        let invalidState = MarkdownEditorState(
            content: "Hello",
            selection: TextRange(at: DocumentPosition(blockIndex: 5, offset: 0))
        )
        let invalidResult = stateService.validateState(invalidState)
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertFalse(invalidResult.errors.isEmpty)
    }
    
    func testStateCreation() {
        let stateService = DefaultMarkdownStateService()
        let content = "# Header\n\nParagraph"
        let position = DocumentPosition(blockIndex: 1, offset: 5)
        
        let result = stateService.createState(from: content, cursorAt: position)
        
        switch result {
        case .success(let state):
            XCTAssertEqual(state.content, content)
            XCTAssertEqual(state.selection.start, position)
            XCTAssertFalse(state.hasUnsavedChanges)
        case .failure(let error):
            XCTFail("State creation failed: \(error)")
        }
    }
    
    func testSelectionUpdate() {
        let stateService = DefaultMarkdownStateService()
        let initialState = MarkdownEditorState.withParagraph("Hello world")
        let newSelection = TextRange(
            start: DocumentPosition(blockIndex: 0, offset: 6),
            end: DocumentPosition(blockIndex: 0, offset: 11)
        )
        
        let result = stateService.updateSelection(to: newSelection, in: initialState)
        
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.selection, newSelection)
            XCTAssertEqual(newState.content, initialState.content)
        case .failure(let error):
            XCTFail("Selection update failed: \(error)")
        }
    }
    
    func testStateEquivalence() {
        let stateService = DefaultMarkdownStateService()
        
        let state1 = MarkdownEditorState.withParagraph("Hello")
        let state2 = MarkdownEditorState(
            content: "Hello",
            selection: state1.selection,
            currentFormatting: state1.currentFormatting,
            currentBlockType: state1.currentBlockType,
            hasUnsavedChanges: true, // Different, but should be ignored
            metadata: DocumentMetadata(createdAt: Date(), modifiedAt: Date(), version: "2.0") // Different, but should be ignored
        )
        
        XCTAssertTrue(stateService.areStatesEquivalent(state1, state2))
    }
    
    func testStateDiff() {
        let stateService = DefaultMarkdownStateService()
        
        let oldState = MarkdownEditorState.withParagraph("Hello")
        let newState = MarkdownEditorState.withParagraph("Hello world")
        
        let diff = stateService.createDiff(from: oldState, to: newState)
        
        XCTAssertTrue(diff.isSignificant)
        XCTAssertFalse(diff.contentChanges.isEmpty)
    }
    
    // MARK: - Inline Formatting Extensions Tests
    
    func testInlineFormattingDescription() {
        let boldItalic: InlineFormatting = [.bold, .italic]
        XCTAssertTrue(boldItalic.description.contains("bold"))
        XCTAssertTrue(boldItalic.description.contains("italic"))
        
        let empty: InlineFormatting = []
        XCTAssertEqual(empty.description, "none")
    }
    
    func testMarkdownSyntax() {
        XCTAssertEqual(InlineFormatting([.bold]).markdownSyntax.prefix, "**")
        XCTAssertEqual(InlineFormatting([.bold]).markdownSyntax.suffix, "**")
        
        XCTAssertEqual(InlineFormatting([.italic]).markdownSyntax.prefix, "*")
        XCTAssertEqual(InlineFormatting([.italic]).markdownSyntax.suffix, "*")
        
        XCTAssertEqual(InlineFormatting([.code]).markdownSyntax.prefix, "`")
        XCTAssertEqual(InlineFormatting([.code]).markdownSyntax.suffix, "`")
    }
    
    func testBlockTypeMarkdownPrefix() {
        XCTAssertEqual(MarkdownBlockType.paragraph.markdownPrefix, "")
        XCTAssertEqual(MarkdownBlockType.heading(level: .h1).markdownPrefix, "# ")
        XCTAssertEqual(MarkdownBlockType.heading(level: .h2).markdownPrefix, "## ")
        XCTAssertEqual(MarkdownBlockType.unorderedList.markdownPrefix, "- ")
        XCTAssertEqual(MarkdownBlockType.orderedList.markdownPrefix, "1. ")
        XCTAssertEqual(MarkdownBlockType.quote.markdownPrefix, "> ")
    }
}