import UIKit
import Lexical
import LexicalMarkdown
import LexicalListPlugin
import LexicalLinkPlugin

// MARK: - Extensions

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
}

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
    private let logger: MarkdownCommandLogger
    private weak var controller: AnyObject?
    private var cursorDelegate: MarkdownCursorDelegate?
    
    // Domain layer bridge
    private let domainBridge: MarkdownDomainBridge
    
    // Command handlers for cleanup
    private var commandHandlers: [Editor.RemovalHandler] = []
    
    // Editing state tracking
    private var isEditing = false
    
    // Pending keystroke log for completion in update listener
    private var pendingKeystrokeLog: PendingKeystrokeLog?
    
    // MARK: - Initialization
    
    public init(configuration: MarkdownEditorConfiguration = .init()) {
        self.configuration = configuration
        
        // Initialize logger with configuration
        self.logger = MarkdownCommandLogger(loggingConfig: configuration.logging)
        
        // Initialize Domain Bridge
        self.domainBridge = MarkdownDomainBridge(logger: logger)
        
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
    
    deinit {
        // Clean up command handlers
        for handler in commandHandlers {
            handler()
        }
        commandHandlers.removeAll()
        
        // Remove keyboard notification observers
        NotificationCenter.default.removeObserver(self)
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
                            // Ensure there is a selection; create one at the start of the first block if missing
                            var selection = try getSelection() as? RangeSelection
                            if selection == nil,
                               let root = getRoot(),
                               let first = root.getFirstChild() as? ElementNode {
                                let point = Point(key: first.key, offset: 0, type: .element)
                                let newSelection = RangeSelection(anchor: point, focus: point, format: TextFormat())
                                getActiveEditorState()?.selection = newSelection
                                selection = newSelection
                            }
                            if let selection = selection {
                                setBlocksType(selection: selection) { createHeadingNode(headingTag: .h1) }
                            }
                        }
                        
                        // Sync domain bridge state after applying the formatting
                        domainBridge.syncFromLexical()
                    } catch {
                        // Silently handle the error for now - startWithTitle is a nice-to-have feature
                    }
                }
                
                // Refresh placeholder visibility after content load to prevent overlap when content is non-empty
                lexicalView.showPlaceholderText()

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
        
        // Capture caret before toggling for safety in UI-layer as well
        var preservedPoint: (key: NodeKey, offset: Int, type: SelectionType)? = nil
        try? lexicalView.editor.read {
            if let selection = try? getSelection() as? RangeSelection {
                preservedPoint = (selection.anchor.key, selection.anchor.offset, selection.anchor.type)
            }
        }
        
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
            
            // Best-effort selection restoration if anchor was forced to start
            if let preservedPoint, preservedPoint.type == .text {
                try? lexicalView.editor.update {
                    if let _: TextNode = getNodeByKey(key: preservedPoint.key) {
                        let clampedOffset: Int = {
                            if let node: TextNode = getNodeByKey(key: preservedPoint.key) {
                                return max(0, min(preservedPoint.offset, node.getTextContentSize()))
                            }
                            return preservedPoint.offset
                        }()
                        let p = Point(key: preservedPoint.key, offset: clampedOffset, type: .text)
                        let newSel = RangeSelection(anchor: p, focus: p, format: TextFormat())
                        getActiveEditorState()?.selection = newSel
                    }
                }
            }
        case .failure(let error):
            logger.logSimpleEvent("ERROR", details: "Block type command failed: \(error.localizedDescription)")
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
        
        // Apply background color from theme
        let backgroundColor = configuration.theme.colors.backgroundColor
        self.backgroundColor = backgroundColor
        lexicalView.backgroundColor = backgroundColor
        lexicalView.textView.backgroundColor = backgroundColor
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
            
            // Complete any pending keystroke logging first (before syncing domain state)
            if self.pendingKeystrokeLog != nil {
                self.completeKeystrokeLog()
            }
            
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
        
        // Register domain command handlers for keyboard events
        registerDomainCommandHandlers()
        
        // Set up keyboard notification observers
        setupKeyboardNotifications()
    }
    
    private func registerDomainCommandHandlers() {
        // Register smart Enter handler by intercepting insertText command
        let enterHandler = lexicalView.editor.registerCommand(
            type: .insertText,
            listener: { [weak self] payload in
                guard let self = self,
                      let text = payload as? String else { return false }
                
                // Capture before state for logging
                let beforeSnapshot = logger.createSnapshot(from: self.lexicalView.editor)
                
                // Check if this is an Enter key
                if text == "\n" {
                    logger.logSimpleEvent("ENTER_DETECTED", details: "Enter key pressed via insertText")
                    
                    // Sync current state
                    self.domainBridge.syncFromLexical()
                    
                    // Check if domain should handle this
                    let state = self.domainBridge.currentDomainState
                    let isInList = (state.currentBlockType == .unorderedList || state.currentBlockType == .orderedList)
                    let isLineEmpty = self.isCurrentLineEmpty()
                    
                    if isInList && isLineEmpty {
                        logger.logSimpleEvent("ENTER", details: "Empty list item detected, converting to paragraph")
                        
                        // Create and execute smart enter command
                        let command = self.domainBridge.createSmartEnterCommand()
                        let result = self.domainBridge.execute(command)
                        
                        // Return true = domain handled it
                        // Return false = use Lexical's default behavior
                        return result.isSuccess
                    } else {
                        // Non-list handling based on returnKeyBehavior and block context
                        switch self.configuration.behavior.returnKeyBehavior {
                        case .insertParagraph:
                            self.lexicalView.editor.dispatchCommand(type: .insertParagraph)
                            return true
                        case .insertLineBreak:
                            self.lexicalView.editor.dispatchCommand(type: .insertLineBreak)
                            return true
                        case .smart:
                            let isHeading: Bool = {
                                if case .heading = state.currentBlockType { return true }
                                return false
                            }()
                            if isHeading {
                                self.lexicalView.editor.dispatchCommand(type: .insertParagraph)
                                // After inserting paragraph, ensure caret is in the new paragraph start
                                try? self.lexicalView.editor.update {
                                    if let selection = try? getSelection() as? RangeSelection,
                                       selection.anchor.type == .element {
                                        // Already at the start of new block
                                        return
                                    }
                                    // If selection remains text-anchored in heading, move to next element start
                                    if let selection = try? getSelection() as? RangeSelection,
                                       let anchorNode = try? selection.anchor.getNode(),
                                       let element = isRootNode(node: anchorNode) ? anchorNode : findMatchingParent(startingNode: anchorNode) { e in
                                           let parent = e.getParent()
                                           return parent != nil && isRootNode(node: parent)
                                       } as? ElementNode,
                                       let next = element.getNextSibling() as? ElementNode {
                                        _ = try? next.selectStart()
                                    }
                                }
                                return true
                            }
                            // Fallback to Lexical default behavior
                            self.logKeystroke("Enter", beforeSnapshot: beforeSnapshot, action: "Insert newline character")
                        }
                    }
                } else {
                    // Log regular character insertion
                    let displayText = text.count == 1 ? "'\(text)'" : "text: \"\(text)\""
                    self.logKeystroke("Character: \(displayText)", beforeSnapshot: beforeSnapshot, action: "Insert text")
                }
                
                // Let Lexical handle normal text insertion
                return false
            },
            priority: .High
        )
        
        // Register smart Backspace handler by intercepting deleteCharacter command
        let backspaceHandler = lexicalView.editor.registerCommand(
            type: .deleteCharacter,
            listener: { [weak self] payload in
                guard let self = self,
                      let isBackwards = payload as? Bool,
                      isBackwards else { return false }
                
                logger.logSimpleEvent("BACKSPACE_DETECTED", details: "Backspace key pressed via deleteCharacter")
                
                // Capture before state for logging
                let beforeSnapshot = logger.createSnapshot(from: self.lexicalView.editor)
                
                // Sync current state
                self.domainBridge.syncFromLexical()
                
                // Check if domain should handle this
                let state = self.domainBridge.currentDomainState
                
                // If in a list and at start of empty line
                let isInList = (state.currentBlockType == .unorderedList || state.currentBlockType == .orderedList)
                let isLineEmpty = self.isCurrentLineEmpty()
                let isAtLineStart = self.isCursorAtLineStart()
                
                if isInList && isLineEmpty && isAtLineStart {
                    logger.logSimpleEvent("BACKSPACE", details: "Empty list item at start, removing list")
                    
                    // Create and execute smart backspace command
                    let command = self.domainBridge.createSmartBackspaceCommand()
                    let result = self.domainBridge.execute(command)
                    
                    return result.isSuccess
                } else {
                    // Log this as a regular keystroke that Lexical will handle
                    self.logKeystroke("Backspace", beforeSnapshot: beforeSnapshot, action: "Delete character backward")
                }
                
                // Let Lexical handle normal backspace
                return false
            },
            priority: .High
        )
        
        // Store handlers for cleanup
        commandHandlers.append(enterHandler)
        commandHandlers.append(backspaceHandler)
    }
    
    // MARK: - Keystroke Event Logging
    
    private func logKeystroke(_ keyName: String, beforeSnapshot: MarkdownStateSnapshot?, action: String) {
        guard configuration.logging.isEnabled && configuration.logging.level >= .verbose else { return }
        guard let beforeSnapshot = beforeSnapshot else { return }
        
        // Log the start of keystroke (before state and action)
        let separator = String(repeating: "=", count: 42)
        print("\n\(separator) KEYSTROKE: \(keyName) \(separator)")
        print(beforeSnapshot.detailedDescription)
        print("\nACTION: \(action)")
        
        // Store pending log to complete in update listener
        pendingKeystrokeLog = PendingKeystrokeLog(
            keyName: keyName,
            action: action,
            beforeSnapshot: beforeSnapshot
        )
    }
    
    private func completeKeystrokeLog() {
        guard configuration.logging.isEnabled && configuration.logging.level >= .verbose else {
            pendingKeystrokeLog = nil
            return
        }
        guard pendingKeystrokeLog != nil else { return }
        
        // Capture after state
        let afterSnapshot = logger.createSnapshot(from: lexicalView.editor)
        
        // Complete the log with after state
        if let afterSnapshot = afterSnapshot {
            print("\nAFTER STATE:")
            print(afterSnapshot.detailedDescription)
        } else {
            print("\nAFTER STATE: Unable to capture")
        }
        
        let endSeparator = String(repeating: "=", count: 100)
        print("\(endSeparator)\n")
        
        // Clear the pending log
        pendingKeystrokeLog = nil
    }
    
    private func isCurrentLineEmpty() -> Bool {
        var isEmpty = false
        
        try? lexicalView.editor.read {
            // Get the current selection
            guard let selection = try? getSelection() as? RangeSelection else {
                return
            }
            
            // Prefer checking the nearest ListItemNode when present
            let anchor = selection.anchor
            var targetNode: Node?
            if let node = try? anchor.getNode() {
                if let li = self.findParentListItem(node) {
                    targetNode = li
                } else if let element = node as? ElementNode {
                    targetNode = element
                } else {
                    targetNode = node.getParent()
                }
            }
            guard let checkNode = targetNode else { return }
            
            // Check if the node has only whitespace/ZWSP or is empty
            let rawText = checkNode.getTextContent()
            let textWithoutZWS = rawText.replacingOccurrences(of: "\u{200B}", with: "")
            isEmpty = textWithoutZWS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        return isEmpty
    }
    
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        updateEditingState(true)
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        updateEditingState(false)
    }
    
    private func updateEditingState(_ editing: Bool) {
        guard isEditing != editing else { return }
        isEditing = editing
        delegate?.markdownEditor(self, didChangeEditingState: isEditing)
    }
    
    private func isCursorAtLineStart() -> Bool {
        var isAtStart = false
        
        try? lexicalView.editor.read {
            // Get the current selection
            guard let selection = try? getSelection() as? RangeSelection else {
                return
            }
            
            guard selection.isCollapsed() else { return }
            let anchor = selection.anchor
            
            if anchor.type == .element {
                // Element-anchored selection: offset 0 means at start
                isAtStart = anchor.offset == 0
                return
            }
            
            // Text-anchored selection: consider ZWSP/whitespace before caret as "at start"
            if anchor.type == .text,
               let textNode = try? anchor.getNode() as? TextNode {
                let fullText = textNode.getTextContent()
                let endIndex = fullText.index(fullText.startIndex, offsetBy: min(anchor.offset, fullText.count))
                let prefix = String(fullText[..<endIndex])
                let sanitized = prefix.replacingOccurrences(of: "\u{200B}", with: "")
                isAtStart = sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
        
        return isAtStart
    }
    
    // MARK: - Helpers
    private func findParentListItem(_ node: Node) -> ListItemNode? {
        var current: Node? = node
        while let n = current {
            if let li = n as? ListItemNode { return li }
            current = n.getParent()
        }
        return nil
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
        // Apply placeholder to Lexical if available
        guard let placeholderText, !placeholderText.isEmpty else {
            // Clear by setting empty placeholder to avoid stale label
            lexicalView.placeholderText = nil
            return
        }
        
        // Choose font based on startWithTitle behavior when the document is empty
        // If startWithTitle is enabled and document is empty, use H1 font; otherwise body font.
        let isEmpty: Bool = {
            let result = domainBridge.exportDocument()
            if case .success(let doc) = result {
                return doc.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        }()
        
        let font: UIFont
        if configuration.behavior.startWithTitle && isEmpty {
            font = configuration.theme.typography.h1
        } else {
            font = configuration.theme.typography.body
        }
        
        let color = configuration.theme.colors.text.withAlphaComponent(0.35)
        let placeholder = LexicalPlaceholderText(text: placeholderText, font: font, color: color)
        lexicalView.placeholderText = placeholder
        // Let Lexical manage placeholder visibility based on content state
    }
}

// MARK: - Delegate Protocol

public protocol MarkdownEditorDelegate: AnyObject {
    func markdownEditorDidChange(_ editor: MarkdownEditorView)
    func markdownEditor(_ editor: MarkdownEditorView, didLoadDocument document: MarkdownDocument)
    func markdownEditor(_ editor: MarkdownEditorView, didAutoSave document: MarkdownDocument)
    func markdownEditor(_ editor: MarkdownEditorView, didEncounterError error: MarkdownEditorError)
    func markdownEditor(_ editor: MarkdownEditorView, didChangeEditingState isEditing: Bool)
}

// Provide default implementations
public extension MarkdownEditorDelegate {
    func markdownEditorDidChange(_ editor: MarkdownEditorView) {}
    func markdownEditor(_ editor: MarkdownEditorView, didLoadDocument document: MarkdownDocument) {}
    func markdownEditor(_ editor: MarkdownEditorView, didAutoSave document: MarkdownDocument) {}
    func markdownEditor(_ editor: MarkdownEditorView, didEncounterError error: MarkdownEditorError) {}
    func markdownEditor(_ editor: MarkdownEditorView, didChangeEditingState isEditing: Bool) {}
}

// MARK: - Keystroke Logging Support

private struct PendingKeystrokeLog {
    let keyName: String
    let action: String
    let beforeSnapshot: MarkdownStateSnapshot
}
