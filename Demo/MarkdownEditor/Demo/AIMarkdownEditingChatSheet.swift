import SwiftUI
import Combine
import AIKit
import AIKitElements
import AIKitMacro
import AIKitOpenRouter

@AIModel
private struct GetMarkdownInput: Codable, Sendable {
    @Field("Unused. Leave null.", maxLength: 1)
    var ignored: String?
}

@AIModel
private struct ReplaceMarkdownBlockInput: Codable, Sendable {
    @Field("Exact text to find in the current Markdown document (verbatim substring).", minLength: 1, maxLength: 8000)
    var findText: String

    @Field("Optional text immediately before `findText`, used to disambiguate matches.", maxLength: 2000)
    var beforeContext: String?

    @Field("Optional text immediately after `findText`, used to disambiguate matches.", maxLength: 2000)
    var afterContext: String?

    @Field("Replacement Markdown for the matched block. This field may be streamed progressively.", maxLength: 24000)
    var replaceText: String
}

private struct ReplaceMarkdownBlockOutput: Codable, Sendable {
    var success: Bool
    var error: String?
}

@MainActor
final class AIMarkdownEditingChatStore: ObservableObject {
    struct Snapshot: Sendable, Equatable {
        var status: ChatStatus
        var messages: [ChatMessage]
        var errorDescription: String?
    }

    @Published var snapshot: Snapshot

    private let bridge: MarkdownEditorAIEditBridge
    private let initialMessages: [ChatMessage]

    private var chat: ChatStore?
    private var chatUpdates: AnyCancellable?

    private var configuredKey: String = ""
    private var configuredModelID: String = ""

    init(bridge: MarkdownEditorAIEditBridge, initialMessages: [ChatMessage] = []) {
        self.bridge = bridge
        self.initialMessages = initialMessages
        self.snapshot = .init(status: .ready, messages: initialMessages, errorDescription: nil)
    }

    var messages: [ChatMessage] { snapshot.messages }
    var status: ChatStatus { snapshot.status }
    var errorDescription: String? { snapshot.errorDescription }

    func configureIfPossible(apiKey: String, modelID: String) {
        let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)

        if apiKey.isEmpty || modelID.isEmpty {
            chatUpdates?.cancel()
            chatUpdates = nil
            chat = nil
            configuredKey = ""
            configuredModelID = ""
            snapshot = .init(
                status: .ready,
                messages: initialMessages,
                errorDescription: apiKey.isEmpty ? "Set an OpenRouter API key in Settings to use this demo." : "Set a model ID in Settings."
            )
            return
        }

        guard apiKey != configuredKey || modelID != configuredModelID || chat == nil else {
            return
        }

        configuredKey = apiKey
        configuredModelID = modelID

        chatUpdates?.cancel()
        chatUpdates = nil

        let provider = createOpenRouter(.init(apiKey: apiKey))
        let model = provider.chat(modelID)

        let chat = ChatStore(
            model: model,
            system: .instructions(Self.systemInstructions),
            tools: makeTools(),
            initialMessages: initialMessages
        )

        self.chat = chat
        snapshot = .init(status: chat.status, messages: chat.messages, errorDescription: chat.errorDescription)
        chatUpdates = chat.objectWillChange.sink { [weak self] _ in
            guard let self, let chat = self.chat else { return }
            self.snapshot = .init(status: chat.status, messages: chat.messages, errorDescription: chat.errorDescription)
        }
    }

    func stop() {
        chat?.stop()
    }

    func send(userText: String) {
        guard let chat else { return }
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        let markdown = bridge.exportMarkdown() ?? ""
        let clippedMarkdown = markdown.count > 12_000 ? String(markdown.prefix(12_000)) + "\n\n<!-- truncated -->" : markdown

        let prompt = """
        Current document:

        ```markdown
        \(clippedMarkdown)
        ```

        Request:
        \(trimmed)
        """

        chat.sendMessage(prompt)
    }

    private func makeTools() -> ToolRegistry {
        var tools = ToolRegistry()
        let bridge = self.bridge

        let getMarkdown = ToolID<GetMarkdownInput, String>("get_markdown")
        tools.register(
            getMarkdown,
            ToolSpec(
                title: "Get Markdown",
                description: "Return the current Markdown document as a string.",
                inputSchema: GetMarkdownInput.schema,
                execute: { _, _ in
                    let markdown = await bridge.exportMarkdown() ?? ""
                    return .final(markdown)
                }
            )
        )

        let replaceBlock = ToolID<ReplaceMarkdownBlockInput, ReplaceMarkdownBlockOutput>("replace_markdown_block")
        tools.register(
            replaceBlock,
            ToolSpec(
                title: "Replace Markdown Block",
                description: "Find a block containing `findText` (optionally disambiguated by context) and stream replacement text into that block.",
                inputSchema: ReplaceMarkdownBlockInput.schema,
                onInputStart: { context in
                    await bridge.toolInputStarted(toolCallID: context.toolCallID)
                },
                onInputDelta: { delta, context in
                    await bridge.toolInputDelta(toolCallID: context.toolCallID, delta: delta)
                },
                execute: { input, context in
                    let result = await bridge.applyFinalReplacement(
                        toolCallID: context.toolCallID,
                        findText: input.findText,
                        beforeContext: input.beforeContext,
                        afterContext: input.afterContext,
                        replaceText: input.replaceText
                    )
                    if result.success {
                        return .final(.init(success: true, error: nil))
                    } else {
                        return .final(.init(success: false, error: result.error ?? "Unknown error"))
                    }
                }
            )
        )

        return tools
    }

    private static let systemInstructions = """
    You help edit a Markdown document.

    Rules:
    - Prefer calling `replace_markdown_block` to perform edits rather than outputting the entire document.
    - `findText` must be a verbatim substring from the current document.
    - Stream `replaceText` progressively as you write it (AIKit will surface the streamed tool input to the app).
    - Use `beforeContext`/`afterContext` only when needed to disambiguate.
    - Keep `replaceText` to a single logical block (paragraph/heading/list item/code block) unless the user explicitly asks for larger edits.
    """
}

struct AIMarkdownEditingChatSheet: View {
    @AppStorage(AppSettings.openRouterAPIKeyKey) private var apiKey: String = ""
    @AppStorage(AppSettings.openRouterModelIDKey) private var modelID: String = AppSettings.defaultOpenRouterModelID

    @ObservedObject var store: AIMarkdownEditingChatStore
    @State private var text: String = ""
    @State private var sendTrigger: Int = 0

    init(store: AIMarkdownEditingChatStore) {
        self.store = store
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Conversation(messages: store.messages, status: store.status, sendTrigger: sendTrigger)
                .conversationAnchorsNewUserMessagesToTop(true)
                .chatComposer(
                    text: $text,
                    status: store.status,
                    showsScrollToLatestButton: true,
                    onSend: { message in
                        sendTrigger += 1
                        store.send(userText: message)
                        text = ""
                    },
                    onStop: { store.stop() }
                )
                .navigationTitle("Chat Sheet")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
                .overlay(alignment: .top) {
                    if let error = store.errorDescription {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.red.opacity(0.85))
                    }
                }
        }
        .task {
            store.configureIfPossible(apiKey: apiKey, modelID: modelID)
        }
        .onChange(of: apiKey) { _, _ in
            store.configureIfPossible(apiKey: apiKey, modelID: modelID)
        }
        .onChange(of: modelID) { _, _ in
            store.configureIfPossible(apiKey: apiKey, modelID: modelID)
        }
    }
}
