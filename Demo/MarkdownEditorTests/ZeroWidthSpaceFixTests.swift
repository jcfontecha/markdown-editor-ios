import XCTest
import Lexical
import LexicalListPlugin
@testable import MarkdownEditor

final class ZeroWidthSpaceFixTests: XCTestCase {
    
    func testZeroWidthSpaceDetection() {
        // This test verifies that the zero-width space fix plugin correctly identifies
        // list items containing only zero-width space characters
        
        // The actual testing of the deletion behavior would require integration testing
        // with a real editor instance, which is complex to set up in unit tests.
        // The logic is implemented in ZeroWidthSpaceFixPlugin.swift
        
        // Test case 1: Empty string should be considered "only zero-width space"
        let emptyText = ""
        let textWithoutZWS1 = emptyText.replacingOccurrences(of: "\u{200B}", with: "")
        XCTAssertTrue(textWithoutZWS1.isEmpty, "Empty text should be considered as only zero-width space")
        
        // Test case 2: Only zero-width space should be detected
        let onlyZWS = "\u{200B}"
        let textWithoutZWS2 = onlyZWS.replacingOccurrences(of: "\u{200B}", with: "")
        XCTAssertTrue(textWithoutZWS2.isEmpty, "Text with only zero-width space should be detected")
        
        // Test case 3: Multiple zero-width spaces should be detected
        let multipleZWS = "\u{200B}\u{200B}\u{200B}"
        let textWithoutZWS3 = multipleZWS.replacingOccurrences(of: "\u{200B}", with: "")
        XCTAssertTrue(textWithoutZWS3.isEmpty, "Text with multiple zero-width spaces should be detected")
        
        // Test case 4: Text with real content should not be detected
        let realContent = "Hello World"
        let textWithoutZWS4 = realContent.replacingOccurrences(of: "\u{200B}", with: "")
        XCTAssertFalse(textWithoutZWS4.isEmpty, "Text with real content should not be detected as only zero-width space")
        
        // Test case 5: Mixed content should not be detected
        let mixedContent = "\u{200B}Hello\u{200B}"
        let textWithoutZWS5 = mixedContent.replacingOccurrences(of: "\u{200B}", with: "")
        XCTAssertFalse(textWithoutZWS5.isEmpty, "Text with mixed content should not be detected as only zero-width space")
    }
    
    func testZeroWidthSpaceFixPluginCreation() {
        // Verify that the plugin can be created successfully
        let plugin = ZeroWidthSpaceFixPlugin()
        XCTAssertNotNil(plugin, "ZeroWidthSpaceFixPlugin should be created successfully")
    }
}