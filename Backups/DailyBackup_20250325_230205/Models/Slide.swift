import CoreData
import Foundation

@objc(CDSlide)
public class CDSlide: NSManagedObject {
    @NSManaged public var content: String?
    @NSManaged public var index: Int32
    @NSManaged public var layout: String?
    @NSManaged public var style: String?
    @NSManaged public var type: String?
    @NSManaged public var title: String?
    
    @NSManaged public var document: CDDocument?
    @NSManaged public var elements: Set<CDElement>?
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        index = 0
    }
}

// MARK: - Generated accessors for elements
extension CDSlide {
    @objc(addElementsObject:)
    @NSManaged public func addToElements(_ value: CDElement)
    
    @objc(removeElementsObject:)
    @NSManaged public func removeFromElements(_ value: CDElement)
    
    @objc(addElements:)
    @NSManaged public func addToElements(_ values: Set<CDElement>)
    
    @objc(removeElements:)
    @NSManaged public func removeFromElements(_ values: Set<CDElement>)
}

// MARK: - Data Conversion
extension CDSlide: EntityModelConvertible {
    public typealias DomainModelType = [String: Any]
    
    /// 转换为数据字典
    public func toDomain() -> [String: Any] {
        var data: [String: Any] = [
            "index": index
        ]
        
        if let content = content {
            data["content"] = content
        }
        
        if let layout = layout {
            data["layout"] = layout
        }
        
        if let style = style {
            data["style"] = style
        }
        
        if let type = type {
            data["type"] = type
        }
        
        if let title = title {
            data["title"] = title
        }
        
        return data
    }
    
    /// 从数据字典更新实体
    public func update(from data: [String: Any]) {
        if let content = data["content"] as? String {
            self.content = content
        }
        
        if let index = data["index"] as? Int32 {
            self.index = index
        }
        
        if let layout = data["layout"] as? String {
            self.layout = layout
        }
        
        if let style = data["style"] as? String {
            self.style = style
        }
        
        if let type = data["type"] as? String {
            self.type = type
        }
        
        if let title = data["title"] as? String {
            self.title = title
        }
    }
} 