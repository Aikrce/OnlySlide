import CoreData
import Foundation
import os

// 添加@preconcurrency导入以解决CoreData的Sendable警告
@preconcurrency import CoreData

/// Core Data 栈管理类
@MainActor public final class CoreDataStack: @unchecked Sendable {
    // MARK: - Singleton
    
    public static let shared = CoreDataStack()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "CoreDataStack")
    
    /// 对象实体缓存 - 按ID缓存常用实体
    private var objectCache: ExpiringCache<NSManagedObjectID, NSManagedObject>
    
    /// 实体查询缓存 - 缓存常用查询结果
    private var queryCache: ExpiringCache<String, NSArray>
    
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
        storeDescription.options = options
        
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
                        let didMigrate = try await migrationManager.performMigration(
                            at: storeURL,
                            progress: { progress in
                                self.logger.debug("Migration progress: \(progress.percentage)%")
                            }
                        )
                        
                        if didMigrate {
                            self.logger.info("数据迁移成功完成")
                        } else {
                            self.logger.info("无需迁移数据")
                        }
                        
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
        // 设置合并策略
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
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
        return objectCache.object(forKey: objectID)
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
        return queryCache.object(forKey: queryKey) as? [NSManagedObject]
    }
    
    /// 获取缓存统计信息
    /// - Returns: 缓存统计结构体
    public func getStatistics() async throws -> CacheStatistics {
        // 获取对象缓存和查询缓存的命中率
        let objectHits = objectCache.hitCount
        let objectMisses = objectCache.missCount
        let queryHits = queryCache.hitCount
        let queryMisses = queryCache.missCount
        
        // 计算总命中和未命中
        let totalHits = objectHits + queryHits
        let totalMisses = objectMisses + queryMisses
        
        return CacheStatistics(hits: totalHits, misses: totalMisses)
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
    private func handlePersistentStoreLoadingError(_ error: Error, storeDescription: NSPersistentStoreDescription) {
        logger.error("无法加载持久化存储: \(error.localizedDescription)")
        
        if let storeURL = storeDescription.url, needsMigration(at: storeURL) {
            logger.warning("检测到需要迁移数据")
            
            // 如果是迁移问题，尝试删除并重新创建存储
            do {
                try FileManager.default.removeItem(at: storeURL)
                logger.notice("已删除旧存储，将创建新存储")
                
                // 重新加载存储
                persistentContainer.loadPersistentStores { (description, error) in
                    if let error = error {
                        self.logger.error("重新创建存储失败: \(error.localizedDescription)")
                        fatalError("重新创建存储失败: \(error.localizedDescription)")
                    }
                }
            } catch {
                logger.error("删除旧存储失败: \(error.localizedDescription)")
                fatalError("删除旧存储失败: \(error.localizedDescription)")
            }
        } else {
            logger.error("无法加载持久化存储且无法恢复: \(error.localizedDescription)")
            fatalError("无法加载持久化存储且无法恢复: \(error.localizedDescription)")
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
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
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
                CoreLogger.error("加载持久化存储失败: \(error), \(error.userInfo)", category: "CoreData")
            } else {
                CoreLogger.info("成功加载持久化存储: \(storeDescription)", category: "CoreData")
                
                // 视图上下文合并策略
                container.viewContext.automaticallyMergesChangesFromParent = true
                container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                
                // 配置索引
                self?.configureModelIndices()
            }
        }
        
        self.persistentContainer = container
    }
    
    /// 配置模型索引
    public func configureModelIndices() {
        // 使用索引配置类配置索引
        guard let model = persistentContainer.managedObjectModel else {
            logger.warning("无法获取模型来配置索引")
            return
        }
        
        CoreDataIndexConfiguration.shared.configureIndices(for: model)
        logger.info("已配置数据模型索引")
    }
} 