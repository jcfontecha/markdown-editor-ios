# WYSIWYG Markdown Editor for iOS
## Technical Specification & Architecture

### Executive Summary

This document outlines the technical feasibility, architecture, and implementation strategy for building a WYSIWYG markdown editor using the Lexical iOS framework. Based on comprehensive analysis of the codebase, the framework provides excellent native support for markdown editing with minimal complexity.

---

## Table of Contents

1. [Framework Analysis](#framework-analysis)
2. [Core Architecture](#core-architecture)
3. [Key APIs & Integration Points](#key-apis--integration-points)
4. [Proposed Swift API Design](#proposed-swift-api-design)
5. [Implementation Strategy](#implementation-strategy)
6. [Public Interface Specification](#public-interface-specification)
7. [Usage Examples](#usage-examples)
8. [Technical Considerations](#technical-considerations)

---

## Framework Analysis

### Lexical iOS Overview

**Source**: `/Users/juan/Downloads/lexical-ios-main/`

Lexical iOS is Meta's extensible text editor framework for iOS, built on TextKit and sharing philosophy with Lexical JavaScript. It's production-tested (used in Workplace iOS) and provides a robust foundation for rich text editing.

### Key Framework Components

#### Core Files Analyzed
- `Lexical/Core/Editor.swift` - Central orchestrator, state management
- `Lexical/Core/EditorState.swift` - Immutable data model with JSON serialization
- `Lexical/Core/Nodes/` - Node type system for document structure
- `Lexical/LexicalView/LexicalView.swift` - Primary UI component
- `Plugins/LexicalMarkdown/` - Native markdown support

#### Node Type System
```swift
// Core node types supporting markdown elements
.root: RootNode.self           // Document root
.text: TextNode.self           // Inline text with formatting
.paragraph: ParagraphNode.self // Block paragraphs
.heading: HeadingNode.self     // H1-H5 headings
.quote: QuoteNode.self         // Block quotes
.code: CodeNode.self           // Code blocks
.list: ListNode.self           // Ordered/unordered lists
.listItem: ListItemNode.self   // List items
.link: LinkNode.self           // Hyperlinks (via plugin)
```

#### Markdown Integration Analysis

**File**: `Plugins/LexicalMarkdown/LexicalMarkdown/LexicalMarkdown.swift`

```swift
open class LexicalMarkdown: Plugin {
  public class func generateMarkdown(
    from editor: Editor,
    selection: BaseSelection?
  ) throws -> String
}
```

**File**: `Plugins/LexicalMarkdown/LexicalMarkdown/LexicalMarkdownSupport.swift`

The framework implements protocol-based markdown conversion:

```swift
public protocol NodeMarkdownBlockSupport: Lexical.Node {
  func exportBlockMarkdown() throws -> Markdown.BlockMarkup
}

public protocol NodeMarkdownInlineSupport: Lexical.Node {
  func exportInlineMarkdown() throws -> Markdown.InlineMarkup
}
```

### Supported Markdown Elements

| Element | Node Type | Support Level | Notes |
|---------|-----------|---------------|-------|
| **Headers (H1-H5)** | `HeadingNode` | ✅ Complete | Native support via `HeadingTagType` enum |
| **Paragraphs** | `ParagraphNode` | ✅ Complete | Default block element |
| **Bold/Italic/Strikethrough** | `TextNode.TextFormat` | ✅ Complete | Inline formatting flags |
| **Inline Code** | `TextNode.TextFormat.code` | ✅ Complete | Monospace formatting |
| **Code Blocks** | `CodeNode` | ✅ Complete | Fenced code blocks |
| **Unordered Lists** | `ListNode(.bullet)` | ✅ Complete | Bullet point lists |
| **Ordered Lists** | `ListNode(.number)` | ✅ Complete | Numbered lists with start index |
| **Block Quotes** | `QuoteNode` | ✅ Complete | Markdown blockquotes |
| **Links** | `LinkNode` | ✅ Complete | Hyperlink support via plugin |
| **Line Breaks** | `LineBreakNode` | ✅ Complete | Hard line breaks |
| **Underline** | `TextFormat.underline` | ⚠️ Limited | Framework supports, but not standard markdown |
| **Subscript/Superscript** | `TextFormat.sub/superScript` | ⚠️ Limited | Framework supports, filtered on export |

---

## Core Architecture

### Data Flow Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Markdown      │───▶│   EditorState    │───▶│   Rendered UI   │
│   Input         │    │   (JSON Model)   │    │   (TextKit)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         ▲                       │                       │
         │                       ▼                       │
         │              ┌──────────────────┐              │
         └──────────────│   Editor API     │◀─────────────┘
                        │   (Updates)      │
                        └──────────────────┘
```

### Component Hierarchy

```
MarkdownEditor (Public API)
├── LexicalView (Lexical Framework)
│   ├── Editor (Core Engine)
│   │   ├── EditorState (Data Model)
│   │   └── Plugin System
│   │       ├── LexicalMarkdown
│   │       ├── ListPlugin
│   │       └── LinkPlugin
│   └── TextKit Stack
│       ├── TextStorage
│       ├── LayoutManager
│       └── TextContainer
└── MarkdownToolbar (Custom UI)
    └── Formatting Controls
```

---

## Key APIs & Integration Points

### Primary Lexical APIs

#### Editor State Management
```swift
// File: Lexical/Core/Editor.swift:51
public class Editor: NSObject {
  public func update(_ closure: @escaping () throws -> Void) throws
  public func getEditorState() -> EditorState
  public func setEditorState(_ editorState: EditorState) throws
}

// File: Lexical/Core/EditorState.swift:17
public class EditorState: NSObject {
  public func toJSON() throws -> String
  public static func fromJSON(json: String, editor: Editor) throws -> EditorState
  public func read<V>(closure: () throws -> V) throws -> V
}
```

#### Node Manipulation (within update blocks)
```swift
// File: Lexical/Core/Nodes/Node.swift
func getRoot() -> RootNode?
func getSelection() throws -> BaseSelection?
func createParagraphNode() -> ParagraphNode
func createHeadingNode(headingTag: HeadingTagType) -> HeadingNode
func createTextNode(text: String) -> TextNode
```

#### Markdown Conversion
```swift
// File: Plugins/LexicalMarkdown/LexicalMarkdown/LexicalMarkdown.swift:24
public class func generateMarkdown(
  from editor: Editor,
  selection: BaseSelection?
) throws -> String
```

#### Text Formatting Commands
```swift
// File: Playground/LexicalPlayground/ToolbarPlugin.swift:370
editor?.dispatchCommand(type: .formatText, payload: TextFormatType.bold)
editor?.dispatchCommand(type: .formatText, payload: TextFormatType.italic)
editor?.dispatchCommand(type: .insertUnorderedList)
editor?.dispatchCommand(type: .insertOrderedList)
```

---

## Proposed Swift API Design

### Core Components

```swift
import Lexical
import LexicalMarkdown
import LexicalListPlugin
import LexicalLinkPlugin
import UIKit

// MARK: - Type-Safe Configuration

public struct MarkdownEditorConfiguration {
    public let theme: MarkdownTheme
    public let features: MarkdownFeatureSet
    public let behavior: EditorBehavior
    
    public init(
        theme: MarkdownTheme = .default,
        features: MarkdownFeatureSet = .standard,
        behavior: EditorBehavior = .default
    ) {
        self.theme = theme
        self.features = features
        self.behavior = behavior
    }
}

public struct MarkdownFeatureSet: OptionSet {
    public let rawValue: Int
    
    public static let headers = MarkdownFeatureSet(rawValue: 1 << 0)
    public static let lists = MarkdownFeatureSet(rawValue: 1 << 1)
    public static let codeBlocks = MarkdownFeatureSet(rawValue: 1 << 2)
    public static let quotes = MarkdownFeatureSet(rawValue: 1 << 3)
    public static let links = MarkdownFeatureSet(rawValue: 1 << 4)
    public static let inlineFormatting = MarkdownFeatureSet(rawValue: 1 << 5)
    
    public static let standard: MarkdownFeatureSet = [
        .headers, .lists, .codeBlocks, .quotes, .links, .inlineFormatting
    ]
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

// MARK: - Result Types

public enum MarkdownEditorResult<T> {
    case success(T)
    case failure(MarkdownEditorError)
    
    public var value: T? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
}

public enum MarkdownEditorError: LocalizedError {
    case invalidMarkdown(String)
    case serializationFailed
    case editorStateCorrupted
    case unsupportedFeature(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidMarkdown(let details):
            return "Invalid markdown format: \(details)"
        case .serializationFailed:
            return "Failed to serialize editor state"
        case .editorStateCorrupted:
            return "Editor state is corrupted"
        case .unsupportedFeature(let feature):
            return "Unsupported feature: \(feature)"
        }
    }
}

// MARK: - Document Model

public struct MarkdownDocument {
    public let content: String
    public let metadata: DocumentMetadata
    
    public init(content: String, metadata: DocumentMetadata = .default) {
        self.content = content
        self.metadata = metadata
    }
}

public struct DocumentMetadata {
    public let createdAt: Date
    public let modifiedAt: Date
    public let version: String
    
    public static let `default` = DocumentMetadata(
        createdAt: Date(),
        modifiedAt: Date(),
        version: "1.0"
    )
    
    public init(createdAt: Date, modifiedAt: Date, version: String) {
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.version = version
    }
}

// MARK: - Formatting Types

public enum MarkdownBlockType: CaseIterable {
    case paragraph
    case heading(level: HeadingLevel)
    case codeBlock
    case quote
    case unorderedList
    case orderedList
    
    public enum HeadingLevel: Int, CaseIterable {
        case h1 = 1, h2, h3, h4, h5
        
        var lexicalType: HeadingTagType {
            switch self {
            case .h1: return .h1
            case .h2: return .h2
            case .h3: return .h3
            case .h4: return .h4
            case .h5: return .h5
            }
        }
    }
}

public struct InlineFormatting: OptionSet {
    public let rawValue: Int
    
    public static let bold = InlineFormatting(rawValue: 1 << 0)
    public static let italic = InlineFormatting(rawValue: 1 << 1)
    public static let strikethrough = InlineFormatting(rawValue: 1 << 2)
    public static let code = InlineFormatting(rawValue: 1 << 3)
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

// MARK: - Theme System

public struct MarkdownTheme {
    public let typography: TypographyTheme
    public let colors: ColorTheme
    public let spacing: SpacingTheme
    
    public static let `default` = MarkdownTheme(
        typography: .default,
        colors: .default,
        spacing: .default
    )
    
    public init(
        typography: TypographyTheme,
        colors: ColorTheme,
        spacing: SpacingTheme
    ) {
        self.typography = typography
        self.colors = colors
        self.spacing = spacing
    }
}

public struct TypographyTheme {
    public let body: UIFont
    public let h1: UIFont
    public let h2: UIFont
    public let h3: UIFont
    public let h4: UIFont
    public let h5: UIFont
    public let code: UIFont
    
    public static let `default` = TypographyTheme(
        body: .systemFont(ofSize: 16),
        h1: .boldSystemFont(ofSize: 28),
        h2: .boldSystemFont(ofSize: 24),
        h3: .boldSystemFont(ofSize: 20),
        h4: .boldSystemFont(ofSize: 18),
        h5: .boldSystemFont(ofSize: 16),
        code: .monospacedSystemFont(ofSize: 14, weight: .regular)
    )
}

public struct ColorTheme {
    public let text: UIColor
    public let accent: UIColor
    public let code: UIColor
    public let quote: UIColor
    
    public static let `default` = ColorTheme(
        text: .label,
        accent: .systemBlue,
        code: .systemGray,
        quote: .systemGray2
    )
}

public struct SpacingTheme {
    public let paragraph: CGFloat
    public let heading: CGFloat
    public let list: CGFloat
    
    public static let `default` = SpacingTheme(
        paragraph: 8,
        heading: 16,
        list: 4
    )
}

// MARK: - Editor Behavior

public struct EditorBehavior {
    public let autoSave: Bool
    public let autoCorrection: Bool
    public let smartQuotes: Bool
    public let returnKeyBehavior: ReturnKeyBehavior
    
    public enum ReturnKeyBehavior {
        case insertLineBreak
        case insertParagraph
        case smart // Context-aware behavior
    }
    
    public static let `default` = EditorBehavior(
        autoSave: true,
        autoCorrection: true,
        smartQuotes: true,
        returnKeyBehavior: .smart
    )
}
```

### Main Editor Component

```swift
// MARK: - Primary Editor Interface

public final class MarkdownEditor: UIView {
    
    // MARK: - Public Properties
    
    public weak var delegate: MarkdownEditorDelegate?
    
    public var isEditable: Bool = true {
        didSet { lexicalView.isEditable = isEditable }
    }
    
    public var placeholderText: String? {
        didSet { updatePlaceholder() }
    }
    
    // MARK: - Private Properties
    
    private let lexicalView: LexicalView
    private let configuration: MarkdownEditorConfiguration
    
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
        setupEditorListeners()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public API
    
    public func loadMarkdown(_ document: MarkdownDocument) -> MarkdownEditorResult<Void> {
        do {
            // Convert markdown to Lexical state
            let editorState = try convertMarkdownToEditorState(document.content)
            try lexicalView.editor.setEditorState(editorState)
            
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
                    createdAt: Date(), // Would track actual creation time
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
        lexicalView.editor.update {
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
                    lexicalView.editor.dispatchCommand(type: .insertUnorderedList)
                case .orderedList:
                    lexicalView.editor.dispatchCommand(type: .insertOrderedList)
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
    
    private static func createLexicalTheme(from markdownTheme: MarkdownTheme) -> Theme {
        let theme = Theme()
        
        // Configure typography
        theme.paragraph = [
            .font: markdownTheme.typography.body,
            .foregroundColor: markdownTheme.colors.text
        ]
        
        theme.setValue(.heading, withSubtype: "h1", to: [
            .font: markdownTheme.typography.h1,
            .foregroundColor: markdownTheme.colors.text
        ])
        
        theme.setValue(.heading, withSubtype: "h2", to: [
            .font: markdownTheme.typography.h2,
            .foregroundColor: markdownTheme.colors.text
        ])
        
        // Configure other styles...
        
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
        
        return plugins
    }
    
    private func convertMarkdownToEditorState(_ markdown: String) throws -> EditorState {
        // Implementation would parse markdown and create corresponding Lexical nodes
        // This is a complex operation that would require careful markdown parsing
        throw MarkdownEditorError.unsupportedFeature("Markdown import not yet implemented")
    }
    
    private func updatePlaceholder() {
        // Implementation for placeholder text
    }
}

// MARK: - Delegate Protocol

public protocol MarkdownEditorDelegate: AnyObject {
    func markdownEditorDidChange(_ editor: MarkdownEditor)
    func markdownEditor(_ editor: MarkdownEditor, didLoadDocument document: MarkdownDocument)
    func markdownEditor(_ editor: MarkdownEditor, didAutoSave document: MarkdownDocument)
    func markdownEditor(_ editor: MarkdownEditor, didEncounterError error: MarkdownEditorError)
}

// Provide default implementations
public extension MarkdownEditorDelegate {
    func markdownEditorDidChange(_ editor: MarkdownEditor) {}
    func markdownEditor(_ editor: MarkdownEditor, didLoadDocument document: MarkdownDocument) {}
    func markdownEditor(_ editor: MarkdownEditor, didAutoSave document: MarkdownDocument) {}
    func markdownEditor(_ editor: MarkdownEditor, didEncounterError error: MarkdownEditorError) {}
}
```

### Toolbar Component

```swift
// MARK: - Formatting Toolbar

public final class MarkdownFormattingToolbar: UIView {
    
    public weak var editor: MarkdownEditor? {
        didSet { setupEditorObservation() }
    }
    
    private let stackView: UIStackView
    private var formattingButtons: [UIButton] = []
    private var blockTypeButton: UIButton!
    
    public init() {
        self.stackView = UIStackView()
        super.init(frame: .zero)
        setupView()
        setupButtons()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(stackView)
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
    private func setupButtons() {
        // Block type selector
        blockTypeButton = createBlockTypeButton()
        stackView.addArrangedSubview(blockTypeButton)
        
        // Separator
        stackView.addArrangedSubview(createSeparator())
        
        // Formatting buttons
        let boldButton = createFormattingButton(
            formatting: .bold,
            image: UIImage(systemName: "bold"),
            accessibilityLabel: "Bold"
        )
        
        let italicButton = createFormattingButton(
            formatting: .italic,
            image: UIImage(systemName: "italic"),
            accessibilityLabel: "Italic"
        )
        
        let strikethroughButton = createFormattingButton(
            formatting: .strikethrough,
            image: UIImage(systemName: "strikethrough"),
            accessibilityLabel: "Strikethrough"
        )
        
        let codeButton = createFormattingButton(
            formatting: .code,
            image: UIImage(systemName: "chevron.left.forwardslash.chevron.right"),
            accessibilityLabel: "Inline Code"
        )
        
        formattingButtons = [boldButton, italicButton, strikethroughButton, codeButton]
        formattingButtons.forEach { stackView.addArrangedSubview($0) }
    }
    
    private func createFormattingButton(
        formatting: InlineFormatting,
        image: UIImage?,
        accessibilityLabel: String
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(image, for: .normal)
        button.accessibilityLabel = accessibilityLabel
        
        button.addAction(UIAction { [weak self] _ in
            self?.editor?.applyFormatting(formatting)
        }, for: .touchUpInside)
        
        return button
    }
    
    private func createBlockTypeButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "paragraph"), for: .normal)
        button.showsMenuAsPrimaryAction = true
        button.menu = createBlockTypeMenu()
        return button
    }
    
    private func createBlockTypeMenu() -> UIMenu {
        let actions = [
            UIAction(title: "Paragraph", image: UIImage(systemName: "paragraph")) { [weak self] _ in
                self?.editor?.setBlockType(.paragraph)
            },
            UIAction(title: "Heading 1", image: UIImage(systemName: "h.square")) { [weak self] _ in
                self?.editor?.setBlockType(.heading(level: .h1))
            },
            UIAction(title: "Heading 2", image: UIImage(systemName: "h.square")) { [weak self] _ in
                self?.editor?.setBlockType(.heading(level: .h2))
            },
            UIAction(title: "Code Block", image: UIImage(systemName: "chevron.left.forwardslash.chevron.right")) { [weak self] _ in
                self?.editor?.setBlockType(.codeBlock)
            },
            UIAction(title: "Quote", image: UIImage(systemName: "quote.opening")) { [weak self] _ in
                self?.editor?.setBlockType(.quote)
            },
            UIAction(title: "Bullet List", image: UIImage(systemName: "list.bullet")) { [weak self] _ in
                self?.editor?.setBlockType(.unorderedList)
            },
            UIAction(title: "Numbered List", image: UIImage(systemName: "list.number")) { [weak self] _ in
                self?.editor?.setBlockType(.orderedList)
            }
        ]
        
        return UIMenu(title: "Block Type", children: actions)
    }
    
    private func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return separator
    }
    
    private func setupEditorObservation() {
        // Would observe editor state changes to update button states
    }
    
    private func updateButtonStates() {
        guard let editor = editor else { return }
        
        let currentFormatting = editor.getCurrentFormatting()
        let currentBlockType = editor.getCurrentBlockType()
        
        // Update formatting button states
        // Update block type button
    }
}
```

---

## Implementation Strategy

### Phase 1: Core Editor Foundation
1. **Basic Editor Setup** - Configure LexicalView with required plugins
2. **Theme Integration** - Map MarkdownTheme to Lexical Theme system
3. **Basic Formatting** - Implement inline formatting commands
4. **Export Functionality** - Integrate LexicalMarkdown for output

### Phase 2: Advanced Features
1. **Markdown Import** - Build markdown parsing and state conversion
2. **Toolbar Component** - Create responsive formatting toolbar
3. **Block Type Management** - Implement heading, list, quote controls
4. **State Management** - Add auto-save and persistence

### Phase 3: Polish & Integration
1. **Error Handling** - Comprehensive error recovery
2. **Accessibility** - VoiceOver and accessibility support
3. **Performance Optimization** - Large document handling
4. **Testing** - Unit and integration test suite

### Key Implementation Files

```
MarkdownEditor/
├── Core/
│   ├── MarkdownEditor.swift          // Main editor component
│   ├── MarkdownDocument.swift        // Document model
│   └── MarkdownConfiguration.swift   // Configuration types
├── UI/
│   ├── MarkdownFormattingToolbar.swift // Formatting controls
│   └── MarkdownTheme.swift           // Theme system
├── Conversion/
│   ├── MarkdownImporter.swift        // Markdown → Lexical conversion
│   └── MarkdownExporter.swift        // Lexical → Markdown conversion
└── Extensions/
    ├── LexicalExtensions.swift       // Lexical framework extensions
    └── HeadingNodeExtensions.swift   // Additional node functionality
```

---

## Technical Considerations

### Performance
- **Large Documents**: Lexical's virtual scrolling handles large content efficiently
- **Real-time Updates**: Framework's reconciler minimizes DOM manipulation
- **Memory Management**: Immutable EditorState prevents memory leaks

### Accessibility
- **VoiceOver Support**: TextKit integration provides native accessibility
- **Keyboard Navigation**: Full keyboard support via UITextView foundation
- **Dynamic Type**: Theme system supports iOS Dynamic Type scaling

### Platform Integration
- **iOS Native**: Built on UIKit/TextKit for authentic iOS experience  
- **Keyboard Shortcuts**: Hardware keyboard support via responder chain
- **Context Menus**: Native iOS context menu integration

### Limitations & Workarounds
- **Nested Lists**: Some complexity noted in framework (functional but not perfect)
- **Checkbox Lists**: Framework recognizes but needs custom implementation
- **Custom Markdown**: Extensions require protocol conformance

---

## Usage Examples

### Basic Implementation

```swift
import UIKit
import MarkdownEditor

class DocumentViewController: UIViewController {
    private let markdownEditor = MarkdownEditor(
        configuration: MarkdownEditorConfiguration(
            theme: .default,
            features: .standard
        )
    )
    
    private let toolbar = MarkdownFormattingToolbar()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupEditor()
    }
    
    private func setupEditor() {
        markdownEditor.delegate = self
        toolbar.editor = markdownEditor
        
        view.addSubview(toolbar)
        view.addSubview(markdownEditor)
        
        // Layout constraints...
        
        // Load sample content
        let sampleMarkdown = """
        # Welcome to Markdown Editor
        
        This is a **WYSIWYG** markdown editor built with *Lexical iOS*.
        
        ## Features
        
        - Rich text editing
        - Live preview
        - Export to markdown
        
        Enjoy writing!
        """
        
        let document = MarkdownDocument(content: sampleMarkdown)
        _ = markdownEditor.loadMarkdown(document)
    }
}

extension DocumentViewController: MarkdownEditorDelegate {
    func markdownEditorDidChange(_ editor: MarkdownEditor) {
        // Handle content changes
        navigationItem.title = "Document*" // Indicate unsaved changes
    }
    
    func markdownEditor(_ editor: MarkdownEditor, didAutoSave document: MarkdownDocument) {
        // Handle auto-save
        navigationItem.title = "Document" // Clear unsaved indicator
    }
}
```

### Custom Theme Example

```swift
let customTheme = MarkdownTheme(
    typography: TypographyTheme(
        body: .systemFont(ofSize: 18),
        h1: .boldSystemFont(ofSize: 32),
        h2: .boldSystemFont(ofSize: 28),
        h3: .boldSystemFont(ofSize: 24),
        h4: .boldSystemFont(ofSize: 20),
        h5: .boldSystemFont(ofSize: 18),
        code: .monospacedSystemFont(ofSize: 16, weight: .medium)
    ),
    colors: ColorTheme(
        text: .label,
        accent: .systemIndigo,
        code: .systemTeal,
        quote: .systemGray
    ),
    spacing: SpacingTheme(
        paragraph: 12,
        heading: 20,
        list: 6
    )
)

let editor = MarkdownEditor(
    configuration: MarkdownEditorConfiguration(
        theme: customTheme,
        features: [.headers, .lists, .inlineFormatting], // Subset of features
        behavior: EditorBehavior(
            autoSave: false,
            autoCorrection: false,
            smartQuotes: false,
            returnKeyBehavior: .insertParagraph
        )
    )
)
```

---

## Conclusion

The proposed architecture leverages Lexical iOS's strengths while providing a modern, type-safe Swift API. The design emphasizes:

- **Type Safety**: Comprehensive enum and option set usage
- **Result Types**: Explicit error handling via Result pattern
- **Protocol-Oriented**: Flexible delegation and configuration
- **iOS Native**: Platform-appropriate UI patterns and behaviors
- **Framework Compliance**: Uses Lexical exactly as intended

This architecture provides a solid foundation for building a production-quality WYSIWYG markdown editor that feels native to iOS while maintaining full markdown compatibility.