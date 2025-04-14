import Foundation

public struct DocumentMetadata {
    public var id: UUID
    public var documentId: UUID
    public var createdDate: Date
    public var modifiedDate: Date
    public var author: String
    
    public init(id: UUID = UUID(), documentId: UUID, createdDate: Date = Date(), modifiedDate: Date = Date(), author: String) {
        self.id = id
        self.documentId = documentId
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.author = author
    }
} 