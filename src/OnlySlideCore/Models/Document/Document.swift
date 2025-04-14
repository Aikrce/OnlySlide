import Foundation

public struct Document {
    public var id: UUID
    public var title: String
    public var templateId: UUID?
    
    public init(id: UUID = UUID(), title: String, templateId: UUID? = nil) {
        self.id = id
        self.title = title
        self.templateId = templateId
    }
} 