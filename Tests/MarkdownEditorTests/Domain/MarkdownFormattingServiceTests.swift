/*
 * MarkdownFormattingServiceTests
 * 
 * Unit tests for the formatting service, focusing on inline formatting
 * and block type operations.
 */

import XCTest
@testable import MarkdownEditor

final class MarkdownFormattingServiceTests: XCTestCase {
    
    var formattingService: MarkdownFormattingService!
    
    override func setUp() {
        super.setUp()
        formattingService = DefaultMarkdownFormattingService()
    }
    
    // MARK: - Inline Formatting Tests
    
    func testApplyBoldFormatting() {
        // Given: Plain text state
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 0),
                end: DocumentPosition(blockIndex: 0, offset: 5)
            )
        )
        
        // When: Apply bold
        let result = formattingService.applyInlineFormatting(
            .bold,
            to: state.selection,
            in: state,
            operation: .apply
        )
        
        // Then: Should succeed with bold markers
        switch result {
        case .success(let newState):
            XCTAssertTrue(newState.content.contains("**"))
            XCTAssertTrue(newState.currentFormatting.contains(.bold))
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }
    
    func testApplyItalicFormatting() {
        // Given: Plain text state
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 6),
                end: DocumentPosition(blockIndex: 0, offset: 11)
            )
        )
        
        // When: Apply italic
        let result = formattingService.applyInlineFormatting(
            .italic,
            to: state.selection,
            in: state,
            operation: .apply
        )
        
        // Then: Should succeed with italic markers
        switch result {
        case .success(let newState):
            XCTAssertTrue(newState.content.contains("*") || newState.content.contains("_"))
            XCTAssertTrue(newState.currentFormatting.contains(.italic))
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }
    
    func testToggleFormatting() {
        // Given: State with bold text
        let state = MarkdownEditorState(
            content: "**Hello** world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 2),
                end: DocumentPosition(blockIndex: 0, offset: 7)
            ),
            currentFormatting: [.bold]
        )
        
        // When: Toggle bold (should remove)
        let result = formattingService.applyInlineFormatting(
            .bold,
            to: state.selection,
            in: state,
            operation: .toggle
        )
        
        // Then: Should remove bold
        switch result {
        case .success(let newState):
            XCTAssertFalse(newState.currentFormatting.contains(.bold))
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }
    
    func testMultipleFormattingCombination() {
        // Given: Plain text
        var state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 0),
                end: DocumentPosition(blockIndex: 0, offset: 5)
            )
        )
        
        // When: Apply bold then italic
        let formats: [InlineFormatting] = [.bold, .italic]
        
        for format in formats {
            let result = formattingService.applyInlineFormatting(
                format,
                to: state.selection,
                in: state,
                operation: .apply
            )
            
            if case .success(let newState) = result {
                state = newState
            }
        }
        
        // Then: Should have both formats
        XCTAssertTrue(state.currentFormatting.contains(.bold))
        XCTAssertTrue(state.currentFormatting.contains(.italic))
    }
    
    // MARK: - Block Type Tests
    
    func testSetHeadingBlockType() {
        // Given: Paragraph state
        let state = MarkdownEditorState(
            content: "This is a title",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .paragraph
        )
        
        // When: Convert to H1
        let result = formattingService.setBlockType(
            .heading(level: .h1),
            at: state.selection.start,
            in: state
        )
        
        // Then: Should add heading marker
        switch result {
        case .success(let newState):
            XCTAssertTrue(newState.content.hasPrefix("# "))
            XCTAssertEqual(newState.currentBlockType, .heading(level: .h1))
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }
    
    func testConvertHeadingToParagraph() {
        // Given: Heading state
        let state = MarkdownEditorState(
            content: "## Subtitle",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .heading(level: .h2)
        )
        
        // When: Convert to paragraph
        let result = formattingService.setBlockType(
            .paragraph,
            at: state.selection.start,
            in: state
        )
        
        // Then: Should remove heading marker
        switch result {
        case .success(let newState):
            XCTAssertFalse(newState.content.hasPrefix("#"))
            XCTAssertEqual(newState.currentBlockType, .paragraph)
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }
    
    func testCreateUnorderedList() {
        // Given: Paragraph state
        let state = MarkdownEditorState(
            content: "First item",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .paragraph
        )
        
        // When: Convert to unordered list
        let result = formattingService.setBlockType(
            .unorderedList,
            at: state.selection.start,
            in: state
        )
        
        // Then: Should add list marker
        switch result {
        case .success(let newState):
            XCTAssertTrue(newState.content.hasPrefix("- "))
            XCTAssertEqual(newState.currentBlockType, .unorderedList)
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }
    
    func testCreateOrderedList() {
        // Given: Paragraph state
        let state = MarkdownEditorState(
            content: "Step one",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5)),
            currentBlockType: .paragraph
        )
        
        // When: Convert to ordered list
        let result = formattingService.setBlockType(
            .orderedList,
            at: state.selection.start,
            in: state
        )
        
        // Then: Should add number marker
        switch result {
        case .success(let newState):
            XCTAssertTrue(newState.content.hasPrefix("1. "))
            XCTAssertEqual(newState.currentBlockType, .orderedList)
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }
    
    // MARK: - Validation Tests
    
    func testCanApplyFormattingToSingleBlock() {
        // Given: State with selection in single block
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 0),
                end: DocumentPosition(blockIndex: 0, offset: 5)
            )
        )
        
        // When: Check if formatting can be applied
        let canApply = formattingService.canApplyFormatting(.bold, to: state.selection, in: state)
        
        // Then: Should be allowed
        XCTAssertTrue(canApply)
    }
    
    func testCannotApplyFormattingToMultiBlock() {
        // Given: State with multi-block selection
        let state = MarkdownEditorState(
            content: "Line 1\nLine 2",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 0),
                end: DocumentPosition(blockIndex: 1, offset: 5)
            )
        )
        
        // When: Check if formatting can be applied
        let canApply = formattingService.canApplyFormatting(.bold, to: state.selection, in: state)
        
        // Then: Should not be allowed (multi-block not supported)
        XCTAssertFalse(canApply)
    }
    
    func testCanSetBlockTypeAtValidPosition() {
        // Given: State with content
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5))
        )
        
        // When: Check if block type can be set
        let canSet = formattingService.canSetBlockType(.heading(level: .h1), at: state.selection.start, in: state)
        
        // Then: Should be allowed
        XCTAssertTrue(canSet)
    }
    
    // MARK: - Helper Method Tests
    
    func testGetFormattingAtPosition() {
        // Given: State with formatted text
        let state = MarkdownEditorState(
            content: "**Bold** and *italic*",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 4))
        )
        
        // When: Get formatting at bold position
        let formatting = formattingService.getFormattingAt(position: state.selection.start, in: state)
        
        // Then: Should detect bold
        XCTAssertTrue(formatting.contains(.bold))
    }
    
    func testGetBlockTypeAtPosition() {
        // Given: State with heading
        let state = MarkdownEditorState(
            content: "# Title\n\nParagraph",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 3))
        )
        
        // When: Get block type
        let blockType = formattingService.getBlockTypeAt(position: state.selection.start, in: state)
        
        // Then: Should detect heading
        XCTAssertEqual(blockType, .heading(level: .h1))
    }
    
    func testGetValidFormattingOptions() {
        // Given: State with paragraph
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(
                start: DocumentPosition(blockIndex: 0, offset: 0),
                end: DocumentPosition(blockIndex: 0, offset: 5)
            ),
            currentBlockType: .paragraph
        )
        
        // When: Get valid formatting options
        let options = formattingService.getValidFormattingOptions(for: state.selection, in: state)
        
        // Then: Should include standard formats
        XCTAssertTrue(options.contains(.bold))
        XCTAssertTrue(options.contains(.italic))
        XCTAssertTrue(options.contains(.code))
    }
    
    func testGetValidBlockTypeOptions() {
        // Given: State with content
        let state = MarkdownEditorState(
            content: "Hello world",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 5))
        )
        
        // When: Get valid block type options
        let options = formattingService.getValidBlockTypeOptions(for: state.selection.start, in: state)
        
        // Then: Should include all block types
        XCTAssertTrue(options.contains(.paragraph))
        XCTAssertTrue(options.contains(.heading(level: .h1)))
        XCTAssertTrue(options.contains(.unorderedList))
        XCTAssertTrue(options.contains(.orderedList))
        XCTAssertTrue(options.contains(.quote))
        XCTAssertTrue(options.contains(.codeBlock))
    }
}