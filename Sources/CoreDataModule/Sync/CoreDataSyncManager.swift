import Core
import CoreDataModuleData
import Combine

/// 同步状态
enum CoreDataSyncState: Equatable {
    case idle
    case syncing(progress: Double)
    case error(Error)
    
    static func == (lhs: CoreDataSyncState, rhs: CoreDataSyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case let (.syncing(lhsProgress), .syncing(rhsProgress)):
            return lhsProgress == rhsProgress
        case let (.error(lhsError), .error(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// 同步配置
struct SyncConfiguration {
    let batchSize: Int
    let retryCount: Int
    let syncInterval: TimeInterval
    let conflictResolutionPolicy: NSMergePolicyType
    
    static let `default` = SyncConfiguration(
        batchSize: 100,
        retryCount: 3,
        syncInterval: 300, // 5分钟
        conflictResolutionPolicy: .mergeByPropertyObjectTrumpMergePolicyType
    )
}

/// Core Data 同步管理器
final class CoreDataSyncManager {
    // MARK: - Properties
    
    static let shared = CoreDataSyncManager()
    
    private let syncQueue = DispatchQueue(label: "com.onlyslide.coredata.sync", qos: .utility)
    private let configuration: SyncConfiguration
    private var syncTimer: Timer?
    private var syncStateSubject = CurrentValueSubject<CoreDataSyncState, Never>(.idle)
    private var cancellables = Set<AnyCancellable>()
    
    var syncState: AnyPublisher<CoreDataSyncState, Never> {
        syncStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init(configuration: SyncConfiguration = .default) {
        self.configuration = configuration
        setupSyncTimer()
        setupObservers()
    }
    
    // MARK: - Sync Management
    
    /// 开始同步
    func startSync() {
        guard syncStateSubject.value == .idle else { return }
        
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.syncStateSubject.send(.syncing(progress: 0.0))
            
            do {
                // 执行同步
                try self.performSync()
                self.syncStateSubject.send(.idle)
            } catch {
                self.syncStateSubject.send(.error(error))
            }
        }
    }
    
    /// 停止同步
    func stopSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func setupSyncTimer() {
        syncTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.syncInterval,
            repeats: true
        ) { [weak self] _ in
            self?.startSync()
        }
    }
    
    private func setupObservers() {
        // 监听远程变更通知
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] _ in
                self?.handleRemoteChange()
            }
            .store(in: &cancellables)
        
        // 监听网络状态变化
        // TODO: 添加网络状态监听
    }
    
    private func performSync() throws {
        let context = CoreDataStack.shared.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: configuration.conflictResolutionPolicy)
        
        // 获取需要同步的更改
        let changes = try fetchPendingChanges(in: context)
        
        // 批量处理更改
        try processBatchChanges(changes, in: context)
        
        // 更新同步状态
        try updateSyncStatus(in: context)
    }
    
    private func fetchPendingChanges(in context: NSManagedObjectContext) throws -> [NSManagedObject] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SyncLog")
        fetchRequest.predicate = NSPredicate(format: "synced == NO")
        fetchRequest.fetchBatchSize = configuration.batchSize
        
        return try context.fetch(fetchRequest)
    }
    
    private func processBatchChanges(_ changes: [NSManagedObject], in context: NSManagedObjectContext) throws {
        var retryCount = 0
        
        repeat {
            do {
                try context.performAndWait {
                    for change in changes {
                        try processChange(change, in: context)
                    }
                    try context.save()
                }
                return
            } catch {
                retryCount += 1
                if retryCount >= configuration.retryCount {
                    throw error
                }
            }
        } while retryCount < configuration.retryCount
    }
    
    private func processChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws {
        // 根据变更类型执行相应的操作
        guard let changeType = change.value(forKey: "type") as? String else {
            throw CoreDataError.invalidManagedObject("Invalid change type")
        }
        
        switch changeType {
        case "insert":
            try handleInsertChange(change, in: context)
        case "update":
            try handleUpdateChange(change, in: context)
        case "delete":
            try handleDeleteChange(change, in: context)
        default:
            throw CoreDataError.invalidManagedObject("Unknown change type: \(changeType)")
        }
    }
    
    private func handleInsertChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws {
        // 处理插入操作
    }
    
    private func handleUpdateChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws {
        // 处理更新操作
    }
    
    private func handleDeleteChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws {
        // 处理删除操作
    }
    
    private func updateSyncStatus(in context: NSManagedObjectContext) throws {
        // 更新同步状态和时间戳
    }
    
    private func handleRemoteChange() {
        // 处理远程变更
        startSync()
    }
    
    // MARK: - Conflict Resolution
    
    /// 解决冲突
    /// - Parameters:
    ///   - localObject: 本地对象
    ///   - remoteObject: 远程对象
    /// - Returns: 解决后的对象
    private func resolveConflict(localObject: NSManagedObject, remoteObject: NSManagedObject) -> NSManagedObject {
        // 根据配置的合并策略解决冲突
        switch configuration.conflictResolutionPolicy {
        case .mergeByPropertyObjectTrumpMergePolicyType:
            // 对象级别的属性合并，本地对象优先
            return localObject
        case .mergeByPropertyStoreTrumpMergePolicyType:
            // 对象级别的属性合并，远程对象优先
            return remoteObject
        case .overwriteMergePolicyType:
            // 完全覆盖
            return remoteObject
        case .rollbackMergePolicyType:
            // 回滚到远程版本
            return remoteObject
        default:
            return localObject
        }
    }
    
    // MARK: - Offline Support
    
    /// 启用离线支持
    func enableOfflineSupport() {
        // 配置离线存储
        let storeDescription = CoreDataStack.shared.persistentContainer.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // 设置变更跟踪
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
    }
    
    /// 合并离线更改
    func mergeOfflineChanges() throws {
        let context = CoreDataStack.shared.newBackgroundContext()
        
        try context.performAndWait {
            // 获取离线更改
            let changes = try fetchOfflineChanges(in: context)
            
            // 处理离线更改
            try processBatchChanges(changes, in: context)
            
            // 清理历史记录
            try cleanupHistory(in: context)
        }
    }
    
    private func fetchOfflineChanges(in context: NSManagedObjectContext) throws -> [NSManagedObject] {
        // 获取离线期间的更改
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "OfflineChange")
        return try context.fetch(fetchRequest)
    }
    
    private func cleanupHistory(in context: NSManagedObjectContext) throws {
        // 清理历史记录
        guard let store = CoreDataStack.shared.persistentContainer.persistentStoreCoordinator.persistentStores.first else {
            return
        }
        
        let deleteHistoryRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: Date())
        try context.execute(deleteHistoryRequest)
    }
} 