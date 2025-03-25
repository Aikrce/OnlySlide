@preconcurrency import Foundation
@preconcurrency import CoreData
@preconcurrency import Combine
import os

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
struct SyncConfiguration: Sendable {
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
@MainActor final class CoreDataSyncManager: Sendable {
    // MARK: - Properties
    
    @MainActor static let shared = CoreDataSyncManager()
    
    private let syncQueue = DispatchQueue(label: "com.onlyslide.coredata.sync", qos: .utility)
    private let configuration: SyncConfiguration
    private var syncTask: Task<Void, Never>?
    private var syncStateSubject = CurrentValueSubject<CoreDataSyncState, Never>(.idle)
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "Sync")
    
    // 添加锁以确保同步操作的线程安全
    private let syncLock = NSLock()
    
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
    @MainActor
    func startSync() async {
        // 使用锁确保同步操作的互斥性
        syncLock.lock()
        
        // 检查当前状态，避免重复同步
        guard syncStateSubject.value == .idle else { 
            logger.info("同步已经在进行中，跳过")
            syncLock.unlock()
            return 
        }
        
        // 更新状态为同步中
        syncStateSubject.send(.syncing(progress: 0.0))
        logger.info("开始同步操作")
        syncLock.unlock()
        
        do {
            // 执行同步
            try await performSync()
            
            // 同步锁定状态更新
            syncLock.lock()
            syncStateSubject.send(.idle)
            logger.info("同步操作成功完成")
            syncLock.unlock()
        } catch {
            // 同步锁定状态更新
            syncLock.lock()
            syncStateSubject.send(.error(error))
            logger.error("同步操作失败: \(error.localizedDescription)")
            syncLock.unlock()
        }
    }
    
    /// 停止同步
    func stopSync() {
        logger.info("正在停止同步定时器和任务")
        syncTask?.cancel()
        syncTask = nil
    }
    
    // MARK: - Private Methods
    
    private func setupSyncTimer() {
        // 使用 Task 和 async/await 替代 Timer
        syncTask = Task {
            while !Task.isCancelled {
                await startSync()
                
                do {
                    // 等待指定的同步间隔
                    try await Task.sleep(nanoseconds: UInt64(configuration.syncInterval * 1_000_000_000))
                } catch {
                    // Task 被取消或其他错误
                    break
                }
            }
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
    
    @MainActor
    private func performSync() async throws {
        let context = CoreDataStack.shared.newBackgroundContext()
        
        // 直接使用合并策略常量
        switch configuration.conflictResolutionPolicy {
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
        
        // 获取需要同步的更改
        var changes: [NSManagedObject] = []
        try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SyncLog")
            fetchRequest.predicate = NSPredicate(format: "synced == NO")
            fetchRequest.fetchBatchSize = self.configuration.batchSize
            
            changes = try context.fetch(fetchRequest)
        }
        
        logger.info("找到 \(changes.count) 个需要同步的更改")
        
        // 批量处理更改
        try await processBatchChanges(changes, in: context)
        
        // 更新同步状态
        try await updateSyncStatus(in: context)
    }
    
    @MainActor
    private func processBatchChanges(_ changes: [NSManagedObject], in context: NSManagedObjectContext) async throws {
        var retryCount = 0
        var processedCount = 0
        let totalCount = changes.count
        
        repeat {
            do {
                var success = false
                
                try await context.perform {
                    for (index, change) in changes.enumerated() {
                        // 更新进度
                        let progress = 0.1 + 0.8 * (Double(index) / Double(totalCount))
                        self.syncLock.lock()
                        self.syncStateSubject.send(.syncing(progress: progress))
                        self.syncLock.unlock()
                        
                        // 处理单个更改
                        try self.processChange(change, in: context)
                        processedCount += 1
                        
                        // 每处理10个对象保存一次，以避免大事务
                        if index % 10 == 9 {
                            try context.save()
                            self.logger.debug("已保存处理的更改，进度: \(String(format: "%.1f", progress * 100))%")
                        }
                    }
                    
                    // 最终保存
                    try context.save()
                    success = true
                    self.logger.info("成功处理并保存了 \(processedCount) 个更改")
                }
                
                if success {
                    return
                }
            } catch {
                retryCount += 1
                if retryCount >= configuration.retryCount {
                    logger.error("处理批量更改失败，已达到最大重试次数: \(error.localizedDescription)")
                    throw error
                }
                
                logger.warning("处理批量更改失败，正在重试 (\(retryCount)/\(configuration.retryCount)): \(error.localizedDescription)")
                
                // 等待一段时间后再重试
                let retryDelay = TimeInterval(retryCount) * 1.0
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        } while retryCount < configuration.retryCount
    }
    
    private func processChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws {
        // 根据变更类型执行相应的操作
        guard let changeType = change.value(forKey: "type") as? String else {
            logger.error("无效的变更类型")
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
            logger.error("未知的变更类型: \(changeType)")
            throw CoreDataError.invalidManagedObject("Unknown change type: \(changeType)")
        }
    }
    
    private func handleInsertChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws {
        // 处理插入操作
        logger.debug("处理插入变更: \(change.objectID.uriRepresentation().lastPathComponent)")
    }
    
    private func handleUpdateChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws {
        // 处理更新操作
        logger.debug("处理更新变更: \(change.objectID.uriRepresentation().lastPathComponent)")
    }
    
    private func handleDeleteChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws {
        // 处理删除操作
        logger.debug("处理删除变更: \(change.objectID.uriRepresentation().lastPathComponent)")
    }
    
    private func updateSyncStatus(in context: NSManagedObjectContext) throws {
        // 更新同步状态和时间戳
        logger.debug("更新同步状态")
    }
    
    /// 处理远程变更
    private func handleRemoteChange() {
        // 处理远程变更
        logger.info("检测到远程变更，启动同步")
        Task {
            await startSync()
        }
    }
    
    // MARK: - Conflict Resolution
    
    /// 解决冲突
    /// - Parameters:
    ///   - localObject: 本地对象
    ///   - remoteObject: 远程对象
    /// - Returns: 解决后的对象
    private func resolveConflict(localObject: NSManagedObject, remoteObject: NSManagedObject) -> NSManagedObject {
        logger.debug("解决冲突: \(localObject.objectID.uriRepresentation().lastPathComponent)")
        
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
    @MainActor
    func enableOfflineSupport() {
        logger.info("启用离线支持")
        
        // 配置离线存储
        let storeDescription = CoreDataStack.shared.persistentContainer.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // 设置变更跟踪
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
    }
    
    /// 合并离线更改
    @MainActor
    func mergeOfflineChanges() async throws {
        logger.info("开始合并离线更改")
        
        let context = CoreDataStack.shared.newBackgroundContext()
        
        try await context.perform {
            // 获取离线更改
            let changes = try self.fetchOfflineChanges(in: context)
            
            self.logger.info("找到 \(changes.count) 个离线更改")
            
            // 处理离线更改
            for change in changes {
                try self.processChange(change, in: context)
            }
            
            try context.save()
            
            // 清理历史记录
            try self.cleanupHistory(in: context)
        }
        
        logger.info("离线更改合并完成")
    }
    
    @MainActor
    private func cleanupHistory(in context: NSManagedObjectContext) throws {
        logger.debug("清理历史记录")
        
        // 清理历史记录
        let persistentStoreCoordinator = CoreDataStack.shared.persistentContainer.persistentStoreCoordinator
        guard let _ = persistentStoreCoordinator.persistentStores.first else {
            return
        }
        
        // 更多清理代码
    }
    
    private func fetchOfflineChanges(in context: NSManagedObjectContext) throws -> [NSManagedObject] {
        // 获取离线期间的更改
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "OfflineChange")
        return try context.fetch(fetchRequest)
    }
} 