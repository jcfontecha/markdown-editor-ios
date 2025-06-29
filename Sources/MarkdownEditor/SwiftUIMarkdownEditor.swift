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
        .frame(minHeight: 200) // Sensible default for ScrollView compatibility
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
    
    func makeUIView(context: Context) -> MarkdownEditorView {
        let editor = MarkdownEditorView(configuration: configuration)
        editor.placeholderText = placeholderText
        editor.delegate = context.coordinator
        
        // Configure scrolling
        editor.textView.isScrollEnabled = isScrollEnabled
        
        // Store reference in coordinator
        context.coordinator.editor = editor
        
        // Load initial text (including empty text to trigger title mode)
        let document = MarkdownDocument(content: text)
        _ = editor.loadMarkdown(document)
        
        return editor
    }
    
    func updateUIView(_ uiView: MarkdownEditorView, context: Context) {
        // Update placeholder if it changed
        if uiView.placeholderText != placeholderText {
            uiView.placeholderText = placeholderText
        }
        
        // Update text if it changed externally
        let result = uiView.exportMarkdown()
        if case .success(let document) = result {
            if document.content != text {
                let newDocument = MarkdownDocument(content: text)
                _ = uiView.loadMarkdown(newDocument)
            }
        }
    }
    
    class Coordinator: MarkdownEditorDelegate {
        let parent: MarkdownEditorRepresentable
        var editor: MarkdownEditorView?
        
        init(_ parent: MarkdownEditorRepresentable) {
            self.parent = parent
        }
        
        func markdownEditorDidChange(_ editor: MarkdownEditorView) {
            // Update the binding when content changes
            let result = editor.exportMarkdown()
            if case .success(let document) = result {
                parent.text = document.content
            }
        }
        
        func markdownEditor(_ editor: MarkdownEditorView, didChangeEditingState isEditing: Bool) {
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
             // Default minHeight is 200 for ScrollView compatibility
             // Override with .frame(minHeight: 300) if needed
             
             HStack {
                 Button("Export") {
                     print(markdownText)
                 }
             }
         }
     }
 }
 ```
 */