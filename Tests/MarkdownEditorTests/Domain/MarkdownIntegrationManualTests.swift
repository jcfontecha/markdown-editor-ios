/*
 * MarkdownIntegrationManualTests
 * 
 * Tests to manually verify that the domain layer is actually working with Lexical.
 */

import XCTest
@testable import MarkdownEditor

final class MarkdownIntegrationManualTests: XCTestCase {
    
    func testSmartListToggleIntegration() {
        // This test simulates what should happen when using the actual editor
        
        // Given: A markdown editor with a list item
        let editor = MarkdownEditorView()
        
        // Load a document with a list
        let document = MarkdownDocument(content: "- List item")
        let loadResult = editor.loadMarkdown(document)
        
        switch loadResult {
        case .success:
            print("✅ Document loaded successfully")
        case .failure(let error):
            XCTFail("Failed to load document: \(error)")
            return
        }
        
        // When: We call setBlockType with the same list type (should toggle to paragraph)
        editor.setBlockType(.unorderedList)
        
        // Then: Check what the current block type is
        let currentBlockType = editor.getCurrentBlockType()
        print("Current block type after toggle: \(currentBlockType)")
        
        // Export to see the content
        let exportResult = editor.exportMarkdown()
        switch exportResult {
        case .success(let exported):
            print("Exported content: '\(exported.content)'")
            
            // If smart toggle worked, it should no longer be a list
            XCTAssertEqual(currentBlockType, .paragraph, "Should toggle to paragraph")
            XCTAssertFalse(exported.content.hasPrefix("-"), "Should not start with list marker")
            
        case .failure(let error):
            XCTFail("Failed to export: \(error)")
        }
    }
    
    func testStartWithTitleIntegration() {
        // Given: Editor with startWithTitle enabled
        let config = MarkdownEditorConfiguration(
            behavior: EditorBehavior(
                autoSave: true,
                autoCorrection: true,
                smartQuotes: true,
                returnKeyBehavior: .smart,
                startWithTitle: true
            )
        )
        let editor = MarkdownEditorView(configuration: config)
        
        // When: Load empty document
        let emptyDocument = MarkdownDocument(content: "")
        let result = editor.loadMarkdown(emptyDocument)
        
        switch result {
        case .success:
            // Then: Should automatically apply title formatting
            let blockType = editor.getCurrentBlockType()
            let exported = editor.exportMarkdown()
            
            print("Block type after loading empty doc: \(blockType)")
            if case .success(let doc) = exported {
                print("Content after startWithTitle: '\(doc.content)'")
            }
            
            XCTAssertEqual(blockType, .heading(level: .h1), "Should start with title")
            
        case .failure(let error):
            XCTFail("Failed to load empty document: \(error)")
        }
    }
    
    func testDomainBridgeConnection() {
        // Test that the domain bridge is actually connected
        let editor = MarkdownEditorView()
        
        // Access the bridge through reflection for testing
        let mirror = Mirror(reflecting: editor)
        let bridge = mirror.children.first { $0.label == "domainBridge" }?.value
        
        XCTAssertNotNil(bridge, "Domain bridge should be connected")
        
        if let domainBridge = bridge as? MarkdownDomainBridge {
            // Test that it can get current state
            let state = domainBridge.getCurrentState()
            print("Initial domain state: \(state)")
            XCTAssertNotNil(state)
        }
    }
}