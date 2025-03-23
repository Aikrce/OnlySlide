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
        CoreDataMigrationManager.shared.performMigration { result in
            switch result {
            case .success:
                // 迁移成功后加载存储
                container.loadPersistentStores { (description, error) in
                    if let error = error {
                        fatalError("无法加载持久化存储: \(error)")
                    }
                }
            case .failure(let error):
                fatalError("数据迁移失败: \(error)")
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
    func saveContext(_ context: NSManagedObjectContext) {
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
    func performBatchOperation(batchSize: Int = 100, operation: @escaping (NSManagedObjectContext) -> Void) {
        let context = newBackgroundContext()
        context.performAndWait {
            context.reset() // 重置上下文以释放内存
            operation(context)
            saveContext(context)
        }
    }
    
    /// 清理无效的托管对象
    func cleanupInvalidManagedObjects() {
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
    func needsMigration() -> Bool {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            return false
        }
        
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
            
            let model = persistentContainer.managedObjectModel
            return !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        } catch {
            CoreDataErrorHandler.shared.handle(error, context: "检查迁移状态")
            return false
        }
    }
    
    /// 执行轻量级迁移
    func performLightweightMigration() {
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