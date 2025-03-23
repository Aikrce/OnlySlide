import Foundation

public struct VersionModel: Codable {
    public let id: UUID
    public let number: Int
    public let createdAt: Date
    public let changes: [String]
    public let metadata: [String: String]
    
    public init(id: UUID = UUID(),
                number: Int,
                createdAt: Date = Date(),
                changes: [String] = [],
                metadata: [String: String] = [:]) {
        self.id = id
        self.number = number
        self.createdAt = createdAt
        self.changes = changes
        self.metadata = metadata
    }
} 