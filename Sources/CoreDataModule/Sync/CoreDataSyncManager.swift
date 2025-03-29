@preconcurrency import Foundation
@preconcurrency import CoreData
@preconcurrency import Combine
import os
import Network

/// 同步配置
public struct SyncConfiguration: Sendable {
    /// 同步间隔，单位为秒
    public let syncInterval: TimeInterval
    
    /// 同步批次大小
    public let batchSize: Int
    
    /// 最大重试次数
    public let retryCount: Int
    
    /// 冲突解决策略
    public let conflictResolutionPolicy: NSMergePolicyType
    
    /// 默认配置
    public static let `default` = SyncConfiguration(
        syncInterval: 60.0,
        batchSize: 100,
        retryCount: 3,
        conflictResolutionPolicy: .mergeByPropertyObjectTrumpMergePolicyType
    )
    
    /// 初始化
    public init(
        syncInterval: TimeInterval,
        batchSize: Int,
        retryCount: Int,
        conflictResolutionPolicy: NSMergePolicyType
    ) {
        self.syncInterval = syncInterval
        self.batchSize = batchSize
        self.retryCount = retryCount
        self.conflictResolutionPolicy = conflictResolutionPolicy
    }
}

/// 同步状态
public enum CoreDataSyncState: Equatable, Sendable {
    /// 空闲状态
    case idle
    
    /// 同步中
    case syncing(progress: Double)
    
    /// 错误
    case error(Error)
    
    public static func == (lhs: CoreDataSyncState, rhs: CoreDataSyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.syncing(let lhsProgress), .syncing(let rhsProgress)):
            return lhsProgress == rhsProgress
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// 同步状态管理的Actor
actor SyncStateActor {
    private let stateSubject = CurrentValueSubject<CoreDataSyncState, Never>(.idle)
    
    var currentState: CoreDataSyncState {
        stateSubject.value
    }
    
    func updateState(_ state: CoreDataSyncState) {
        stateSubject.send(state)
    }
    
    func publisher() -> AnyPublisher<CoreDataSyncState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
}

/// 负责Core Data同步的管理器
public actor CoreDataSyncManager {
    // MARK: - Properties
    
    private static var _shared: CoreDataSyncManager?
    public static var shared: CoreDataSyncManager {
        if _shared == nil {
            _shared = CoreDataSyncManager()
        }
        return _shared!
    }
    
    private let configuration: SyncConfiguration
    private var syncTask: Task<Void, Never>?
    private let stateActor = SyncStateActor()
    private var cancellables = Set<AnyCancellable>()
    
    // 存储通知观察者任务，以便可以取消它们
    private var observerTasks: [Task<Void, Never>] = []
    
    // 网络状态监视器
    private var networkMonitor: NWPathMonitor?
    
    // 当前网络状态 - 使用 nonisolated(unsafe) 允许在非 actor 上下文中访问，
    // 但需要在处理时格外小心，确保访问时在 Task 中
    nonisolated(unsafe) private var isNetworkAvailable: Bool = false
    
    var syncState: AnyPublisher<CoreDataSyncState, Never> {
        get async {
            return await stateActor.publisher()
        }
    }
    
    // MARK: - Initialization
    
    init(configuration: SyncConfiguration = .default) {
        self.configuration = configuration
        // 在初始化器中不能调用异步方法
    }
    
    /// 创建和设置共享实例
    public static func initialize() async {
        // 设置观察者和定时器
        await shared.setupObservers()
        await shared.setupNetworkMonitoring()
        await shared.setupSyncTimer()
    }
    
    // MARK: - Sync Management
    
    /// 开始同步
    func startSync() async {
        // 检查网络可用性
        if !isNetworkAvailable {
            CoreLogger.warning("网络不可用，跳过同步", category: "Sync")
            await stateActor.updateState(.error(CoreDataError.networkUnavailable))
            return
        }
        
        // 获取当前状态，检查是否已经在同步
        let currentState = await stateActor.currentState
        
        // 检查当前状态，避免重复同步
        guard currentState == .idle else { 
            CoreLogger.info("同步已经在进行中，跳过", category: "Sync")
            return 
        }
        
        // 更新状态为同步中
        await stateActor.updateState(.syncing(progress: 0.0))
        CoreLogger.info("开始同步操作", category: "Sync")
        
        do {
            // 执行同步
            try await performSync()
            
            // 同步锁定状态更新
            await stateActor.updateState(.idle)
            CoreLogger.info("同步操作成功完成", category: "Sync")
        } catch {
            // 同步锁定状态更新
            await stateActor.updateState(.error(error))
            CoreLogger.error("同步操作失败: \(error.localizedDescription)", category: "Sync")
        }
    }
    
    /// 停止同步
    func stopSync() {
        CoreLogger.info("正在停止同步定时器和任务", category: "Sync")
        syncTask?.cancel()
        syncTask = nil
        
        // 取消所有观察者任务
        for task in observerTasks {
            task.cancel()
        }
        observerTasks.removeAll()
        
        // 停止网络监视器
        stopNetworkMonitoring()
    }
    
    /// 设置网络状态监视
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { [weak self] in
                guard let self = self else { return }
                
                let newNetworkAvailable = path.status == .satisfied
                
                // 在 Task 中访问 actor 隔离的属性，这样是安全的
                await self.updateNetworkStatus(newNetworkAvailable: newNetworkAvailable)
            }
        }
        
        // 在全局队列上启动监视器
        let queue = DispatchQueue(label: "com.onlyslide.network-monitor")
        networkMonitor?.start(queue: queue)
        
        CoreLogger.info("网络监视已启动", category: "Sync")
    }
    
    /// 停止网络状态监视
    private func stopNetworkMonitoring() {
        networkMonitor?.cancel()
        networkMonitor = nil
        CoreLogger.info("网络监视已停止", category: "Sync")
    }
    
    /// 设置同步定时器
    func setupSyncTimer() {
        // 使用 Task 和 async/await 替代 Timer
        // 使用 @Sendable 闭包避免数据竞争
        syncTask = Task { @Sendable [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                await self.startSync()
                
                do {
                    // 等待指定的同步间隔
                    try await Task.sleep(nanoseconds: UInt64(self.configuration.syncInterval * 1_000_000_000))
                } catch {
                    // Task 被取消或其他错误
                    break
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // 使用NSNotification.Name类型而不是直接使用字符串，避免Optional<Notification>的Sendable问题
        let notificationName = NSNotification.Name.NSPersistentStoreRemoteChange
        
        // 创建任务并存储引用以便后续取消
        let task = Task { @Sendable [weak self] in
            // 创建一个只接收通知但不传递Notification对象的流
            let notifications = NotificationCenter.default.notifications(named: notificationName)
            for await _ in notifications {
                // 获取self
                guard let self = self else { break }
                // 异步调用处理方法
                await self.handleRemoteChange()
            }
        }
        
        // 存储任务以便后续取消
        observerTasks.append(task)
    }
    
    private func handleRemoteChange() async {
        CoreLogger.info("接收到远程变更通知", category: "Sync")
        await startSync()
    }
    
    private func performSync() async throws {
        // 在主actor上创建上下文
        let context = await MainActor.run { CoreDataStack.shared.newBackgroundContext() }
        
        // 设置冲突解决策略
        await MainActor.run {
            // 直接使用合并策略常量
            switch self.configuration.conflictResolutionPolicy {
            case .mergeByPropertyObjectTrumpMergePolicyType:
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            case .mergeByPropertyStoreTrumpMergePolicyType:
                context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
            case .overwriteMergePolicyType:
                context.mergePolicy = NSOverwriteMergePolicy
            case .rollbackMergePolicyType:
                context.mergePolicy = NSRollbackMergePolicy
            default:
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            }
        }
        
        // 安全地获取需要同步的更改
        let changes = try await fetchChangesNeedingSync(context: context)
        
        CoreLogger.info("找到 \(changes.count) 个需要同步的更改", category: "Sync")
        
        // 批量处理更改
        try await processBatchChanges(changes, in: context)
        
        // 更新同步状态
        try await updateSyncStatus(in: context)
    }
    
    /// 安全地获取需要同步的更改
    private func fetchChangesNeedingSync(context: NSManagedObjectContext) async throws -> [NSManagedObject] {
        // 使用Task.detached创建隔离的执行环境，防止数据竞争
        return try await Task.detached {
            return try await context.performAndWait {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SyncLog")
                fetchRequest.predicate = NSPredicate(format: "synced == NO")
                fetchRequest.fetchBatchSize = self.configuration.batchSize
                
                return try context.fetch(fetchRequest)
            }
        }.value
    }
    
    private func processBatchChanges(_ changes: [NSManagedObject], in context: NSManagedObjectContext) async throws {
        var retryCount = 0
        var processedCount = 0
        let totalCount = changes.count
        
        // 创建changes的本地不可变副本，避免数据竞争
        let changesCopy = changes
        
        repeat {
            do {
                var success = false
                
                try await context.performAndWait {
                    for (index, change) in changesCopy.enumerated() {
                        // 更新进度
                        let progress = 0.1 + 0.8 * (Double(index) / Double(totalCount))
                        
                        // 使用async let避免捕获self和可变状态
                        async let _ = self.stateActor.updateState(.syncing(progress: progress))
                        
                        // 处理单个更改
                        try self.processChange(change, in: context)
                        processedCount += 1
                        
                        // 每处理10个对象保存一次，以避免大事务
                        if index % 10 == 9 {
                            try context.save()
                            CoreLogger.debug("已保存处理的更改，进度: \(String(format: "%.1f", progress * 100))%", category: "Sync")
                        }
                    }
                    
                    // 最终保存
                    try context.save()
                    success = true
                    CoreLogger.info("成功处理并保存了 \(processedCount) 个更改", category: "Sync")
                }
                
                if success {
                    return
                }
            } catch {
                retryCount += 1
                if retryCount >= self.configuration.retryCount {
                    CoreLogger.error("处理批量更改失败，已达到最大重试次数: \(error.localizedDescription)", category: "Sync")
                    throw error
                }
                
                CoreLogger.warning("处理批量更改失败，正在重试 (\(retryCount)/\(self.configuration.retryCount)): \(error.localizedDescription)", category: "Sync")
                
                // 等待一段时间后再重试 - 使用指数退避策略
                let retryDelay = TimeInterval(pow(2.0, Double(retryCount - 1)))
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        } while retryCount < self.configuration.retryCount
    }
    
    private func processChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws {
        // 根据变更类型执行相应的操作
        guard let changeType = change.value(forKey: "type") as? String else {
            CoreLogger.error("无效的变更类型", category: "Sync")
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
            CoreLogger.error("不支持的变更类型: \(changeType)", category: "Sync")
            throw CoreDataError.invalidManagedObject("Unsupported change type: \(changeType)")
        }
        
        // 标记为已同步
        change.setValue(true, forKey: "synced")
        change.setValue(Date(), forKey: "syncedAt")
    }
    
    private func handleInsertChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws {
        // 处理插入操作
        CoreLogger.debug("处理插入操作", category: "Sync")
        // 实际插入代码...
    }
    
    private func handleUpdateChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws {
        // 处理更新操作
        CoreLogger.debug("处理更新操作", category: "Sync")
        // 实际更新代码...
    }
    
    private func handleDeleteChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws {
        // 处理删除操作
        CoreLogger.debug("处理删除操作", category: "Sync")
        // 实际删除代码...
    }
    
    private func updateSyncStatus(in context: NSManagedObjectContext) async throws {
        // 更新最后同步时间等信息
        CoreLogger.debug("更新同步状态", category: "Sync")
        
        try await context.performAndWait {
            // 实际更新代码...
            // 例如设置最后同步时间
            let now = Date()
            
            // 清理老旧的同步日志
            try self.clearSyncLogs(olderThan: now.addingTimeInterval(-30 * 86400), in: context)
        }
    }
    
    private func clearSyncLogs(olderThan date: Date, in context: NSManagedObjectContext) throws {
        // 清理老旧的同步日志
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SyncLog")
        fetchRequest.predicate = NSPredicate(format: "syncedAt < %@", date as NSDate)
        
        let oldLogs = try context.fetch(fetchRequest)
        CoreLogger.info("清理 \(oldLogs.count) 条老旧同步日志", category: "Sync")
        
        for log in oldLogs {
            context.delete(log)
        }
        
        try context.save()
    }
    
    /// 更新网络状态
    private func updateNetworkStatus(newNetworkAvailable: Bool) async {
        let previousNetworkAvailable = self.isNetworkAvailable
        self.isNetworkAvailable = newNetworkAvailable
        
        // 记录网络状态变化
        if previousNetworkAvailable != newNetworkAvailable {
            CoreLogger.info("网络状态变更: \(newNetworkAvailable ? "可用" : "不可用")", category: "Sync")
            
            // 如果网络恢复且同步状态为错误状态，触发同步
            if newNetworkAvailable {
                let currentState = await self.stateActor.currentState
                if case .error = currentState {
                    await self.startSync()
                }
            }
        }
    }
} 