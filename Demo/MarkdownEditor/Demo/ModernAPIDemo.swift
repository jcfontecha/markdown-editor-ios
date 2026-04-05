import SwiftUI
import MarkdownEditor

// MARK: - Export Timing (Local Copy)

@available(iOS 17.0, *)
public enum ExportTiming {
    case manual
    case onFocusLoss
    case debounced(TimeInterval)
}

// MARK: - API Demo

@available(iOS 17.0, *)
struct APIDemo: View {
    @State private var markdownText = sampleMarkdown
    @State private var showingExport = false
    @State private var showingOnAppearTest = false
    @State private var showingFlexibleDemo = false
    
    var body: some View {
        NavigationView {
            MarkdownEditor(
                text: $markdownText,
                configuration: .default
                    .theme(.default)
                    .features(.standard),
                placeholderText: "Start writing your markdown..."
            )
            .navigationTitle("Markdown Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        showingExport = true
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu("Demo") {
                        Button("Flexible Embedding") {
                            showingFlexibleDemo = true
                        }
                        Button("Test OnAppear") {
                            showingOnAppearTest = true
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingExport) {
            ExportView(markdown: markdownText)
        }
        .sheet(isPresented: $showingOnAppearTest) {
            OnAppearTestView()
        }
        .sheet(isPresented: $showingFlexibleDemo) {
            FlexibleEmbeddingDemo()
        }
    }
}

// MARK: - Flexible Embedding Demo

@available(iOS 17.0, *)
struct FlexibleEmbeddingDemo: View {
    @State private var markdownText = flexibleDemoMarkdown
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Custom header that scrolls with content
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("Document Header")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Author:")
                                .foregroundColor(.secondary)
                            Text("Demo User")
                                .fontWeight(.medium)
                            Spacer()
                            Text("Last modified:")
                                .foregroundColor(.secondary)
                            Text("Today")
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                        
                        Divider()
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .background(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Markdown editor with flexible embedding
                    MarkdownEditor(
                        text: $markdownText,
                        configuration: .default
                            .theme(.default)
                            .features(.standard),
                        placeholderText: "Start writing your document...",
                        isScrollEnabled: false // Key: disable internal scrolling
                    )
                    .fixedSize(horizontal: false, vertical: true) // Use intrinsic height
                    .padding(.horizontal, 16)
                    
                    // Custom footer that scrolls with content
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.top, 24)
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                            Text("This document header and footer scroll together with the markdown content")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Word count: \(wordCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Characters: \(markdownText.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Flexible Embedding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var wordCount: Int {
        markdownText.split(whereSeparator: \.isWhitespace).count
    }
}

// MARK: - Export View

struct ExportView: View {
    let markdown: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(markdown)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Exported Markdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Extension Support

extension ExportTiming: Equatable {
    public static func == (lhs: ExportTiming, rhs: ExportTiming) -> Bool {
        switch (lhs, rhs) {
        case (.manual, .manual), (.onFocusLoss, .onFocusLoss):
            return true
        case (.debounced(let delay1), .debounced(let delay2)):
            return delay1 == delay2
        default:
            return false
        }
    }
}

extension ExportTiming: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .manual:
            hasher.combine(0)
        case .onFocusLoss:
            hasher.combine(1)
        case .debounced(let delay):
            hasher.combine(2)
            hasher.combine(delay)
        }
    }
}

// MARK: - Sample Content

private let sampleMarkdown = """
# Welcome to the Markdown Editor

This demo showcases the **MarkdownEditor** with the following features:

## Observable State Management
- Real-time formatting updates
- Block type detection
- Change tracking

## Async/Await API
Easy to use with simple binding patterns:

```swift
// Simple binding API
@State private var markdownText = "# Hello World"
MarkdownEditor(text: $markdownText)
```

## Fluent Configuration
Configure your editor with a fluent API:

```swift
MarkdownEditor(
    text: $markdownText,
    configuration: .default
        .theme(.default)
        .features(.standard)
)
```

> Try editing this content and watch the toolbar update in real-time!

### Features
- [x] SwiftUI binding integration
- [x] FluentUI CommandBar  
- [x] Real-time markdown editing
- [x] Type-safe configuration
- [x] Performance optimized

*Happy editing!* 🎉
"""

private let flexibleDemoMarkdown = """
# Flexible Embedding Demo

This demonstrates how to embed the **MarkdownEditor** within custom scroll views alongside other content.

## Key Features

- **Header scrolls with content**: The document header above moves naturally with the text
- **Footer scrolls with content**: Statistics and info below stay connected
- **Unified scrolling experience**: Everything feels like one cohesive document
- **No scroll conflicts**: The editor doesn't fight with the parent scroll view

## How It Works

The magic happens with `isScrollEnabled: false`:

```swift
MarkdownEditor(
    text: $markdownText,
    isScrollEnabled: false // Disable internal scrolling
)
```

This allows the parent `ScrollView` to handle all scrolling, creating a seamless experience.

## Use Cases

Perfect for:
- Document editors with metadata headers
- Note-taking apps with custom UI elements
- Forms that include rich text editing
- Any app needing flexible layout control

Try typing more content and notice how the header and footer scroll naturally with your text! ✨
"""

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    APIDemo()
}
