import Foundation
import CoreData

/// 用于配置Core Data模型索引的工具类
public final class CoreDataIndexConfiguration {
    
    /// 为模型添加常用查询字段的索引
    /// - Parameter model: 需要配置索引的托管对象模型
    public static func configureIndices(for model: NSManagedObjectModel) {
        for entity in model.entities {
            // 为每种实体类型配置相应的索引
            switch entity.name {
            case "SyncLog":
                configureIndicesForSyncLog(entity: entity)
            case "Document":
                configureIndicesForDocument(entity: entity)
            case "User":
                configureIndicesForUser(entity: entity)
            case "Tag":
                configureIndicesForTag(entity: entity)
            case "Slide":
                configureIndicesForSlide(entity: entity)
            default:
                configureDefaultIndices(entity: entity)
            }
        }
    }
    
    // MARK: - 私有配置方法
    
    /// 为SyncLog实体配置索引
    private static func configureIndicesForSyncLog(entity: NSEntityDescription) {
        // 为常用查询字段添加索引
        let indexedAttributes = ["synced", "syncedAt", "type", "createdAt"]
        addIndices(for: entity, attributes: indexedAttributes)
    }
    
    /// 为Document实体配置索引
    private static func configureIndicesForDocument(entity: NSEntityDescription) {
        // 为常用查询字段添加索引
        let indexedAttributes = ["name", "lastModifiedAt", "createdAt", "isDeleted", "isShared"]
        addIndices(for: entity, attributes: indexedAttributes)
    }
    
    /// 为User实体配置索引
    private static func configureIndicesForUser(entity: NSEntityDescription) {
        // 为常用查询字段添加索引
        let indexedAttributes = ["email", "username", "lastLoginAt", "isActive"]
        addIndices(for: entity, attributes: indexedAttributes)
    }
    
    /// 为Tag实体配置索引
    private static func configureIndicesForTag(entity: NSEntityDescription) {
        // 为常用查询字段添加索引
        let indexedAttributes = ["name", "color"]
        addIndices(for: entity, attributes: indexedAttributes)
    }
    
    /// 为Slide实体配置索引
    private static func configureIndicesForSlide(entity: NSEntityDescription) {
        // 为常用查询字段添加索引
        let indexedAttributes = ["order", "lastModifiedAt", "isDeleted"]
        addIndices(for: entity, attributes: indexedAttributes)
    }
    
    /// 为其他实体配置默认索引
    private static func configureDefaultIndices(entity: NSEntityDescription) {
        // 为通用的常用查询字段添加索引
        let indexedAttributes = ["createdAt", "lastModifiedAt", "isDeleted", "name", "id"]
        addIndices(for: entity, attributes: indexedAttributes)
    }
    
    /// 为给定实体的属性添加索引
    private static func addIndices(for entity: NSEntityDescription, attributes: [String]) {
        for attributeName in attributes {
            if let attribute = entity.attributesByName[attributeName] {
                #if swift(>=5.0)
                // 使用现代API
                // 注意：实际项目中可能需要根据iOS/macOS的版本选择不同的实现
                var indices = entity.indexes
                let indexDesc = NSFetchIndexDescription(name: "\(attributeName)_idx", elements: [
                    NSFetchIndexElementDescription(property: attribute, collationType: .binary)
                ])
                indices.append(indexDesc)
                entity.indexes = indices
                #else
                // 使用旧API
                attribute.isIndexed = true
                #endif
            }
        }
    }
    
    /// 为给定实体添加复合索引
    private static func addCompoundIndex(for entity: NSEntityDescription, attributes: [String]) {
        guard !attributes.isEmpty else { return }
        
        // 确保所有属性都存在
        let validAttributes = attributes.filter { entity.attributesByName[$0] != nil }
        guard validAttributes.count == attributes.count else { return }
        
        // 创建复合索引
        let entityNameString = entity.name ?? "Unknown"
        let compoundIndex = NSFetchIndexDescription(name: "\(entityNameString)_\(validAttributes.joined(separator: "_"))_idx", elements: validAttributes.map { attribute in
            return NSFetchIndexElementDescription(property: entity.attributesByName[attribute]!, collationType: .binary)
        })
        
        // 添加到实体的索引列表中
        var indices = entity.indexes
        indices.append(compoundIndex)
        entity.indexes = indices
    }
}

// MARK: - CoreDataStack扩展

extension CoreDataStack {
    /// 在初始化持久化容器后配置索引
    public func setupModelIndices() {
        // 获取托管对象模型
        // 这里不使用guard let，因为managedObjectModel不是可选类型
        let model = persistentContainer.managedObjectModel
        
        // 配置索引
        CoreDataIndexConfiguration.configureIndices(for: model)
    }
} 