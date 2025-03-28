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
    
    private init() {
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
        
        return container
    }()
    
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
} 