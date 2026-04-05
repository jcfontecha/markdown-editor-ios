import SwiftUI
import MarkdownEditor

@available(iOS 17.0, *)
struct CustomCommandBarDemo: View {
    @State private var markdownText = customCommandBarSampleMarkdown
    @State private var showingExport = false
    @State private var wordCount = 0

    var body: some View {
        MarkdownEditor(
            text: $markdownText,
            configuration: .default
                .commandBar {
                    // Cherry-pick built-in groups
                    CommandBarContent.undoRedoGroup
                    CommandBarContent.formattingGroup
                    CommandBarContent.listsGroup

                    // Custom group with host-defined buttons
                    CommandBarGroup {
                        CommandBarItem.iconButton(
                            systemName: "doc.on.clipboard",
                            label: "Word Count"
                        ) { editor in
                            if case .success(let doc) = editor.exportMarkdown() {
                                wordCount = doc.content
                                    .split(whereSeparator: \.isWhitespace).count
                            }
                        }
                        CommandBarItem.iconButton(
                            systemName: "trash",
                            label: "Clear"
                        ) { editor in
                            _ = editor.loadMarkdown(MarkdownDocument(content: ""))
                        }
                    }
                },
            placeholderText: "Start writing..."
        )
        .overlay(alignment: .topTrailing) {
            if wordCount > 0 {
                Text("\(wordCount) words")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding()
                    .transition(.opacity)
                    .onTapGesture { wordCount = 0 }
            }
        }
        .animation(.default, value: wordCount)
        .ignoresSafeArea()
        .navigationTitle("Custom Command Bar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private let customCommandBarSampleMarkdown = """
# Custom Command Bar Demo

This editor uses a **customized command bar** with:

- Built-in formatting groups (undo/redo, bold/italic/strikethrough, lists)
- No heading buttons (removed from defaults)
- A custom **Word Count** button
- A custom **Clear** button

Try tapping the custom buttons in the toolbar!
"""

@available(iOS 17.0, *)
#Preview {
    NavigationView {
        CustomCommandBarDemo()
    }
}
