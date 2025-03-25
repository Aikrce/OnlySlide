import CoreData
import Foundation

@objc(CDUser)
public class CDUser: NSManagedObject, Identifiable {
    public typealias IdentifierType = UUID
    
    @NSManaged public var email: String?
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    
    @NSManaged public var collaboratedDocuments: Set<CDDocument>?
    @NSManaged public var ownedDocuments: Set<CDDocument>?
    @NSManaged public var settings: NSManagedObject?
    @NSManaged public var versions: Set<NSManagedObject>?
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
    }
}

// MARK: - Generated accessors for collaboratedDocuments
extension CDUser {
    @objc(addCollaboratedDocumentsObject:)
    @NSManaged public func addToCollaboratedDocuments(_ value: CDDocument)
    
    @objc(removeCollaboratedDocumentsObject:)
    @NSManaged public func removeFromCollaboratedDocuments(_ value: CDDocument)
    
    @objc(addCollaboratedDocuments:)
    @NSManaged public func addToCollaboratedDocuments(_ values: Set<CDDocument>)
    
    @objc(removeCollaboratedDocuments:)
    @NSManaged public func removeFromCollaboratedDocuments(_ values: Set<CDDocument>)
}

// MARK: - Generated accessors for ownedDocuments
extension CDUser {
    @objc(addOwnedDocumentsObject:)
    @NSManaged public func addToOwnedDocuments(_ value: CDDocument)
    
    @objc(removeOwnedDocumentsObject:)
    @NSManaged public func removeFromOwnedDocuments(_ value: CDDocument)
    
    @objc(addOwnedDocuments:)
    @NSManaged public func addToOwnedDocuments(_ values: Set<CDDocument>)
    
    @objc(removeOwnedDocuments:)
    @NSManaged public func removeFromOwnedDocuments(_ values: Set<CDDocument>)
}

// MARK: - Data Conversion
extension CDUser: EntityModelConvertible {
    public typealias DomainModelType = [String: Any]
    
    /// 转换为数据字典
    public func toDomain() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "name": name
        ]
        
        if let email = email {
            data["email"] = email
        }
        
        return data
    }
    
    /// 从数据字典更新实体
    public func update(from data: [String: Any]) {
        if let name = data["name"] as? String {
            self.name = name
        }
        
        if let email = data["email"] as? String {
            self.email = email
        }
    }
} 