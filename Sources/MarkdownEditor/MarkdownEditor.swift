import UIKit
import Lexical
import LexicalMarkdown
import LexicalListPlugin
import LexicalLinkPlugin

// MARK: - Extensions

private extension HeadingTagType {
    var intValue: Int {
        switch self {
        case .h1: return 1
        case .h2: return 2
        case .h3: return 3
        case .h4: return 4
        case .h5: return 5
        }
    }
}

// MARK: - Primary Editor Interface

public final class MarkdownEditorView: UIView {
    
    // MARK: - Public Properties
    
    public weak var delegate: MarkdownEditorDelegate?
    
    public var isEditable: Bool = true {
        didSet { lexicalView.textView.isEditable = isEditable }
    }
    
    public var placeholderText: String? {
        didSet { updatePlaceholder() }
    }
    
    /// Access to the underlying text view for setting inputAccessoryView
    public var textView: UITextView {
        return lexicalView.textView
    }
    
    /// Input accessory view for this editor
    public override var inputAccessoryView: UIView? {
        get { return textView.inputAccessoryView }
        set { textView.inputAccessoryView = newValue }
    }
    
    // MARK: - Private Properties
    
    private let lexicalView: LexicalView
    private let configuration: MarkdownEditorConfiguration
    private weak var controller: AnyObject?
    private var cursorDelegate: MarkdownCursorDelegate?
    
    // Domain layer bridge
    private let domainBridge: MarkdownDomainBridge
    
    // MARK: - Initialization
    
    public init(configuration: MarkdownEditorConfiguration = .init()) {
        self.configuration = configuration
        
        // Initialize Domain Bridge
        self.domainBridge = MarkdownDomainBridge()
        
        // Initialize Lexical components
        let theme = Self.createLexicalTheme(from: configuration.theme)
        let plugins = Self.createPlugins(for: configuration.features)
        
        let editorConfig = EditorConfig(theme: theme, plugins: plugins)
        self.lexicalView = LexicalView(
            editorConfig: editorConfig,
            featureFlags: FeatureFlags()
        )
        
        super.init(frame: .zero)
        setupView()
        
        // Connect domain bridge to Lexical editor
        domainBridge.connect(to: lexicalView.editor)
        
        // Set up cursor customization
        setupCursorCustomization()
        
        setupCommandBar()
        setupEditorListeners()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public API
    
    public func loadMarkdown(_ document: MarkdownDocument) -> MarkdownEditorResult<Void> {
        // Parse and validate through domain
        let parseResult = domainBridge.parseDocument(document)
        
        switch parseResult {
        case .success(let parsed):
            // Apply to Lexical through bridge
            let applyResult = domainBridge.applyToLexical(parsed, editor: lexicalView.editor)
            
            switch applyResult {
            case .success:
                // If document is empty and startWithTitle is enabled, apply H1 formatting
                if document.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                    && configuration.behavior.startWithTitle {
                    // For empty documents, apply H1 formatting directly to Lexical
                    // This bypasses the domain validation which expects existing content
                    do {
                        try lexicalView.editor.update {
                            guard let selection = try getSelection() as? RangeSelection else { return }
                            setBlocksType(selection: selection) { createHeadingNode(headingTag: .h1) }
                        }
                        
                        // Sync domain bridge state after applying the formatting
                        domainBridge.syncFromLexical()
                    } catch {
                        // Silently handle the error for now - startWithTitle is a nice-to-have feature
                    }
                }
                
                delegate?.markdownEditor(self, didLoadDocument: document)
                return .success(())
                
            case .failure(let error):
                let editorError = MarkdownEditorError.invalidMarkdown(error.localizedDescription)
                return .failure(editorError)
            }
            
        case .failure(let error):
            let editorError = MarkdownEditorError.invalidMarkdown(error.localizedDescription)
            return .failure(editorError)
        }
    }
    
    public func exportMarkdown() -> MarkdownEditorResult<MarkdownDocument> {
        // Export through domain bridge
        let result = domainBridge.exportDocument()
        
        switch result {
        case .success(let document):
            return .success(document)
        case .failure(let error):
            // Map domain error to editor error
            switch error {
            case .serializationFailed:
                return .failure(.serializationFailed)
            default:
                return .failure(.editorStateCorrupted)
            }
        }
    }
    
    public func applyFormatting(_ formatting: InlineFormatting) {
        // Sync current state from Lexical
        domainBridge.syncFromLexical()
        
        // Create domain command
        let command = domainBridge.createFormattingCommand(formatting)
        
        // Execute through domain bridge (validates and applies)
        let result = domainBridge.execute(command)
        
        switch result {
        case .success:
            // Success - state is already updated in Lexical
            break
        case .failure(let error):
            // Map domain error to editor error
            let editorError: MarkdownEditorError
            switch error {
            case .unsupportedOperation(let reason):
                editorError = .unsupportedFeature(reason)
            default:
                editorError = .editorStateCorrupted
            }
            delegate?.markdownEditor(self, didEncounterError: editorError)
        }
    }
    
    public func setBlockType(_ blockType: MarkdownBlockType) {
        // Sync current state from Lexical
        domainBridge.syncFromLexical()
        
        // Create domain command with smart list toggle logic
        let command = domainBridge.createBlockTypeCommand(blockType)
        
        // Execute through domain bridge
        let result = domainBridge.execute(command)
        
        switch result {
        case .success:
            // Force layout update for list items to trigger bullet rendering
            if blockType == .unorderedList || blockType == .orderedList {
                DispatchQueue.main.async { [weak self] in
                    self?.lexicalView.setNeedsLayout()
                }
            }
        case .failure(let error):
            // Map domain error to editor error
            let editorError: MarkdownEditorError
            switch error {
            case .unsupportedOperation(let reason):
                editorError = .unsupportedFeature(reason)
            default:
                editorError = .editorStateCorrupted
            }
            delegate?.markdownEditor(self, didEncounterError: editorError)
        }
    }
    
    public func getCurrentFormatting() -> InlineFormatting {
        // Sync current state from Lexical
        domainBridge.syncFromLexical()
        
        // Get formatting from domain state
        let state = domainBridge.getCurrentState()
        return state.currentFormatting
    }
    
    public func getCurrentBlockType() -> MarkdownBlockType {
        // Sync current state from Lexical
        domainBridge.syncFromLexical()
        
        // Get block type from domain state
        let state = domainBridge.getCurrentState()
        return state.currentBlockType
    }
    
    // MARK: - Private Methods
    
    private func setupView() {
        addSubview(lexicalView)
        lexicalView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lexicalView.topAnchor.constraint(equalTo: topAnchor),
            lexicalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            lexicalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            lexicalView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func setupCursorCustomization() {
        // Create and set the cursor delegate
        let cursorDelegate = MarkdownCursorDelegate(theme: configuration.theme)
        self.cursorDelegate = cursorDelegate
        
        // Set the delegate on the TextView
        let textView = lexicalView.textView as TextView
        textView.cursorDelegate = cursorDelegate
    }
    
    private func setupEditorListeners() {
        _ = lexicalView.editor.registerUpdateListener { [weak self] activeEditorState, previousEditorState, dirtyNodes in
            guard let self = self else { return }
            
            // Sync domain state with Lexical state
            self.domainBridge.syncFromLexical()
            
            // Notify delegate of content changes
            self.delegate?.markdownEditorDidChange(self)
            
            // Auto-export if configured
            if self.configuration.behavior.autoSave {
                if let document = self.exportMarkdown().value {
                    self.delegate?.markdownEditor(self, didAutoSave: document)
                }
            }
        }
    }
    
    // MARK: - Controller Binding
    
    @available(iOS 17.0, *)
    internal func bindController(_ controller: Any) {
        self.controller = controller as AnyObject
    }
    
    private static func createLexicalTheme(from markdownTheme: MarkdownTheme) -> Theme {
        let theme = Theme()
        
        // Configure list styling from MarkdownTheme
        theme.indentSize = markdownTheme.spacing.indentSize
        theme.listBulletMargin = markdownTheme.spacing.listBulletMargin
        theme.listBulletTextSpacing = markdownTheme.spacing.listBulletTextSpacing
        
        // Note: Cursor height adjustment is now handled automatically per-block 
        // in TextView.caretRect(for:) based on actual line spacing at cursor position
        
        // Configure typography with line spacing and paragraph spacing (BEFORE and AFTER blocks)
        theme.paragraph = [
            .font: markdownTheme.typography.body,
            .foregroundColor: markdownTheme.colors.text,
            .lineSpacing: markdownTheme.spacing.lineSpacing,
            .paragraphSpacing: markdownTheme.spacing.paragraphSpacing,
            .paragraphSpacingBefore: markdownTheme.spacing.paragraphSpacingBefore
        ]
        
        theme.setValue(.heading, forSubtype: "h1", value: [
            .font: markdownTheme.typography.h1,
            .foregroundColor: markdownTheme.colors.text,
            .lineSpacing: markdownTheme.spacing.lineSpacing,
            .paragraphSpacing: markdownTheme.spacing.headingSpacing,
            .paragraphSpacingBefore: markdownTheme.spacing.headingSpacingBefore
        ])
        
        theme.setValue(.heading, forSubtype: "h2", value: [
            .font: markdownTheme.typography.h2,
            .foregroundColor: markdownTheme.colors.text,
            .lineSpacing: markdownTheme.spacing.lineSpacing,
            .paragraphSpacing: markdownTheme.spacing.headingSpacing,
            .paragraphSpacingBefore: markdownTheme.spacing.headingSpacingBefore
        ])
        
        theme.setValue(.heading, forSubtype: "h3", value: [
            .font: markdownTheme.typography.h3,
            .foregroundColor: markdownTheme.colors.text,
            .lineSpacing: markdownTheme.spacing.lineSpacing,
            .paragraphSpacing: markdownTheme.spacing.headingSpacing,
            .paragraphSpacingBefore: markdownTheme.spacing.headingSpacingBefore
        ])
        
        theme.setValue(.heading, forSubtype: "h4", value: [
            .font: markdownTheme.typography.h4,
            .foregroundColor: markdownTheme.colors.text,
            .lineSpacing: markdownTheme.spacing.lineSpacing,
            .paragraphSpacing: markdownTheme.spacing.headingSpacing,
            .paragraphSpacingBefore: markdownTheme.spacing.headingSpacingBefore
        ])
        
        theme.setValue(.heading, forSubtype: "h5", value: [
            .font: markdownTheme.typography.h5,
            .foregroundColor: markdownTheme.colors.text,
            .lineSpacing: markdownTheme.spacing.lineSpacing,
            .paragraphSpacing: markdownTheme.spacing.headingSpacing,
            .paragraphSpacingBefore: markdownTheme.spacing.headingSpacingBefore
        ])
        
        theme.code = [
            .font: markdownTheme.typography.code,
            .foregroundColor: markdownTheme.colors.code
        ]
        
        theme.quote = [
            .font: markdownTheme.typography.body,
            .foregroundColor: markdownTheme.colors.quote
        ]
        
        // Configure list item spacing and bullet styling
        theme.listItem = [
            .lineSpacing: markdownTheme.spacing.lineSpacing,
            .paragraphSpacing: markdownTheme.spacing.listItemSpacing,  // Space between list items
            .listSpacing: markdownTheme.spacing.listSpacing,  // Space after entire list
            .bulletSizeIncrease: markdownTheme.spacing.bulletSizeIncrease,  // Bullet size increase
            .bulletWeight: markdownTheme.spacing.bulletWeight.rawValue,  // Bullet font weight
            .bulletVerticalOffset: markdownTheme.spacing.bulletVerticalOffset  // Bullet vertical positioning
        ]
        
        return theme
    }
    
    private static func createPlugins(for features: MarkdownFeatureSet) -> [Plugin] {
        var plugins: [Plugin] = []
        
        // Always include markdown support
        plugins.append(LexicalMarkdown())
        
        if features.contains(.lists) {
            plugins.append(ListPlugin())
        }
        
        if features.contains(.links) {
            plugins.append(LinkPlugin())
        }
        
        // Always add the zero-width space fix plugin for better list item deletion behavior
        plugins.append(ZeroWidthSpaceFixPlugin())
        
        return plugins
    }
    
    private func setupCommandBar() {
        // Create FluentUI CommandBar and size it based on its intrinsic content size
        let commandBar = MarkdownCommandBar()
        commandBar.editor = self
        
        // For inputAccessoryView, we need to provide a frame with the intrinsic height
        // Use screen width so it works on all devices - system will resize to keyboard width anyway
        let intrinsicHeight = commandBar.intrinsicContentSize.height
        let screenWidth = UIScreen.main.bounds.width
        commandBar.frame = CGRect(x: 0, y: 0, width: screenWidth, height: intrinsicHeight)
        
        textView.inputAccessoryView = commandBar
    }
    
    private func updatePlaceholder() {
        // Implementation for placeholder text would go here
        // This would require custom placeholder handling in Lexical
    }
}

// MARK: - Delegate Protocol

public protocol MarkdownEditorDelegate: AnyObject {
    func markdownEditorDidChange(_ editor: MarkdownEditorView)
    func markdownEditor(_ editor: MarkdownEditorView, didLoadDocument document: MarkdownDocument)
    func markdownEditor(_ editor: MarkdownEditorView, didAutoSave document: MarkdownDocument)
    func markdownEditor(_ editor: MarkdownEditorView, didEncounterError error: MarkdownEditorError)
}

// Provide default implementations
public extension MarkdownEditorDelegate {
    func markdownEditorDidChange(_ editor: MarkdownEditorView) {}
    func markdownEditor(_ editor: MarkdownEditorView, didLoadDocument document: MarkdownDocument) {}
    func markdownEditor(_ editor: MarkdownEditorView, didAutoSave document: MarkdownDocument) {}
    func markdownEditor(_ editor: MarkdownEditorView, didEncounterError error: MarkdownEditorError) {}
}
