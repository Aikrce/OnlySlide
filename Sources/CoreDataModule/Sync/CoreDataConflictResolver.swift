import Foundation
import Core
import CoreDataModuleData

/// Core Data 冲突解析器
/// 负责处理数据同步过程中的冲突情况
class CoreDataConflictResolver {
    // MARK: - Properties
    
    /// 共享实例
    static let shared = CoreDataConflictResolver()
    
    /// 冲突解决策略
    enum ConflictResolutionStrategy {
        /// 本地数据优先
        case localWins
        /// 服务器数据优先
        case serverWins
        /// 最新修改时间胜出
        case mostRecent
        /// 手动解决
        case manual
        /// 合并更改（智能合并）
        case merge
    }
    
    /// 默认冲突解决策略
    private var defaultStrategy: ConflictResolutionStrategy = .mostRecent
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 设置默认冲突解决策略
    /// - Parameter strategy: 要设置的策略
    func setDefaultStrategy(_ strategy: ConflictResolutionStrategy) {
        defaultStrategy = strategy
    }
    
    /// 解决对象冲突
    /// - Parameters:
    ///   - localObject: 本地对象
    ///   - serverObject: 服务器对象数据
    ///   - strategy: 冲突解决策略，如果为nil则使用默认策略
    ///   - objectType: 对象类型
    ///   - context: 托管对象上下文
    /// - Returns: 解决冲突后的对象
    /// - Throws: CoreDataError 如果解决冲突失败
    func resolveConflict<T: NSManagedObject>(
        localObject: T,
        serverData: [String: Any],
        strategy: ConflictResolutionStrategy? = nil,
        context: NSManagedObjectContext
    ) throws -> T {
        let strategyToUse = strategy ?? defaultStrategy
        
        switch strategyToUse {
        case .localWins:
            return localObject
            
        case .serverWins:
            try applyServerChanges(to: localObject, from: serverData)
            return localObject
            
        case .mostRecent:
            return try resolveMostRecent(localObject: localObject, serverData: serverData)
            
        case .manual:
            // 返回两个版本的数据，让UI层展示冲突解决界面
            // 这里只是占位，实际实现需要与UI交互
            return localObject
            
        case .merge:
            return try mergeDifferences(localObject: localObject, serverData: serverData, context: context)
        }
    }
    
    // MARK: - Private Methods
    
    /// 应用服务器变更到本地对象
    /// - Parameters:
    ///   - object: 本地对象
    ///   - data: 服务器数据
    /// - Throws: CoreDataError 如果应用变更失败
    private func applyServerChanges<T: NSManagedObject>(to object: T, from data: [String: Any]) throws {
        let entity = object.entity
        
        for (key, value) in data {
            // 检查属性是否存在
            if let property = entity.propertiesByName[key] {
                if property is NSAttributeDescription {
                    // 属性
                    object.setValue(value, forKey: key)
                } else if let relationshipProperty = property as? NSRelationshipDescription {
                    // 关系
                    try handleRelationship(object: object, key: key, value: value, relationship: relationshipProperty)
                }
            }
        }
    }
    
    /// 处理关系类型的属性
    /// - Parameters:
    ///   - object: 目标对象
    ///   - key: 关系名称
    ///   - value: 关系数据
    ///   - relationship: 关系描述
    /// - Throws: CoreDataError 如果处理关系失败
    private func handleRelationship<T: NSManagedObject>(
        object: T,
        key: String,
        value: Any,
        relationship: NSRelationshipDescription
    ) throws {
        // 这里需要根据具体的数据模型和同步协议实现
        // 通常涉及查找或创建关联对象并建立关系
        
        if relationship.isToMany {
            // 处理一对多或多对多关系
            if let relationshipData = value as? [[String: Any]],
               let context = object.managedObjectContext {
                let destinationEntity = relationship.destinationEntity!
                let destinationObjects = try relationshipData.map { data -> NSManagedObject in
                    // 查找或创建目标对象的逻辑
                    // 这需要根据具体的同步协议实现
                    return try findOrCreateRelatedObject(entityName: destinationEntity.name!, data: data, context: context)
                }
                
                if relationship.isOrdered {
                    object.setValue(NSOrderedSet(array: destinationObjects), forKey: key)
                } else {
                    object.setValue(Set(destinationObjects) as NSSet, forKey: key)
                }
            }
        } else {
            // 处理一对一关系
            if let relationshipData = value as? [String: Any],
               let context = object.managedObjectContext,
               let destinationEntity = relationship.destinationEntity {
                let destinationObject = try findOrCreateRelatedObject(
                    entityName: destinationEntity.name!,
                    data: relationshipData,
                    context: context
                )
                object.setValue(destinationObject, forKey: key)
            } else if value is NSNull {
                // 清除关系
                object.setValue(nil, forKey: key)
            }
        }
    }
    
    /// 查找或创建关联对象
    /// - Parameters:
    ///   - entityName: 实体名称
    ///   - data: 对象数据
    ///   - context: 托管对象上下文
    /// - Returns: 查找到的或新创建的对象
    /// - Throws: CoreDataError 如果查找或创建对象失败
    private func findOrCreateRelatedObject(entityName: String, data: [String: Any], context: NSManagedObjectContext) throws -> NSManagedObject {
        // 从data中提取标识符信息
        guard let identifier = data["id"] as? String else {
            throw CoreDataError.invalidManagedObject("Missing identifier for related object")
        }
        
        // 查找现有对象
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "id == %@", identifier)
        
        do {
            let existingObjects = try context.fetch(fetchRequest)
            if let existingObject = existingObjects.first {
                // 更新现有对象
                try applyServerChanges(to: existingObject, from: data)
                return existingObject
            } else {
                // 创建新对象
                let newObject = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
                try applyServerChanges(to: newObject, from: data)
                return newObject
            }
        } catch {
            throw CoreDataError.fetchFailed("Failed to fetch related object: \(error.localizedDescription)")
        }
    }
    
    /// 根据最近修改时间解决冲突
    /// - Parameters:
    ///   - localObject: 本地对象
    ///   - serverData: 服务器数据
    /// - Returns: 解决冲突后的对象
    /// - Throws: CoreDataError 如果解决冲突失败
    private func resolveMostRecent<T: NSManagedObject>(localObject: T, serverData: [String: Any]) throws -> T {
        // 提取修改时间
        guard let localUpdatedAt = localObject.value(forKey: "updatedAt") as? Date,
              let serverUpdatedAtString = serverData["updatedAt"] as? String,
              let serverUpdatedAt = ISO8601DateFormatter().date(from: serverUpdatedAtString) else {
            throw CoreDataError.invalidManagedObject("Missing updatedAt field for conflict resolution")
        }
        
        if serverUpdatedAt > localUpdatedAt {
            // 服务器数据更新，应用服务器变更
            try applyServerChanges(to: localObject, from: serverData)
        }
        // 本地数据更新，保持本地状态
        
        return localObject
    }
    
    /// 合并对象差异
    /// - Parameters:
    ///   - localObject: 本地对象
    ///   - serverData: 服务器数据
    ///   - context: 托管对象上下文
    /// - Returns: 合并差异后的对象
    /// - Throws: CoreDataError 如果合并差异失败
    private func mergeDifferences<T: NSManagedObject>(
        localObject: T,
        serverData: [String: Any],
        context: NSManagedObjectContext
    ) throws -> T {
        let entity = localObject.entity
        
        // 提取本地对象的最后同步时间
        guard let lastSyncedAt = localObject.value(forKey: "lastSyncedAt") as? Date else {
            throw CoreDataError.invalidManagedObject("Missing lastSyncedAt field for merge resolution")
        }
        
        for (key, serverValue) in serverData {
            // 检查是否为有效属性
            guard let property = entity.propertiesByName[key] else { continue }
            
            if property is NSAttributeDescription {
                let localValue = localObject.value(forKey: key)
                
                // 检查属性是否在本地被修改
                if let modifiedAt = localObject.value(forKey: "\(key)ModifiedAt") as? Date, modifiedAt > lastSyncedAt {
                    // 本地修改优先，不覆盖
                    continue
                }
                
                // 应用服务器变更
                if !isEqual(localValue, serverValue) {
                    localObject.setValue(serverValue, forKey: key)
                }
            } else if property is NSRelationshipDescription {
                // 处理关系类型属性的合并
                // 这是复杂的逻辑，需要根据具体的数据模型设计实现
                // 例如，可能需要比较关系中的每个对象，执行子对象的合并等
            }
        }
        
        // 更新最后同步时间
        localObject.setValue(Date(), forKey: "lastSyncedAt")
        
        return localObject
    }
    
    /// 比较两个值是否相等
    /// - Parameters:
    ///   - value1: 第一个值
    ///   - value2: 第二个值
    /// - Returns: 是否相等
    private func isEqual(_ value1: Any?, _ value2: Any?) -> Bool {
        if let v1 = value1 as? NSObject, let v2 = value2 as? NSObject {
            return v1.isEqual(v2)
        }
        
        // 特殊情况处理
        if value1 == nil && value2 is NSNull { return true }
        if value1 is NSNull && value2 == nil { return true }
        
        return false
    }
} 