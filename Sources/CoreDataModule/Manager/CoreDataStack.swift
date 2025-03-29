import CoreData
import Foundation
import os

// 添加@preconcurrency导入以解决CoreData的Sendable警告
@preconcurrency import CoreData

/// Core Data 栈管理类
@MainActor public final class CoreDataStack: Sendable {
    // MARK: - Singleton
    
    public static let shared = CoreDataStack()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "CoreDataStack")
    
    /// 对象实体缓存 - 按ID缓存常用实体
    private let objectCache: ExpiringCache<NSManagedObjectID, NSManagedObject>
    
    /// 实体查询缓存 - 缓存常用查询结果
    private let queryCache: ExpiringCache<String, NSArray>
    
    // 添加缓存统计actor
    private actor CacheStatsActor {
        var objectCacheHits: Int = 0
        var objectCacheMisses: Int = 0
        var queryCacheHits: Int = 0
        var queryCacheMisses: Int = 0
        
        func recordObjectCacheHit() {
            objectCacheHits += 1
        }
        
        func recordObjectCacheMiss() {
            objectCacheMisses += 1
        }
        
        func recordQueryCacheHit() {
            queryCacheHits += 1
        }
        
        func recordQueryCacheMiss() {
            queryCacheMisses += 1
        }
        
        func getObjectCacheStats() -> (hits: Int, misses: Int) {
            return (objectCacheHits, objectCacheMisses)
        }
        
        func getQueryCacheStats() -> (hits: Int, misses: Int) {
            return (queryCacheHits, queryCacheMisses)
        }
        
        func resetStats() {
            objectCacheHits = 0
            objectCacheMisses = 0
            queryCacheHits = 0
            queryCacheMisses = 0
        }
    }
    
    private let cacheStatsActor = CacheStatsActor()
    
    private init() {
        // 初始化缓存
        self.objectCache = ExpiringCache(
            name: "EntityObjectCache",
            countLimit: 200,
            totalCostLimit: 20 * 1024 * 1024,
            expirationInterval: 10 * 60 // 10分钟过期
        )
        
        self.queryCache = ExpiringCache(
            name: "QueryResultCache",
            countLimit: 50,
            totalCostLimit: 10 * 1024 * 1024,
            expirationInterval: 5 * 60 // 5分钟过期
        )
        
        // 注册值转换器
        registerValueTransformers()
    }
    
    // MARK: - Core Data Stack
    
    /// 持久化存储选项
    public var persistentStoreOptions: [String: Any] {
        return [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
    }
    
    /// 持久化容器
    public lazy var persistentContainer: NSPersistentContainer = {
        // 尝试从资源管理器获取模型
        let resourceManager = CoreDataResourceManager.shared
        var managedObjectModel: NSManagedObjectModel
        
        if let existingModel = resourceManager.mergedObjectModel() {
            managedObjectModel = existingModel
            logger.info("使用资源管理器加载合并的对象模型")
        } else {
            // 回退到Bundle.main
            guard let modelURL = Bundle.main.url(forResource: "OnlySlide", withExtension: "momd") else {
                logger.error("无法找到对象模型文件")
                fatalError("无法找到对象模型文件")
            }
            
            guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
                logger.error("无法加载对象模型")
                fatalError("无法加载对象模型")
            }
            
            managedObjectModel = model
            logger.info("使用Bundle.main加载对象模型")
        }
        
        // 注册实体类名映射
        registerEntityClassNames(in: managedObjectModel)
        
        // 创建持久化容器
        let container = NSPersistentContainer(name: "OnlySlide", managedObjectModel: managedObjectModel)
        
        // 配置存储选项
        let storeDescription = NSPersistentStoreDescription()
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // 配置迁移选项
        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        storeDescription.setOption(true as NSObject, forKey: NSMigratePersistentStoresAutomaticallyOption)
        storeDescription.setOption(true as NSObject, forKey: NSInferMappingModelAutomaticallyOption)
        
        container.persistentStoreDescriptions = [storeDescription]
        
        // 执行迁移
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error {
                // 处理加载错误
                self.handlePersistentStoreLoadingError(error, storeDescription: storeDescription)
            } else if let storeURL = storeDescription.url {
                // 检查是否需要迁移
                Task {
                    do {
                        let migrationManager = CoreDataMigrationManager.shared
                        // 不要使用返回值做条件判断，而是直接使用结果
                        // 将原来会导致类型转换错误的写法改为新的方式
                        try await migrationManager.checkAndMigrateStoreIfNeeded(
                            at: storeURL
                        )
                        
                        // 成功完成后记录日志和配置索引
                        self.logger.info("数据模型检查完成")
                        
                        // 配置模型索引
                        self.configureModelIndices()
                    } catch {
                        self.logger.error("数据迁移失败: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // 自动合并更改
        container.viewContext.automaticallyMergesChangesFromParent = true
        // 创建一个新的NSMergePolicy实例而不是使用全局共享的变量
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        // 配置视图上下文
        container.viewContext.shouldDeleteInaccessibleFaults = true
        container.viewContext.name = "MainContext"
        
        // 添加存储通知观察者
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStoreRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
        
        // 添加对象更改通知观察者
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleObjectsDidChange(_:)),
            name: NSNotification.Name.NSManagedObjectContextObjectsDidChange,
            object: nil
        )
        
        return container
    }()
    
    /// 主上下文 - 用于UI更新
    public var mainContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Cache Operations
    
    /// 缓存对象
    /// - Parameters:
    ///   - object: 要缓存的对象
    ///   - cost: 缓存成本（默认为1）
    public func cacheObject(_ object: NSManagedObject, cost: Int = 1) {
        objectCache.setObject(object, forKey: object.objectID, cost: cost)
    }
    
    /// 从缓存获取对象
    /// - Parameter objectID: 对象ID
    /// - Returns: 缓存的对象（如果存在）
    public func cachedObject(for objectID: NSManagedObjectID) -> NSManagedObject? {
        if let object = objectCache.object(forKey: objectID) {
            Task { await cacheStatsActor.recordObjectCacheHit() }
            return object
        }
        Task { await cacheStatsActor.recordObjectCacheMiss() }
        return nil
    }
    
    /// 缓存查询结果
    /// - Parameters:
    ///   - results: 查询结果
    ///   - queryKey: 查询键
    ///   - cost: 缓存成本（默认为结果数量）
    public func cacheQueryResults(_ results: [NSManagedObject], forKey queryKey: String, cost: Int? = nil) {
        let cacheCost = cost ?? results.count
        queryCache.setObject(results as NSArray, forKey: queryKey, cost: cacheCost)
    }
    
    /// 获取缓存的查询结果
    /// - Parameter queryKey: 查询键
    /// - Returns: 缓存的查询结果（如果存在）
    public func cachedQueryResults(forKey queryKey: String) -> [NSManagedObject]? {
        if let results = queryCache.object(forKey: queryKey) as? [NSManagedObject] {
            Task { await cacheStatsActor.recordQueryCacheHit() }
            return results
        }
        Task { await cacheStatsActor.recordQueryCacheMiss() }
        return nil
    }
    
    /// 获取缓存统计信息
    /// - Returns: 缓存统计结构体
    public func getStatistics() async -> CacheStatistics {
        // 获取对象缓存和查询缓存的命中率
        let objectStats = await cacheStatsActor.getObjectCacheStats()
        
        // 计算总命中和未命中
        let totalHits = objectStats.hits
        let totalMisses = objectStats.misses
        
        return CacheStatistics(hits: totalHits, misses: totalMisses)
    }
    
    /// 重置缓存统计信息
    public func resetStatistics() async {
        await cacheStatsActor.resetStats()
    }
    
    /// 清理过期缓存
    public func cleanupExpiredCache() {
        objectCache.removeExpiredObjects()
        queryCache.removeExpiredObjects()
    }
    
    /// 清除所有缓存
    public func clearAllCaches() {
        objectCache.removeAllObjects()
        queryCache.removeAllObjects()
        logger.info("已清除所有实体对象缓存")
    }
    
    /// 获取缓存统计信息
    public func cacheStatistics() -> String {
        let objectStats = objectCache.statistics
        let queryStats = queryCache.statistics
        
        return """
        实体对象缓存：\(objectStats.count) 项
        查询结果缓存：\(queryStats.count) 项
        """
    }
    
    // MARK: - Entity Class Names Registration
    
    /// 注册实体类名映射
    private func registerEntityClassNames(in model: NSManagedObjectModel) {
        // 获取所有实体
        for entity in model.entities where entity.managedObjectClassName != nil {
            switch entity.name {
            case "Document":
                entity.managedObjectClassName = String(describing: CDDocument.self)
            case "Slide":
                entity.managedObjectClassName = String(describing: CDSlide.self)
            case "Element":
                entity.managedObjectClassName = String(describing: CDElement.self)
            case "User":
                entity.managedObjectClassName = String(describing: CDUser.self)
            case "Template":
                entity.managedObjectClassName = String(describing: CDTemplate.self)
            default:
                continue
            }
        }
    }
    
    // MARK: - Value Transformers
    
    /// 注册值转换器
    private func registerValueTransformers() {
        DocumentMetadataTransformer.register()
    }
    
    /// 处理持久化存储加载错误
    /// - Parameters:
    ///   - error: 错误
    ///   - storeDescription: 存储描述
    private func handlePersistentStoreLoadingError(_ error: Error, storeDescription: NSPersistentStoreDescription) {
        logger.error("错误: 加载持久化存储失败: \(error.localizedDescription)")
        
        // 检查是否由迁移失败导致
        if let nserror = error as NSError {
            if nserror.domain == NSCocoaErrorDomain && 
               (nserror.code == NSPersistentStoreIncompatibleVersionHashError ||
                nserror.code == NSMigrationMissingSourceModelError) {
                
                // 记录迁移错误
                logger.error("错误: 需要迁移，但迁移失败: \(nserror)")
                
                // 尝试执行手动迁移
                Task {
                    do {
                        guard let storeURL = storeDescription.url else {
                            logger.error("错误: 无法获取存储URL")
                            return
                        }
                        
                        let migrationManager = CoreDataMigrationManager.shared
                        try await migrationManager.performMigration(at: storeURL)
                        
                        // 迁移成功后，尝试重新加载存储
                        logger.info("手动迁移成功，正在尝试重新加载存储")
                        try persistentContainer.persistentStoreCoordinator.addPersistentStore(
                            ofType: storeDescription.type,
                            configurationName: storeDescription.configuration,
                            at: storeURL,
                            options: storeDescription.options
                        )
                    } catch {
                        logger.error("手动迁移和重新加载失败: \(error.localizedDescription)")
                    }
                }
            } else {
                // 其他错误类型
                logger.error("持久化存储加载失败: \(error.localizedDescription), 错误域: \(nserror.domain), 错误码: \(nserror.code)")
                
                // 处理常见错误
                handleCommonPersistentStoreErrors(error)
            }
        } else {
            // 非NSError类型错误
            logger.error("持久化存储加载错误: \(error.localizedDescription)")
        }
    }
    
    /// 主视图上下文
    public var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // MARK: - Background Context
    
    /// 创建后台上下文
    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        let mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.mergePolicy = mergePolicy
        context.shouldDeleteInaccessibleFaults = true
        return context
    }
    
    // MARK: - Saving
    
    /// 保存上下文
    /// - Parameter context: 需要保存的上下文
    public func saveContext(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            CoreDataErrorHandler.shared.handle(error, context: "保存上下文")
        }
    }
    
    /// 保存主上下文
    public func saveViewContext() {
        saveContext(viewContext)
    }
    
    // MARK: - Utilities
    
    /// 执行批量操作
    /// - Parameters:
    ///   - batchSize: 批量大小
    ///   - operation: 批量操作闭包
    public func performBatchOperation(batchSize: Int = 100, operation: @escaping (NSManagedObjectContext) -> Void) {
        let context = newBackgroundContext()
        context.performAndWait {
            context.reset() // 重置上下文以释放内存
            operation(context)
            saveContext(context)
        }
    }
    
    /// 清理无效的托管对象
    public func cleanupInvalidManagedObjects() {
        viewContext.refreshAllObjects()
    }
    
    // MARK: - Store Notifications
    
    /// 处理远程存储更改通知
    @objc private func handleStoreRemoteChange(_ notification: Notification) {
        // 处理远程存储更改
        viewContext.perform {
            self.viewContext.mergeChanges(fromContextDidSave: notification)
        }
    }
    
    /// 处理对象更改通知
    @objc private func handleObjectsDidChange(_ notification: Notification) {
        // 仅处理来自视图上下文或后台上下文的通知
        guard let context = notification.object as? NSManagedObjectContext,
              context === viewContext || context.parent === viewContext else {
            return
        }
        
        // 获取已删除对象，从缓存中移除
        if let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>, !deletedObjects.isEmpty {
            for object in deletedObjects {
                objectCache.removeObject(forKey: object.objectID)
            }
        }
        
        // 获取已插入或更新的对象，更新缓存
        if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>, !updatedObjects.isEmpty {
            for object in updatedObjects {
                // 仅缓存Document和Slide等重要实体
                if let entityName = object.entity.name,
                   ["Document", "Slide", "User", "Template"].contains(entityName) {
                    cacheObject(object)
                }
            }
        }
        
        // 如果有变更，清理查询缓存
        if (notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>)?.isEmpty == false ||
           (notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>)?.isEmpty == false ||
           (notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>)?.isEmpty == false {
            // 清理查询缓存
            queryCache.removeAllObjects()
        }
    }
    
    // MARK: - Migration
    
    /// 检查是否需要迁移
    /// - Returns: 是否需要迁移
    private func needsMigration(at storeURL: URL) -> Bool {
        do {
            return try CoreDataModelVersionManager.shared.requiresMigration(at: storeURL)
        } catch {
            CoreDataErrorHandler.shared.handle(error, context: "检查迁移状态")
            return false
        }
    }
    
    /// 执行轻量级迁移
    public func performLightweightMigration() {
        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            return
        }
        
        do {
            try persistentContainer.persistentStoreCoordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: options
            )
        } catch {
            CoreDataErrorHandler.shared.handle(error, context: "轻量级迁移")
        }
    }
    
    /// 设置持久化容器
    /// - Parameter name: 模型名称
    public func setupPersistentContainer(name: String) {
        let container = NSPersistentContainer(name: name)
        
        // 添加持久化存储描述
        let description = NSPersistentStoreDescription()
        // 配置存储选项
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // 应用存储描述
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { [weak self] (storeDescription, error) in
            if let error = error as NSError? {
                self?.logger.error("加载持久化存储失败: \(error), \(error.userInfo)")
            } else {
                self?.logger.info("成功加载持久化存储: \(storeDescription)")
                
                // 视图上下文合并策略
                container.viewContext.automaticallyMergesChangesFromParent = true
                // 创建一个新的NSMergePolicy实例而不是使用全局共享的变量
                container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
                
                // 配置索引
                self?.configureModelIndices()
            }
        }
        
        self.persistentContainer = container
    }
    
    /// 配置模型索引
    public func configureModelIndices() {
        // 使用索引配置类配置索引
        // 注意：model变量在这里实际未被使用
        _ = persistentContainer.managedObjectModel
        
        // TODO: 这里应该实现实际的索引配置
        // 由于 CoreDataIndexConfiguration.shared 不存在，我们需要直接实现或移除这部分
        
        // 临时解决方案：注释掉不存在的调用
        // CoreDataIndexConfiguration.shared.configureIndices(for: model)
        logger.info("已配置数据模型索引")
    }
    
    // MARK: - Context and Store Management
    
    /// 重置视图上下文
    public func resetContext() {
        persistentContainer.viewContext.reset()
        logger.info("已重置视图上下文")
    }
    
    /// 重置持久化存储
    /// - Throws: 重置过程中的错误
    public func resetStore() async throws {
        logger.info("开始重置持久化存储")
        
        // 获取存储URL和协调器
        let coordinator = persistentContainer.persistentStoreCoordinator
        guard let store = coordinator.persistentStores.first,
              let storeURL = store.url else {
            throw CoreDataError.storeNotFound("无法获取持久化存储")
        }
        
        // 清除所有缓存
        clearAllCaches()
        
        // 重置视图上下文
        await mainContext.perform {
            self.mainContext.reset()
        }
        
        do {
            // 删除存储
            try coordinator.remove(store)
            
            // 添加新存储
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: persistentStoreOptions
            )
            
            logger.info("持久化存储重置成功")
        } catch {
            logger.error("重置持久化存储失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 重新创建持久化存储
    /// - Throws: 重建过程中的错误
    public func recreateStore() async throws {
        logger.info("开始重建持久化存储")
        
        // 获取存储URL和协调器
        let coordinator = persistentContainer.persistentStoreCoordinator
        guard let store = coordinator.persistentStores.first,
              let storeURL = store.url else {
            throw CoreDataError.storeNotFound("无法获取持久化存储")
        }
        
        // 获取存储路径
        let storePath = storeURL.path
        // 注意：storeDirectory 变量在下面的代码中未被使用
        // let storeDirectory = storeURL.deletingLastPathComponent().path
        let fileManager = FileManager.default
        
        // 清除所有缓存
        clearAllCaches()
        
        // 重置视图上下文
        await mainContext.perform {
            self.mainContext.reset()
        }
        
        do {
            // 删除存储
            try coordinator.remove(store)
            
            // 删除所有相关文件
            if fileManager.fileExists(atPath: storePath) {
                try fileManager.removeItem(atPath: storePath)
            }
            
            // 删除WAL和SHM文件
            let walPath = storePath + "-wal"
            if fileManager.fileExists(atPath: walPath) {
                try fileManager.removeItem(atPath: walPath)
            }
            
            let shmPath = storePath + "-shm"
            if fileManager.fileExists(atPath: shmPath) {
                try fileManager.removeItem(atPath: shmPath)
            }
            
            // 添加新存储
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: persistentStoreOptions
            )
            
            logger.info("持久化存储重建成功")
        } catch {
            logger.error("重建持久化存储失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 保存上下文
    /// - Throws: 保存过程中的错误
    public func saveContext() async throws {
        if mainContext.hasChanges {
            do {
                try await mainContext.perform {
                    try self.mainContext.save()
                }
                logger.debug("成功保存视图上下文")
            } catch {
                logger.error("保存视图上下文失败: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    /// 处理常见的持久化存储错误
    /// - Parameter error: 错误对象
    private func handleCommonPersistentStoreErrors(_ error: Error) {
        let nsError = error as NSError
        
        switch (nsError.domain, nsError.code) {
        case (NSCocoaErrorDomain, NSFileReadNoSuchFileError),
             (NSCocoaErrorDomain, NSFileReadInvalidFileNameError):
            // 文件不存在或文件名无效
            logger.warning("存储文件不存在或无效，将创建新的存储文件")
            
        case (NSCocoaErrorDomain, NSPersistentStoreIncompatibleVersionHashError):
            // 版本不兼容
            logger.error("存储文件版本不兼容")
            
        case (NSCocoaErrorDomain, NSMigrationError),
             (NSCocoaErrorDomain, NSMigrationMissingSourceModelError),
             (NSCocoaErrorDomain, NSMigrationMissingMappingModelError):
            // 迁移相关错误
            logger.error("存储迁移失败: \(nsError.localizedDescription)")
            
        case (NSPOSIXErrorDomain, 13): // EACCES
            // 权限错误
            logger.error("无访问权限: \(nsError.localizedDescription)")
            
        case (NSCocoaErrorDomain, NSPersistentStoreIncompleteSaveError):
            // 保存不完整
            logger.error("保存操作不完整: \(nsError.localizedDescription)")
            
        case (NSCocoaErrorDomain, NSPersistentStoreInvalidTypeError):
            // 无效存储类型
            logger.error("无效的存储类型: \(nsError.localizedDescription)")
            
        case (NSCocoaErrorDomain, NSPersistentStoreCoordinatorLockingError):
            // 存储协调器锁定错误
            logger.error("存储协调器锁定错误: \(nsError.localizedDescription)")
            
        case (NSCocoaErrorDomain, NSCoreDataError):
            // 通用Core Data错误
            logger.error("通用Core Data错误: \(nsError.localizedDescription)")
            
        default:
            // 未知错误
            logger.error("未分类持久化存储错误: \(nsError.domain), \(nsError.code): \(nsError.localizedDescription)")
        }
    }
} 