# Clean Cursor Height Implementation

## Overview
This document describes the clean API implementation for customizing cursor height in the Markdown Editor, using a proper delegate pattern instead of workarounds.

## Changes Made

### 1. In lexical-ios Fork (`../lexical-ios`)

#### Added TextViewCursorDelegate Protocol
**File**: `Lexical/TextView/TextView.swift`

```swift
/// Protocol for customizing cursor appearance
@objc public protocol TextViewCursorDelegate: NSObjectProtocol {
  /// Called to determine the cursor height for a given position
  /// - Parameters:
  ///   - textView: The text view requesting cursor customization
  ///   - position: The text position where the cursor will be displayed
  ///   - defaultRect: The default cursor rect calculated by the system
  /// - Returns: The desired cursor rect, or nil to use the default
  @objc optional func textView(_ textView: TextView, cursorRectFor position: UITextPosition, defaultRect: CGRect) -> CGRect
}
```

#### Made Editor Property Public
Changed from:
```swift
let editor: Editor
```
To:
```swift
public let editor: Editor
```

#### Added Cursor Delegate Property
```swift
@objc public weak var cursorDelegate: TextViewCursorDelegate?
```

#### Modified caretRect Method
The `caretRect(for:)` method now checks the delegate first:
```swift
override public func caretRect(for position: UITextPosition) -> CGRect {
    let defaultRect = super.caretRect(for: position)
    
    // Check if delegate wants to customize the cursor
    if let customRect = cursorDelegate?.textView?(self, cursorRectFor: position, defaultRect: defaultRect) {
        return customRect
    }
    
    // Fall back to the existing implementation
    // ... existing code ...
}
```

### 2. In MarkdownEditor

#### Created MarkdownCursorDelegate
**File**: `Sources/MarkdownEditor/MarkdownCursorDelegate.swift`

This delegate:
- Implements `TextViewCursorDelegate`
- Determines block type at cursor position (paragraph, heading, list item)
- Calculates cursor height based on block type's font size
- Uses theme configuration for cursor height multiplier

#### Updated MarkdownEditor
**File**: `Sources/MarkdownEditor/MarkdownEditor.swift`

Added:
- `cursorDelegate` property to hold the delegate instance
- `setupCursorCustomization()` method to configure the delegate
- Sets the delegate on TextView during initialization

## Key Benefits

1. **Clean API**: Uses standard iOS delegate pattern
2. **No Workarounds**: No method swizzling or associated objects
3. **Maintainable**: Changes are in the fork, easy to upstream
4. **Flexible**: Delegate can be swapped or disabled easily
5. **Type Safe**: Proper Swift/Objective-C types throughout

## How It Works

1. TextView calls `caretRect(for:)` when drawing cursor
2. TextView checks if `cursorDelegate` is set
3. If set, calls delegate method with current position
4. Delegate determines block type at position
5. Delegate calculates appropriate cursor height
6. TextView uses the custom rect returned by delegate

## Testing the Implementation

The cursor should now:
- Have consistent height based on block type
- Not flicker or change size with text history
- Show different heights for headings vs paragraphs
- Remain stable on empty lines

## Reverting to Remote Package

When ready to commit changes to the fork and use the remote version:

1. Commit changes in `../lexical-ios`
2. Push to the fork repository
3. Update `Package.swift` to use remote URL again:
   ```swift
   .package(url: "https://github.com/jcfontecha/lexical-ios.git", branch: "main")
   ```
4. Run `swift package resolve`

## Future Considerations

1. **Upstream Contribution**: Consider submitting the cursor delegate API to the main lexical-ios project
2. **Additional Customization**: The delegate could be extended to customize:
   - Cursor color
   - Cursor width
   - Cursor animation
3. **Performance**: Current implementation reads node tree on each call; could be optimized with caching