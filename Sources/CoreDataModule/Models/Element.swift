import CoreData
import Foundation

@objc(CDElement)
public class CDElement: NSManagedObject {
    @NSManaged public var content: String?
    @NSManaged public var position: String?
    @NSManaged public var style: String?
    @NSManaged public var type: String?
    @NSManaged public var dimensions: String?
    
    @NSManaged public var slide: CDSlide?
}

// MARK: - Data Conversion
extension CDElement: EntityModelConvertible {
    public typealias DomainModelType = [String: Any]
    
    /// 转换为数据字典
    public func toDomain() -> [String: Any] {
        var data: [String: Any] = [:]
        
        if let content = content {
            data["content"] = content
        }
        
        if let position = position {
            data["position"] = position
        }
        
        if let style = style {
            data["style"] = style
        }
        
        if let type = type {
            data["type"] = type
        }
        
        if let dimensions = dimensions {
            data["dimensions"] = dimensions
        }
        
        return data
    }
    
    /// 从数据字典更新实体
    public func update(from data: [String: Any]) {
        if let content = data["content"] as? String {
            self.content = content
        }
        
        if let position = data["position"] as? String {
            self.position = position
        }
        
        if let style = data["style"] as? String {
            self.style = style
        }
        
        if let type = data["type"] as? String {
            self.type = type
        }
        
        if let dimensions = data["dimensions"] as? String {
            self.dimensions = dimensions
        }
    }
} 