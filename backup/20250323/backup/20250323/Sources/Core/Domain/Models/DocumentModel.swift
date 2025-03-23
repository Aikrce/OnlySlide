import Foundation

public struct DocumentModel: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let content: String
    public let createdAt: Date
    public let updatedAt: Date
    public let metadata: String
    public let slides: [SlideModel]
    
    public init(id: UUID = UUID(),
                title: String,
                content: String,
                createdAt: Date = Date(),
                updatedAt: Date = Date(),
                metadata: String = "",
                slides: [SlideModel] = []) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.slides = slides
    }
} 