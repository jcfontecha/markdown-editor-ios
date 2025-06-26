import Foundation

// MARK: - Document Model

public struct MarkdownDocument {
    public let content: String
    public let metadata: DocumentMetadata
    
    public init(content: String, metadata: DocumentMetadata = .default) {
        self.content = content
        self.metadata = metadata
    }
}

public struct DocumentMetadata: Equatable {
    public let createdAt: Date
    public let modifiedAt: Date
    public let version: String
    
    public init(createdAt: Date, modifiedAt: Date, version: String) {
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.version = version
    }
    
    public static let `default` = DocumentMetadata(
        createdAt: Date(),
        modifiedAt: Date(),
        version: "1.0"
    )
}