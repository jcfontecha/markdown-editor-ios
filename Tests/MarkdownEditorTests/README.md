# MarkdownEditor Testing Framework

This directory contains a comprehensive testing framework for the MarkdownEditor that leverages lexical-ios building blocks to test markdown-specific domain logic and state transitions.

## Overview

The testing framework provides:

- **State Transition Testing**: Test scenarios using the `given(state) → when(action) → then(expectation)` pattern
- **Domain-Specific Utilities**: Pre-built helpers for creating markdown structures
- **Robust Assertions**: Comprehensive expectations for validating editor state
- **Edge Case Coverage**: Utilities for testing complex scenarios and edge cases

## Key Components

### 1. MarkdownTestHelpers.swift

Core testing infrastructure including:

- `MarkdownTestCase`: Base class for all markdown tests
- State transition framework (`given`, `when`, `then`)
- Common actions (`userTypes`, `userPressesBackspace`, etc.)
- Common expectations (`expectHeaderNode`, `expectListNode`, etc.)

### 2. MarkdownNodeTreeHelpers.swift

Utilities for creating complex test scenarios:

- Document structure helpers (multi-paragraph, mixed content)
- Markdown element helpers (headers, lists, code blocks, quotes)
- Complex scenario builders (blog posts, nested structures)

### 3. MarkdownStateTransitionTests.swift

Comprehensive test suites covering:

- Header state transitions
- List operations
- Inline formatting
- Block elements
- Edge cases and performance

## Usage Examples

### Basic State Transition Test

```swift
func testHeaderCreation() {
    given(emptyDocument)
        .when(userTypes("# My Header"))
        .then(expectHeaderNode(.h1, text: "My Header"))
}
```

### Complex State Transition

```swift
func testListItemIndentation() {
    given(unorderedListDocument(items: ["Item 1", "Item 2"]))
        .when(MarkdownTestAction { editor in
            // Custom action to indent second item
            try editor.update {
                // ... indentation logic
            }
        })
        .then(expectNestedListStructure())
}
```

### Multi-Step Operations

```swift
func testComplexEditing() {
    given(blogPostDocument)
        .when(userTypes("\n\nAdditional content"))
        .then(expectNodeStructure({ rootNode in
            return rootNode.getChildrenSize() > 5
        }, description: "Should have additional content"))
}
```

## Available Test States

### Document States
- `emptyDocument`: Clean slate for testing
- `paragraphDocument(text)`: Single paragraph with text
- `headerDocument(level, text)`: Header at specified level
- `mixedContentDocument`: Complex document with multiple element types
- `blogPostDocument`: Realistic blog post structure

### List States
- `unorderedListDocument(items)`: Bullet list with items
- `orderedListDocument(items, startNumber)`: Numbered list
- `nestedListDocument`: Multi-level list structure

### Formatting States
- `formattedTextDocument`: Text with mixed inline formatting
- `codeBlockDocument(code, language)`: Code block
- `quoteDocument(text)`: Quote block

## Available Actions

### Text Input
- `userTypes(text)`: Simulate typing text
- `userSelectsAll`: Select all content
- `userPressesBackspace`: Backspace at current position
- `userPressesBackspaceAtBeginning`: Backspace at element start

### Custom Actions
```swift
MarkdownTestAction { editor in
    try editor.update {
        // Custom editor manipulation
    }
}
```

## Available Expectations

### Structure Expectations
- `expectParagraphNode(text)`: Verify paragraph content
- `expectHeaderNode(level, text)`: Verify header level and text
- `expectListNode(type)`: Verify list type (bullet/number)
- `expectChildCount(count)`: Verify number of root children
- `expectEmptyDocument`: Verify clean document state

### Content Expectations
- `expectDocumentText(text)`: Verify complete document text
- `expectFormattedText(text, bold, italic)`: Verify text formatting
- `expectCodeBlock(code, language)`: Verify code block content
- `expectQuoteBlock(text)`: Verify quote content

### Custom Expectations
```swift
expectNodeStructure({ rootNode in
    // Custom validation logic
    return validationResult
}, description: "Description of expectation")
```

## Writing New Tests

### 1. Choose Your Test Framework

**Swift Testing** (recommended for new tests):
```swift
struct MyMarkdownTests {
    @Test func myTestCase() async throws {
        // Simple unit tests for configuration, etc.
    }
}
```

**XCTest** (for state transition tests):
```swift
class MyMarkdownTests: MarkdownTestCase {
    func testStateTransition() {
        given(initialState)
            .when(action)
            .then(expectation)
    }
}
```

### 2. Create Test Scenarios

1. **Identify the markdown feature to test**
2. **Define the initial state** using helper functions
3. **Specify the user action** (typing, backspace, etc.)
4. **Assert the expected outcome** using expectation helpers

### 3. Test Categories

#### Conversion Tests
Test markdown syntax triggering format changes:
```swift
func testBoldConversion() {
    given(emptyDocument)
        .when(userTypes("**bold**"))
        .then(expectFormattedText(text: "bold", bold: true))
}
```

#### Editing Tests
Test editing operations on existing structures:
```swift
func testHeaderBackspace() {
    given(headerDocument(.h1, "Title"))
        .when(userPressesBackspaceAtBeginning)
        .then(expectParagraphNode(text: "# Title"))
}
```

#### Complex Scenario Tests
Test real-world usage patterns:
```swift
func testDocumentComposition() {
    given(emptyDocument)
        .when(userTypes("# Title\n\nContent with **bold** text"))
        .then(expectMixedStructure())
}
```

## Best Practices

### 1. Test Naming
Use descriptive names that explain the scenario:
- `testTypingHashCreatesHeader`
- `testBackspaceInEmptyListItemRemovesList`
- `testNestedListIndentationStructure`

### 2. Test Organization
Group related tests in separate classes:
- `MarkdownHeaderTests`
- `MarkdownListTests`
- `MarkdownFormattingTests`

### 3. Custom Helpers
Create domain-specific helpers for complex scenarios:
```swift
func documentWithFormattedTable() -> MarkdownTestState {
    // Complex setup logic
}
```

### 4. Error Testing
Test edge cases and error conditions:
```swift
func testMalformedMarkdownHandling() {
    given(emptyDocument)
        .when(userTypes("**unclosed bold"))
        .then(expectGracefulHandling())
}
```

## Performance Testing

Use `measure` blocks for performance-critical operations:
```swift
func testLargeDocumentPerformance() {
    measure {
        given(largeDocument)
            .when(complexOperation)
            .then(expectation)
    }
}
```

## Debugging Tips

### 1. State Inspection
Add debug helpers to inspect editor state:
```swift
.when(MarkdownTestAction { editor in
    try editor.getEditorState().read {
        print("Current state: \(getNodeHierarchy(editorState: editor.getEditorState()))")
    }
})
```

### 2. Incremental Testing
Break complex scenarios into smaller steps:
```swift
func testComplexScenario() {
    given(emptyDocument)
        .when(userTypes("# Header"))
        .then(expectHeaderNode(.h1, text: "Header"))
    
    // Continue with additional steps...
}
```

### 3. Custom Assertions
Create specific assertions for complex validations:
```swift
func expectComplexStructure() -> MarkdownTestExpectation {
    return MarkdownTestExpectation {
        // Detailed validation logic
    }
}
```

## Integration with CI/CD

These tests are designed to run in continuous integration:

- **Fast execution**: State transitions are in-memory operations
- **Deterministic**: No external dependencies or timing issues
- **Comprehensive**: Cover core functionality and edge cases
- **Maintainable**: Clear structure and helper functions

## Contributing

When adding new tests:

1. Follow the established patterns
2. Add helpers to the appropriate file
3. Document complex test scenarios
4. Ensure tests are deterministic and fast
5. Cover both happy path and edge cases

## Future Enhancements

Potential improvements to the testing framework:

1. **Property-based testing**: Generate random markdown input
2. **Snapshot testing**: Compare rendered output
3. **Integration testing**: Test with real UI interactions
4. **Accessibility testing**: Verify VoiceOver compatibility
5. **Localization testing**: Test with different languages