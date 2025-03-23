import CoreData

@objc(User)
public class User: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var email: String?
    @NSManaged public var collaboratedDocuments: Set<DocumentEntity>?
    @NSManaged public var ownedDocuments: Set<DocumentEntity>?
    @NSManaged public var settings: Settings?
    @NSManaged public var versions: Set<Version>?
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
    }
    
    public var userModel: User {
        get {
            return User(
                id: id,
                name: name,
                email: email,
                collaboratedDocuments: collaboratedDocuments?.map { $0.documentModel } ?? [],
                ownedDocuments: ownedDocuments?.map { $0.documentModel } ?? [],
                settings: settings,
                versions: versions?.map { $0.versionModel } ?? []
            )
        }
        set {
            id = newValue.id
            name = newValue.name
            email = newValue.email
            // 关系属性需要单独处理
        }
    }
}

extension User {
    static var entityName: String {
        return String(describing: User.self)
    }
}

// MARK: - Generated accessors for ownedDocuments
extension User {
    @objc(addOwnedDocumentsObject:)
    @NSManaged public func addToOwnedDocuments(_ value: DocumentEntity)
    
    @objc(removeOwnedDocumentsObject:)
    @NSManaged public func removeFromOwnedDocuments(_ value: DocumentEntity)
    
    @objc(addOwnedDocuments:)
    @NSManaged public func addToOwnedDocuments(_ values: Set<DocumentEntity>)
    
    @objc(removeOwnedDocuments:)
    @NSManaged public func removeFromOwnedDocuments(_ values: Set<DocumentEntity>)
}

// MARK: - Generated accessors for collaboratedDocuments
extension User {
    @objc(addCollaboratedDocumentsObject:)
    @NSManaged public func addToCollaboratedDocuments(_ value: DocumentEntity)
    
    @objc(removeCollaboratedDocumentsObject:)
    @NSManaged public func removeFromCollaboratedDocuments(_ value: DocumentEntity)
    
    @objc(addCollaboratedDocuments:)
    @NSManaged public func addToCollaboratedDocuments(_ values: Set<DocumentEntity>)
    
    @objc(removeCollaboratedDocuments:)
    @NSManaged public func removeFromCollaboratedDocuments(_ values: Set<DocumentEntity>)
}

// MARK: - Generated accessors for versions
extension User {
    @objc(addVersionsObject:)
    @NSManaged public func addToVersions(_ value: Version)
    
    @objc(removeVersionsObject:)
    @NSManaged public func removeFromVersions(_ value: Version)
    
    @objc(addVersions:)
    @NSManaged public func addToVersions(_ values: Set<Version>)
    
    @objc(removeVersions:)
    @NSManaged public func removeFromVersions(_ values: Set<Version>)
} 