import Foundation

public struct Slide {
    public var id: UUID
    public var documentId: UUID
    public var title: String
    public var content: String
    public var order: Int
    
    public init(id: UUID = UUID(), documentId: UUID, title: String, content: String = "", order: Int) {
        self.id = id
        self.documentId = documentId
        self.title = title
        self.content = content
        self.order = order
    }
} 