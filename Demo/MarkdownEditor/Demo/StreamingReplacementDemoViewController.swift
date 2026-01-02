import UIKit
import MarkdownEditor

final class StreamingReplacementDemoViewController: UIViewController {

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

    private var streamingTask: Task<Void, Never>?
    private var streamingSession: ReplacementSession?
    private var exportBarButtonItem: UIBarButtonItem?
    private var streamBarButtonItem: UIBarButtonItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupEditor()
        setupNavBar()
        setupConstraints()
        loadSampleContent()
    }

    deinit {
        streamingTask?.cancel()
        if let session = streamingSession {
            Task { @MainActor in session.cancel() }
        }
    }

    private func setupView() {
        view.backgroundColor = .systemBackground
        title = "Streaming Replacement"
    }

    private func setupEditor() {
        markdownEditor.delegate = self
        markdownEditor.placeholderText = "Start typing your markdown..."
        view.addSubview(markdownEditor)
        markdownEditor.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupNavBar() {
        let exportItem = UIBarButtonItem(
            title: "Export",
            style: .plain,
            target: self,
            action: #selector(exportMarkdown)
        )

        let streamItem = UIBarButtonItem(
            title: "Stream",
            style: .plain,
            target: self,
            action: #selector(streamingReplaceDemo)
        )

        exportBarButtonItem = exportItem
        streamBarButtonItem = streamItem
        navigationItem.rightBarButtonItems = [exportItem, streamItem]
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            markdownEditor.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            markdownEditor.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            markdownEditor.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            markdownEditor.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func loadSampleContent() {
        let sampleMarkdown = """
        # Streaming Replacement Demo

        Tap “Stream” to simulate streaming replacement text (as if parsed from a tool input stream).

        Target:
        Find me: The quick brown fox jumps over the lazy dog.

        Control:
        This paragraph should stay unchanged.
        """

        let document = MarkdownDocument(content: sampleMarkdown)
        let result = markdownEditor.loadMarkdown(document)
        if case .failure(let error) = result {
            showAlert(title: "Error Loading Content", message: error.localizedDescription)
        }
    }

    @objc private func streamingReplaceDemo() {
        streamingTask?.cancel()
        streamingTask = nil

        streamingSession?.cancel()
        streamingSession = nil

        exportBarButtonItem?.isEnabled = false
        streamBarButtonItem?.isEnabled = false

        streamingTask = Task { @MainActor in
            defer {
                self.streamingSession = nil
                self.exportBarButtonItem?.isEnabled = true
                self.streamBarButtonItem?.isEnabled = true
            }

            do {
                let session = try self.markdownEditor.startReplacement(
                    findText: "The quick brown fox jumps over the lazy dog.",
                    beforeContext: "Find me: ",
                    afterContext: nil
                )
                self.streamingSession = session

                // Mimic a model streaming a tool input that ultimately yields a replacement string.
                // Here we simulate a UI-layer extraction of “replacementText so far” and set it.
                let fullText = Self.makeRandomizedReplacementText()
                let partials = Self.makeProgressivePartials(from: fullText)
                for partial in partials {
                    if Task.isCancelled { break }
                    session.setText(partial)
                    try? await Task.sleep(nanoseconds: Self.randomizedDelayNanoseconds())
                }

                if Task.isCancelled {
                    session.cancel()
                } else {
                    session.finish()
                }
            } catch {
                self.showAlert(title: "Streaming Failed", message: error.localizedDescription)
            }
        }
    }

    private static func randomizedDelayNanoseconds() -> UInt64 {
        // Faster stream with small jitter: ~35–90ms per update.
        UInt64(Int.random(in: 35...90)) * 1_000_000
    }

    private static func makeProgressivePartials(from fullText: String) -> [String] {
        if fullText.isEmpty { return [""] }

        var rng = SystemRandomNumberGenerator()
        var partials: [String] = []
        partials.reserveCapacity(min(200, max(20, fullText.count / 12)))

        var index = fullText.startIndex
        var current = ""
        while index < fullText.endIndex {
            let chunkSize = Int.random(in: 8...28, using: &rng)
            let end = fullText.index(index, offsetBy: chunkSize, limitedBy: fullText.endIndex) ?? fullText.endIndex
            current.append(contentsOf: fullText[index..<end])
            partials.append(current)
            index = end
        }

        if partials.last != fullText {
            partials.append(fullText)
        }

        return partials
    }

    private static func makeRandomizedReplacementText() -> String {
        var rng = SystemRandomNumberGenerator()
        let adjectives = ["clear", "punchy", "lean", "thoughtful", "vivid", "precise", "warm", "confident", "curious", "measured"]
        let verbs = ["glides", "weaves", "bounds", "threads", "moves", "leans", "steps", "drifts", "turns", "settles"]
        let nouns = ["paragraph", "sentence", "rewrite", "pass", "draft", "section", "idea", "note", "phrase", "arc"]

        func pick(_ values: [String]) -> String {
            values[Int.random(in: 0..<values.count, using: &rng)]
        }

        let header = "The quick brown fox (edited) now \(pick(verbs)) gracefully over the lazy dog."

        var lines: [String] = [header, ""]
        lines.append("This is a longer replacement meant to feel like a streamed tool output. It aims to be \(pick(adjectives)), \(pick(adjectives)), and \(pick(adjectives)) while staying readable.")
        lines.append("As the stream progresses, we replace the target block with the latest full text, simulating “replacementText so far” extraction from a tool input stream.")
        lines.append("")

        let sentenceCount = Int.random(in: 8...14, using: &rng)
        for i in 1...sentenceCount {
            let s = "Pass \(i): a \(pick(adjectives)) \(pick(nouns)) that \(pick(verbs)) forward, adding detail without losing the thread."
            lines.append(s)
        }

        lines.append("")
        lines.append("Final note: this demo intentionally streams quickly with jitter to stress selection stability and update performance.")
        return lines.joined(separator: "\n")
    }

    @objc private func exportMarkdown() {
        let result = markdownEditor.exportMarkdown()
        switch result {
        case .success(let document):
            presentMarkdownExport(document.content)
        case .failure(let error):
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    private func presentMarkdownExport(_ markdown: String) {
        let alert = UIAlertController(
            title: "Exported Markdown",
            message: "Copy exported markdown to clipboard?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Copy", style: .default) { _ in
            UIPasteboard.general.string = markdown
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @MainActor
    func triggerExport() {
        exportMarkdown()
    }

    @MainActor
    func triggerStream() {
        streamingReplaceDemo()
    }
}

extension StreamingReplacementDemoViewController: MarkdownEditorDelegate {
    func markdownEditorDidChange(_ editor: any MarkdownEditorInterface) {
        if streamingTask == nil {
            navigationItem.title = "Streaming Replacement*"
        }
    }

    func markdownEditor(_ editor: any MarkdownEditorInterface, didLoadDocument document: MarkdownDocument) {
        navigationItem.title = "Streaming Replacement"
    }

    func markdownEditor(_ editor: any MarkdownEditorInterface, didAutoSave document: MarkdownDocument) {
        navigationItem.title = "Streaming Replacement"
    }

    func markdownEditor(_ editor: any MarkdownEditorInterface, didEncounterError error: MarkdownEditorError) {
        showAlert(title: "Editor Error", message: error.localizedDescription)
    }
}
