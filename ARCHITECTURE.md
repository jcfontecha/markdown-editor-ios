# MarkdownEditor Architecture

## Overview

The MarkdownEditor is a Swift package that provides a rich markdown editor for iOS, built on Meta's Lexical framework with a clean Domain-Driven Design (DDD) architecture for business logic testing and validation.

## Architecture Principles

### 1. Lexical as the Foundation
- **Lexical remains the single source of truth** for all editing operations
- We use a local fork at `/Users/juan/Developer/lexical-ios` for customization
- All UI interactions and rendering go through Lexical's proven patterns

### 2. Domain Layer for Business Logic
- **Pure, testable business logic** without UI dependencies
- Markdown-specific rules and behaviors encapsulated in domain services
- Command pattern for all operations with built-in undo/redo support

### 3. Bridge Pattern Integration
- **MarkdownDomainBridge** connects domain logic to Lexical without breaking patterns
- Bidirectional state synchronization
- Zero modifications to existing Lexical behavior

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interaction                         │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  MarkdownEditorView (UI Layer)              │
│  • Thin wrapper around Lexical                              │
│  • Delegates business logic to domain                       │
│  • Manages view lifecycle                                   │
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

## Core Components

### UI Layer
```
MarkdownEditorView (UIKit)
├── LexicalView (Text editing engine)
├── MarkdownCommandBar (Formatting toolbar)
└── SwiftUIMarkdownEditor (SwiftUI wrapper)
```

### Domain Layer
```
Domain Logic
├── MarkdownCommands (Command pattern operations)
├── MarkdownDomainModels (Pure domain types)
├── MarkdownDocumentService (Document operations)
├── MarkdownFormattingService (Formatting logic)
└── MarkdownStateService (State management)
```

### Integration Layer
```
MarkdownDomainBridge
├── State Synchronization (Lexical ↔ Domain)
├── Command Execution (Domain → Lexical)
└── Command Registration (Lexical → Domain) [NOT IMPLEMENTED]
```

## Data Flow

### 1. Toolbar Action Flow (WORKING ✅)

```
User clicks "Bullet List" button
    ↓
MarkdownEditor.setBlockType(.unorderedList)
    ↓
DomainBridge.syncFromLexical()
    ↓
DomainBridge.createBlockTypeCommand()
    ↓
SetBlockTypeCommand.execute()
    ├── Check current state (e.g., already unorderedList?)
    ├── Apply business logic (smart toggle: list → paragraph)
    └── Return new state
    ↓
DomainBridge.applyToLexical()
    ↓
Lexical updates and re-renders
```

### 2. Keyboard Input Flow (NOT IMPLEMENTED ❌)

```
User presses Enter key
    ↓
[MISSING] Lexical Command System Registration
    ↓
[MISSING] DomainBridge.createSmartEnterCommand()
    ↓
[WOULD] SmartEnterCommand.execute()
    ├── Check context (in list? empty line?)
    ├── Apply smart behavior (exit list if empty)
    └── Return action
    ↓
[WOULD] Return true/false to Lexical
    └── true = handled by domain
    └── false = use Lexical default behavior
```

## Current Implementation Status

### ✅ Fully Integrated Commands

1. **SetBlockTypeCommand**
   - Smart list toggle logic (clicking same list type → paragraph)
   - All block type conversions (heading, quote, code, etc.)
   - Used by: `setBlockType()` method

2. **ApplyFormattingCommand**
   - Bold, italic, code inline formatting
   - Toggle/add/remove operations
   - Used by: `applyFormatting()` method

### ❌ Commands Ready but NOT Integrated

1. **SmartEnterCommand**
   - Would handle: Enter on empty list item → convert to paragraph
   - Would handle: Enter at end of list → smart continuation
   - Status: Implemented but not wired to keyboard events

2. **SmartBackspaceCommand**
   - Would handle: Backspace on empty list item → single press deletion
   - Would handle: Backspace at start of list item → outdent/convert
   - Status: Implemented but not wired to keyboard events

3. **InsertTextCommand** / **DeleteTextCommand**
   - General text operations with domain validation
   - Could enforce markdown rules during typing
   - Status: Implemented but not used

## The Missing Piece: Lexical Command System Integration

### What Lexical Provides

Lexical has a complete command system designed for exactly this use case:

```swift
// Available in Lexical/Core/Editor.swift
public func registerCommand(
    type: CommandType,              // .keyEnter, .keyBackspace, etc.
    listener: @escaping CommandListener,
    priority: CommandPriority = .Editor,
    shouldWrapInUpdateBlock: Bool = true
) -> RemovalHandler

// Available command types include:
CommandType.keyEnter
CommandType.keyBackspace
CommandType.insertText
CommandType.deleteCharacter
CommandType.insertLineBreak
```

### What We Need to Implement

```swift
// In MarkdownEditor.swift - setupEditorListeners()
private func registerDomainCommandHandlers() {
    // Register our smart Enter handler with Lexical's command system
    let enterHandler = lexicalView.editor.registerCommand(
        type: .keyEnter,
        listener: { [weak self] _ in
            guard let self = self else { return false }
            
            // Sync current state
            self.domainBridge.syncFromLexical()
            
            // Check if domain should handle this
            let state = self.domainBridge.currentDomainState
            
            // If in a list and current line is empty
            if (state.currentBlockType == .unorderedList || 
                state.currentBlockType == .orderedList) &&
                self.isCurrentLineEmpty() {
                
                // Create and execute smart enter command
                let command = SmartEnterCommand(
                    at: state.selection.start,
                    context: self.domainBridge.commandContext
                )
                
                let result = self.domainBridge.execute(command)
                
                // Return true = domain handled it
                // Return false = use Lexical's default behavior
                return result.isSuccess
            }
            
            // Let Lexical handle normal enter
            return false
        },
        priority: .High  // Higher priority = earlier in chain
    )
    
    // Store handler for cleanup
    self.commandHandlers.append(enterHandler)
    
    // Similar registration for backspace...
}
```

## Why This Architecture Matters

### What Works Now
1. **Clean Separation**: Business logic is separate from UI
2. **Testability**: All markdown rules can be unit tested
3. **Smart Toggle**: List toggle behavior works perfectly via toolbar
4. **No Regressions**: Existing Lexical functionality preserved

### What's Missing
1. **Keyboard Command Registration**: Smart behaviors only work via toolbar, not keyboard
2. **Real-time Validation**: Can't enforce rules during typing
3. **Complete Domain Control**: Text input bypasses business logic

### The Impact
Without registering domain handlers with Lexical's command system:
- ✅ Click "bullet list" on a bullet → converts to paragraph (WORKS)
- ❌ Press Enter on empty list item → should exit list (DOESN'T WORK)
- ❌ Press Backspace on empty list item → should need only one press (DOESN'T WORK)

## Implementation Roadmap

### Phase 1: Current State ✅
- Domain architecture integrated
- Command pattern implemented
- Smart list toggle working via toolbar
- Comprehensive test suite
- 90%+ domain test coverage

### Phase 2: Lexical Command System Integration 🚧
1. Implement `registerDomainCommandHandlers()` in MarkdownEditor
2. Register `SmartEnterCommand` with Lexical's `.keyEnter` command
3. Register `SmartBackspaceCommand` with Lexical's `.keyBackspace` command
4. Add proper cleanup in `deinit`
5. Test smart behaviors work via keyboard

### Phase 3: Full Domain Control (Future)
- Intercept all text modifications
- Route through `InsertTextCommand`/`DeleteTextCommand`
- Add more smart behaviors:
  - Auto-list continuation
  - Smart quotes
  - Link detection
  - Markdown shortcuts (e.g., `**` → bold)

## Key Integration Points

### MarkdownEditor.swift
```swift
// Current integrations
setBlockType()         ✅ Uses SetBlockTypeCommand
applyFormatting()      ✅ Uses ApplyFormattingCommand  
loadMarkdown()         ✅ Uses domain bridge
exportMarkdown()       ✅ Uses domain bridge

// Missing integration  
registerDomainCommandHandlers()  ❌ NOT IMPLEMENTED
```

### MarkdownDomainBridge.swift
```swift
// Command creation methods
createBlockTypeCommand()      ✅ Used by toolbar
createFormattingCommand()     ✅ Used by toolbar
createSmartEnterCommand()     ❌ Not used (no command registration)
createSmartBackspaceCommand() ❌ Not used (no command registration)
createInsertTextCommand()     ❌ Not used
createDeleteTextCommand()     ❌ Not used
```

## Testing Strategy

### Unit Tests (Domain Layer)
- ✅ Command execution logic
- ✅ Smart toggle behavior
- ✅ Document parsing/serialization
- ✅ Formatting operations
- ✅ State management

### Integration Tests
- ✅ Domain bridge connection
- ✅ Smart list toggle via toolbar
- ❌ Smart enter behavior (blocked by missing command registration)
- ❌ Smart backspace behavior (blocked by missing command registration)

### What Can Be Tested Now
All business logic can be tested in isolation:
```swift
// Domain tests work perfectly
let command = SetBlockTypeCommand(blockType: .unorderedList, ...)
let result = command.execute(on: currentState)
// Assert smart toggle worked
```

### What Can't Be Tested
End-to-end keyboard flows can't be tested because the integration isn't there.

## Summary

The MarkdownEditor successfully implements a Domain-Driven architecture that:

1. **Separates business logic from UI** - All markdown rules are in testable domain layer
2. **Preserves Lexical's strengths** - Uses Lexical as designed, no hacks
3. **Enables smart behaviors** - Like list toggle (click bullet on bullet → paragraph)

However, the implementation is **incomplete**:
- **Toolbar actions** flow through domain ✅
- **Keyboard input** bypasses domain ❌

The architecture is designed to work WITH Lexical through its official `registerCommand` API - this is the proper way to add custom behavior to Lexical commands. The domain commands (`SmartEnterCommand`, `SmartBackspaceCommand`) are ready and tested, waiting to be registered with Lexical's command system.

This represents a **partial success** - the architecture works and provides value, but doesn't yet fulfill the complete vision of having all markdown business logic flow through the testable domain layer.