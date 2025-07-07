import UIKit
import Lexical

// MARK: - Type-Safe Configuration

public struct MarkdownEditorConfiguration {
    public let theme: MarkdownTheme
    public let features: MarkdownFeatureSet
    public let behavior: EditorBehavior
    public let logging: LoggingConfiguration
    
    public init(
        theme: MarkdownTheme = .default,
        features: MarkdownFeatureSet = .standard,
        behavior: EditorBehavior = .default,
        logging: LoggingConfiguration = .default
    ) {
        self.theme = theme
        self.features = features
        self.behavior = behavior
        self.logging = logging
    }
}

// MARK: - Fluent Configuration API

public extension MarkdownEditorConfiguration {
    /// Configure the editor theme
    func theme(_ theme: MarkdownTheme) -> MarkdownEditorConfiguration {
        return MarkdownEditorConfiguration(
            theme: theme,
            features: self.features,
            behavior: self.behavior,
            logging: self.logging
        )
    }
    
    /// Configure the enabled features
    func features(_ features: MarkdownFeatureSet) -> MarkdownEditorConfiguration {
        return MarkdownEditorConfiguration(
            theme: self.theme,
            features: features,
            behavior: self.behavior,
            logging: self.logging
        )
    }
    
    /// Configure the editor behavior
    func behavior(_ behavior: EditorBehavior) -> MarkdownEditorConfiguration {
        return MarkdownEditorConfiguration(
            theme: self.theme,
            features: self.features,
            behavior: behavior,
            logging: self.logging
        )
    }
    
    /// Configure the logging behavior
    func logging(_ logging: LoggingConfiguration) -> MarkdownEditorConfiguration {
        return MarkdownEditorConfiguration(
            theme: self.theme,
            features: self.features,
            behavior: self.behavior,
            logging: logging
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
        behavior: .default,
        logging: .default
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
    public let startWithTitle: Bool
    
    public enum ReturnKeyBehavior {
        case insertLineBreak
        case insertParagraph
        case smart // Context-aware behavior
    }
    
    public init(
        autoSave: Bool,
        autoCorrection: Bool,
        smartQuotes: Bool,
        returnKeyBehavior: ReturnKeyBehavior,
        startWithTitle: Bool = true
    ) {
        self.autoSave = autoSave
        self.autoCorrection = autoCorrection
        self.smartQuotes = smartQuotes
        self.returnKeyBehavior = returnKeyBehavior
        self.startWithTitle = startWithTitle
    }
    
    public static let `default` = EditorBehavior(
        autoSave: true,
        autoCorrection: true,
        smartQuotes: true,
        returnKeyBehavior: .smart,
        startWithTitle: true
    )
}

// MARK: - Formatting Types

public enum MarkdownBlockType: Equatable, Hashable {
    case paragraph
    case heading(level: HeadingLevel)
    case codeBlock
    case quote
    case unorderedList
    case orderedList
    
    public enum HeadingLevel: Int, CaseIterable {
        case h1 = 1, h2, h3, h4, h5, h6
        
        var lexicalType: HeadingTagType {
            switch self {
            case .h1: return .h1
            case .h2: return .h2
            case .h3: return .h3
            case .h4: return .h4
            case .h5: return .h5
            case .h6: return .h5  // Map h6 to h5 since HeadingTagType only goes to h5
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

extension InlineFormatting: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        if contains(.bold) { parts.append("bold") }
        if contains(.italic) { parts.append("italic") }
        if contains(.strikethrough) { parts.append("strikethrough") }
        if contains(.code) { parts.append("code") }
        return parts.isEmpty ? "none" : parts.joined(separator: ", ")
    }
}

extension InlineFormatting {
    /// Get the markdown syntax for this formatting
    public var markdownSyntax: (prefix: String, suffix: String) {
        // For simplicity, use the first format found
        if contains(.bold) { return ("**", "**") }
        if contains(.italic) { return ("*", "*") }
        if contains(.strikethrough) { return ("~~", "~~") }
        if contains(.code) { return ("`", "`") }
        return ("", "")
    }
}

// MARK: - Logging Configuration

public struct LoggingConfiguration {
    public let isEnabled: Bool
    public let level: LogLevel
    public let includeTimestamps: Bool
    public let includeDetailedState: Bool
    
    public enum LogLevel: Int, Comparable {
        case none = 0
        case error = 1
        case warning = 2
        case info = 3
        case debug = 4
        case verbose = 5
        
        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    public init(
        isEnabled: Bool = false,
        level: LogLevel = .error,
        includeTimestamps: Bool = false,
        includeDetailedState: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.level = level
        self.includeTimestamps = includeTimestamps
        self.includeDetailedState = includeDetailedState
    }
    
    public static let `default` = LoggingConfiguration()
    
    public static let verbose = LoggingConfiguration(
        isEnabled: true,
        level: .verbose,
        includeTimestamps: true,
        includeDetailedState: true
    )
    
    public static let debug = LoggingConfiguration(
        isEnabled: true,
        level: .debug,
        includeTimestamps: false,
        includeDetailedState: false
    )
    
    public static let production = LoggingConfiguration(
        isEnabled: true,
        level: .error,
        includeTimestamps: true,
        includeDetailedState: false
    )
}