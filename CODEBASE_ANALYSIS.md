# MarkdownEditor Codebase Analysis
## Refactoring Guide for Domain-Driven Architecture

### Executive Summary

This document analyzes the current MarkdownEditor codebase and provides a detailed refactoring guide to implement the domain-driven architecture outlined in DOMAIN_ARCHITECTURE.md. The analysis identifies what code needs to be removed, refactored, kept, or built from scratch.

### Table of Contents

1. [Current State Overview](#current-state-overview)
2. [What to Remove](#what-to-remove)
3. [What to Refactor](#what-to-refactor)
4. [What to Keep](#what-to-keep)
5. [What to Build](#what-to-build)
6. [Refactoring Plan](#refactoring-plan)
7. [Risk Assessment](#risk-assessment)

## Current State Overview

### Existing Domain Layer ✅

The domain layer has a solid foundation with:

```
Domain/
├── MarkdownDomainModels.swift      # Core types and abstractions
├── MarkdownStateService.swift      # State management logic
├── MarkdownDocumentService.swift   # Document operations
├── MarkdownFormattingService.swift # Formatting rules
├── MarkdownCommands.swift          # Command pattern implementation
└── MarkdownInputEventProcessor.swift # Input event handling
```

**Key Finding**: The domain layer exists but is NOT connected to the UI layer. The current integration in `MarkdownEditor.swift` is only for testing, not for driving actual behavior.

### Current Architecture Problems

1. **Business Logic in UI Layer**: Complex markdown rules are embedded directly in `MarkdownEditor.swift`
2. **Direct Lexical Manipulation**: No abstraction layer between UI and Lexical
3. **Untestable Logic**: List toggling, block type changes, and formatting rules can't be unit tested
4. **State Synchronization**: No connection between domain state and Lexical state

## What to Remove

### 1. Business Logic from MarkdownEditor.swift

These methods contain business logic that should move to the domain layer:

#### `applyFormatting(_:)` (lines 129-148)
```swift
// REMOVE: Direct Lexical manipulation
public func applyFormatting(_ formatting: InlineFormatting) {
    do {
        try lexicalView.editor.update {
            if formatting.contains(.bold) {
                lexicalView.editor.dispatchCommand(type: .formatText, payload: TextFormatType.bold)
            }
            // ... more formatting
        }
    } catch {
        delegate?.markdownEditor(self, didEncounterError: .editorStateCorrupted)
    }
}
```

#### `setBlockType(_:)` (lines 150-209)
```swift
// REMOVE: Complex business logic embedded in UI
public func setBlockType(_ blockType: MarkdownBlockType) {
    // 60 lines of list toggle logic, block type detection, etc.
    // This is EXACTLY what should be in domain layer!
}
```

### 2. State Query Methods

#### `getCurrentFormatting()` (lines 211-228)
```swift
// REMOVE: Should query domain state instead
public func getCurrentFormatting() -> InlineFormatting {
    var formatting: InlineFormatting = []
    try lexicalView.editor.read {
        // Direct Lexical state reading
    }
    return formatting
}
```

#### `getCurrentBlockType()` (lines 230-260)
```swift
// REMOVE: Should query domain state instead
public func getCurrentBlockType() -> MarkdownBlockType {
    // Direct Lexical node inspection
}
```

### 3. Test-Only Integration

Remove the current domain integration that's only used for testing:
- `simulateTyping(_:)` implementation
- `simulateInputEvents(_:)` implementation
- `getDomainState()` implementation
- `validateOperation(_:)` implementation

## What to Refactor

### 1. Document Operations

#### `loadMarkdown(_:)` → Route through domain
```swift
// CURRENT
public func loadMarkdown(_ document: MarkdownDocument) -> MarkdownEditorResult<Void> {
    try MarkdownImporter.importMarkdown(document.content, into: lexicalView.editor)
    // Direct manipulation
}

// REFACTORED
public func loadMarkdown(_ document: MarkdownDocument) -> MarkdownEditorResult<Void> {
    // 1. Parse and validate through domain
    let parseResult = domainBridge.parseDocument(document)
    
    // 2. Apply to Lexical through bridge
    domainBridge.applyToLexical(parseResult, editor: lexicalView.editor)
    
    // 3. Sync domain state
    domainBridge.syncState()
}
```

#### `exportMarkdown()` → Use domain service
```swift
// REFACTORED
public func exportMarkdown() -> MarkdownEditorResult<MarkdownDocument> {
    return domainBridge.exportDocument()
}
```

### 2. Formatting Operations

Transform these to use domain commands:

```swift
// CURRENT
public func applyFormatting(_ formatting: InlineFormatting) {
    // Direct Lexical calls
}

// REFACTORED
public func applyFormatting(_ formatting: InlineFormatting) {
    let command = domainBridge.createFormattingCommand(formatting)
    domainBridge.execute(command)
}
```

### 3. Block Type Changes

The most complex refactoring - extract list toggle logic:

```swift
// CURRENT: 60 lines of embedded logic
public func setBlockType(_ blockType: MarkdownBlockType) {
    // Complex list detection
    // Toggle logic
    // Direct manipulation
}

// REFACTORED: Delegate to domain
public func setBlockType(_ blockType: MarkdownBlockType) {
    let command = domainBridge.createBlockTypeCommand(blockType)
    domainBridge.execute(command)
}
```

## What to Keep

### 1. Public API Surface ✅
- All public method signatures remain unchanged
- `MarkdownEditorDelegate` protocol stays the same
- Configuration system unchanged

### 2. UI Management ✅
- Lexical view initialization and setup
- Theme creation and application
- Plugin management
- Command bar setup
- Cursor delegate handling

### 3. Platform Integration ✅
- UIView subclassing
- Text view management
- Input accessory view handling
- SwiftUI wrapper support

### 4. Current Working Features ✅
- Basic text editing (via Lexical)
- Markdown import/export (enhance with domain)
- Delegate notifications
- Auto-save functionality

## What to Build

### 1. MarkdownDomainBridge 🆕

The critical missing piece - bridges domain and Lexical:

```swift
class MarkdownDomainBridge {
    private let stateService: MarkdownStateService
    private let commandExecutor: MarkdownCommandExecutor
    private var currentDomainState: MarkdownEditorState
    
    // Synchronize states
    func syncFromLexical(_ editor: Editor) {
        try? editor.read {
            self.currentDomainState = extractState(from: editor)
        }
    }
    
    // Execute domain commands on Lexical
    func execute(_ command: MarkdownCommand) {
        // Validate against domain rules
        guard command.canExecute(on: currentDomainState) else { return }
        
        // Translate to Lexical operations
        try? editor.update {
            applyCommandToLexical(command, editor)
        }
        
        // Update domain state
        syncFromLexical(editor)
    }
}
```

### 2. Missing Domain Commands 🆕

Complete the command implementations:

```swift
// SetBlockTypeCommand - handles complex list logic
class SetBlockTypeCommand: MarkdownCommand {
    func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        // Implement list toggle logic here (testable!)
    }
}

// SmartEnterCommand - context-aware enter handling
class SmartEnterCommand: MarkdownCommand {
    func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        switch state.currentContext {
        case .emptyListItem: // Convert to paragraph
        case .listItem: // New list item
        case .codeBlock: // Plain newline
        // etc.
        }
    }
}
```

### 3. Lexical Command Translator 🆕

Translate domain commands to Lexical operations:

```swift
class LexicalCommandTranslator {
    func translate(_ command: MarkdownCommand, for editor: Editor) -> LexicalOperation {
        switch command {
        case let insert as InsertTextCommand:
            return .insertText(insert.text)
        case let format as ApplyFormattingCommand:
            return .dispatchCommand(.formatText, format.formatting)
        // etc.
        }
    }
}
```

### 4. Enhanced State Extraction 🆕

Extract complete state from Lexical:

```swift
extension MarkdownDomainBridge {
    private func extractState(from editor: Editor) -> MarkdownEditorState {
        // Get selection
        let selection = extractSelection(from: editor)
        
        // Get current block context
        let blockType = detectBlockType(at: selection)
        
        // Get formatting
        let formatting = extractFormatting(at: selection)
        
        // Get document content
        let content = LexicalMarkdown.generateMarkdown(from: editor)
        
        return MarkdownEditorState(
            content: content,
            selection: selection,
            currentFormatting: formatting,
            currentBlockType: blockType
        )
    }
}
```

## Refactoring Plan

### Phase 1: Foundation (Week 1)
1. **Day 1-2**: Build `MarkdownDomainBridge`
2. **Day 3-4**: Implement state synchronization
3. **Day 5**: Add bridge to `MarkdownEditor` as private property

### Phase 2: Command Migration (Week 2)
1. **Day 1-2**: Migrate formatting operations
2. **Day 3-4**: Migrate block type changes (including list logic)
3. **Day 5**: Migrate document operations

### Phase 3: State Management (Week 3)
1. **Day 1-2**: Replace state query methods
2. **Day 3-4**: Implement proper state synchronization
3. **Day 5**: Add validation pipeline

### Phase 4: Testing & Polish (Week 4)
1. **Day 1-2**: Update existing tests
2. **Day 3-4**: Add domain-specific tests
3. **Day 5**: Performance optimization

## Risk Assessment

### Low Risk ✅
- Public API remains unchanged
- Lexical continues to handle rendering
- Incremental refactoring possible

### Medium Risk ⚠️
- State synchronization complexity
- Performance overhead of double state
- Command translation accuracy

### Mitigation Strategies
1. **Feature Flags**: Enable domain layer incrementally
2. **Parallel Implementation**: Keep old code during transition
3. **Comprehensive Testing**: Test each migrated feature
4. **Performance Monitoring**: Track overhead of domain layer

## Code Migration Examples

### Example 1: List Toggle Logic Migration

#### Before (in MarkdownEditor.swift):
```swift
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
    }
```

#### After (in Domain):
```swift
// In MarkdownBlockTypeRules.swift
func shouldToggleList(currentBlock: MarkdownBlock, targetType: MarkdownBlockType) -> BlockAction {
    switch (currentBlock.type, targetType) {
    case (.unorderedList, .unorderedList):
        return .convertToParagraph
    case (.orderedList, .orderedList):
        return .convertToParagraph
    case (_, .unorderedList):
        return .convertToList(type: .bullet)
    case (_, .orderedList):
        return .convertToList(type: .number)
    default:
        return .convert(to: targetType)
    }
}

// Fully unit testable!
```

### Example 2: Smart Enter Key

#### Current (Missing):
```swift
// No context-aware enter handling
```

#### After (in Domain):
```swift
class SmartEnterCommand: MarkdownCommand {
    func execute(on state: MarkdownEditorState) -> Result<MarkdownEditorState, DomainError> {
        let context = analyzeContext(state)
        
        switch context {
        case .emptyListItem(let depth):
            if depth > 0 {
                return outdentListItem(state)
            } else {
                return convertToParagraph(state)
            }
        
        case .afterHeading:
            return insertParagraph(state)
            
        case .inCodeBlock:
            return insertNewline(state)
            
        case .afterListItem:
            return insertListItem(state)
            
        default:
            return insertParagraph(state)
        }
    }
}
```

## Conclusion

The refactoring plan:
1. **Preserves** the working Lexical integration
2. **Extracts** business logic to testable domain layer
3. **Maintains** backward compatibility
4. **Enables** comprehensive unit testing
5. **Improves** code organization and maintainability

The key insight is that most of the domain layer already exists - it just needs to be connected properly. The main work is building the bridge between domain and Lexical, then migrating the business logic from the UI layer to the domain layer.