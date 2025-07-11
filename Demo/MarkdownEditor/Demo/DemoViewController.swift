import UIKit
import MarkdownEditor

class DemoViewController: UIViewController {
    
    private let markdownEditor = MarkdownEditorView(
        configuration: MarkdownEditorConfiguration(
            theme: .spacious, // Use spacious theme with improved spacing and auto-adjusting cursor
            features: .standard,
            behavior: EditorBehavior(
                autoSave: true,
                autoCorrection: true,
                smartQuotes: true,
                returnKeyBehavior: .smart
            )
        )
    )
    
    private let exportButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupEditor()
        setupExportButton()
        setupConstraints()
        loadSampleContent()
    }
    
    private func setupView() {
        view.backgroundColor = .systemBackground
        title = "Markdown Editor Demo"
    }
    
    private func setupEditor() {
        markdownEditor.delegate = self
        markdownEditor.placeholderText = "Start typing your markdown..."
        
        view.addSubview(markdownEditor)
        markdownEditor.translatesAutoresizingMaskIntoConstraints = false
    }
    
    
    private func setupExportButton() {
        // Move export button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Export",
            style: .plain,
            target: self,
            action: #selector(exportMarkdown)
        )
    }
    
    private func setupConstraints() {
        // Simple full-screen layout - editor fills entire view like FluentUI demo
        NSLayoutConstraint.activate([
            markdownEditor.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            markdownEditor.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            markdownEditor.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            markdownEditor.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadSampleContent() {
        let sampleMarkdown = """
        # Test Editor
        
        Simple paragraph for testing.
        """
        
        let document = MarkdownDocument(content: sampleMarkdown)
        let result = markdownEditor.loadMarkdown(document)
        
        if case .failure(let error) = result {
            showAlert(title: "Error Loading Content", message: error.localizedDescription)
        }
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
            message: "The markdown has been exported. You can copy it to the clipboard.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Copy", style: .default) { _ in
            UIPasteboard.general.string = markdown
        })
        
        alert.addAction(UIAlertAction(title: "View", style: .default) { _ in
            self.presentMarkdownViewer(markdown)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func presentMarkdownViewer(_ markdown: String) {
        let viewController = MarkdownViewerController(markdown: markdown)
        let navigationController = UINavigationController(rootViewController: viewController)
        present(navigationController, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
}

// MARK: - MarkdownEditorDelegate

extension DemoViewController: MarkdownEditorDelegate {
    func markdownEditorDidChange(_ editor: MarkdownEditorView) {
        // Update UI to show unsaved changes
        navigationItem.title = "Markdown Editor Demo*"
    }
    
    func markdownEditor(_ editor: MarkdownEditorView, didLoadDocument document: MarkdownDocument) {
        navigationItem.title = "Markdown Editor Demo"
    }
    
    func markdownEditor(_ editor: MarkdownEditorView, didAutoSave document: MarkdownDocument) {
        // Clear unsaved indicator
        navigationItem.title = "Markdown Editor Demo"
    }
    
    func markdownEditor(_ editor: MarkdownEditorView, didEncounterError error: MarkdownEditorError) {
        showAlert(title: "Editor Error", message: error.localizedDescription)
    }
}

// MARK: - Markdown Viewer

class MarkdownViewerController: UIViewController {
    private let textView = UITextView()
    private let markdown: String
    
    init(markdown: String) {
        self.markdown = markdown
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    private func setupView() {
        view.backgroundColor = .systemBackground
        title = "Exported Markdown"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissViewer)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Copy",
            style: .plain,
            target: self,
            action: #selector(copyMarkdown)
        )
        
        textView.text = markdown
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8
        
        view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func dismissViewer() {
        dismiss(animated: true)
    }
    
    @objc private func copyMarkdown() {
        UIPasteboard.general.string = markdown
        
        // Show brief confirmation
        let alert = UIAlertController(title: "Copied!", message: "Markdown copied to clipboard", preferredStyle: .alert)
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
}
