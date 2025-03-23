import CoreData

@objc(SlideEntity)
public class SlideEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var index: Int32
    @NSManaged public var content: String?
    @NSManaged public var layout: String?
    @NSManaged public var style: String?
    @NSManaged public var type: String?
    @NSManaged public var title: String?
    @NSManaged public var document: DocumentEntity?
    @NSManaged public var elements: Set<Element>?
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
    }
}

extension SlideEntity {
    static var entityName: String {
        return String(describing: SlideEntity.self)
    }
    
    public var slideModel: Slide {
        get {
            return Slide(
                id: id,
                title: title ?? "",
                content: content ?? "",
                index: Int(index),
                elements: elements?.map { $0.elementModel } ?? []
            )
        }
        set {
            id = newValue.id
            title = newValue.title
            content = newValue.content
            index = Int32(newValue.index)
            // 关系属性需要单独处理
        }
    }
}

// MARK: - Generated accessors for elements
extension SlideEntity {
    @objc(addElementsObject:)
    @NSManaged public func addToElements(_ value: Element)
    
    @objc(removeElementsObject:)
    @NSManaged public func removeFromElements(_ value: Element)
    
    @objc(addElements:)
    @NSManaged public func addToElements(_ values: Set<Element>)
    
    @objc(removeElements:)
    @NSManaged public func removeFromElements(_ values: Set<Element>)
}

extension SlideEntity {
    @objc
    public class func fetchRequest() -> NSFetchRequest<SlideEntity> {
        return NSFetchRequest<SlideEntity>(entityName: "SlideEntity")
    }
} 