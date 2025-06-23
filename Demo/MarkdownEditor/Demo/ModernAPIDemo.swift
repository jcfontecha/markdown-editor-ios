import SwiftUI
import MarkdownEditor

// MARK: - Modern API Demo

struct ModernAPIDemo: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Manual Export Pattern Demo
                ManualExportDemo()
                    .tabItem {
                        Image(systemName: "hand.point.up")
                        Text("Manual")
                    }
                    .tag(0)
                
                // Binding Pattern Demo
                BindingDemo()
                    .tabItem {
                        Image(systemName: "link")
                        Text("Binding")
                    }
                    .tag(1)
            }
            .navigationTitle("Modern API Demo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Manual Export Demo

struct ManualExportDemo: View {
    @State private var controller = MarkdownEditorController()
    @State private var exportedMarkdown = ""
    @State private var showingExport = false
    
    var body: some View {
        VStack(spacing: 0) {
                // Editor
                SwiftUIMarkdownEditor(
                    controller: controller,
                    configuration: .default
                        .theme(.default)
                        .features(.standard),
                    placeholderText: "Start writing your markdown..."
                )
                
                // Formatting Toolbar
                FormattingToolbarView(controller: controller)
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .shadow(radius: 1)
                
                // Status Bar
                StatusBarView(controller: controller) {
                    Task {
                        do {
                            exportedMarkdown = try await controller.exportMarkdown()
                            showingExport = true
                        } catch {
                            print("Export failed: \(error)")
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
            }
            .navigationTitle("Modern API Demo")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Load sample content
                do {
                    try await controller.load(markdown: sampleMarkdown)
                } catch {
                    print("Failed to load sample: \(error)")
                }
            }
        }
        .sheet(isPresented: $showingExport) {
            ExportView(markdown: exportedMarkdown)
        }
    }


// MARK: - Formatting Toolbar

struct FormattingToolbarView: View {
    @State private var controller: MarkdownEditorController
    
    init(controller: MarkdownEditorController) {
        self._controller = State(initialValue: controller)
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Inline formatting
                Group {
                    FormatButton("Bold", systemImage: "bold") {
                        await controller.bold()
                    }
                    .active(controller.currentFormatting.contains(.bold))
                    
                    FormatButton("Italic", systemImage: "italic") {
                        await controller.italic()
                    }
                    .active(controller.currentFormatting.contains(.italic))
                    
                    FormatButton("Code", systemImage: "chevron.left.forwardslash.chevron.right") {
                        await controller.code()
                    }
                    .active(controller.currentFormatting.contains(.code))
                    
                    FormatButton("Strike", systemImage: "strikethrough") {
                        await controller.strikethrough()
                    }
                    .active(controller.currentFormatting.contains(.strikethrough))
                }
                
                Divider()
                    .frame(height: 24)
                
                // Block types
                Group {
                    FormatButton("H1", systemImage: "textformat.size.larger") {
                        await controller.heading(.h1)
                    }
                    .active(controller.currentBlockType == .heading(level: .h1))
                    
                    FormatButton("H2", systemImage: "textformat.size") {
                        await controller.heading(.h2)
                    }
                    .active(controller.currentBlockType == .heading(level: .h2))
                    
                    FormatButton("Quote", systemImage: "text.quote") {
                        await controller.quote()
                    }
                    .active(controller.currentBlockType == .quote)
                    
                    FormatButton("Code", systemImage: "curlybraces") {
                        await controller.codeBlock()
                    }
                    .active(controller.currentBlockType == .codeBlock)
                    
                    FormatButton("List", systemImage: "list.bullet") {
                        await controller.unorderedList()
                    }
                    .active(controller.currentBlockType == .unorderedList)
                    
                    FormatButton("Numbers", systemImage: "list.number") {
                        await controller.orderedList()
                    }
                    .active(controller.currentBlockType == .orderedList)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Format Button

struct FormatButton: View {
    let title: String
    let systemImage: String
    let action: () async -> Void
    @State private var isActive = false
    
    init(_ title: String, systemImage: String, action: @escaping () async -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
    
    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isActive ? .white : .primary)
                .frame(width: 32, height: 32)
                .background(isActive ? Color.accentColor : Color.clear)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .accessibilityLabel(title)
    }
    
    func active(_ isActive: Bool) -> FormatButton {
        var button = self
        button.isActive = isActive
        return button
    }
}

// MARK: - Status Bar

struct StatusBarView: View {
    @State private var controller: MarkdownEditorController
    let onExport: () -> Void
    
    init(controller: MarkdownEditorController, onExport: @escaping () -> Void) {
        self._controller = State(initialValue: controller)
        self.onExport = onExport
    }
    
    var body: some View {
        HStack {
            // Status indicators
            HStack(spacing: 8) {
                if controller.hasChanges {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Saved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Toggle("Editable", isOn: Binding(
                    get: { controller.isEditable },
                    set: { controller.isEditable = $0 }
                ))
                .font(.caption)
                
                Button("Export") {
                    onExport()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
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

// MARK: - Sample Content

private let sampleMarkdown = """
# Welcome to the Modern Markdown Editor

This demo showcases the **new modern API** with the following features:

## Observable State Management
- Real-time formatting updates
- Block type detection
- Change tracking

## Async/Await API
All formatting operations now use modern async patterns:

```swift
// Modern API
await controller.bold()
await controller.heading(.h1)
let markdown = try await controller.exportMarkdown()
```

## Fluent Configuration
Configure your editor with a fluent API:

```swift
SwiftUIMarkdownEditor(
    controller: controller,
    configuration: .default
        .theme(.modern)
        .features(.standard)
        .behavior(.default)
)
```

> Try editing this content and watch the toolbar update in real-time!

### Features
- [x] Observable formatting state
- [x] Async formatting operations  
- [x] SwiftUI integration
- [x] Type-safe configuration
- [x] Performance optimized

*Happy editing!* 🎉
"""

private let bindingSampleMarkdown = """
# Binding API Demo

This demonstrates the **convenience binding API** that automatically syncs with a `@State` variable.

## How it works
- Updates the binding when you type
- Respects export timing settings
- Handles external updates

Try changing the export timing and watch how it affects the sync behavior below!

> **Performance Note**: The manual export pattern is more efficient for complex documents.
"""

// MARK: - Binding Demo

struct BindingDemo: View {
    @State private var markdownText = bindingSampleMarkdown
    @State private var exportTiming: ExportTiming = .debounced(1.0)
    
    var body: some View {
        VStack(spacing: 0) {
            // Editor with binding
            BindingMarkdownEditor(
                $markdownText,
                exportTiming: exportTiming,
                configuration: .default
                    .theme(.default)
                    .features(.standard),
                placeholderText: "Type here and watch the binding update..."
            )
            
            // Controls
            VStack(spacing: 16) {
                // Export timing picker
                Picker("Export Timing", selection: $exportTiming) {
                    Text("Manual").tag(ExportTiming.manual)
                    Text("On Focus Loss").tag(ExportTiming.onFocusLoss)
                    Text("Debounced (1s)").tag(ExportTiming.debounced(1.0))
                    Text("Debounced (3s)").tag(ExportTiming.debounced(3.0))
                }
                .pickerStyle(.segmented)
                
                // Live markdown display
                ScrollView {
                    Text(markdownText)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 120)
                
                // External update test
                Button("Update Externally") {
                    markdownText = "# External Update\nThis was updated from outside the editor at \(Date())."
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}

// MARK: - Export Timing Equatable

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

// MARK: - Preview

#Preview {
    ModernAPIDemo()
}
