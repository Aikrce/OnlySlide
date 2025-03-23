import Foundation

public struct TemplateModel: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var content: String
    public var category: String?
    public var metadata: [String: String]?
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        content: String,
        category: String? = nil,
        metadata: [String: String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.category = category
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 