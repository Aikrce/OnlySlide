import CoreData

/// 通用仓储协议
protocol Repository {
    associatedtype Entity: NSManagedObject
    
    func create() -> Entity
    func fetch(predicate: NSPredicate?) -> [Entity]
    func fetchOne(predicate: NSPredicate?) -> Entity?
    func update(_ entity: Entity)
    func delete(_ entity: Entity)
    func deleteAll()
}

/// Core Data 仓储基类
class CoreDataRepository<T: NSManagedObject>: Repository {
    typealias Entity = T
    
    internal let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }
    
    // MARK: - CRUD Operations
    
    func create() -> T {
        T(context: context)
    }
    
    func fetch(predicate: NSPredicate? = nil) -> [T] {
        let request = T.fetchRequest()
        request.predicate = predicate
        
        do {
            return try context.fetch(request) as? [T] ?? []
        } catch {
            print("获取实体失败: \(error)")
            return []
        }
    }
    
    func fetchOne(predicate: NSPredicate?) -> T? {
        let request = T.fetchRequest()
        request.predicate = predicate
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first as? T
        } catch {
            print("获取单个实体失败: \(error)")
            return nil
        }
    }
    
    func update(_ entity: T) {
        if context.hasChanges {
            CoreDataStack.shared.saveContext(context)
        }
    }
    
    func delete(_ entity: T) {
        context.delete(entity)
        CoreDataStack.shared.saveContext(context)
    }
    
    func deleteAll() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: T.entity().name!)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            CoreDataStack.shared.saveContext(context)
        } catch {
            print("删除所有实体失败: \(error)")
        }
    }
    
    // MARK: - Batch Operations
    
    /// 批量保存实体
    /// - Parameter entities: 实体数组
    func batchSave(_ entities: [T]) {
        CoreDataStack.shared.performBatchOperation { context in
            entities.forEach { entity in
                context.insert(entity)
            }
        }
    }
    
    /// 批量更新实体
    /// - Parameters:
    ///   - propertiesToUpdate: 需要更新的属性
    ///   - predicate: 更新条件
    func batchUpdate(propertiesToUpdate: [AnyHashable: Any], predicate: NSPredicate? = nil) {
        let request = NSBatchUpdateRequest(entityName: T.entity().name!)
        request.predicate = predicate
        request.propertiesToUpdate = propertiesToUpdate
        request.resultType = .updatedObjectIDsResultType
        
        do {
            let result = try context.execute(request) as? NSBatchUpdateResult
            let changes = [NSUpdatedObjectsKey: result?.result as? [NSManagedObjectID] ?? []]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        } catch {
            print("批量更新失败: \(error)")
        }
    }
    
    /// 批量删除实体
    /// - Parameter predicate: 删除条件
    func batchDelete(predicate: NSPredicate? = nil) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: T.entity().name!)
        request.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            CoreDataStack.shared.saveContext(context)
        } catch {
            print("批量删除失败: \(error)")
        }
    }
} 