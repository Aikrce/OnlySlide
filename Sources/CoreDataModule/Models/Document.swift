import CoreData
import Foundation

@objc(CDDocument)
public class CDDocument: NSManagedObject, Identifiable {
    public typealias IdentifierType = UUID
    
    @NSManaged public var content: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var id: UUID
    @NSManaged public var metadata: NSObject?
    @NSManaged public var processingStatus: Int16
    @NSManaged public var sourceURL: URL?
    @NSManaged public var title: String
    @NSManaged public var updatedAt: Date
    @NSManaged public var type: String?
    @NSManaged public var tags: [String]?
    @NSManaged public var dimensions: String?
    
    @NSManaged public var collaborators: Set<CDUser>?
    @NSManaged public var owner: CDUser?
    @NSManaged public var slides: Set<CDSlide>?
    @NSManaged public var template: CDTemplate?
    @NSManaged public var versions: Set<NSManagedObject>?
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        updatedAt = Date()
        processingStatus = 0
    }
}

// MARK: - Generated accessors for collaborators
extension CDDocument {
    @objc(addCollaboratorsObject:)
    @NSManaged public func addToCollaborators(_ value: CDUser)
    
    @objc(removeCollaboratorsObject:)
    @NSManaged public func removeFromCollaborators(_ value: CDUser)
    
    @objc(addCollaborators:)
    @NSManaged public func addToCollaborators(_ values: Set<CDUser>)
    
    @objc(removeCollaborators:)
    @NSManaged public func removeFromCollaborators(_ values: Set<CDUser>)
}

// MARK: - Generated accessors for slides
extension CDDocument {
    @objc(addSlidesObject:)
    @NSManaged public func addToSlides(_ value: CDSlide)
    
    @objc(removeSlidesObject:)
    @NSManaged public func removeFromSlides(_ value: CDSlide)
    
    @objc(addSlides:)
    @NSManaged public func addToSlides(_ values: Set<CDSlide>)
    
    @objc(removeSlides:)
    @NSManaged public func removeFromSlides(_ values: Set<CDSlide>)
}

// MARK: - Data Conversion
extension CDDocument: EntityModelConvertible {
    public typealias DomainModelType = [String: Any]
    
    /// 转换为数据字典
    public func toDomain() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "title": title,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "processingStatus": processingStatus,
        ]
        
        if let content = content {
            data["content"] = content
        }
        
        if let metadata = metadata {
            data["metadata"] = metadata
        }
        
        if let sourceURL = sourceURL {
            data["sourceURL"] = sourceURL
        }
        
        if let type = type {
            data["type"] = type
        }
        
        if let tags = tags {
            data["tags"] = tags
        }
        
        if let dimensions = dimensions {
            data["dimensions"] = dimensions
        }
        
        // 处理关联ID
        if let owner = owner {
            data["ownerId"] = owner.id
        }
        
        if let collaborators = collaborators, !collaborators.isEmpty {
            data["collaboratorIds"] = collaborators.map { $0.id }
        }
        
        return data
    }
    
    /// 从数据字典更新实体
    public func update(from data: [String: Any]) {
        if let title = data["title"] as? String {
            self.title = title
        }
        
        if let content = data["content"] as? String {
            self.content = content
        }
        
        if let metadata = data["metadata"] {
            self.metadata = metadata as? NSObject
        }
        
        if let sourceURL = data["sourceURL"] as? URL {
            self.sourceURL = sourceURL
        }
        
        if let type = data["type"] as? String {
            self.type = type
        }
        
        if let tags = data["tags"] as? [String] {
            self.tags = tags
        }
        
        if let dimensions = data["dimensions"] as? String {
            self.dimensions = dimensions
        }
        
        // 更新时间
        self.updatedAt = Date()
    }
} 