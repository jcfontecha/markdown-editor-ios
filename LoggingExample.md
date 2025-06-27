# Enhanced Logging Output Examples

With the new logging system, you'll see detailed Lexical node structure along with the markdown content. Here's what the output looks like:

## Example 1: Toggle List Command

```
========================================== COMMAND: Toggle Block Type ==========================================
CONTENT: "# Test Editor\n\nSimple paragraph fo..."
TYPE: [paragraph] SELECTION: (0)
NODES:
RootNode [key: root]
  HeadingNode(h1) [key: abc123]
    TextNode [key: def456] "Test Editor"
  ParagraphNode [key: ghi789] <-- anchor(0) <-- focus(0)
    TextNode [key: jkl012] "Simple paragraph for testing."
ACTION: SetBlockType(unorderedList)

AFTER STATE:
CONTENT: "# Test Editor\n\n- Simple paragraph f..."
TYPE: [list] SELECTION: (0)
NODES:
RootNode [key: root]
  HeadingNode(h1) [key: abc123]
    TextNode [key: def456] "Test Editor"
  ListNode(ul) [key: mno345]
    ListItemNode [key: pqr678] <-- anchor(0) <-- focus(0)
      TextNode [key: stu901] "Simple paragraph for testing."
====================================================================================================
```

## Example 2: Smart Enter in Empty List

```
[ENTER] Empty list item detected, converting to paragraph

========================================== COMMAND: Smart Enter ==========================================
CONTENT: "# Test Editor\n\n- |"
TYPE: [list] SELECTION: (0)
NODES:
RootNode [key: root]
  HeadingNode(h1) [key: abc123]
    TextNode [key: def456] "Test Editor"
  ListNode(ul) [key: mno345]
    ListItemNode [key: pqr678] <-- anchor(0) <-- focus(0)
      TextNode [key: stu901] ""
ACTION: SmartEnter(at: 0)

AFTER STATE:
CONTENT: "# Test Editor\n\n|"
TYPE: [paragraph] SELECTION: (0)
NODES:
RootNode [key: root]
  HeadingNode(h1) [key: abc123]
    TextNode [key: def456] "Test Editor"
  ParagraphNode [key: vwx234] <-- anchor(0) <-- focus(0)
====================================================================================================
```

## Example 3: Text with Formatting

```
========================================== COMMAND: Apply Formatting ==========================================
CONTENT: "This is **bold** and *italic* text"
TYPE: [paragraph] SELECTION: (8-14)
NODES:
RootNode [key: root]
  ParagraphNode [key: abc123]
    TextNode [key: def456] "This is "
    TextNode [key: ghi789] "bold" [bold] <-- anchor(0) <-- focus(4)
    TextNode [key: jkl012] " and "
    TextNode [key: mno345] "italic" [italic]
    TextNode [key: pqr678] " text"
ACTION: ApplyFormatting(strikethrough)

AFTER STATE:
CONTENT: "This is ~~**bold**~~ and *italic* text"
TYPE: [paragraph] SELECTION: (8-14)
NODES:
RootNode [key: root]
  ParagraphNode [key: abc123]
    TextNode [key: def456] "This is "
    TextNode [key: ghi789] "bold" [bold, strikethrough] <-- anchor(0) <-- focus(4)
    TextNode [key: jkl012] " and "
    TextNode [key: mno345] "italic" [italic]
    TextNode [key: pqr678] " text"
====================================================================================================
```

## Key Features of the New Logging:

1. **Node Structure Visualization**: Shows the complete Lexical node tree with indentation
2. **Node Keys**: Each node has a unique key for tracking
3. **Selection Markers**: Shows exactly where the cursor/selection is with `<-- anchor()` and `<-- focus()`
4. **Text Content**: Shows actual text content for TextNodes (truncated if too long)
5. **Formatting Info**: Shows applied formatting like `[bold]`, `[italic]`, etc.
6. **Node Types**: Clear identification of node types (ParagraphNode, ListNode, etc.)

This detailed view helps you understand exactly how Lexical transforms the document structure when commands are executed.