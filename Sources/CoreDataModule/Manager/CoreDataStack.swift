import CoreData
import Foundation

/// Core Data 栈管理类
public final class CoreDataStack {
    // MARK: - Singleton
    
    public static let shared = CoreDataStack()
    
    private init() {}
    
    // MARK: - Core Data Stack
    
    /// 持久化容器
    public lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "OnlySlide")
        
        // 配置存储选项
        let storeDescription = NSPersistentStoreDescription()
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // 配置迁移选项
        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        storeDescription.setOption(options as NSDictionary, forKey: NSPersistentStoreOptionsKey)
        
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
                                print("Migration progress: \(progress.percentage)%")
                            }
                        )
                        
                        if didMigrate {
                            print("数据迁移成功完成")
                        }
                    } catch {
                        print("数据迁移失败: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // 自动合并更改
        container.viewContext.automaticallyMergesChangesFromParent = true
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
    
    /// 处理持久化存储加载错误
    private func handlePersistentStoreLoadingError(_ error: Error, storeDescription: NSPersistentStoreDescription) {
        print("无法加载持久化存储: \(error.localizedDescription)")
        
        if let storeURL = storeDescription.url, needsMigration(at: storeURL) {
            print("检测到需要迁移数据")
            
            // 如果是迁移问题，尝试删除并重新创建存储
            do {
                try FileManager.default.removeItem(at: storeURL)
                print("已删除旧存储，将创建新存储")
                
                // 重新加载存储
                persistentContainer.loadPersistentStores { (description, error) in
                    if let error = error {
                        fatalError("重新创建存储失败: \(error.localizedDescription)")
                    }
                }
            } catch {
                fatalError("删除旧存储失败: \(error.localizedDescription)")
            }
        } else {
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