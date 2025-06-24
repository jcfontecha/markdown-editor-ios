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
    
    // MARK: - Initialization
    
    public init(configuration: MarkdownEditorConfiguration = .init()) {
        self.configuration = configuration
        
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
        setupCommandBar()
        setupEditorListeners()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public API
    
    public func loadMarkdown(_ document: MarkdownDocument) -> MarkdownEditorResult<Void> {
        do {
            // Parse markdown and create proper Lexical nodes
            try MarkdownImporter.importMarkdown(document.content, into: lexicalView.editor)
            
            // If document is empty and startWithTitle is enabled, apply H1 formatting
            if document.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                && configuration.behavior.startWithTitle {
                // Equivalent to clicking the "Title" button
                setBlockType(.heading(level: .h1))
            }
            
            delegate?.markdownEditor(self, didLoadDocument: document)
            return .success(())
        } catch {
            let editorError = MarkdownEditorError.invalidMarkdown(error.localizedDescription)
            return .failure(editorError)
        }
    }
    
    public func exportMarkdown() -> MarkdownEditorResult<MarkdownDocument> {
        do {
            let markdownText = try LexicalMarkdown.generateMarkdown(
                from: lexicalView.editor,
                selection: nil
            )
            
            let document = MarkdownDocument(
                content: markdownText,
                metadata: DocumentMetadata(
                    createdAt: Date(),
                    modifiedAt: Date(),
                    version: "1.0"
                )
            )
            
            return .success(document)
        } catch {
            return .failure(.serializationFailed)
        }
    }
    
    public func applyFormatting(_ formatting: InlineFormatting) {
        do {
            try lexicalView.editor.update {
                if formatting.contains(.bold) {
                    lexicalView.editor.dispatchCommand(type: .formatText, payload: TextFormatType.bold)
                }
                if formatting.contains(.italic) {
                    lexicalView.editor.dispatchCommand(type: .formatText, payload: TextFormatType.italic)
                }
                if formatting.contains(.strikethrough) {
                    lexicalView.editor.dispatchCommand(type: .formatText, payload: TextFormatType.strikethrough)
                }
                if formatting.contains(.code) {
                    lexicalView.editor.dispatchCommand(type: .formatText, payload: TextFormatType.code)
                }
            }
        } catch {
            delegate?.markdownEditor(self, didEncounterError: .editorStateCorrupted)
        }
    }
    
    public func setBlockType(_ blockType: MarkdownBlockType) {
        do {
            try lexicalView.editor.update {
                guard let selection = try getSelection() as? RangeSelection else { return }
                
                switch blockType {
                case .paragraph:
                    setBlocksType(selection: selection) { createParagraphNode() }
                case .heading(let level):
                    setBlocksType(selection: selection) { createHeadingNode(headingTag: level.lexicalType) }
                case .codeBlock:
                    setBlocksType(selection: selection) { createCodeNode() }
                case .quote:
                    setBlocksType(selection: selection) { createQuoteNode() }
                case .unorderedList:
                    // Check if we're already in an unordered list to toggle back to paragraph
                    guard let anchorNode = try? selection.anchor.getNode() else { return }
                    let element = isRootNode(node: anchorNode) ? anchorNode : 
                        findMatchingParent(startingNode: anchorNode) { e in
                            let parent = e.getParent()
                            return parent != nil && isRootNode(node: parent)
                        }
                    
                    if (element is ListItemNode && (element?.getParent() as? ListNode)?.getListType() == .bullet) ||
                       (element as? ListNode)?.getListType() == .bullet {
                        setBlocksType(selection: selection) { createParagraphNode() }
                    } else {
                        lexicalView.editor.dispatchCommand(type: .insertUnorderedList)
                        // Force layout update to trigger bullet rendering for empty list items
                        // This ensures bullets appear immediately because it forces TextKit to 
                        // process the new list structure and call getAttributedStringAttributes()
                        DispatchQueue.main.async { [weak self] in
                            self?.lexicalView.setNeedsLayout()
                        }
                    }
                case .orderedList:
                    // Check if we're already in an ordered list to toggle back to paragraph
                    guard let anchorNode = try? selection.anchor.getNode() else { return }
                    let element = isRootNode(node: anchorNode) ? anchorNode : 
                        findMatchingParent(startingNode: anchorNode) { e in
                            let parent = e.getParent()
                            return parent != nil && isRootNode(node: parent)
                        }
                    
                    if (element is ListItemNode && (element?.getParent() as? ListNode)?.getListType() == .number) ||
                       (element as? ListNode)?.getListType() == .number {
                        setBlocksType(selection: selection) { createParagraphNode() }
                    } else {
                        lexicalView.editor.dispatchCommand(type: .insertOrderedList)
                        // Force layout update to trigger bullet rendering for empty list items
                        DispatchQueue.main.async { [weak self] in
                            self?.lexicalView.setNeedsLayout()
                        }
                    }
                }
            }
        } catch {
            delegate?.markdownEditor(self, didEncounterError: .editorStateCorrupted)
        }
    }
    
    public func getCurrentFormatting() -> InlineFormatting {
        var formatting: InlineFormatting = []
        
        do {
            try lexicalView.editor.read {
                guard let selection = try getSelection() as? RangeSelection else { return }
                
                if selection.hasFormat(type: .bold) { formatting.insert(.bold) }
                if selection.hasFormat(type: .italic) { formatting.insert(.italic) }
                if selection.hasFormat(type: .strikethrough) { formatting.insert(.strikethrough) }
                if selection.hasFormat(type: .code) { formatting.insert(.code) }
            }
        } catch {
            // Return empty formatting on error
        }
        
        return formatting
    }
    
    public func getCurrentBlockType() -> MarkdownBlockType {
        var blockType: MarkdownBlockType = .paragraph
        
        do {
            try lexicalView.editor.read {
                guard let selection = try getSelection() as? RangeSelection,
                      let anchorNode = try? selection.anchor.getNode() else { return }
                
                let element = isRootNode(node: anchorNode) ? anchorNode : 
                    findMatchingParent(startingNode: anchorNode) { e in
                        let parent = e.getParent()
                        return parent != nil && isRootNode(node: parent)
                    }
                
                if let heading = element as? HeadingNode {
                    let level = MarkdownBlockType.HeadingLevel(rawValue: heading.getTag().intValue) ?? .h1
                    blockType = .heading(level: level)
                } else if element is CodeNode {
                    blockType = .codeBlock
                } else if element is QuoteNode {
                    blockType = .quote
                } else if let listNode = element as? ListNode {
                    blockType = listNode.getListType() == .bullet ? .unorderedList : .orderedList
                }
            }
        } catch {
            // Return paragraph on error
        }
        
        return blockType
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
    
    private func setupEditorListeners() {
        _ = lexicalView.editor.registerUpdateListener { [weak self] activeEditorState, previousEditorState, dirtyNodes in
            guard let self = self else { return }
            
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
