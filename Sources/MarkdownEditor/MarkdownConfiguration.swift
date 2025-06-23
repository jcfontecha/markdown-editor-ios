import UIKit
import Lexical

// MARK: - Type-Safe Configuration

public struct MarkdownEditorConfiguration {
    public let theme: MarkdownTheme
    public let features: MarkdownFeatureSet
    public let behavior: EditorBehavior
    
    public init(
        theme: MarkdownTheme = .default,
        features: MarkdownFeatureSet = .standard,
        behavior: EditorBehavior = .default
    ) {
        self.theme = theme
        self.features = features
        self.behavior = behavior
    }
}

// MARK: - Fluent Configuration API

public extension MarkdownEditorConfiguration {
    /// Configure the editor theme
    func theme(_ theme: MarkdownTheme) -> MarkdownEditorConfiguration {
        return MarkdownEditorConfiguration(
            theme: theme,
            features: self.features,
            behavior: self.behavior
        )
    }
    
    /// Configure the enabled features
    func features(_ features: MarkdownFeatureSet) -> MarkdownEditorConfiguration {
        return MarkdownEditorConfiguration(
            theme: self.theme,
            features: features,
            behavior: self.behavior
        )
    }
    
    /// Configure the editor behavior
    func behavior(_ behavior: EditorBehavior) -> MarkdownEditorConfiguration {
        return MarkdownEditorConfiguration(
            theme: self.theme,
            features: self.features,
            behavior: behavior
        )
    }
}

public struct MarkdownFeatureSet: OptionSet {
    public let rawValue: Int
    
    public static let headers = MarkdownFeatureSet(rawValue: 1 << 0)
    public static let lists = MarkdownFeatureSet(rawValue: 1 << 1)
    public static let codeBlocks = MarkdownFeatureSet(rawValue: 1 << 2)
    public static let quotes = MarkdownFeatureSet(rawValue: 1 << 3)
    public static let links = MarkdownFeatureSet(rawValue: 1 << 4)
    public static let inlineFormatting = MarkdownFeatureSet(rawValue: 1 << 5)
    
    public static let standard: MarkdownFeatureSet = [
        .headers, .lists, .codeBlocks, .quotes, .links, .inlineFormatting
    ]
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

// MARK: - Result Types

public enum MarkdownEditorResult<T> {
    case success(T)
    case failure(MarkdownEditorError)
    
    public var value: T? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
}

public extension MarkdownEditorConfiguration {
    /// Default configuration with balanced settings for most use cases
    static let `default` = MarkdownEditorConfiguration(
        theme: .default,
        features: .standard,
        behavior: .default
    )
}

public enum MarkdownEditorError: LocalizedError {
    case invalidMarkdown(String)
    case serializationFailed
    case editorStateCorrupted
    case unsupportedFeature(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidMarkdown(let details):
            return "Invalid markdown format: \(details)"
        case .serializationFailed:
            return "Failed to serialize editor state"
        case .editorStateCorrupted:
            return "Editor state is corrupted"
        case .unsupportedFeature(let feature):
            return "Unsupported feature: \(feature)"
        }
    }
}

// MARK: - Editor Behavior

public struct EditorBehavior {
    public let autoSave: Bool
    public let autoCorrection: Bool
    public let smartQuotes: Bool
    public let returnKeyBehavior: ReturnKeyBehavior
    
    public enum ReturnKeyBehavior {
        case insertLineBreak
        case insertParagraph
        case smart // Context-aware behavior
    }
    
    public init(
        autoSave: Bool,
        autoCorrection: Bool,
        smartQuotes: Bool,
        returnKeyBehavior: ReturnKeyBehavior
    ) {
        self.autoSave = autoSave
        self.autoCorrection = autoCorrection
        self.smartQuotes = smartQuotes
        self.returnKeyBehavior = returnKeyBehavior
    }
    
    public static let `default` = EditorBehavior(
        autoSave: true,
        autoCorrection: true,
        smartQuotes: true,
        returnKeyBehavior: .smart
    )
}

// MARK: - Formatting Types

public enum MarkdownBlockType {
    case paragraph
    case heading(level: HeadingLevel)
    case codeBlock
    case quote
    case unorderedList
    case orderedList
    
    public enum HeadingLevel: Int, CaseIterable {
        case h1 = 1, h2, h3, h4, h5
        
        var lexicalType: HeadingTagType {
            switch self {
            case .h1: return .h1
            case .h2: return .h2
            case .h3: return .h3
            case .h4: return .h4
            case .h5: return .h5
            }
        }
    }
}

public struct InlineFormatting: OptionSet {
    public let rawValue: Int
    
    public static let bold = InlineFormatting(rawValue: 1 << 0)
    public static let italic = InlineFormatting(rawValue: 1 << 1)
    public static let strikethrough = InlineFormatting(rawValue: 1 << 2)
    public static let code = InlineFormatting(rawValue: 1 << 3)
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}