import UIKit
import MarkdownEditor

class DemoViewController: UIViewController {
    
    private let markdownEditor = MarkdownEditor(
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
    
    private let commandBar = MarkdownCommandBar()
    private let exportButton = UIButton(type: .system)
    private let styleSegmentedControl = UISegmentedControl(items: ["Fluent", "Compact", "Spacious"])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupEditor()
        setupStyleControl()
        setupCommandBar()
        setupExportButton()
        setupConstraints()
        loadSampleContent()
    }
    
    private func setupView() {
        view.backgroundColor = .systemBackground
        title = "Beautiful Markdown Editor"
    }
    
    private func setupEditor() {
        markdownEditor.delegate = self
        markdownEditor.placeholderText = "Start typing your markdown..."
        
        view.addSubview(markdownEditor)
        markdownEditor.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupStyleControl() {
        styleSegmentedControl.selectedSegmentIndex = 0 // Fluent
        styleSegmentedControl.addTarget(self, action: #selector(styleChanged), for: .valueChanged)
        
        view.addSubview(styleSegmentedControl)
        styleSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupCommandBar() {
        commandBar.editor = markdownEditor
        commandBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Use FluentUI's proper approach: set CommandBar as inputAccessoryView
        markdownEditor.textView.inputAccessoryView = commandBar
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
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            // Style control at top
            styleSegmentedControl.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 8),
            styleSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            styleSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Editor extends ALL THE WAY DOWN - CommandBar is now inputAccessoryView
            markdownEditor.topAnchor.constraint(equalTo: styleSegmentedControl.bottomAnchor, constant: 8),
            markdownEditor.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            markdownEditor.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            markdownEditor.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadSampleContent() {
        let sampleMarkdown = """
        # Welcome to Markdown Editor
        
        This is a **WYSIWYG** markdown editor built with *Lexical iOS*.
        
        ## Features
        
        - Rich text editing
        - Live preview of markdown formatting
        - Export to markdown with full fidelity
        - Support for `inline code` formatting
        
        ### Lists
        
        - First level bullet point
          - Second level nested bullet
            - Third level nested bullet
        - Back to first level
        
        #### Numbered Lists
        
        1. First numbered item
        2. Second numbered item
           1. Nested numbered item
           2. Another nested item
        3. Back to main level
        
        > This is a blockquote to demonstrate quote formatting.
        
        ### Code Example
        
        ```swift
        let config = MarkdownEditorConfiguration()
        let editor = MarkdownEditor(configuration: config)
        ```
        
        Enjoy writing!
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
    
    @objc private func styleChanged() {
        // FluentUI CommandBar handles its own styling
        // Style changes would be handled through FluentUI's theme system if needed
    }
}

// MARK: - MarkdownEditorDelegate

extension DemoViewController: MarkdownEditorDelegate {
    func markdownEditorDidChange(_ editor: MarkdownEditor) {
        // Update UI to show unsaved changes
        navigationItem.title = "Markdown Editor Demo*"
    }
    
    func markdownEditor(_ editor: MarkdownEditor, didLoadDocument document: MarkdownDocument) {
        navigationItem.title = "Markdown Editor Demo"
    }
    
    func markdownEditor(_ editor: MarkdownEditor, didAutoSave document: MarkdownDocument) {
        // Clear unsaved indicator
        navigationItem.title = "Markdown Editor Demo"
    }
    
    func markdownEditor(_ editor: MarkdownEditor, didEncounterError error: MarkdownEditorError) {
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
