/*
 * MarkdownEmptyListToggleTests
 * 
 * Tests for empty list item toggle behavior.
 */

import XCTest
@testable import MarkdownEditor

final class MarkdownEmptyListToggleTests: XCTestCase {
    
    var context: MarkdownCommandContext!
    
    override func setUp() {
        super.setUp()
        context = MarkdownCommandContext(
            documentService: DefaultMarkdownDocumentService(),
            formattingService: DefaultMarkdownFormattingService(),
            stateService: DefaultMarkdownStateService()
        )
    }
    
    func testEmptyListDetection() {
        // Test what constitutes an "empty" list item
        let testCases = [
            ("- ", true, "Dash with space"),
            ("-", false, "Dash without space"),
            ("- Item", false, "List with content"),
            ("1. ", true, "Number with space"),
            ("1.", false, "Number without space"),
            ("1. Item", false, "Numbered with content"),
            ("  - ", true, "Indented empty list"),
            ("* ", true, "Asterisk list marker")
        ]
        
        for (line, shouldBeEmpty, description) in testCases {
            let isEmptyUnordered = line.trimmingCharacters(in: .whitespaces) == "-"
            let isEmptyOrdered = line.range(of: #"^\s*\d+\.\s*$"#, options: .regularExpression) != nil
            let isEmpty = isEmptyUnordered || isEmptyOrdered
            
            XCTAssertEqual(isEmpty, shouldBeEmpty, "Failed for: \(description)")
        }
    }
    
    func testCurrentSetBlockTypeCommand() {
        // Test the current implementation to see what happens
        
        // Given: State with empty unordered list
        let state = MarkdownEditorState(
            content: "- ",
            selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 2)),
            currentBlockType: .unorderedList
        )
        
        // When: Apply same block type
        let command = SetBlockTypeCommand(
            blockType: .unorderedList,
            at: state.selection.start,
            context: context
        )
        
        let result = command.execute(on: state)
        
        // Then: Check what happens
        switch result {
        case .success(let newState):
            print("Current behavior:")
            print("- Old content: '\(state.content)'")
            print("- New content: '\(newState.content)'")
            print("- Old type: \(state.currentBlockType)")
            print("- New type: \(newState.currentBlockType)")
            
            // Current implementation should toggle to paragraph
            XCTAssertEqual(newState.currentBlockType, .paragraph)
        case .failure(let error):
            XCTFail("Command failed: \(error)")
        }
    }
    
    func testEmptyListItemRemoval() {
        // Test that empty list markers are removed when toggling
        
        // Given: Various empty list states
        let testCases: [(String, MarkdownBlockType, String)] = [
            ("- ", .unorderedList, ""),
            ("1. ", .orderedList, ""),
            ("  - ", .unorderedList, "  "), // Preserve indentation
            ("* ", .unorderedList, "")
        ]
        
        for (content, blockType, expectedResult) in testCases {
            let state = MarkdownEditorState(
                content: content,
                selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: content.count)),
                currentBlockType: blockType
            )
            
            let command = SetBlockTypeCommand(
                blockType: blockType,
                at: state.selection.start,
                context: context
            )
            
            let result = command.execute(on: state)
            
            switch result {
            case .success(let newState):
                XCTAssertEqual(newState.content.trimmingCharacters(in: .whitespacesAndNewlines), expectedResult)
                XCTAssertEqual(newState.currentBlockType, .paragraph)
            case .failure(let error):
                XCTFail("Command failed for '\(content)': \(error)")
            }
        }
    }
}