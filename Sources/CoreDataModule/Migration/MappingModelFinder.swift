import CoreData
import Foundation

/// 映射模型查找器
/// 负责发现和创建数据模型迁移所需的映射模型
public class MappingModelFinder {
    
    // MARK: - Properties
    
    /// 模型版本管理器
    private let versionManager: CoreDataModelVersionManager
    
    // MARK: - Initialization
    
    /// 初始化映射模型查找器
    /// - Parameter versionManager: 模型版本管理器
    public init(versionManager: CoreDataModelVersionManager) {
        self.versionManager = versionManager
    }
    
    // MARK: - Mapping Model Discovery
    
    /// 查找或创建源模型到目标模型的映射模型
    /// - Parameters:
    ///   - sourceModel: 源数据模型
    ///   - destinationModel: 目标数据模型
    /// - Returns: 映射模型，如果找不到则返回nil
    public func mappingModel(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel
    ) -> NSMappingModel? {
        // 1. 尝试找到自定义映射模型
        if let customMappingModel = findCustomMappingModel(from: sourceModel, to: destinationModel) {
            return customMappingModel
        }
        
        // 2. 尝试推断映射模型
        do {
            return try NSMappingModel.inferredMappingModel(
                forSourceModel: sourceModel,
                destinationModel: destinationModel
            )
        } catch {
            print("Error inferring mapping model: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 查找自定义映射模型
    /// - Parameters:
    ///   - sourceModel: 源数据模型
    ///   - destinationModel: 目标数据模型
    /// - Returns: 自定义映射模型，如果找不到则返回nil
    private func findCustomMappingModel(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel
    ) -> NSMappingModel? {
        // 首先尝试使用系统方法查找
        let sourceModelHash = sourceModel.entityVersionHashesByName
        let destinationModelHash = destinationModel.entityVersionHashesByName
        
        // 尝试使用系统API查找映射模型
        return NSMappingModel(
            from: [Bundle.module],
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        )
    }
    
    // MARK: - Mapping Model Creation
    
    /// 创建自定义映射模型
    /// - Parameters:
    ///   - sourceModel: 源数据模型
    ///   - destinationModel: 目标数据模型
    /// - Returns: 创建的映射模型
    public func createCustomMappingModel(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel
    ) -> NSMappingModel {
        let mappingModel = NSMappingModel()
        var entityMappings: [NSEntityMapping] = []
        
        // 为每个目标实体创建映射
        for destinationEntity in destinationModel.entities {
            if let sourceEntity = findCorrespondingSourceEntity(
                for: destinationEntity,
                in: sourceModel
            ) {
                // 创建实体映射
                let entityMapping = createEntityMapping(
                    from: sourceEntity,
                    to: destinationEntity
                )
                entityMappings.append(entityMapping)
            } else {
                // 处理新增的实体（目标模型中有，但源模型中没有）
                let entityMapping = createEntityMappingForNewEntity(destinationEntity)
                entityMappings.append(entityMapping)
            }
        }
        
        // 设置映射模型的实体映射
        mappingModel.entityMappings = entityMappings
        
        return mappingModel
    }
    
    /// 查找源模型中与目标实体对应的实体
    /// - Parameters:
    ///   - destinationEntity: 目标实体
    ///   - sourceModel: 源数据模型
    /// - Returns: 对应的源实体，如果找不到则返回nil
    private func findCorrespondingSourceEntity(
        for destinationEntity: NSEntityDescription,
        in sourceModel: NSManagedObjectModel
    ) -> NSEntityDescription? {
        // 首先尝试匹配名称
        if let entity = sourceModel.entitiesByName[destinationEntity.name!] {
            return entity
        }
        
        // 如果名称不匹配，可以尝试其他匹配策略
        // 例如，检查是否有映射指示（例如重命名的实体）
        
        return nil
    }
    
    /// 创建从源实体到目标实体的映射
    /// - Parameters:
    ///   - sourceEntity: 源实体
    ///   - destinationEntity: 目标实体
    /// - Returns: 实体映射
    private func createEntityMapping(
        from sourceEntity: NSEntityDescription,
        to destinationEntity: NSEntityDescription
    ) -> NSEntityMapping {
        let entityMapping = NSEntityMapping()
        
        // 设置实体映射的基本属性
        entityMapping.sourceEntityName = sourceEntity.name
        entityMapping.destinationEntityName = destinationEntity.name
        entityMapping.sourceEntityVersionHash = sourceEntity.versionHash
        entityMapping.destinationEntityVersionHash = destinationEntity.versionHash
        
        // 设置映射类型为复制
        entityMapping.mappingType = .copyEntityMappingType
        
        // 创建属性映射
        entityMapping.attributeMappings = createAttributeMappings(
            from: sourceEntity,
            to: destinationEntity
        )
        
        // 创建关系映射
        entityMapping.relationshipMappings = createRelationshipMappings(
            from: sourceEntity,
            to: destinationEntity
        )
        
        // 设置自定义实体迁移策略类（如果有的话）
        entityMapping.entityMigrationPolicyClassName = getMigrationPolicyClassName(
            for: destinationEntity.name ?? ""
        )
        
        return entityMapping
    }
    
    /// 为新增实体创建映射
    /// - Parameter destinationEntity: 目标实体
    /// - Returns: 实体映射
    private func createEntityMappingForNewEntity(_ destinationEntity: NSEntityDescription) -> NSEntityMapping {
        let entityMapping = NSEntityMapping()
        
        // 设置实体映射的基本属性
        entityMapping.destinationEntityName = destinationEntity.name
        entityMapping.destinationEntityVersionHash = destinationEntity.versionHash
        
        // 设置映射类型为添加
        entityMapping.mappingType = .addEntityMappingType
        
        return entityMapping
    }
    
    /// 创建属性映射
    /// - Parameters:
    ///   - sourceEntity: 源实体
    ///   - destinationEntity: 目标实体
    /// - Returns: 属性映射数组
    private func createAttributeMappings(
        from sourceEntity: NSEntityDescription,
        to destinationEntity: NSEntityDescription
    ) -> [NSPropertyMapping] {
        var propertyMappings: [NSPropertyMapping] = []
        
        // 遍历目标实体的所有属性
        for (attributeName, destinationAttribute) in destinationEntity.attributesByName {
            let propertyMapping = NSPropertyMapping()
            propertyMapping.name = attributeName
            
            // 检查源实体是否有相同名称的属性
            if let sourceAttribute = sourceEntity.attributesByName[attributeName] {
                // 简单的一对一映射
                propertyMapping.valueExpression = NSExpression(format: "$source.\(attributeName)")
            } else {
                // 处理新增的属性或需要特殊转换的属性
                // 这里可以设置默认值或转换表达式
                propertyMapping.valueExpression = createDefaultValueExpression(for: destinationAttribute)
            }
            
            propertyMappings.append(propertyMapping)
        }
        
        return propertyMappings
    }
    
    /// 为属性创建默认值表达式
    /// - Parameter attribute: 实体属性
    /// - Returns: 表达式
    private func createDefaultValueExpression(for attribute: NSAttributeDescription) -> NSExpression {
        // 根据属性类型设置适当的默认值
        switch attribute.attributeType {
        case .stringAttributeType:
            return NSExpression(format: "''")
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
            return NSExpression(format: "0")
        case .doubleAttributeType, .floatAttributeType, .decimalAttributeType:
            return NSExpression(format: "0.0")
        case .booleanAttributeType:
            return NSExpression(format: "false")
        case .dateAttributeType:
            return NSExpression(format: "CAST(null, 'NSDate')")
        case .binaryDataAttributeType:
            return NSExpression(format: "CAST(null, 'NSData')")
        case .UUIDAttributeType:
            return NSExpression(format: "CAST(null, 'NSUUID')")
        case .URIAttributeType:
            return NSExpression(format: "CAST(null, 'NSURL')")
        case .transformableAttributeType, .objectIDAttributeType:
            return NSExpression(format: "nil")
        @unknown default:
            return NSExpression(format: "nil")
        }
    }
    
    /// 创建关系映射
    /// - Parameters:
    ///   - sourceEntity: 源实体
    ///   - destinationEntity: 目标实体
    /// - Returns: 关系映射数组
    private func createRelationshipMappings(
        from sourceEntity: NSEntityDescription,
        to destinationEntity: NSEntityDescription
    ) -> [NSPropertyMapping] {
        var propertyMappings: [NSPropertyMapping] = []
        
        // 遍历目标实体的所有关系
        for (relationshipName, destinationRelationship) in destinationEntity.relationshipsByName {
            let propertyMapping = NSPropertyMapping()
            propertyMapping.name = relationshipName
            
            // 检查源实体是否有相同名称的关系
            if let _ = sourceEntity.relationshipsByName[relationshipName] {
                // 简单的一对一关系映射
                propertyMapping.valueExpression = NSExpression(format: "$source.\(relationshipName)")
            } else {
                // 处理新增的关系
                if destinationRelationship.isToMany {
                    // 对于多对多或一对多关系，设置为空集合
                    propertyMapping.valueExpression = NSExpression(format: "CAST(null, 'NSSet')")
                } else {
                    // 对于一对一关系，设置为nil
                    propertyMapping.valueExpression = NSExpression(format: "nil")
                }
            }
            
            propertyMappings.append(propertyMapping)
        }
        
        return propertyMappings
    }
    
    /// 获取实体的迁移策略类名
    /// - Parameter entityName: 实体名称
    /// - Returns: 迁移策略类名
    private func getMigrationPolicyClassName(for entityName: String) -> String? {
        // 根据实体名称返回相应的迁移策略类名
        switch entityName {
        case "Document":
            return String(describing: DocumentEntityMigrationPolicy.self)
        case "Slide":
            return String(describing: SlideEntityMigrationPolicy.self)
        case "Element":
            return String(describing: ElementEntityMigrationPolicy.self)
        default:
            // 对于其他实体，使用基类策略
            return String(describing: EntityMigrationPolicy.self)
        }
    }
} 