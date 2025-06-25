import XCTest
import Lexical
import LexicalListPlugin
import LexicalLinkPlugin
import LexicalMarkdown
@testable import MarkdownEditor

// MARK: - Markdown Node Tree Creation Helpers (Simplified)

/// Simplified utilities for creating specific markdown node tree structures for testing
/// This version focuses on working API patterns from SimpleMarkdownTests
struct MarkdownNodeTreeHelpers {
    
    // MARK: - Document Structure Helpers
    
    /// Creates a document with multiple paragraphs
    static func createMultiParagraphDocument(texts: [String]) -> MarkdownTestState {
        return MarkdownTestState { editor in
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node available")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                // Create paragraphs
                for text in texts {
                    let paragraph = ParagraphNode()
                    if !text.isEmpty {
                        let textNode = TextNode()
                        try textNode.setText(text)
                        try paragraph.append([textNode])
                    }
                    try rootNode.append([paragraph])
                }
            }
        }
    }
    
    /// Creates a document with mixed content types
    static func createMixedContentDocument() -> MarkdownTestState {
        return MarkdownTestState { editor in
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node available")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                // H1 Header
                let h1 = createHeadingNode(headingTag: .h1)
                let h1Text = TextNode()
                try h1Text.setText("Main Title")
                try h1.append([h1Text])
                try rootNode.append([h1])
                
                // Paragraph
                let para1 = ParagraphNode()
                let paraText = TextNode()
                try paraText.setText("This is a paragraph with some content.")
                try para1.append([paraText])
                try rootNode.append([para1])
                
                // H2 Header
                let h2 = createHeadingNode(headingTag: .h2)
                let h2Text = TextNode()
                try h2Text.setText("Subsection")
                try h2.append([h2Text])
                try rootNode.append([h2])
                
                // Unordered List
                let list = ListNode(listType: .bullet, start: 1)
                let item1 = ListItemNode()
                let item1Text = TextNode()
                try item1Text.setText("First item")
                try item1.append([item1Text])
                
                let item2 = ListItemNode()
                let item2Text = TextNode()
                try item2Text.setText("Second item")
                try item2.append([item2Text])
                
                try list.append([item1, item2])
                try rootNode.append([list])
            }
        }
    }
    
    // MARK: - Simple List Helpers
    
    /// Creates a simple unordered list
    static func createUnorderedList(items: [String]) -> MarkdownTestState {
        return MarkdownTestState { editor in
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node available")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let list = ListNode(listType: .bullet, start: 1)
                
                for itemText in items {
                    let listItem = ListItemNode()
                    let textNode = TextNode()
                    try textNode.setText(itemText)
                    try listItem.append([textNode])
                    try list.append([listItem])
                }
                
                try rootNode.append([list])
            }
        }
    }
    
    /// Creates a simple ordered list
    static func createOrderedList(items: [String]) -> MarkdownTestState {
        return MarkdownTestState { editor in
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node available")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let list = ListNode(listType: .number, start: 1)
                
                for itemText in items {
                    let listItem = ListItemNode()
                    let textNode = TextNode()
                    try textNode.setText(itemText)
                    try listItem.append([textNode])
                    try list.append([listItem])
                }
                
                try rootNode.append([list])
            }
        }
    }
}

// MARK: - Extension for Test Case helpers

extension MarkdownTestCase {
    
    /// Creates a paragraph document with the given text
    func paragraphDocument(text: String) -> MarkdownTestState {
        return MarkdownTestState { editor in
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node available")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let paragraph = ParagraphNode()
                let textNode = TextNode()
                try textNode.setText(text)
                try paragraph.append([textNode])
                try rootNode.append([paragraph])
            }
        }
    }
    
    /// Creates a header document with the given level and text
    func headerDocument(_ level: HeadingTagType, text: String) -> MarkdownTestState {
        return MarkdownTestState { editor in
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node available")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                let header = createHeadingNode(headingTag: level)
                let textNode = TextNode()
                try textNode.setText(text)
                try header.append([textNode])
                try rootNode.append([header])
            }
        }
    }
    
    /// Creates an unordered list document with the given items
    func unorderedListDocument(items: [String]) -> MarkdownTestState {
        return MarkdownNodeTreeHelpers.createUnorderedList(items: items)
    }
    
    /// Creates a mixed content document
    var mixedContentDocument: MarkdownTestState {
        return MarkdownNodeTreeHelpers.createMixedContentDocument()
    }
    
    /// Creates a blog post style document
    var blogPostDocument: MarkdownTestState {
        return MarkdownTestState { editor in
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node available")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                // Blog title
                let title = createHeadingNode(headingTag: .h1)
                let titleText = TextNode()
                try titleText.setText("My Blog Post")
                try title.append([titleText])
                try rootNode.append([title])
                
                // Introduction
                let intro = ParagraphNode()
                let introText = TextNode()
                try introText.setText("Welcome to my blog post about markdown editing.")
                try intro.append([introText])
                try rootNode.append([intro])
                
                // Section
                let section = createHeadingNode(headingTag: .h2)
                let sectionText = TextNode()
                try sectionText.setText("Key Features")
                try section.append([sectionText])
                try rootNode.append([section])
                
                // Feature list
                let list = ListNode(listType: .bullet, start: 1)
                let features = ["Real-time editing", "Markdown support", "Native iOS UI"]
                
                for feature in features {
                    let item = ListItemNode()
                    let itemText = TextNode()
                    try itemText.setText(feature)
                    try item.append([itemText])
                    try list.append([item])
                }
                
                try rootNode.append([list])
            }
        }
    }
    
    /// Creates a nested list document for testing complex structures
    var nestedListDocument: MarkdownTestState {
        return MarkdownTestState { editor in
            try editor.update {
                guard let rootNode = getActiveEditorState()?.getRootNode() else {
                    XCTFail("No root node available")
                    return
                }
                
                // Clear existing content
                try rootNode.getChildren().forEach { try $0.remove() }
                
                // Main list
                let mainList = ListNode(listType: .bullet, start: 1)
                
                // First item with sub-list
                let item1 = ListItemNode()
                let item1Text = TextNode()
                try item1Text.setText("Main item 1")
                try item1.append([item1Text])
                
                // Sub-list
                let subList = ListNode(listType: .bullet, start: 1)
                let subItem = ListItemNode()
                let subItemText = TextNode()
                try subItemText.setText("Sub item")
                try subItem.append([subItemText])
                try subList.append([subItem])
                try item1.append([subList])
                
                // Second item
                let item2 = ListItemNode()
                let item2Text = TextNode()
                try item2Text.setText("Main item 2")
                try item2.append([item2Text])
                
                try mainList.append([item1, item2])
                try rootNode.append([mainList])
            }
        }
    }
}