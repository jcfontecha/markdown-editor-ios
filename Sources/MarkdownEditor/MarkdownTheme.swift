import UIKit
import Lexical

// MARK: - Theme System

public struct MarkdownTheme {
    public let typography: TypographyTheme
    public let colors: ColorTheme
    public let spacing: SpacingTheme
    
    public init(
        typography: TypographyTheme,
        colors: ColorTheme,
        spacing: SpacingTheme
    ) {
        self.typography = typography
        self.colors = colors
        self.spacing = spacing
    }
    
    public static let `default` = MarkdownTheme(
        typography: .default,
        colors: .default,
        spacing: .default
    )
    
    // MARK: - List Styling Presets
    
    /// Compact styling with minimal spacing
    public static let compact = MarkdownTheme(
        typography: .default,
        colors: .default,
        spacing: SpacingTheme(
            lineSpacing: 3,
            paragraphSpacing: 4,
            headingSpacing: 6,
            listSpacing: 4,
            listItemSpacing: 0,
            paragraphSpacingBefore: 0,
            headingSpacingBefore: 2,
            listSpacingBefore: 2,
            listBulletMargin: 12,
            listBulletTextSpacing: 14,
            indentSize: 24,
            bulletSizeIncrease: 2,  // Smaller bullet increase for compact
            bulletWeight: .regular,  // Regular weight for minimal style
            bulletVerticalOffset: -0.5,  // Minimal offset for compact
            cursorHeightMultiplier: 1.15,  // Slightly smaller cursor for compact
            cursorVerticalOffset: 0.0  // Top-aligned cursor
        )
    )
    
    /// Spacious styling with generous spacing
    public static let spacious = MarkdownTheme(
        typography: .default,
        colors: .default,
        spacing: SpacingTheme(
            lineSpacing: 14,
            paragraphSpacing: 12,
            headingSpacing: 16,
            listSpacing: 14,
            listItemSpacing: 2,
            paragraphSpacingBefore: 0,
            headingSpacingBefore: 16,
            listSpacingBefore: 12,
            listBulletMargin: 24,
            listBulletTextSpacing: 20,
            indentSize: 48,
            bulletSizeIncrease: 4,  // Larger bullet increase for spacious
            bulletWeight: .semibold,  // Bolder bullets for spacious style
            bulletVerticalOffset: -1.5,  // More offset for larger bullets
            cursorHeightMultiplier: 1.25,  // Larger cursor for spacious
            cursorVerticalOffset: 0.0  // Top-aligned cursor
        )
    )
    
    /// Traditional document styling
    public static let traditional = MarkdownTheme(
        typography: .default,
        colors: .default,
        spacing: SpacingTheme(
            lineSpacing: 8,
            paragraphSpacing: 20,
            headingSpacing: 24,
            listSpacing: 14,
            listItemSpacing: 4,
            paragraphSpacingBefore: 0,
            headingSpacingBefore: 10,  // Traditional spacing before headings
            listSpacingBefore: 6,
            listBulletMargin: 20,
            listBulletTextSpacing: 24,
            indentSize: 36,
            bulletSizeIncrease: 3,  // Standard bullet increase
            bulletWeight: .medium,  // Traditional medium weight
            bulletVerticalOffset: -1.0,  // Standard offset
            cursorHeightMultiplier: 1.2,  // Standard cursor height
            cursorVerticalOffset: 0.0  // Top-aligned cursor
        )
    )
}

public struct TypographyTheme {
    public let body: UIFont
    public let h1: UIFont
    public let h2: UIFont
    public let h3: UIFont
    public let h4: UIFont
    public let h5: UIFont
    public let code: UIFont
    
    public init(
        body: UIFont,
        h1: UIFont,
        h2: UIFont,
        h3: UIFont,
        h4: UIFont,
        h5: UIFont,
        code: UIFont
    ) {
        self.body = body
        self.h1 = h1
        self.h2 = h2
        self.h3 = h3
        self.h4 = h4
        self.h5 = h5
        self.code = code
    }
    
    public static let `default` = TypographyTheme(
        body: .systemFont(ofSize: 16),
        h1: .boldSystemFont(ofSize: 28),
        h2: .boldSystemFont(ofSize: 24),
        h3: .boldSystemFont(ofSize: 20),
        h4: .boldSystemFont(ofSize: 18),
        h5: .boldSystemFont(ofSize: 16),
        code: .monospacedSystemFont(ofSize: 14, weight: .regular)
    )
}

public struct ColorTheme {
    public let text: UIColor
    public let accent: UIColor
    public let code: UIColor
    public let quote: UIColor
    public let backgroundColor: UIColor
    
    public init(
        text: UIColor,
        accent: UIColor,
        code: UIColor,
        quote: UIColor,
        backgroundColor: UIColor
    ) {
        self.text = text
        self.accent = accent
        self.code = code
        self.quote = quote
        self.backgroundColor = backgroundColor
    }
    
    public static let `default` = ColorTheme(
        text: .label,
        accent: .systemBlue,
        code: .systemGray,
        quote: .systemGray2,
        backgroundColor: .systemBackground
    )
}

public struct SpacingTheme {
    public let lineSpacing: CGFloat  // Space between lines within a block
    
    // Spacing after elements
    public let paragraphSpacing: CGFloat  // Space after paragraphs
    public let headingSpacing: CGFloat  // Space after headings  
    public let listSpacing: CGFloat  // Space after lists
    public let listItemSpacing: CGFloat  // Space between list items
    
    // Spacing before elements
    public let paragraphSpacingBefore: CGFloat  // Space before paragraphs
    public let headingSpacingBefore: CGFloat  // Space before headings
    public let listSpacingBefore: CGFloat  // Space before lists
    
    public let listBulletMargin: CGFloat
    public let listBulletTextSpacing: CGFloat
    public let indentSize: CGFloat
    
    // Bullet styling
    public let bulletSizeIncrease: CGFloat  // Points to add to bullet font size
    public let bulletWeight: UIFont.Weight  // Font weight for bullets
    public let bulletVerticalOffset: CGFloat  // Vertical offset to compensate for larger bullets (negative = up)
    
    // Cursor styling
    public let cursorHeightMultiplier: CGFloat  // Multiplier for cursor height relative to font size (e.g., 1.2)
    public let cursorVerticalOffset: CGFloat  // Vertical offset for cursor position (0 = top aligned, 0.5 = centered) 
    
    public init(
        lineSpacing: CGFloat,
        paragraphSpacing: CGFloat,
        headingSpacing: CGFloat,
        listSpacing: CGFloat,
        listItemSpacing: CGFloat,
        paragraphSpacingBefore: CGFloat,
        headingSpacingBefore: CGFloat,
        listSpacingBefore: CGFloat,
        listBulletMargin: CGFloat,
        listBulletTextSpacing: CGFloat,
        indentSize: CGFloat,
        bulletSizeIncrease: CGFloat,
        bulletWeight: UIFont.Weight,
        bulletVerticalOffset: CGFloat,
        cursorHeightMultiplier: CGFloat,
        cursorVerticalOffset: CGFloat
    ) {
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.headingSpacing = headingSpacing
        self.listSpacing = listSpacing
        self.listItemSpacing = listItemSpacing
        self.paragraphSpacingBefore = paragraphSpacingBefore
        self.headingSpacingBefore = headingSpacingBefore
        self.listSpacingBefore = listSpacingBefore
        self.listBulletMargin = listBulletMargin
        self.listBulletTextSpacing = listBulletTextSpacing
        self.indentSize = indentSize
        self.bulletSizeIncrease = bulletSizeIncrease
        self.bulletWeight = bulletWeight
        self.bulletVerticalOffset = bulletVerticalOffset
        self.cursorHeightMultiplier = cursorHeightMultiplier
        self.cursorVerticalOffset = cursorVerticalOffset
    }
    
    public static let `default` = SpacingTheme(
        lineSpacing: 10,  // Spacious line spacing (was 'spacious' values)
        paragraphSpacing: 6,  // Good breathing room after paragraphs
        headingSpacing: 6,  // Space after headings
        listSpacing: 10,  // Space after entire lists
        listItemSpacing: 0,  // No space between list items for clean look
        paragraphSpacingBefore: 0,  // No extra space before paragraphs by default
        headingSpacingBefore: 12,  // Space before headings for separation
        listSpacingBefore: 8,  // Space before lists
        listBulletMargin: 20,
        listBulletTextSpacing: 16,
        indentSize: 40,
        bulletSizeIncrease: 4,  // Make bullets 3pt larger
        bulletWeight: .bold,  // Medium weight for bullets
        bulletVerticalOffset: -4.0,  // Move bullets up slightly to compensate for size
        cursorHeightMultiplier: 1.2,  // Cursor height is 1.2x the font size
        cursorVerticalOffset: 0.0  // Top-aligned cursor
    )
}
