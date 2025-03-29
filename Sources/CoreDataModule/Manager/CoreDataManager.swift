import CoreData
import Combine
import os

/// CoreData 管理器
/// 负责管理CoreData栈和提供数据持久化操作
@MainActor public final class CoreDataManager: Sendable {
    // MARK: - Properties
    
    /// 共享实例
    @MainActor public static let shared = CoreDataManager()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "CoreDataManager")
    
    /// 持久化容器
    internal lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "OnlySlide")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("无法加载Core Data存储: \(error)")
            }
        }
        // 启用自动合并策略
        container.viewContext.automaticallyMergesChangesFromParent = true
        // 设置合并策略 - 使用NSMergePolicy.mergeByPropertyObjectTrump而不是全局共享变量
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return container
    }()
    
    /// 主上下文
    public var mainContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Context Management
    
    /// 创建后台上下文
    /// - Returns: 新的后台上下文
    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }
    
    /// 执行后台任务
    /// - Parameter block: 要执行的任务闭包
    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    // MARK: - CRUD Operations
    
    /// 保存上下文
    /// - Parameter context: 要保存的上下文
    /// - Throws: 保存错误
    public func saveContext(_ context: NSManagedObjectContext) throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    /// 保存主上下文
    /// - Throws: 保存错误
    public func saveMainContext() throws {
        try saveContext(mainContext)
    }
    
    /// 异步保存上下文
    /// - Parameters:
    ///   - context: 要保存的上下文
    ///   - completion: 完成回调
    public func saveContextAsync(_ context: NSManagedObjectContext, completion: ((Error?) -> Void)? = nil) {
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
    public func fetch<T: NSManagedObject>(
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
    public func fetchAsync<T: NSManagedObject>(
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
    public func delete(_ object: NSManagedObject, context: NSManagedObjectContext) throws {
        context.delete(object)
        try saveContext(context)
    }
    
    /// 批量删除对象
    /// - Parameters:
    ///   - entityName: 实体名称
    ///   - predicate: 谓词条件
    ///   - context: 上下文
    /// - Throws: 删除错误
    public func batchDelete(
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
    public func performMigration(completion: @escaping (Error?) -> Void) {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            completion(CoreDataError.storeNotFound("无法获取存储URL"))
            return
        }
        
        // 使用异步任务执行迁移
        Task {
            do {
                let migrationManager = CoreDataMigrationManager.shared
                try await migrationManager.performMigration(at: storeURL)
                
                logger.info("数据迁移成功完成")
                
                // 在主线程调用完成回调
                await MainActor.run {
                    completion(nil)
                }
            } catch {
                logger.error("数据迁移失败: \(error.localizedDescription)")
                
                // 在主线程调用完成回调
                await MainActor.run {
                    completion(error)
                }
            }
        }
        
        // 注意：这个方法不返回布尔值，而是通过回调通知完成状态
    }
    
    /// 异步执行数据迁移
    /// - Returns: 是否已执行迁移，如果为false则表示不需要迁移
    @MainActor
    public func migrateAsync() async throws -> Bool {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            throw CoreDataError.storeNotFound("无法获取存储URL")
        }
        
        let migrationManager = CoreDataMigrationManager.shared
        
        do {
            // 尝试执行迁移
            try await migrationManager.performMigration(at: storeURL)
            logger.info("数据迁移成功完成")
            return true  // 返回true表示已执行迁移
        } catch {
            logger.error("数据迁移失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Utilities
    
    /// 检查实体是否存在
    /// - Parameters:
    ///   - entityName: 实体名称
    ///   - predicate: 谓词条件
    ///   - context: 上下文
    /// - Returns: 是否存在
    /// - Throws: 检查错误
    public func exists(
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
    public func count(
        entityName: String,
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext
    ) throws -> Int {
        let request = NSFetchRequest<NSNumber>(entityName: entityName)
        request.predicate = predicate
        request.resultType = .countResultType
        return try context.count(for: request)
    }
    
    // MARK: - Error Handling
    
    /// 处理错误
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误上下文描述
    ///   - file: 发生错误的文件
    ///   - line: 发生错误的行
    ///   - function: 发生错误的函数
    public func handleError(_ error: Error, context: String, file: String = #file, line: Int = #line, function: String = #function) {
        CoreDataErrorManager.shared.handle(error, context: context, file: file, line: line, function: function)
    }
    
    /// 处理错误并抛出
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误上下文描述
    ///   - file: 发生错误的文件
    ///   - line: 发生错误的行
    ///   - function: 发生错误的函数
    /// - Throws: 处理后的错误对象
    public func handleErrorAndThrow(_ error: Error, context: String, file: String = #file, line: Int = #line, function: String = #function) throws {
        try CoreDataErrorManager.shared.handleAndThrow(error, context: context, file: file, line: line, function: function)
    }
    
    /// 尝试恢复错误
    /// - Parameters:
    ///   - error: 要恢复的错误
    ///   - context: 错误上下文
    /// - Returns: 恢复结果
    public func attemptErrorRecovery(from error: Error, context: String) async -> RecoveryResult {
        return await CoreDataRecoveryExecutor.shared.attemptRecovery(from: error, context: context)
    }
    
    /// 注册错误处理策略
    /// - Parameters:
    ///   - strategy: 错误处理策略
    ///   - errorType: 错误类型
    ///   - context: 错误上下文描述
    public func registerErrorStrategy(_ strategy: ErrorHandlingStrategy, for errorType: String, context: String? = nil) {
        CoreDataErrorManager.shared.registerStrategy(strategy, for: errorType, context: context)
    }
    
    /// 订阅错误通知
    /// - Returns: 错误通知发布者
    public var errorPublisher: AnyPublisher<(Error, String), Never> {
        return CoreDataErrorManager.shared.errorPublisher
    }
    
    // MARK: - Enhanced Operations with Error Handling
    
    /// 安全保存上下文
    /// 包含错误处理和恢复机制
    /// - Parameter context: 要保存的上下文
    /// - Throws: 保存错误
    public func safeSave(context: NSManagedObjectContext) async throws {
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            // 记录错误
            logger.error("保存上下文失败: \(error.localizedDescription)")
            
            // 尝试恢复
            let result = await attemptErrorRecovery(from: error, context: "保存上下文")
            
            // 处理恢复结果
            switch result {
            case .success:
                // 恢复成功，重试保存
                if context.hasChanges {
                    try context.save()
                }
            case .partialSuccess(let message):
                // 部分恢复，记录信息并尝试重新保存
                logger.info("部分恢复: \(message)")
                if context.hasChanges {
                    try context.save()
                }
            case .requiresUserInteraction:
                // 需要用户交互，抛出错误
                throw CoreDataError.saveFailed(error)
            case .failure(let recoveryError):
                // 恢复失败，抛出错误
                throw CoreDataError.saveFailed(recoveryError)
            }
        }
    }
    
    /// 安全获取数据
    /// 包含错误处理和恢复机制
    /// - Parameters:
    ///   - request: 获取请求
    ///   - context: 管理对象上下文
    /// - Returns: 获取结果
    /// - Throws: 获取错误
    public func safeFetch<T: NSFetchRequestResult>(_ request: NSFetchRequest<T>, in context: NSManagedObjectContext) async throws -> [T] {
        do {
            return try context.fetch(request)
        } catch {
            // 记录错误
            logger.error("获取数据失败: \(error.localizedDescription)")
            
            // 尝试恢复
            let result = await attemptErrorRecovery(from: error, context: "获取数据")
            
            // 处理恢复结果
            switch result {
            case .success, .partialSuccess:
                // 恢复成功或部分成功，重试获取
                return try context.fetch(request)
            case .requiresUserInteraction, .failure:
                // 需要用户交互或恢复失败，抛出错误
                throw CoreDataError.fetchFailed(error)
            }
        }
    }
    
    /// 安全执行请求
    /// 包含错误处理和恢复机制
    /// - Parameters:
    ///   - request: 持久化存储请求
    ///   - context: 管理对象上下文
    /// - Throws: 执行错误
    public func safeExecute(_ request: NSPersistentStoreRequest, in context: NSManagedObjectContext) async throws {
        do {
            try context.execute(request)
        } catch {
            // 记录错误
            logger.error("执行请求失败: \(error.localizedDescription)")
            
            // 尝试恢复
            let result = await attemptErrorRecovery(from: error, context: "执行请求")
            
            // 处理恢复结果
            switch result {
            case .success, .partialSuccess:
                // 恢复成功或部分成功，重试执行
                try context.execute(request)
            case .requiresUserInteraction, .failure:
                // 需要用户交互或恢复失败，抛出错误
                throw CoreDataError.unknown(error)
            }
        }
    }
} 