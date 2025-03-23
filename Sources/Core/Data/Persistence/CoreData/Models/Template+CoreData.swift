import Foundation
import CoreData

@objc(Template)
public class Template: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var content: String
    @NSManaged public var category: String?
    @NSManaged public var metadata: [String: String]?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        updatedAt = Date()
    }
}

extension Template {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Template> {
        return NSFetchRequest<Template>(entityName: "Template")
    }
    
    public func toDomain() -> TemplateModel {
        return TemplateModel(
            id: id,
            name: name,
            content: content,
            category: category,
            metadata: metadata,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Domain Model Conversion
extension Template {
    var templateModel: TemplateModel {
        get {
            return TemplateModel(
                id: id,
                name: name,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
                metadata: metadata ?? [:],
                category: category ?? ""
            )
        }
        set {
            id = newValue.id
            name = newValue.name
            content = newValue.content
            createdAt = newValue.createdAt
            updatedAt = newValue.updatedAt
            metadata = newValue.metadata
            category = newValue.category
        }
    }
} 