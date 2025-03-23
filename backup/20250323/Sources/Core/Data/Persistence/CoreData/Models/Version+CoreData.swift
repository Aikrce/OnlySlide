import Foundation
import CoreData

@objc(Version)
public class Version: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var number: Int64
    @NSManaged public var content: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var document: DocumentEntity?
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
    
    public var versionModel: Version {
        get {
            return Version(
                id: id,
                number: Int(number),
                createdAt: createdAt,
                document: document?.documentModel
            )
        }
        set {
            id = newValue.id
            number = Int64(newValue.number)
            createdAt = newValue.createdAt
            // 关系属性需要单独处理
        }
    }
}

extension Version {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Version> {
        return NSFetchRequest<Version>(entityName: "Version")
    }
}

// MARK: - Domain Model Conversion
extension Version {
    var versionModel: VersionModel {
        get {
            return VersionModel(
                id: id,
                number: Int(number),
                content: content ?? "",
                createdAt: createdAt
            )
        }
        set {
            id = newValue.id
            number = Int64(newValue.number)
            content = newValue.content
            createdAt = newValue.createdAt
        }
    }
} 