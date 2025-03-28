import CoreData
import Foundation

@objc(CDTemplate)
public class CDTemplate: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var content: String
    @NSManaged public var category: String?
    @NSManaged public var metadata: [String: String]?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    @NSManaged public var documents: Set<CDDocument>?
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        updatedAt = Date()
    }
}

// MARK: - Generated accessors for documents
extension CDTemplate {
    @objc(addDocumentsObject:)
    @NSManaged public func addToDocuments(_ value: CDDocument)
    
    @objc(removeDocumentsObject:)
    @NSManaged public func removeFromDocuments(_ value: CDDocument)
    
    @objc(addDocuments:)
    @NSManaged public func addToDocuments(_ values: Set<CDDocument>)
    
    @objc(removeDocuments:)
    @NSManaged public func removeFromDocuments(_ values: Set<CDDocument>)
}

// MARK: - Data Conversion
extension CDTemplate {
    /// 转换为数据字典
    public func toDomain() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "name": name,
            "content": content,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
        
        if let category = category {
            data["category"] = category
        }
        
        if let metadata = metadata {
            data["metadata"] = metadata
        }
        
        return data
    }
    
    /// 从数据字典更新实体
    public func update(from data: [String: Any]) {
        if let name = data["name"] as? String {
            self.name = name
        }
        
        if let content = data["content"] as? String {
            self.content = content
        }
        
        if let category = data["category"] as? String {
            self.category = category
        }
        
        if let metadata = data["metadata"] as? [String: String] {
            self.metadata = metadata
        }
        
        // 更新时间
        self.updatedAt = Date()
    }
} 