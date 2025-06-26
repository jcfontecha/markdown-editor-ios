# MarkdownEditor - Claude Documentation

## Repository Overview

This is a Swift package that provides a rich markdown editor for iOS, built on top of Meta's Lexical framework. The editor combines a proven UI framework (Lexical) with a clean domain layer for testing and validation.

## Architecture

### Core Components

1. **Lexical Foundation** (Primary)
   - **LexicalView**: The main text editing component
   - **Lexical Editor**: Handles all real-time editing operations
   - **Lexical Plugins**: Lists, links, markdown import/export
   - **Command System**: Lexical's proven command pattern for operations

2. **Domain Layer** (Testing/Validation)
   - **MarkdownEditorState**: Pure domain model of editor state
   - **MarkdownInputEventProcessor**: Simulate input sequences for testing
   - **MarkdownDocumentService**: Parse/validate markdown content
   - **MarkdownFormattingService**: Business rules for formatting operations
   - **Command Pattern**: Domain commands with undo/redo support

3. **UI Layer**
   - **MarkdownEditorView**: Main editor component (UIKit)
   - **SwiftUIMarkdownEditor**: SwiftUI wrapper
   - **MarkdownCommandBar**: FluentUI-based formatting toolbar
   - **MarkdownCursorDelegate**: Custom cursor height handling

### Design Philosophy

- **Lexical-First**: Lexical remains the single source of truth for all editing operations
- **Lexical Fork Control**: We use a local fork of Lexical that we can modify/extend as needed for our requirements
- **Domain as Testing Layer**: Domain layer provides unit-testable business logic without UI dependencies  
- **Zero Regressions**: Domain integration is additive and doesn't modify existing behavior
- **Clean Separation**: UI concerns handled by Lexical, business logic testable via domain layer

## Build & Test Workflow

### Prerequisites
- Xcode 15.5+
- iOS 16.0+ target
- **Local Lexical fork** at `/Users/juan/Developer/lexical-ios` (we can modify this as needed)

### Building

```bash
# Use Xcode workspace (recommended)
xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -scheme MarkdownEditor -destination 'platform=iOS Simulator,name=iPhone 16' build

# Alternative: Swift Package Manager (may have platform compatibility issues)
swift build --target MarkdownEditor
```

### Testing

```bash
# Run all tests
xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -scheme MarkdownEditor -destination 'platform=iOS Simulator,name=iPhone 16' test

# Note: Some existing tests may fail due to pre-existing issues unrelated to domain integration
```

### Key Test Categories

1. **Domain Layer Tests** (`MarkdownEditorTests.swift`)
   - Input simulation and validation
   - Business rule testing
   - State reflection accuracy
   - Performance validation

2. **Integration Tests** (`MarkdownEditorDomainTests`)
   - Domain ↔ Lexical integration
   - Complex editing scenarios
   - Error recovery patterns

3. **UI Tests** (`MarkdownEditorXCTestExamples`)
   - Comprehensive editing operations
   - Markdown parsing/rendering
   - Selection and navigation

## Development Patterns

### Testing Complex Scenarios

```swift
// Example: Test complex editing sequence without UI
let editor = MarkdownEditorView()
let testable = editor as MarkdownEditorTestable

let events: [InputEvent] = [
    .keystroke(character: "#", modifiers: []),
    .keystroke(character: " ", modifiers: []),
    .keystroke(character: "H", modifiers: []),
    .enter,
    .keystroke(character: "b", modifiers: [.command]) // Bold shortcut
]

let result = testable.simulateInputEvents(events)
let validation = testable.validateDocument()
```

### Domain State Inspection

```swift
// Get current editor state as domain model
let domainState = testable.getDomainState()
print("Content: \(domainState.content)")
print("Block type: \(domainState.currentBlockType)")
print("Formatting: \(domainState.currentFormatting)")
```

### Operation Validation

```swift
// Validate operations before execution
let result = testable.validateOperation {
    editor.applyFormatting([.bold])
    editor.setBlockType(.heading(level: .h1))
}
```

## Dependencies

- **Lexical**: **Local fork** at `/Users/juan/Developer/lexical-ios` (we control this and can modify as needed)
- **FluentUI**: Microsoft's design system (`0.34.2`)
- **swift-markdown**: Apple's markdown parsing (`main` branch)
- **SwiftSoup**: HTML parsing for Lexical (`2.8.8`)

## File Structure

```
Sources/MarkdownEditor/
├── MarkdownEditor.swift              # Main editor component + testable interface
├── SwiftUIMarkdownEditor.swift       # SwiftUI wrapper
├── MarkdownConfiguration.swift       # Configuration types
├── MarkdownCommandBar.swift          # FluentUI toolbar
├── MarkdownCursorDelegate.swift      # Custom cursor handling
├── MarkdownDocument.swift            # Document model
├── MarkdownImporter.swift            # Lexical markdown import
├── ZeroWidthSpaceFixPlugin.swift     # List editing fix
└── Domain/
    ├── MarkdownDomainModels.swift        # Core domain types
    ├── MarkdownStateService.swift       # State management service
    ├── MarkdownDocumentService.swift    # Document operations
    ├── MarkdownFormattingService.swift  # Formatting business logic
    ├── MarkdownCommands.swift           # Command pattern implementation
    └── MarkdownInputEventProcessor.swift # Input simulation

Tests/MarkdownEditorTests/
├── MarkdownEditorTests.swift         # Main test suite with domain examples
├── Domain/
│   ├── MarkdownDomainTests.swift     # Pure domain tests
│   ├── MarkdownInputEventTests.swift # Input simulation tests
│   └── MarkdownStateTransitionTests.swift # State transition tests
└── Testing Infrastructure/           # Comprehensive testing framework
```

## Key Integration Points

### MarkdownEditorTestable Protocol

The main interface for accessing domain testing capabilities:

- `simulateTyping(_:)` - Test typing sequences
- `simulateInputEvents(_:)` - Test complex input patterns  
- `getDomainState()` - Get current state as domain model
- `validateDocument()` - Validate current content
- `validateOperation(_:)` - Validate operations before execution

### Domain ↔ Lexical Bridge

The integration maintains Lexical as the authoritative source while providing domain layer access:

1. **State Reflection**: Domain state reflects current Lexical state
2. **Input Simulation**: Domain events can trigger Lexical operations  
3. **Validation**: Domain rules validate before Lexical execution
4. **Testing**: Complex scenarios testable without UI dependencies

## Performance Considerations

- Domain layer adds minimal runtime overhead
- State reflection only occurs when explicitly requested
- Input simulation is for testing only, not production paths
- Validation is optional and can be disabled in production

## Future Enhancements

- Extend input simulation to cover more Lexical operations
- Add domain-level undo/redo as supplement to Lexical undo
- Enhanced business rule validation
- Performance metrics collection through domain layer
- Advanced testing patterns for complex document scenarios
- **Lexical Fork Modifications**: Since we control the Lexical fork, we can:
  - Add custom node types for specialized markdown elements
  - Extend command system for domain-specific operations
  - Optimize performance for our specific use cases
  - Add hooks for better domain layer integration