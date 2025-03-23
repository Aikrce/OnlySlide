import CoreData

/// 迁移映射管理器
final class MigrationMapping {
    // MARK: - Properties
    
    static let shared = MigrationMapping()
    
    private init() {}
    
    private let sourceModel: NSManagedObjectModel
    private let destinationModel: NSManagedObjectModel
    
    init(sourceModel: NSManagedObjectModel, destinationModel: NSManagedObjectModel) {
        self.sourceModel = sourceModel
        self.destinationModel = destinationModel
    }
    
    // MARK: - Mapping Models
    
    /// 获取迁移映射模型
    /// - Returns: 映射模型
    func mappingModel() -> NSMappingModel? {
        // 尝试获取自定义映射模型
        if let customMapping = customMappingModel() {
            return customMapping
        }
        
        // 如果没有自定义映射，则创建推断映射
        return try? NSMappingModel.inferredMappingModel(forSourceModel: sourceModel, destinationModel: destinationModel)
    }
    
    // MARK: - Custom Mapping
    
    /// 获取自定义映射模型
    private func customMappingModel() -> NSMappingModel? {
        // 根据模型版本创建映射名称
        let mappingName = "\(sourceModel.versionIdentifiers.first ?? "Unknown")_to_\(destinationModel.versionIdentifiers.first ?? "Unknown")"
        
        // 尝试加载自定义映射模型
        return NSMappingModel(contentsOf: Bundle.main.url(forResource: mappingName, withExtension: "cdm"))
    }
    
    // MARK: - Entity Mapping
    
    /// 创建实体映射
    /// - Parameters:
    ///   - entityName: 实体名称
    /// - Returns: 实体映射
    func createEntityMapping(for entityName: String) -> NSEntityMapping {
        let entityMapping = NSEntityMapping()
        
        // 设置源实体和目标实体
        guard let sourceEntity = sourceModel.entitiesByName[entityName],
              let destinationEntity = destinationModel.entitiesByName[entityName] else {
            fatalError("无法找到实体: \(entityName)")
        }
        
        entityMapping.sourceEntityName = entityName
        entityMapping.destinationEntityName = entityName
        entityMapping.mappingType = .copyEntityPolicy
        
        // 创建属性映射
        var propertyMappings: [NSPropertyMapping] = []
        
        // 映射属性
        for (name, _) in sourceEntity.attributesByName {
            if destinationEntity.attributesByName[name] != nil {
                let mapping = NSPropertyMapping()
                mapping.name = name
                mapping.valueExpression = NSExpression(format: "$source.\(name)")
                propertyMappings.append(mapping)
            }
        }
        
        // 映射关系
        for (name, _) in destinationEntity.relationshipsByName {
            let mapping = NSPropertyMapping()
            mapping.name = name
            mapping.valueExpression = NSExpression(format: "$source.\(name)")
            propertyMappings.append(mapping)
        }
        
        entityMapping.attributeMappings = propertyMappings
        
        return entityMapping
    }
} 