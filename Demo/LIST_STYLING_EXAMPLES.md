# List Styling Examples

Your markdown editor now supports customizable list styling! Here's how to use it:

## Quick Start

The default theme now includes improved list styling with proper margins:

```swift
let editor = MarkdownEditor(text: $text, configuration: .default) // Uses improved default styling
```

## Customization Options

### Built-in Presets

```swift
// Compact styling (minimal margins)
let compactEditor = MarkdownEditor(
    text: $text,
    configuration: .init(theme: .compact)
)

// Spacious styling (generous margins) 
let spaciousEditor = MarkdownEditor(
    text: $text,
    configuration: .init(theme: .spacious)
)

// Traditional document styling
let traditionalEditor = MarkdownEditor(
    text: $text,
    configuration: .init(theme: .traditional)
)
```

### Custom List Styling

```swift
let customTheme = MarkdownTheme(
    typography: .default,
    colors: .default,
    spacing: SpacingTheme(
        paragraph: 12,
        heading: 20,
        list: 6,
        listBulletMargin: 24,        // Distance from left edge to bullet
        listBulletTextSpacing: 28,   // Space between bullet and text
        indentSize: 40               // Width of each indent level
    )
)

let customEditor = MarkdownEditor(
    text: $text,
    configuration: .init(theme: customTheme)
)
```

## Theme Properties Explained

- **`listBulletMargin`**: How far bullets are positioned from the left edge
- **`listBulletTextSpacing`**: Gap between the bullet character and text
- **`indentSize`**: How much each nested level indents

## Visual Layout

```
[listBulletMargin] • [listBulletTextSpacing] Text content
[listBulletMargin + indentSize] • [listBulletTextSpacing] Nested item
```

Example with default values (16pt + 20pt + 32pt):
- Bullet: 16pt from left
- Text: 36pt from left 
- Nested bullet: 48pt from left
- Nested text: 68pt from left

## Migration

No breaking changes! Existing code continues to work but now gets better list styling automatically.
