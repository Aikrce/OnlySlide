import CoreData

@objc(DocumentEntity)
public class DocumentEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String?
    @NSManaged public var content: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var metadata: DocumentMetadata?
    @NSManaged public var processingStatus: Int16
    @NSManaged public var sourceURL: URL?
    @NSManaged public var type: Int16
    @NSManaged public var tags: Set<Tag>?
    @NSManaged public var user: User?
    @NSManaged public var slides: Set<Slide>?
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        createdAt = Date()
        updatedAt = Date()
    }
    
    public var status: DocumentStatus {
        get {
            return DocumentStatus(rawValue: Int(processingStatus)) ?? .draft
        }
        set {
            processingStatus = Int16(newValue.rawValue)
        }
    }
    
    @objc(addSlidesObject:)
    @NSManaged public func addToSlides(_ value: Slide)
    
    @objc(removeSlidesObject:)
    @NSManaged public func removeFromSlides(_ value: Slide)
    
    @objc(addSlides:)
    @NSManaged public func addToSlides(_ values: Set<Slide>)
    
    @objc(removeSlides:)
    @NSManaged public func removeFromSlides(_ values: Set<Slide>)
    
    public var documentModel: Document {
        get {
            return Document(
                id: id,
                title: title ?? "",
                content: content ?? "",
                createdAt: createdAt,
                updatedAt: updatedAt,
                metadata: metadata?.description ?? "",
                status: status,
                sourceURL: sourceURL,
                type: DocumentType(rawValue: Int(type)) ?? .unknown,
                tags: tags?.map { $0.tagModel } ?? [],
                user: user?.userModel,
                slides: slides?.map { $0.slideModel } ?? []
            )
        }
        set {
            id = newValue.id
            title = newValue.title
            content = newValue.content
            createdAt = newValue.createdAt
            updatedAt = newValue.updatedAt
            metadata = DocumentMetadata(documentDescription: newValue.metadata)
            status = newValue.status
            sourceURL = newValue.sourceURL
            type = Int16(newValue.type.rawValue)
            // 关系属性需要单独处理
        }
    }
}

extension DocumentEntity {
    static var entityName: String {
        return String(describing: DocumentEntity.self)
    }
}

extension DocumentEntity {
    static func fetchRequest() -> NSFetchRequest<DocumentEntity> {
        return NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
    }
}

// MARK: - Generated accessors for collaborators
extension DocumentEntity {
    @objc(addCollaboratorsObject:)
    @NSManaged public func addToCollaborators(_ value: User)
    
    @objc(removeCollaboratorsObject:)
    @NSManaged public func removeFromCollaborators(_ value: User)
    
    @objc(addCollaborators:)
    @NSManaged public func addToCollaborators(_ values: Set<User>)
    
    @objc(removeCollaborators:)
    @NSManaged public func removeFromCollaborators(_ values: Set<User>)
}

// MARK: - Generated accessors for versions
extension DocumentEntity {
    @objc(addVersionsObject:)
    @NSManaged public func addToVersions(_ value: Version)
    
    @objc(removeVersionsObject:)
    @NSManaged public func removeFromVersions(_ value: Version)
    
    @objc(addVersions:)
    @NSManaged public func addToVersions(_ values: Set<Version>)
    
    @objc(removeVersions:)
    @NSManaged public func removeFromVersions(_ values: Set<Version>)
} 