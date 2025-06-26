# MarkdownEditor Data Flow Diagrams

## Sequence Diagrams

### 1. Formatting Command Flow

```mermaid
sequenceDiagram
    participant User
    participant UI as MarkdownEditorView
    participant Bridge as MarkdownDomainBridge
    participant Cmd as ApplyFormattingCommand
    participant Lexical as Lexical Editor
    
    User->>UI: Click Bold Button
    UI->>Bridge: applyFormatting(.bold)
    
    Bridge->>Bridge: syncFromLexical()
    Note over Bridge: Extract current state<br/>from Lexical
    
    Bridge->>Bridge: createFormattingCommand(.bold)
    Note over Bridge: Create command with<br/>current selection
    
    Bridge->>Cmd: execute(command)
    Cmd->>Cmd: canExecute() validation
    Cmd->>Cmd: Apply formatting logic
    Cmd-->>Bridge: Return new state
    
    Bridge->>Lexical: dispatchCommand(.formatText, .bold)
    Lexical->>Lexical: Update internal state
    Lexical->>Lexical: Re-render text
    
    Bridge->>Bridge: syncFromLexical()
    Note over Bridge: Update domain state
    
    UI-->>User: Text appears bold
```

### 2. Smart List Toggle Flow

```mermaid
sequenceDiagram
    participant User
    participant UI as MarkdownEditorView
    participant Bridge as MarkdownDomainBridge
    participant Cmd as SetBlockTypeCommand
    participant Lexical as Lexical Editor
    
    User->>UI: Click Bullet List<br/>(already in list)
    UI->>Bridge: setBlockType(.unorderedList)
    
    Bridge->>Bridge: syncFromLexical()
    Note over Bridge: Current: .unorderedList
    
    Bridge->>Bridge: createBlockTypeCommand(.unorderedList)
    
    Bridge->>Cmd: execute(command)
    Cmd->>Cmd: Detect toggle scenario
    Note over Cmd: Current == Target<br/>Toggle to paragraph
    Cmd-->>Bridge: Return .paragraph state
    
    Bridge->>Lexical: setBlocksType(createParagraphNode)
    Lexical->>Lexical: Convert list to paragraph
    Lexical->>Lexical: Re-render
    
    UI-->>User: List becomes paragraph
```

### 3. Document Loading Flow

```mermaid
sequenceDiagram
    participant App
    participant UI as MarkdownEditorView
    participant Bridge as MarkdownDomainBridge
    participant DocSvc as DocumentService
    participant Lexical as Lexical Editor
    
    App->>UI: loadMarkdown(document)
    UI->>Bridge: parseDocument(document)
    
    Bridge->>DocSvc: parseMarkdown(content)
    DocSvc->>DocSvc: Parse into blocks
    DocSvc->>DocSvc: Validate structure
    DocSvc-->>Bridge: ParsedMarkdownDocument
    
    Bridge->>Bridge: applyToLexical(parsed)
    
    Bridge->>Lexical: Clear existing content
    loop For each block
        Bridge->>Bridge: createLexicalNode(block)
        Bridge->>Lexical: append(node)
    end
    
    Bridge->>Bridge: syncFromLexical()
    Note over Bridge: Update domain state
    
    UI->>App: Notify delegate
    App-->>App: Document loaded
```

## State Management

### Domain State Structure

```
MarkdownEditorState
├── content: String              // Full markdown text
├── selection: TextRange         // Current cursor/selection
├── currentFormatting: InlineFormatting  // Active formats
├── currentBlockType: MarkdownBlockType   // Current block
├── hasUnsavedChanges: Bool
└── metadata: DocumentMetadata
```

### State Synchronization Points

1. **Before Command Execution**
   - `syncFromLexical()` extracts current Lexical state
   - Ensures domain has latest state

2. **After Lexical Operations**
   - `syncFromLexical()` updates domain state
   - Keeps domain in sync with Lexical

3. **On Editor Updates**
   - Update listener triggers sync
   - Maintains consistency during typing

## Command Execution Pipeline

```
1. Create Command
   ├── Capture current state
   ├── Define operation parameters
   └── Set target state

2. Validate Command
   ├── Check if operation is allowed
   ├── Verify state consistency
   └── Apply business rules

3. Execute Command
   ├── Pure function execution
   ├── No side effects
   └── Return new state

4. Apply to Lexical
   ├── Translate to Lexical operations
   ├── Use Lexical's API
   └── Let Lexical handle rendering

5. Sync State
   ├── Extract new Lexical state
   ├── Update domain state
   └── Ready for next command
```

## Error Handling Flow

```mermaid
flowchart TD
    A[User Action] --> B{Domain Validation}
    B -->|Valid| C[Execute Command]
    B -->|Invalid| D[Return Error]
    
    C --> E{Lexical Application}
    E -->|Success| F[Sync State]
    E -->|Failure| G[Rollback State]
    
    D --> H[Show Error to User]
    G --> H
    
    F --> I[Operation Complete]
```

## Performance Considerations

### Optimization Points

1. **Lazy State Extraction**
   - Only extract what's needed
   - Cache frequently accessed state

2. **Batch Operations**
   - Group related commands
   - Single Lexical update transaction

3. **Selective Sync**
   - Only sync changed portions
   - Avoid full state extraction

### Overhead Analysis

```
Operation          | Domain Overhead | Benefit
-------------------|-----------------|------------------
Format Toggle      | ~1ms           | Testable logic
Block Type Change  | ~2ms           | Smart toggles
State Query        | <1ms           | Cached state
Document Parse     | ~5-10ms        | Validation
```

## Testing Boundaries

### Unit Testable (Domain Only)
- Command execution logic
- State transitions
- Business rule validation
- Document parsing/generation

### Integration Tests (Domain + Lexical)
- Command translation
- State synchronization
- End-to-end operations
- Performance validation

### UI Tests (Full Stack)
- User interactions
- Visual feedback
- Platform integration
- Accessibility