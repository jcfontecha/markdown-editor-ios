# Cursor Height Investigation and Implementation

## Problem Statement
The cursor height in the Markdown Editor was unstable and inconsistent. It would change size depending on:
- Whether the line had never had text typed vs having text typed and then deleted
- The line state (empty vs non-empty)
- Text attributes at runtime

The goal was to create a reliable cursor height that is proportional to the text size of the block type (paragraph, heading, list item).

## Initial Investigation

### 1. Current Implementation Discovery
Found the cursor height implementation in:
- **File**: `.build/checkouts/lexical-ios/Lexical/TextView/TextView.swift`
- **Method**: `caretRect(for position: UITextPosition)` (lines 396-440)

The existing implementation:
```swift
// Dynamically adjusts cursor height based on text spacing
let heightReductionMultiplier: CGFloat = 0.6
let verticalPositionOffset: CGFloat = 0.25
let minimumSpacingThreshold: CGFloat = 2.0

// Reads attributes at cursor position
let paragraphStyle = textStorage.attribute(.paragraphStyle, at: stringLocation, effectiveRange: nil)
let lineSpacing = paragraphStyle?.lineSpacing ?? 0
let paragraphSpacing = paragraphStyle?.paragraphSpacing ?? 0
let paragraphSpacingBefore = paragraphStyle?.paragraphSpacingBefore ?? 0
```

**Problem**: This approach reads text attributes at runtime, which can be inconsistent for empty lines or lines with different text history.

### 2. Understanding the Architecture

#### Text Attribute Flow
- Attributes are applied through `getAttributedStringAttributes(theme:)` on each node type
- `AttributeUtils.attributedStringStyles()` combines attributes from the node hierarchy
- NSParagraphStyle is created when line spacing or paragraph spacing attributes are present

#### Empty Line Handling
- Empty list items use a zero-width space (`\u{200B}`) for bullet rendering
- `ZeroWidthSpaceFixPlugin` handles the double-backspace issue
- Empty paragraphs don't have special handling - they rely on standard text layout

#### Theme System
- MarkdownEditor has its own `MarkdownTheme` structure
- Lexical has a separate `Theme` class
- Themes are converted from MarkdownTheme to Lexical Theme in `createLexicalTheme()`

### 3. Key Dependencies
- `lexical-ios` is included as a Swift Package dependency
- Fork URL: `https://github.com/jcfontecha/lexical-ios.git`
- Package is read-only in `.build` directory

## Initial Approach and Roadblocks

### Attempt 1: Modify TextView's caretRect Method Directly
**Plan**: Edit the `caretRect` method in `.build/checkouts/lexical-ios/Lexical/TextView/TextView.swift`

**Roadblock**: 
```
EACCES: permission denied, open '/Users/juan/Developer/MarkdownEditor/.build/checkouts/lexical-ios/Lexical/TextView/TextView.swift'
```
The `.build` directory is read-only and managed by Swift Package Manager.

### Attempt 2: Create Custom TextView Subclass
**Plan**: Create `MarkdownTextView` that extends `TextView` and overrides `caretRect`

**Roadblock**: 
- `LexicalView` creates its own `TextView` instance internally
- No way to inject a custom TextView class during initialization
- `LexicalView.init()` hardcodes: `self.textView = TextView(editorConfig: editorConfig, featureFlags: featureFlags)`

### Attempt 3: Access Editor Property
**Plan**: Access the `editor` property from TextView to read node information

**Roadblock**:
```swift
error: 'editor' is inaccessible due to 'internal' protection level
```
The `editor` property in TextView is internal, not public.

## Final Solution

### 1. Method Swizzling Approach
Used Objective-C runtime method swizzling to override `caretRect` behavior at runtime:

```swift
public static func enableMarkdownCursorHeight() {
    guard let originalMethod = class_getInstanceMethod(TextView.self, #selector(caretRect(for:))),
          let swizzledMethod = class_getInstanceMethod(TextView.self, #selector(markdownCaretRect(for:))) else {
        return
    }
    
    method_exchangeImplementations(originalMethod, swizzledMethod)
}
```

### 2. Associated Objects for Data Storage
Used `objc_getAssociatedObject` and `objc_setAssociatedObject` to attach data to TextView instances:

```swift
private var markdownThemeKey: UInt8 = 0
private var markdownEditorKey: UInt8 = 0

extension TextView {
    public var markdownTheme: MarkdownTheme? {
        get { objc_getAssociatedObject(self, &markdownThemeKey) as? MarkdownTheme }
        set { objc_setAssociatedObject(self, &markdownThemeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    internal var associatedEditor: Editor? {
        get { objc_getAssociatedObject(self, &markdownEditorKey) as? Editor }
        set { objc_setAssociatedObject(self, &markdownEditorKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
```

**Why Associated Objects?**
- Cannot modify TextView class directly (it's in an external package)
- Cannot subclass TextView (LexicalView won't use our subclass)
- Need to attach additional data (theme and editor reference) to existing TextView instances
- Associated objects allow runtime attachment of properties to any NSObject

### 3. Accessing Editor Through LexicalView
Found that while TextView's `editor` is internal, LexicalView's `editor` is public:

```swift
// In MarkdownEditor init
let textView = lexicalView.textView as TextView
textView.markdownTheme = configuration.theme
textView.associatedEditor = lexicalView.editor  // Access editor through LexicalView
```

### 4. Node Type Detection
Created `getBlockNodeAtCursor()` method to:
- Use the associated editor to read current selection
- Traverse up the node tree to find block-level parent
- Determine font size based on node type and theme

## Implementation Details

### Files Created/Modified

1. **`Sources/MarkdownEditor/TextViewExtensions.swift`** (created)
   - Contains TextView extensions
   - Method swizzling implementation
   - Node detection logic

2. **`Sources/MarkdownEditor/MarkdownTheme.swift`** (modified)
   - Added `cursorHeightMultiplier` and `cursorVerticalOffset` to `SpacingTheme`
   - Updated all theme presets

3. **`Sources/MarkdownEditor/MarkdownEditor.swift`** (modified)
   - Added static initialization to enable method swizzling
   - Set theme and editor on TextView during initialization

### Key Technical Decisions

1. **Method Swizzling vs Other Approaches**
   - Swizzling was the only way to modify behavior without access to source
   - Alternatives considered: Subclassing (blocked), Forking lexical-ios (too heavy)

2. **Block-Type Based Heights**
   - More reliable than reading text attributes
   - Consistent behavior for empty lines
   - Allows different heights for different content types

3. **Theme Integration**
   - Added cursor configuration to existing theme system
   - Maintains consistency with other theme settings
   - Easy to customize per theme preset

## Lessons Learned

1. **Swift Package Limitations**
   - Cannot modify code in `.build` directory
   - Dependencies are read-only
   - Need creative solutions for extending external packages

2. **Lexical Architecture**
   - TextView and Editor have complex interdependencies
   - Not all properties are public
   - LexicalView acts as a facade for accessing internals

3. **iOS Text System**
   - Text attributes can be inconsistent for empty content
   - Cursor height is determined by `caretRect(for:)` method
   - Method swizzling works well for UIKit customization

## Future Considerations

1. **Alternative to Swizzling**
   - Could fork lexical-ios and modify directly
   - Could submit PR to make editor property public
   - Could request customization hooks in LexicalView

2. **Performance**
   - Current solution reads node tree on every cursor movement
   - Could cache node type until selection changes
   - Monitor for any performance issues with large documents

3. **Compatibility**
   - Method swizzling could break with iOS updates
   - Should monitor lexical-ios updates for changes to TextView
   - Consider adding version checks if needed

## Testing Notes

The implementation should be tested with:
- Empty paragraphs
- Empty list items
- Headings of different levels
- Switching between block types
- Lines that have had text typed and deleted
- Different theme presets

The cursor height should remain stable and proportional to the block type's font size in all cases.