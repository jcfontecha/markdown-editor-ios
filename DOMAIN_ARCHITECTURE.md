# MarkdownEditor Domain Architecture
## Integrating Business Logic with Lexical

### Executive Summary

This document outlines the architecture for adding a testable domain layer to the MarkdownEditor while leveraging Lexical's proven text editing foundation. The approach allows comprehensive unit testing of markdown-specific business rules while working with Lexical's intended patterns, not against them.

### Table of Contents

1. [Problem Statement](#problem-statement)
2. [Lexical API Analysis](#lexical-api-analysis)
3. [Proposed Architecture](#proposed-architecture)
4. [Implementation Plan](#implementation-plan)
5. [Testing Strategy](#testing-strategy)
6. [Code Examples](#code-examples)

## Problem Statement

### Goals
- Create highly unit-testable markdown business logic
- Test markdown-specific constraints and rules without UI dependencies
- Leverage Lexical's proven text editing capabilities
- Work with Lexical's patterns, not against them

### Key Challenge: State-Dependent Behavior
Markdown editing is inherently state-dependent. The same input produces different results based on context:

```
Enter key behavior examples:
- After paragraph text → New paragraph
- After list item text → New list item  
- On empty list item → Convert to paragraph
- Inside code block → Plain newline
- After "# " → New paragraph (not heading)
```

## Lexical API Analysis

### Validated Extension Points

#### 1. Command System ✅
```swift
// Commands can be intercepted before execution
editor.registerCommand(
    type: .deleteCharacter,
    listener: { payload in
        // Return true to handle, false to pass through
        return validateAndHandle(payload)
    }
)
```

#### 2. Plugin Architecture ✅
```swift
class MarkdownDomainPlugin: Plugin {
    func setUp(editor: Editor) {
        // Register listeners and handlers
    }
    func tearDown() {
        // Cleanup
    }
}
```

#### 3. State Management ✅
```swift
// Explicit read/write transactions
try editor.update { /* mutations */ }
try editor.read { /* reads */ }

// State change notifications
editor.registerUpdateListener { active, previous, dirty in
    // React to changes
}
```

#### 4. Node Manipulation ✅
- Rich API for creating/modifying nodes
- Type-safe node creation functions
- Hierarchical node traversal

### Data Flow Analysis

```
User Input → TextView → Lexical Internal Handler → Command Dispatch → State Update → Re-render
                                                         ↑                ↑
                                                  Can Intercept    Can Observe
```

### Key Findings

1. **Command Interception**: Commands can be intercepted, validated, and modified
2. **Plugin Support**: First-class plugin system for extending functionality
3. **State Observation**: Update listeners provide hooks for state synchronization
4. **Local Fork**: We control the Lexical fork, enabling deeper integration if needed

## Proposed Architecture

### Three-Layer Design

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (Thin)                          │
│  - MarkdownEditorView: Coordinates between domain & Lexical │
│  - Delegates business decisions to domain layer             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              Markdown Domain Layer (Testable)               │
│  - Business Rules: Block type constraints, formatting rules │
│  - State Machine: Context-aware command generation          │
│  - Validation: Pre-execution validation of operations       │
│  - Testing Interface: Pure functions for unit testing       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                 Lexical Engine (Foundation)                 │
│  - Text Editing: Selection, cursor, input handling          │
│  - Node Management: Creation, traversal, manipulation       │
│  - Rendering: Platform-specific text rendering              │
│  - Undo/Redo: Built-in history management                  │
└─────────────────────────────────────────────────────────────┘
```

### Integration Points

#### 1. Command Validation Pipeline
```swift
User Action → Domain Validation → Lexical Command → State Update
                     ↑
                Unit Testable
```

#### 2. State Synchronization
```swift
Lexical State Change → Update Listener → Domain State Sync → Business Rule Updates
```

#### 3. Context-Aware Command Generation
```swift
Input Event + Current State → Domain Logic → Appropriate Command(s)
```

## Implementation Plan

### Phase 1: Foundation (Week 1)

#### 1.1 Create Domain Plugin
```swift
class MarkdownDomainPlugin: Plugin {
    private let stateService: MarkdownStateService
    private let validator: MarkdownValidator
    
    func setUp(editor: Editor) {
        registerCommandInterceptors(editor)
        registerStateObservers(editor)
    }
}
```

#### 1.2 Implement State Extraction
```swift
extension MarkdownStateService {
    func extractState(from editor: Editor) -> MarkdownEditorState {
        // Convert Lexical state to domain state
    }
}
```

#### 1.3 Create Command Validators
```swift
class MarkdownValidator {
    func validateFormatting(_ formatting: InlineFormatting, 
                          in state: MarkdownEditorState) -> ValidationResult
    
    func validateBlockTypeChange(_ newType: MarkdownBlockType,
                               at position: DocumentPosition) -> ValidationResult
}
```

### Phase 2: Core Business Logic (Week 2)

#### 2.1 State-Dependent Command Generation
```swift
class MarkdownCommandGenerator {
    func handleEnterKey(state: MarkdownEditorState) -> LexicalCommand {
        switch state.currentContext {
        case .emptyListItem:
            return .convertToParagraph
        case .listItem:
            return .insertNewListItem
        case .heading:
            return .insertParagraph
        // ... etc
        }
    }
}
```

#### 2.2 Formatting Rules Engine
```swift
class MarkdownFormattingRules {
    func canApplyFormatting(_ format: InlineFormatting,
                          to selection: TextRange,
                          in context: BlockContext) -> Bool {
        // Implement markdown-specific rules
    }
}
```

#### 2.3 Block Type Transitions
```swift
class MarkdownBlockTransitions {
    func allowedTransitions(from: MarkdownBlockType) -> [MarkdownBlockType]
    func transitionCommand(from: MarkdownBlockType, to: MarkdownBlockType) -> LexicalCommand
}
```

### Phase 3: Testing Infrastructure (Week 3)

#### 3.1 Enhanced Testable Interface
```swift
protocol MarkdownEditorTestable {
    // Simulation
    func simulateMarkdownSequence(_ sequence: String) -> Result<Void, DomainError>
    func simulateContextualInput(_ input: InputEvent, 
                               in context: MarkdownContext) -> Result<Void, DomainError>
    
    // Validation
    func validateMarkdownRules() -> [RuleViolation]
    func validateStateConsistency() -> Bool
    
    // Inspection
    func getMarkdownAST() -> MarkdownDocument
    func getContextAtCursor() -> MarkdownContext
}
```

#### 3.2 Test Helpers
```swift
class MarkdownTestBuilder {
    func given(_ markdown: String) -> Self
    func when(_ action: MarkdownAction) -> Self
    func then(_ assertion: MarkdownAssertion) -> TestResult
}
```

### Phase 4: Advanced Features (Week 4)

#### 4.1 Smart Lists
- Auto-continuation with proper numbering
- Intelligent indentation
- Tab/Shift-Tab for nesting

#### 4.2 Smart Quotes and Typography
- Context-aware quote conversion
- Em-dash and en-dash handling
- Ellipsis conversion

#### 4.3 Markdown Shortcuts
- Auto-link detection
- Shorthand expansions
- Block quote handling

## Testing Strategy

### Unit Tests (Domain Layer)

```swift
class MarkdownDomainTests: XCTestCase {
    func testEnterOnEmptyListItem() {
        // Given
        let state = MarkdownEditorState(
            currentBlock: .listItem(level: 1, content: ""),
            selection: .endOfBlock
        )
        
        // When  
        let command = domainLogic.handleEnterKey(state)
        
        // Then
        XCTAssertEqual(command, .convertBlockToParagraph)
    }
    
    func testFormattingInCodeBlock() {
        // Given
        let state = MarkdownEditorState(currentBlock: .codeBlock)
        
        // When
        let canBold = validator.canApplyFormatting(.bold, in: state)
        
        // Then
        XCTAssertFalse(canBold, "Cannot apply formatting in code blocks")
    }
}
```

### Integration Tests (Domain + Lexical)

```swift
class MarkdownIntegrationTests: XCTestCase {
    func testMarkdownRoundTrip() {
        // Given
        let markdown = "# Title\n\n- Item 1\n- Item 2"
        
        // When
        editor.loadMarkdown(markdown)
        let exported = editor.exportMarkdown()
        
        // Then
        XCTAssertEqual(exported, markdown)
    }
}
```

## Code Examples

### Example 1: Context-Aware Enter Key

```swift
extension MarkdownDomainPlugin {
    private func registerEnterKeyHandler(_ editor: Editor) {
        editor.registerCommand(type: .insertParagraph) { [weak self] _ in
            guard let self = self else { return false }
            
            var handled = false
            try? editor.update {
                let state = self.extractCurrentState(editor)
                let command = self.generateEnterCommand(for: state)
                
                switch command {
                case .convertEmptyListToParagraph:
                    self.convertCurrentListItemToParagraph(editor)
                    handled = true
                case .insertNewListItem:
                    self.insertNewListItem(editor)
                    handled = true
                default:
                    handled = false // Let Lexical handle
                }
            }
            
            return handled
        }
    }
}
```

### Example 2: Formatting Validation

```swift
extension MarkdownDomainPlugin {
    private func registerFormattingValidator(_ editor: Editor) {
        editor.registerCommand(type: .formatText) { [weak self] payload in
            guard let self = self else { return false }
            
            let state = self.extractCurrentState(editor)
            let validation = self.validator.canApplyFormatting(payload, in: state)
            
            if !validation.isValid {
                // Optionally show user feedback
                self.delegate?.markdownEditor(didRejectFormatting: payload, 
                                            reason: validation.reason)
                return true // Handled (by rejecting)
            }
            
            return false // Let Lexical apply the formatting
        }
    }
}
```

### Example 3: Smart List Continuation

```swift
class SmartListHandler {
    func handleListItemCreation(in editor: Editor, afterItem: ListItemNode) {
        let itemText = afterItem.getTextContent()
        
        if itemText.isEmpty {
            // Empty item - convert to paragraph
            convertListItemToParagraph(afterItem, in: editor)
        } else if let listNode = afterItem.getParent() as? ListNode {
            // Create new item with proper numbering/bullets
            let newItem = createListItemNode()
            
            if listNode.getListType() == .number {
                // Update numbering for ordered lists
                updateOrderedListNumbering(listNode)
            }
            
            listNode.insertAfter(newItem, afterItem)
            selectStartOfNode(newItem)
        }
    }
}
```

## Benefits of This Architecture

1. **Testability**: Pure domain functions can be unit tested without UI
2. **Lexical Alignment**: Works with Lexical's patterns, not against them
3. **Maintainability**: Clear separation of concerns
4. **Extensibility**: Easy to add new markdown rules
5. **Performance**: Minimal overhead - validation only when needed
6. **Flexibility**: Can enable/disable domain rules as needed

## Conclusion

This architecture successfully integrates a testable markdown domain layer with Lexical by:
- Using Lexical's plugin system for clean integration
- Intercepting commands for validation without bypassing Lexical
- Maintaining Lexical as the source of truth for state
- Providing a pure, testable domain layer for business rules
- Enabling comprehensive unit testing of markdown behavior

The approach respects Lexical's design philosophy while achieving the goal of highly testable markdown business logic.