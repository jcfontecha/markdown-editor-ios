import UIKit
import MarkdownEditor

final class AIMarkdownEditingDemoViewController: UIViewController {
    private let bridge: MarkdownEditorAIEditBridge

    private let markdownEditor: MarkdownEditorView = {
        var configuration = MarkdownEditorConfiguration(
            theme: .default,
            features: .standard,
            behavior: EditorBehavior(
                autoSave: true,
                autoCorrection: true,
                smartQuotes: true,
                returnKeyBehavior: .smart
            )
        )
        configuration = configuration.logging(.verbose)
        return MarkdownEditorView(configuration: configuration)
    }()

    init(bridge: MarkdownEditorAIEditBridge) {
        self.bridge = bridge
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        markdownEditor.delegate = self
        markdownEditor.placeholderText = "Start typing your markdown..."
        view.addSubview(markdownEditor)
        markdownEditor.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            markdownEditor.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            markdownEditor.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            markdownEditor.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            markdownEditor.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        bridge.attachEditor(markdownEditor)
        loadSampleContent()
    }

    private func loadSampleContent() {
        let sampleMarkdown = """
        # AI Editing Demo

        Use the “AI” button to open chat in a sheet.

        Try asking:
        - “Rewrite the intro to be more friendly.”
        - “Turn the list into a numbered list.”
        - “Add a short ‘Next steps’ section at the end.”

        ## Notes

        This demo applies **streaming tool input** directly into the editor (as it arrives), using `startReplacement(...)` and `ReplacementSession.setText(...)`.
        """

        let document = MarkdownDocument(content: sampleMarkdown)
        let result = markdownEditor.loadMarkdown(document)
        if case .failure(let error) = result {
            bridge.lastErrorDescription = error.localizedDescription
        }
    }
}

extension AIMarkdownEditingDemoViewController: MarkdownEditorDelegate {
    func markdownEditor(_ editor: any MarkdownEditorInterface, didEncounterError error: MarkdownEditorError) {
        bridge.lastErrorDescription = error.localizedDescription
    }
}
