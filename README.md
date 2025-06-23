# MarkdownEditor for iOS

A native iOS WYSIWYG markdown editor built with Swift and the Lexical-iOS framework.

![iOS](https://img.shields.io/badge/iOS-16.0%2B-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.7%2B-orange.svg)
![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)

## Overview

MarkdownEditor provides a production-ready WYSIWYG markdown editing experience for iOS applications. It combines the power of the Lexical-iOS text editing framework with a clean, type-safe Swift API designed for easy integration into iOS apps.

### Key Features

- **🎯 Real-time WYSIWYG editing** - See formatted text as you type
- **📝 Full markdown compatibility** - Import and export standard markdown
- **🎨 Rich formatting support** - Bold, italic, strikethrough, code, headers, lists, quotes
- **📱 Native iOS integration** - Built with UIKit, supports accessibility
- **🎛️ Configurable theming** - Customize typography, colors, and spacing
- **⌨️ Command bar interface** - FluentUI-based formatting toolbar
- **🔒 Type-safe API** - Swift-first design with comprehensive error handling
- **🏗️ Modular architecture** - Clean separation of concerns

## Demo

The repository includes a complete demo application that showcases all features:

- Interactive markdown editing with live preview
- Multiple theme presets (Default, Compact, Spacious, Traditional)
- Formatting toolbar with all markdown features
- Export functionality with markdown viewing
- Comprehensive example implementation

## Requirements

- iOS 16.0+
- Xcode 14.0+
- Swift 5.7+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/jcfontecha/markdown-editor-ios.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/jcfontecha/markdown-editor-ios.git`
3. Select the version and add to your target

## Quick Start

```swift
import MarkdownEditor

class ViewController: UIViewController {
    private let editor = MarkdownEditor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the editor
        view.addSubview(editor)
        editor.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            editor.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            editor.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editor.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Load markdown content
        let document = MarkdownDocument(content: "# Hello World\n\nThis is **bold** text.")
        _ = editor.loadMarkdown(document)
    }
}
```

## Components

### MarkdownEditor

The main editor component that provides WYSIWYG markdown editing:

```swift
let configuration = MarkdownEditorConfiguration(
    theme: .default,
    features: .standard,
    behavior: .default
)
let editor = MarkdownEditor(configuration: configuration)
```

### MarkdownFormattingToolbar

A clean formatting toolbar with buttons for common markdown operations:

```swift
let toolbar = MarkdownFormattingToolbar()
toolbar.editor = editor
toolbar.style = .default // .compact, .spacious
```

### MarkdownCommandBar

A FluentUI-based command bar with scrollable formatting options:

```swift
let commandBar = MarkdownCommandBar()
commandBar.editor = editor

// Use as input accessory view
textView.inputAccessoryView = commandBar
```

## Configuration

### Themes

Choose from predefined themes or create custom ones:

```swift
// Predefined themes
let editor = MarkdownEditor(configuration: .init(theme: .default))
let compactEditor = MarkdownEditor(configuration: .init(theme: .compact))
let spaciousEditor = MarkdownEditor(configuration: .init(theme: .spacious))
let traditionalEditor = MarkdownEditor(configuration: .init(theme: .traditional))
```

### Feature Sets

Control which markdown features are enabled:

```swift
let features: MarkdownFeatureSet = [
    .headers,           // H1-H5 headings
    .lists,             // Bullet and numbered lists
    .codeBlocks,        // Code blocks and inline code
    .quotes,            // Blockquotes
    .links,             // Hyperlinks
    .inlineFormatting   // Bold, italic, strikethrough
]

let editor = MarkdownEditor(configuration: .init(features: features))
```

### Custom Themes

Create your own theme for complete customization:

```swift
let customTheme = MarkdownTheme(
    typography: TypographyTheme(
        body: .systemFont(ofSize: 16),
        h1: .boldSystemFont(ofSize: 28),
        h2: .boldSystemFont(ofSize: 24),
        h3: .boldSystemFont(ofSize: 20),
        h4: .boldSystemFont(ofSize: 18),
        h5: .boldSystemFont(ofSize: 16),
        code: .monospacedSystemFont(ofSize: 14, weight: .regular)
    ),
    colors: ColorTheme(
        text: .label,
        accent: .systemBlue,
        code: .systemGray,
        quote: .systemGray2
    ),
    spacing: SpacingTheme(
        lineSpacing: 8,
        paragraphSpacing: 12,
        headingSpacing: 16,
        listSpacing: 10,
        listItemSpacing: 2,
        // ... additional spacing configuration
    )
)

let editor = MarkdownEditor(configuration: .init(theme: customTheme))
```

## API Reference

### Loading and Exporting Content

```swift
// Load markdown
let document = MarkdownDocument(content: markdownString)
let result = editor.loadMarkdown(document)

switch result {
case .success:
    print("Markdown loaded successfully")
case .failure(let error):
    print("Failed to load: \(error)")
}

// Export markdown
let exportResult = editor.exportMarkdown()
switch exportResult {
case .success(let document):
    print(document.content) // The markdown string
case .failure(let error):
    print("Export failed: \(error)")
}
```

### Applying Formatting

```swift
// Apply inline formatting
editor.applyFormatting(.bold)
editor.applyFormatting([.bold, .italic])

// Set block types
editor.setBlockType(.heading(level: .h1))
editor.setBlockType(.unorderedList)
editor.setBlockType(.orderedList)
editor.setBlockType(.quote)
editor.setBlockType(.codeBlock)
editor.setBlockType(.paragraph)

// Get current formatting
let currentFormatting = editor.getCurrentFormatting()
let currentBlockType = editor.getCurrentBlockType()
```

### Delegate Methods

Implement `MarkdownEditorDelegate` to respond to editor events:

```swift
class MyViewController: UIViewController, MarkdownEditorDelegate {
    func markdownEditorDidChange(_ editor: MarkdownEditor) {
        // Content changed - update UI, enable save button, etc.
    }
    
    func markdownEditor(_ editor: MarkdownEditor, didLoadDocument document: MarkdownDocument) {
        // Document loaded successfully
    }
    
    func markdownEditor(_ editor: MarkdownEditor, didAutoSave document: MarkdownDocument) {
        // Auto-save occurred (if enabled in configuration)
    }
    
    func markdownEditor(_ editor: MarkdownEditor, didEncounterError error: MarkdownEditorError) {
        // Handle errors (invalid markdown, serialization failures, etc.)
    }
}
```

### Editor Behavior Configuration

```swift
let behavior = EditorBehavior(
    autoSave: true,                    // Enable auto-save
    autoCorrection: true,              // Enable auto-correction
    smartQuotes: true,                 // Enable smart quotes
    returnKeyBehavior: .smart          // Smart return key behavior
)

let editor = MarkdownEditor(configuration: .init(behavior: behavior))
```

## Advanced Usage

### Custom Styling

```swift
// List styling presets
let compactTheme = MarkdownTheme.compact      // Minimal spacing
let spaciousTheme = MarkdownTheme.spacious    // Generous spacing  
let traditionalTheme = MarkdownTheme.traditional // Document-style spacing

// Bullet customization
let customSpacing = SpacingTheme(
    // ... other properties
    bulletSizeIncrease: 4,        // Make bullets larger
    bulletWeight: .bold,          // Bold bullets
    bulletVerticalOffset: -1.0    // Adjust bullet positioning
)
```

### Integration Patterns

```swift
// With navigation controller
class DocumentViewController: UIViewController {
    private let editor = MarkdownEditor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add formatting toolbar to navigation
        let toolbar = MarkdownFormattingToolbar(style: .compact)
        toolbar.editor = editor
        
        // Add export button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Export",
            style: .plain,
            target: self,
            action: #selector(exportDocument)
        )
    }
}

// With input accessory view
class ChatViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let commandBar = MarkdownCommandBar()
        commandBar.editor = editor
        editor.textView.inputAccessoryView = commandBar
    }
}
```

## Building and Development

### Package Structure
```
MarkdownEditor/
├── Package.swift                 # Swift Package Manager manifest
├── README.md                     # This file
├── Sources/
│   └── MarkdownEditor/          # Main package source
│       ├── MarkdownEditor.swift          # Main editor component
│       ├── MarkdownConfiguration.swift   # Configuration types
│       ├── MarkdownDocument.swift        # Document model
│       ├── MarkdownTheme.swift           # Theming system
│       ├── MarkdownFormattingToolbar.swift # Formatting toolbar
│       ├── MarkdownCommandBar.swift      # FluentUI command bar
│       ├── MarkdownImporter.swift        # Markdown parsing
│       └── ZeroWidthSpaceFixPlugin.swift # Lexical plugin
├── Tests/
│   └── MarkdownEditorTests/     # Package tests
└── Demo/                        # Example application
    ├── MarkdownEditor.xcodeproj # Demo Xcode project
    └── MarkdownEditor/          # Demo app source
```

### Building

The package builds successfully in Xcode and integrates seamlessly into iOS projects. For command-line building, there may be dependency resolution warnings that don't affect functionality when used in Xcode projects.

```bash
# Build the demo project
cd Demo
open MarkdownEditor.xcodeproj
# Build and run in Xcode
```

## Dependencies

- **[Lexical-iOS](https://github.com/jcfontecha/lexical-ios)** - Forked version of Facebook's Lexical text editing framework
- **[FluentUI](https://github.com/microsoft/fluentui-apple)** - Microsoft's design system for command bar components

## Contributing

We welcome contributions! Please feel free to submit issues, feature requests, and pull requests.

### Development Setup

1. Clone the repository
2. Open `Demo/MarkdownEditor.xcodeproj` in Xcode
3. Build and run the demo to see the editor in action
4. Make your changes to the package source in `Sources/MarkdownEditor/`
5. Test your changes with the demo app

### Guidelines

- Follow Swift API design guidelines
- Maintain backwards compatibility
- Add tests for new features
- Update documentation for API changes
- Ensure all demos continue to work

## License

MIT License - see [LICENSE](LICENSE) file for details.