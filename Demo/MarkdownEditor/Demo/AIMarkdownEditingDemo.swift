import SwiftUI
import AIKitElements

struct AIMarkdownEditingDemo: View {
    @StateObject private var bridge: MarkdownEditorAIEditBridge
    @StateObject private var chatStore: AIMarkdownEditingChatStore
    @State private var showingChat = false
    @State private var showingExport = false
    @State private var exportedMarkdown: String = ""

    init() {
        let bridge = MarkdownEditorAIEditBridge()
        _bridge = StateObject(wrappedValue: bridge)
        _chatStore = StateObject(wrappedValue: AIMarkdownEditingChatStore(bridge: bridge))
    }

    var body: some View {
        AIMarkdownEditingDemoControllerRepresentable(bridge: bridge)
            .navigationTitle("AI Editing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("AI") { showingChat = true }
                    Button("Export") {
                        exportedMarkdown = bridge.exportMarkdown() ?? ""
                        showingExport = true
                    }
                }
            }
            .sheet(isPresented: $showingChat) {
                AIMarkdownEditingChatSheet(store: chatStore)
                    .chatSheetDefaults()
            }
            .sheet(isPresented: $showingExport) {
                ExportView(markdown: exportedMarkdown)
            }
    }
}

private struct AIMarkdownEditingDemoControllerRepresentable: UIViewControllerRepresentable {
    let bridge: MarkdownEditorAIEditBridge

    func makeUIViewController(context: Context) -> AIMarkdownEditingDemoViewController {
        AIMarkdownEditingDemoViewController(bridge: bridge)
    }

    func updateUIViewController(_ uiViewController: AIMarkdownEditingDemoViewController, context: Context) {
        // No-op
    }
}

#Preview {
    NavigationView {
        AIMarkdownEditingDemo()
    }
}
