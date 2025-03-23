import CoreData
import Combine

/// CoreData 管理器
/// 负责管理CoreData栈和提供数据持久化操作
final class CoreDataManager {
    // MARK: - Properties
    
    /// 共享实例
    static let shared = CoreDataManager()
    
    /// 持久化容器
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "OnlySlide")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("无法加载Core Data存储: \(error)")
            }
        }
        // 启用自动合并策略
        container.viewContext.automaticallyMergesChangesFromParent = true
        // 设置合并策略
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()
    
    /// 主上下文
    var mainContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Context Management
    
    /// 创建后台上下文
    /// - Returns: 新的后台上下文
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// 执行后台任务
    /// - Parameter block: 要执行的任务闭包
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    // MARK: - CRUD Operations
    
    /// 保存上下文
    /// - Parameter context: 要保存的上下文
    /// - Throws: 保存错误
    func saveContext(_ context: NSManagedObjectContext) throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    /// 保存主上下文
    /// - Throws: 保存错误
    func saveMainContext() throws {
        try saveContext(mainContext)
    }
    
    /// 异步保存上下文
    /// - Parameters:
    ///   - context: 要保存的上下文
    ///   - completion: 完成回调
    func saveContextAsync(_ context: NSManagedObjectContext, completion: ((Error?) -> Void)? = nil) {
        context.perform {
            do {
                try self.saveContext(context)
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: - Fetch Operations
    
    /// 获取实体
    /// - Parameters:
    ///   - entityName: 实体名称
    ///   - predicate: 谓词条件
    ///   - sortDescriptors: 排序描述符
    ///   - context: 上下文
    /// - Returns: 实体对象数组
    /// - Throws: 获取错误
    func fetch<T: NSManagedObject>(
        entityName: String,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        context: NSManagedObjectContext
    ) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        return try context.fetch(request)
    }
    
    /// 异步获取实体
    /// - Parameters:
    ///   - entityName: 实体名称
    ///   - predicate: 谓词条件
    ///   - sortDescriptors: 排序描述符
    ///   - context: 上下文
    ///   - completion: 完成回调
    func fetchAsync<T: NSManagedObject>(
        entityName: String,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        context: NSManagedObjectContext,
        completion: @escaping (Result<[T], Error>) -> Void
    ) {
        context.perform {
            do {
                let results: [T] = try self.fetch(
                    entityName: entityName,
                    predicate: predicate,
                    sortDescriptors: sortDescriptors,
                    context: context
                )
                completion(.success(results))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Delete Operations
    
    /// 删除对象
    /// - Parameters:
    ///   - object: 要删除的对象
    ///   - context: 上下文
    /// - Throws: 删除错误
    func delete(_ object: NSManagedObject, context: NSManagedObjectContext) throws {
        context.delete(object)
        try saveContext(context)
    }
    
    /// 批量删除对象
    /// - Parameters:
    ///   - entityName: 实体名称
    ///   - predicate: 谓词条件
    ///   - context: 上下文
    /// - Throws: 删除错误
    func batchDelete(
        entityName: String,
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext
    ) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        request.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
        let changes: [AnyHashable: Any] = [
            NSDeletedObjectsKey: result?.result as? [NSManagedObjectID] ?? []
        ]
        
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
    }
    
    // MARK: - Migration
    
    /// 执行数据迁移
    /// - Parameter completion: 完成回调
    func performMigration(completion: @escaping (Error?) -> Void) {
        // TODO: 实现数据迁移逻辑
    }
    
    // MARK: - Utilities
    
    /// 检查实体是否存在
    /// - Parameters:
    ///   - entityName: 实体名称
    ///   - predicate: 谓词条件
    ///   - context: 上下文
    /// - Returns: 是否存在
    /// - Throws: 检查错误
    func exists(
        entityName: String,
        predicate: NSPredicate,
        context: NSManagedObjectContext
    ) throws -> Bool {
        let request = NSFetchRequest<NSNumber>(entityName: entityName)
        request.predicate = predicate
        request.resultType = .countResultType
        let count = try context.count(for: request)
        return count > 0
    }
    
    /// 获取实体数量
    /// - Parameters:
    ///   - entityName: 实体名称
    ///   - predicate: 谓词条件
    ///   - context: 上下文
    /// - Returns: 实体数量
    /// - Throws: 计数错误
    func count(
        entityName: String,
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext
    ) throws -> Int {
        let request = NSFetchRequest<NSNumber>(entityName: entityName)
        request.predicate = predicate
        request.resultType = .countResultType
        return try context.count(for: request)
    }
} 