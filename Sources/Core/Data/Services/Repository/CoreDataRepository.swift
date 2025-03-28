import CoreData
import CoreDataModule

/// 通用仓储协议
protocol Repository {
    associatedtype Entity: NSManagedObject
    
    func create() -> Entity
    func fetch(predicate: NSPredicate?) throws -> [Entity]
    func fetchOne(predicate: NSPredicate?) throws -> Entity?
    func update(_ entity: Entity) throws
    func delete(_ entity: Entity) throws
    func deleteAll() throws
}

/// Core Data 仓储基类
class CoreDataRepository<T: NSManagedObject>: Repository {
    typealias Entity = T
    
    internal let context: NSManagedObjectContext
    private let errorHandler = CoreDataErrorHandler.shared
    
    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }
    
    // MARK: - CRUD Operations
    
    func create() -> T {
        T(context: context)
    }
    
    func fetch(predicate: NSPredicate? = nil) throws -> [T] {
        let request = T.fetchRequest()
        request.predicate = predicate
        
        do {
            return try context.fetch(request) as? [T] ?? []
        } catch {
            errorHandler.handle(error, context: "获取\(T.entity().name ?? "实体")失败")
            throw CoreDataError.fetchFailed(error)
        }
    }
    
    func fetchOne(predicate: NSPredicate?) throws -> T? {
        let request = T.fetchRequest()
        request.predicate = predicate
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first as? T
        } catch {
            errorHandler.handle(error, context: "获取单个\(T.entity().name ?? "实体")失败")
            throw CoreDataError.fetchFailed(error)
        }
    }
    
    func update(_ entity: T) throws {
        if !context.hasChanges {
            return // 如果没有变更，不需要保存
        }
        
        do {
            try context.save()
        } catch {
            errorHandler.handle(error, context: "更新\(T.entity().name ?? "实体")失败")
            throw CoreDataError.updateFailed(error)
        }
    }
    
    func delete(_ entity: T) throws {
        context.delete(entity)
        
        do {
            try context.save()
        } catch {
            errorHandler.handle(error, context: "删除\(T.entity().name ?? "实体")失败")
            throw CoreDataError.deleteFailed(error)
        }
    }
    
    func deleteAll() throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: T.entity().name!)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            errorHandler.handle(error, context: "删除所有\(T.entity().name ?? "实体")失败")
            throw CoreDataError.deleteFailed(error)
        }
    }
    
    // MARK: - Batch Operations
    
    /// 批量保存实体
    /// - Parameter entities: 实体数组
    /// - Throws: CoreDataError.saveFailed 保存失败
    func batchSave(_ entities: [T]) throws {
        // 创建一个后台上下文
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        
        backgroundContext.perform {
            for entity in entities {
                backgroundContext.insert(entity)
            }
            
            do {
                try backgroundContext.save()
            } catch {
                self.errorHandler.handle(error, context: "批量保存\(T.entity().name ?? "实体")失败")
            }
        }
    }
    
    /// 批量更新实体
    /// - Parameters:
    ///   - propertiesToUpdate: 需要更新的属性
    ///   - predicate: 更新条件
    /// - Throws: CoreDataError.updateFailed 更新失败
    func batchUpdate(propertiesToUpdate: [AnyHashable: Any], predicate: NSPredicate? = nil) throws {
        let request = NSBatchUpdateRequest(entityName: T.entity().name!)
        request.predicate = predicate
        request.propertiesToUpdate = propertiesToUpdate
        request.resultType = .updatedObjectIDsResultType
        
        do {
            let result = try context.execute(request) as? NSBatchUpdateResult
            let changes = [NSUpdatedObjectsKey: result?.result as? [NSManagedObjectID] ?? []]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        } catch {
            errorHandler.handle(error, context: "批量更新\(T.entity().name ?? "实体")失败")
            throw CoreDataError.updateFailed(error)
        }
    }
    
    /// 批量删除实体
    /// - Parameter predicate: 删除条件
    /// - Throws: CoreDataError.deleteFailed 删除失败
    func batchDelete(predicate: NSPredicate? = nil) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: T.entity().name!)
        request.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            let changes = [NSDeletedObjectsKey: result?.result as? [NSManagedObjectID] ?? []]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        } catch {
            errorHandler.handle(error, context: "批量删除\(T.entity().name ?? "实体")失败")
            throw CoreDataError.deleteFailed(error)
        }
    }
    
    // MARK: - Thread Safety Methods
    
    /// 在主线程上下文中执行操作
    /// - Parameter block: 要执行的代码块
    func performOnMainContext(_ block: @escaping () -> Void) {
        let mainContext = CoreDataStack.shared.viewContext
        
        if Thread.isMainThread {
            block()
        } else {
            mainContext.perform {
                block()
            }
        }
    }
    
    /// 在后台上下文中执行操作
    /// - Parameter block: 要执行的代码块
    func performInBackground(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        
        backgroundContext.perform {
            block(backgroundContext)
        }
    }
    
    /// 异步执行操作并返回结果
    /// - Parameters:
    ///   - block: 要执行的异步代码块
    ///   - completion: 完成回调
    func performAsync<ResultType>(_ block: @escaping (NSManagedObjectContext) throws -> ResultType, completion: @escaping (Result<ResultType, Error>) -> Void) {
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        
        backgroundContext.perform {
            do {
                let result = try block(backgroundContext)
                completion(.success(result))
            } catch {
                self.errorHandler.handle(error, context: "异步操作失败")
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Extensions for Domain Model Conversions

extension CoreDataRepository where T: EntityModelConvertible {
    /// 获取领域模型
    /// - Parameter predicate: 查询条件
    /// - Returns: 领域模型数组
    /// - Throws: CoreDataError.fetchFailed 获取失败
    func fetchDomain(predicate: NSPredicate? = nil) throws -> [T.DomainModelType] {
        let entities = try fetch(predicate: predicate)
        return entities.map { $0.toDomain() }
    }
    
    /// 获取单个领域模型
    /// - Parameter predicate: 查询条件
    /// - Returns: 单个领域模型，如果不存在则返回nil
    /// - Throws: CoreDataError.fetchFailed 获取失败
    func fetchOneDomain(predicate: NSPredicate?) throws -> T.DomainModelType? {
        guard let entity = try fetchOne(predicate: predicate) else {
            return nil
        }
        
        return entity.toDomain()
    }
    
    /// 根据领域模型更新实体
    /// - Parameter domainModel: 领域模型
    /// - Returns: 更新后的实体
    /// - Throws: CoreDataError.updateFailed 更新失败
    func updateFromDomain<DomainType>(_ domainModel: DomainType) throws -> T where T: Identifiable, T.IdentifierType == UUID, DomainType: Identifiable, DomainType.IdentifierType == UUID {
        // 查找已有实体或创建新实体
        let entity: T
        
        if let existingEntity = T.find(byID: domainModel.id, in: context) {
            entity = existingEntity
        } else {
            entity = create()
        }
        
        // 使用领域模型更新实体
        if let entityConvertible = entity as? EntityModelConvertible, let domainModelConvertible = domainModel as? EntityModelConvertible.DomainModelType {
            entityConvertible.update(from: domainModelConvertible)
        }
        
        // 保存更改
        try update(entity)
        
        return entity
    }
} 
} 