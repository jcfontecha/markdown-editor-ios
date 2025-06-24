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
                    Button("Test OnAppear") {
                        showingOnAppearTest = true
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
        .ignoresSafeArea()
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

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    APIDemo()
}
