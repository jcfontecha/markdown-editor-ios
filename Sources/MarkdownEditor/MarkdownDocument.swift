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

