import SwiftUI
import UIKit

// MARK: - SwiftUI Wrapper

/// A SwiftUI Markdown Editor with FluentUI CommandBar
@available(iOS 17.0, *)
public struct MarkdownEditor: View {
    
    // MARK: - Properties
    
    /// Binding to the markdown content
    @Binding private var text: String
    
    /// Configuration for the editor
    public let configuration: MarkdownEditorConfiguration
    
    /// Optional placeholder text
    public let placeholderText: String?
    
    /// Whether scrolling is enabled (default: true)
    public let isScrollEnabled: Bool
    
    /// Optional binding to track editing state
    @Binding private var isEditing: Bool
    
    // MARK: - Initialization
    
    /// Create a new SwiftUI markdown editor
    /// - Parameters:
    ///   - text: Binding to the markdown string
    ///   - configuration: Editor configuration
    ///   - placeholderText: Optional placeholder text
    ///   - isScrollEnabled: Whether scrolling is enabled (default: true)
    ///   - isEditing: Optional binding to track editing state
    public init(
        text: Binding<String>,
        configuration: MarkdownEditorConfiguration = .default,
        placeholderText: String? = nil,
        isScrollEnabled: Bool = true,
        isEditing: Binding<Bool> = .constant(false)
    ) {
        self._text = text
        self.configuration = configuration
        self.placeholderText = placeholderText
        self.isScrollEnabled = isScrollEnabled
        self._isEditing = isEditing
    }
    
    // MARK: - Body
    
    public var body: some View {
        MarkdownEditorRepresentable(
            text: $text,
            configuration: configuration,
            placeholderText: placeholderText,
            isScrollEnabled: isScrollEnabled,
            isEditing: $isEditing
        )
    }
}

// MARK: - UIViewRepresentable Implementation

@available(iOS 17.0, *)
private struct MarkdownEditorRepresentable: UIViewRepresentable {
    @Binding var text: String
    let configuration: MarkdownEditorConfiguration
    let placeholderText: String?
    let isScrollEnabled: Bool
    @Binding var isEditing: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        if isScrollEnabled {
            // Use the wrapper with built-in scroll management
            let editor = MarkdownEditorView(configuration: configuration)
            editor.placeholderText = placeholderText
            editor.delegate = context.coordinator
            
            // Store reference in coordinator
            context.coordinator.editor = editor
            
            // Load initial text (including empty text to trigger title mode)
            let document = MarkdownDocument(content: text)
            _ = editor.loadMarkdown(document)
            
            return editor
        } else {
            // Use content-only view for flexible embedding
            let contentView = MarkdownEditorContentView(configuration: configuration)
            contentView.placeholderText = placeholderText
            contentView.delegate = context.coordinator
            
            // Store reference in coordinator  
            context.coordinator.contentView = contentView
            
            // Load initial text (including empty text to trigger title mode)
            let document = MarkdownDocument(content: text)
            _ = contentView.loadMarkdown(document)
            
            return contentView
        }
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Handle both MarkdownEditorView and MarkdownEditorContentView
        if let editorView = uiView as? MarkdownEditorView {
            // Update placeholder if it changed
            if editorView.placeholderText != placeholderText {
                editorView.placeholderText = placeholderText
            }
            
            // Avoid pushing external text while the editor is actively editing to prevent race conditions
            if context.coordinator.isUpdatingFromEditor { return }
            if editorView.textView.isFirstResponder || isEditing { return }
            
            // Update text if it changed externally
            let result = editorView.exportMarkdown()
            if case .success(let document) = result {
                if document.content != text {
                    let newDocument = MarkdownDocument(content: text)
                    _ = editorView.loadMarkdown(newDocument)
                }
            }
        } else if let contentView = uiView as? MarkdownEditorContentView {
            // Update placeholder if it changed
            if contentView.placeholderText != placeholderText {
                contentView.placeholderText = placeholderText
            }
            
            // Avoid pushing external text while the editor is actively editing to prevent race conditions
            if context.coordinator.isUpdatingFromEditor { return }
            if contentView.textView.isFirstResponder || isEditing { return }
            
            // Update text if it changed externally
            let result = contentView.exportMarkdown()
            if case .success(let document) = result {
                if document.content != text {
                    let newDocument = MarkdownDocument(content: text)
                    _ = contentView.loadMarkdown(newDocument)
                }
            }
        }
    }
    
    class Coordinator: MarkdownEditorDelegate {
        let parent: MarkdownEditorRepresentable
        var editor: MarkdownEditorView?
        var contentView: MarkdownEditorContentView?
        var isUpdatingFromEditor = false
        
        init(_ parent: MarkdownEditorRepresentable) {
            self.parent = parent
        }
        
        func markdownEditorDidChange(_ editor: any MarkdownEditorInterface) {
            // Update the binding when content changes (works for both view types)
            let result = editor.exportMarkdown()
            if case .success(let document) = result {
                isUpdatingFromEditor = true
                parent.text = document.content
                // Reset flag after a brief delay to allow SwiftUI to process the update
                DispatchQueue.main.async { [weak self] in
                    self?.isUpdatingFromEditor = false
                }
            }
        }
        
        func markdownEditor(_ editor: any MarkdownEditorInterface, didChangeEditingState isEditing: Bool) {
            parent.isEditing = isEditing
        }
    }
}

// MARK: - Simple, Clean API

@available(iOS 17.0, *)
public extension MarkdownEditor {
    /// Create a markdown editor with fluent configuration
    init(
        text: Binding<String>,
        placeholderText: String? = nil,
        isScrollEnabled: Bool = true,
        isEditing: Binding<Bool> = .constant(false),
        @ConfigurationBuilder configuration: () -> MarkdownEditorConfiguration
    ) {
        self.init(
            text: text,
            configuration: configuration(),
            placeholderText: placeholderText,
            isScrollEnabled: isScrollEnabled,
            isEditing: isEditing
        )
    }
}

// MARK: - Configuration Builder

@resultBuilder
public struct ConfigurationBuilder {
    public static func buildBlock(_ configuration: MarkdownEditorConfiguration) -> MarkdownEditorConfiguration {
        configuration
    }
}


// MARK: - Usage Examples in Documentation

/*
 Example Usage:
 
 ```swift
 struct ContentView: View {
     @State private var markdownText = "# Hello World"
     
     var body: some View {
         VStack {
             MarkdownEditor(
                 text: $markdownText,
                 configuration: .default
                     .theme(.default)
                     .features(.standard),
                 placeholderText: "Start writing..."
             )
             // For flexible embedding in custom scroll views, use isScrollEnabled: false
             // Example: MarkdownEditor(text: $text, isScrollEnabled: false)
             
         HStack {
             Button("Export") {
                     // `markdownText` is always kept in sync with editor changes.
                 }
             }
         }
     }
 }
 
 // Example with flexible embedding:
 struct ContentViewWithHeader: View {
     @State private var markdownText = "# Hello World"
     
     var body: some View {
         ScrollView {
             VStack {
                 Text("Custom Header")
                     .font(.title)
                     .padding()
                 
                 MarkdownEditor(
                     text: $markdownText,
                     isScrollEnabled: false // Key: disable internal scrolling
                 )
                 
                 Text("Custom Footer")
                     .padding()
             }
         }
     }
 }
 ```
 */
