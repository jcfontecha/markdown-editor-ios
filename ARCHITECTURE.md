# MarkdownEditor Architecture & Data Flow

## Overview

The MarkdownEditor uses a **Domain-Driven Design** with a clear separation between UI, business logic, and the underlying text engine (Lexical). This architecture enables comprehensive unit testing of markdown-specific business rules while leveraging Lexical's proven text editing capabilities.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interaction                         │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  MarkdownEditorView (UI Layer)              │
│  • Thin wrapper around Lexical                              │
│  • Delegates all business logic to domain                   │
│  • Manages view lifecycle and platform integration          │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              MarkdownDomainBridge (Integration)             │
│  • Bridges domain layer with Lexical                        │
│  • Synchronizes state bidirectionally                       │
│  • Translates domain commands to Lexical operations         │
└─────────────┬─────────────────────────────┬─────────────────┘
              ▼                             ▼
┌─────────────────────────┐     ┌─────────────────────────────┐
│   Domain Layer          │     │   Lexical Engine            │
│  • Business Rules       │     │  • Text Editing             │
│  • Commands             │     │  • Node Management          │
│  • State Management     │     │  • Rendering                │
│  • Validation           │     │  • Selection/Cursor         │
└─────────────────────────┘     └─────────────────────────────┘
```

## Component Breakdown

### 1. MarkdownEditorView (UI Layer)

**Purpose**: Thin UI wrapper that coordinates between user interactions and the domain layer.

**Key Properties**:
```swift
private let lexicalView: LexicalView           // The Lexical text editor
private let domainBridge: MarkdownDomainBridge // Bridge to domain logic
public weak var delegate: MarkdownEditorDelegate?
```

**Key Methods**:
```swift
// Public API - delegates to domain
public func applyFormatting(_ formatting: InlineFormatting)
public func setBlockType(_ blockType: MarkdownBlockType)
public func getCurrentFormatting() -> InlineFormatting
public func getCurrentBlockType() -> MarkdownBlockType
public func loadMarkdown(_ document: MarkdownDocument) -> MarkdownEditorResult<Void>
public func exportMarkdown() -> MarkdownEditorResult<MarkdownDocument>
```

### 2. MarkdownDomainBridge

**Purpose**: Critical integration layer that connects the domain layer with Lexical.

**Key Properties**:
```swift
private let stateService: MarkdownStateService
private let documentService: MarkdownDocumentService
private let formattingService: MarkdownFormattingService
private var currentDomainState: MarkdownEditorState
private weak var editor: Editor? // Lexical editor reference
```

**Key Methods**:
```swift
// State synchronization
public func connect(to editor: Editor)
public func syncFromLexical()
public func getCurrentState() -> MarkdownEditorState

// Command execution
public func execute(_ command: MarkdownCommand) -> Result<Void, DomainError>
public func createFormattingCommand(_ formatting: InlineFormatting) -> MarkdownCommand
public func createBlockTypeCommand(_ blockType: MarkdownBlockType) -> MarkdownCommand

// Document operations
public func parseDocument(_ document: MarkdownDocument) -> Result<ParsedMarkdownDocument, DomainError>
public func applyToLexical(_ parsed: ParsedMarkdownDocument, editor: Editor) -> Result<Void, DomainError>
public func exportDocument() -> Result<MarkdownDocument, DomainError>
```

### 3. Domain Layer Components

#### MarkdownCommand (Protocol)
**Purpose**: Encapsulates all editing operations as testable commands.

```swift
protocol MarkdownCommand {
    func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError>
    func canExecute(on state: MarkdownEditorState) -> Bool
    func createUndo(for state: MarkdownEditorState) -> MarkdownCommand?
    var description: String { get }
    var isUndoable: Bool { get }
}
```

**Key Implementations**:
- `SetBlockTypeCommand` - Changes block types with smart list toggle logic
- `ApplyFormattingCommand` - Applies inline formatting (bold, italic, etc.)
- `InsertTextCommand` - Inserts text at a position
- `DeleteTextCommand` - Deletes text in a range

#### MarkdownStateService
**Purpose**: Manages editor state and state transitions.

```swift
protocol MarkdownStateService {
    func createState(from content: String, cursorAt: DocumentPosition) -> Result<MarkdownEditorState, DomainError>
    func updateSelection(to newSelection: TextRange, in state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError>
    func validateState(_ state: MarkdownEditorState) -> ValidationResult
}
```

#### MarkdownFormattingService
**Purpose**: Handles all formatting business rules.

```swift
protocol MarkdownFormattingService {
    func applyInlineFormatting(_ formatting: InlineFormatting, to range: TextRange, in state: MarkdownEditorState, operation: FormattingOperation) -> Result<MarkdownEditorState, DomainError>
    func setBlockType(_ blockType: MarkdownBlockType, at position: DocumentPosition, in state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError>
    func canApplyFormatting(_ formatting: InlineFormatting, to range: TextRange, in state: MarkdownEditorState) -> Bool
}
```

#### MarkdownDocumentService
**Purpose**: Handles document parsing, generation, and manipulation.

```swift
protocol MarkdownDocumentService {
    func parseMarkdown(_ content: String) -> ParsedMarkdownDocument
    func generateMarkdown(from document: ParsedMarkdownDocument) -> String
    func validateDocument(_ content: String) -> ValidationResult
    func insertText(_ text: String, at position: DocumentPosition, in content: String) -> Result<String, DomainError>
}
```

## Data Flow Examples

### Example 1: Applying Bold Formatting

```
1. User clicks Bold button in toolbar
   ↓
2. MarkdownEditorView.applyFormatting(.bold)
   ↓
3. domainBridge.syncFromLexical()
   - Extracts current state from Lexical
   - Updates currentDomainState
   ↓
4. domainBridge.createFormattingCommand(.bold)
   - Creates ApplyFormattingCommand with current selection
   ↓
5. domainBridge.execute(command)
   - Validates command can execute
   - Executes command in domain (pure function)
   - Translates to Lexical operation
   - Applies to Lexical editor
   ↓
6. Lexical updates its internal state and re-renders
```

### Example 2: Smart List Toggle

```
1. User clicks "Bullet List" button while in a bullet list
   ↓
2. MarkdownEditorView.setBlockType(.unorderedList)
   ↓
3. domainBridge.syncFromLexical()
   - Detects current block is already .unorderedList
   ↓
4. domainBridge.createBlockTypeCommand(.unorderedList)
   - Creates SetBlockTypeCommand
   ↓
5. SetBlockTypeCommand.execute()
   - Detects toggle scenario (same type)
   - Changes target to .paragraph
   ↓
6. domainBridge translates to Lexical
   - Calls setBlocksType() with createParagraphNode()
   ↓
7. List converts to paragraph
```

### Example 3: Loading a Markdown Document

```
1. App calls loadMarkdown(document)
   ↓
2. domainBridge.parseDocument(document)
   - Parses markdown into domain model
   - Validates document structure
   ↓
3. domainBridge.applyToLexical(parsed, editor)
   - Clears existing Lexical content
   - Creates Lexical nodes from domain blocks
   - Appends nodes to editor
   ↓
4. domainBridge.syncFromLexical()
   - Updates domain state to match Lexical
   ↓
5. Delegate notified of successful load
```

## Key Design Principles

### 1. **Lexical as Foundation**
- Lexical remains the source of truth for editor state
- All rendering and platform integration handled by Lexical
- Domain layer never bypasses Lexical's mechanisms

### 2. **Domain for Business Logic**
- All markdown-specific rules in domain layer
- Pure functions enable comprehensive unit testing
- Commands encapsulate operations for testability

### 3. **Bidirectional Sync**
- Domain state extracted from Lexical when needed
- Domain commands translated to Lexical operations
- State kept in sync after each operation

### 4. **Clean Separation**
- UI layer has no business logic
- Domain layer has no UI dependencies
- Bridge is the only component that knows both

## Testing Strategy

### Domain Layer Tests
```swift
// Test business logic without UI
func testListToggle() {
    let state = MarkdownEditorState(currentBlockType: .unorderedList)
    let command = SetBlockTypeCommand(blockType: .unorderedList)
    let result = command.execute(on: state)
    
    XCTAssertEqual(result.value?.currentBlockType, .paragraph)
}
```

### Integration Tests
```swift
// Test domain-Lexical integration
func testFormattingApplication() {
    let editor = MarkdownEditorView()
    editor.loadMarkdown(MarkdownDocument(content: "Hello"))
    editor.applyFormatting(.bold)
    
    let exported = editor.exportMarkdown()
    XCTAssertEqual(exported.value?.content, "**Hello**")
}
```

## Benefits

1. **Testability**: Business logic can be tested without UI or Lexical
2. **Maintainability**: Clear separation of concerns
3. **Flexibility**: Can change business rules without touching UI
4. **Reliability**: Lexical handles all complex text editing
5. **Extensibility**: Easy to add new commands and rules

## Future Enhancements

1. **Smart Enter Command**: Context-aware enter key behavior
2. **Validation Pipeline**: Pre-execution validation of operations
3. **Undo/Redo**: Domain-level command history
4. **Performance Monitoring**: Track domain operation overhead
5. **Custom Markdown Extensions**: Easily add new markdown features