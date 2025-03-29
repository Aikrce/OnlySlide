import Foundation
@preconcurrency import CoreData
@preconcurrency import Combine
import os

// MARK: - 同步管理器类
/// CoreData 同步管理器类
public actor EnhancedSyncManager: Sendable {
    // MARK: - 状态actor
    
    private actor StateActor {
        /// 当前同步状态
        var state: SyncState = .idle
        
        /// 最后同步日期
        var lastSyncDate: Date?
        
        /// 是否正在同步
        var isSyncing = false
        
        /// 更新状态
        func updateState(_ newState: SyncState) {
            state = newState
            
            // 更新同步标志
            if newState.isActive {
                isSyncing = true
            } else {
                isSyncing = false
            }
            
            // 如果完成，更新最后同步日期
            if case .completed = newState {
                lastSyncDate = Date()
            }
        }
        
        /// 获取当前状态
        func getCurrentState() -> SyncState {
            return state
        }
        
        /// 获取是否正在同步
        func isSyncingNow() -> Bool {
            return isSyncing
        }
        
        /// 获取最后同步日期
        func getLastSyncDate() -> Date? {
            return lastSyncDate
        }
    }
    
    // MARK: - 发布者Actor
    
    private actor SubjectActor {
        /// 状态发布者
        let stateSubject = PassthroughSubject<SyncState, Never>()
        
        /// 发送新状态
        func send(_ state: SyncState) {
            stateSubject.send(state)
        }
        
        /// 获取发布者
        func publisher() -> AnyPublisher<SyncState, Never> {
            return stateSubject.eraseToAnyPublisher()
        }
        
        /// 设置观察器
        func setupObserver() {
            Task { @MainActor in
                let publisher = self.stateSubject.receive(on: DispatchQueue.main)
                publisher.sink { state in
                    NotificationCenter.default.post(
                        name: Notification.Name("SyncProgressUpdate"),
                        object: nil,
                        userInfo: ["state": state]
                    )
                }
                .cancel() // 简化处理，实际中应该存储此订阅
            }
        }
    }
    
    // MARK: - 属性
    
    /// 状态管理器
    private let stateActor = StateActor()
    
    /// 发布者管理器
    private let subjectActor = SubjectActor()
    
    /// 上下文 - 声明为非隔离以允许在 MainActor 上下文中访问
    private nonisolated let context: NSManagedObjectContext
    
    /// 同步服务
    private let syncService: SyncServiceProtocol
    
    /// 进度报告器
    private let progressReporter: SyncProgressReporterProtocol
    
    /// 缓存对象
    private let objectCache: NSCache<NSString, AnyObject>
    
    /// Logger
    private let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "SyncManager")
    
    // MARK: - 初始化
    
    /// 初始化同步管理器
    /// - Parameters:
    ///   - context: 托管对象上下文
    ///   - syncService: 同步服务
    ///   - progressReporter: 进度报告器
    public init(
        context: NSManagedObjectContext,
        syncService: SyncServiceProtocol,
        progressReporter: SyncProgressReporterProtocol
    ) {
        self.context = context
        self.syncService = syncService
        self.progressReporter = progressReporter
        
        // 初始化缓存
        let cache = NSCache<NSString, AnyObject>()
        cache.name = "com.onlyslide.enhancedsyncmanager.cache"
        cache.countLimit = 1000  // 最多缓存1000个对象
        cache.totalCostLimit = 10 * 1024 * 1024  // 最大10MB
        self.objectCache = cache
        
        // 设置状态发布 - 延迟初始化，避免在初始化中使用异步调用
        Task {
            await setupStatePublishing()
        }
    }
    
    // MARK: - 状态发布
    
    /// 设置状态发布
    private func setupStatePublishing() async {
        // 设置状态变更的观察器
        await subjectActor.setupObserver()
    }
    
    // MARK: - 状态管理
    
    /// 更新同步状态
    /// - Parameter newState: 新状态
    private func updateState(_ newState: SyncState) async {
        // 更新内部actor的状态
        await stateActor.updateState(newState)
        
        // 发送状态变更通知
        await subjectActor.send(newState)
    }
    
    /// 获取当前状态
    public func getCurrentState() async -> SyncState {
        return await stateActor.getCurrentState()
    }
    
    /// 检查是否正在同步
    public func isSyncingNow() async -> Bool {
        return await stateActor.isSyncingNow()
    }
    
    /// 获取最后同步日期
    public func getLastSyncDate() async -> Date? {
        return await stateActor.getLastSyncDate()
    }
    
    // MARK: - 发布者
    
    /// 获取状态发布者
    public func statePublisher() async -> AnyPublisher<SyncState, Never> {
        return await subjectActor.publisher()
    }
    
    // MARK: - 同步操作
    
    /// 执行同步操作
    /// - Parameters:
    ///   - options: 同步选项
    /// - Returns: 操作是否成功
    public func sync(with options: SyncOptions = .default) async throws -> Bool {
        // 确保不会重复同步
        guard await !stateActor.isSyncingNow() else {
            return false
        }
        
        // 报告准备状态
        await progressReporter.reportPreparing()
        
        do {
            // 从存储中读取当前数据
            let localData = try await readLocalData()
            
            // 更新状态为正在同步
            await updateState(.syncing)
            
            // 根据同步方向执行不同操作
            switch options.direction {
            case .bidirectional:
                try await executeBidirectionalSync(localData: localData, options: options)
            case .upload:
                try await executeUploadSync(localData: localData, options: options)
            case .download:
                try await executeDownloadSync(options: options)
            }
            
            // 报告完成
            await progressReporter.reportCompleted()
            await updateState(.completed)
            
            return true
        } catch {
            // 报告失败
            await progressReporter.reportFailed(error: error)
            await updateState(.failed(error))
            
            // 如果配置了回滚，执行回滚
            if options.rollbackOnFailure {
                await attemptRollback()
            }
            
            // 重新抛出错误
            throw error
        }
    }
    
    /// 执行双向同步
    /// - Parameters:
    ///   - localData: 本地数据
    ///   - options: 同步选项
    private func executeBidirectionalSync(
        localData: SyncData,
        options: SyncOptions
    ) async throws {
        // 报告同步状态
        await progressReporter.reportSyncing()
        
        // 从服务器获取数据
        await progressReporter.reportDownloading(progress: 0.3)
        let remoteData = try await syncService.fetchDataFromServer()
        await progressReporter.reportDownloading(progress: 0.5)
        
        // 解决冲突
        await progressReporter.reportSyncing()
        let mergedData = try await syncService.resolveConflicts(
            local: localData,
            remote: remoteData,
            strategy: options.autoMergeStrategy
        )
        
        // 检查数据是否有变化
        guard hasChanges(newData: mergedData, comparedTo: localData) else {
            // 没有变化，直接返回
            await updateState(.completed)
            return
        }
        
        // 上传合并数据
        await progressReporter.reportUploading(progress: 0.7)
        _ = try await syncService.uploadDataToServer(mergedData)
        await progressReporter.reportUploading(progress: 0.9)
        
        // 更新本地存储
        try await updateLocalData(with: mergedData)
    }
    
    /// 执行上传同步
    /// - Parameters:
    ///   - localData: 本地数据
    ///   - options: 同步选项
    private func executeUploadSync(
        localData: SyncData,
        options: SyncOptions
    ) async throws {
        // 更新状态
        await updateState(.uploading(progress: 0.2))
        
        // 上传数据
        await progressReporter.reportUploading(progress: 0.5)
        _ = try await syncService.uploadDataToServer(localData)
        await progressReporter.reportUploading(progress: 1.0)
        
        // 更新状态
        await updateState(.uploading(progress: 1.0))
    }
    
    /// 执行下载同步
    /// - Parameters:
    ///   - options: 同步选项
    private func executeDownloadSync(options: SyncOptions) async throws {
        // 更新状态
        await updateState(.downloading(progress: 0.2))
        
        // 从服务器获取数据
        await progressReporter.reportDownloading(progress: 0.3)
        let remoteData = try await syncService.fetchDataFromServer()
        await progressReporter.reportDownloading(progress: 0.7)
        
        // 更新本地存储
        try await updateLocalData(with: remoteData)
        await progressReporter.reportDownloading(progress: 1.0)
        
        // 更新状态
        await updateState(.downloading(progress: 1.0))
    }
    
    /// 尝试回滚
    private func attemptRollback() async {
        logger.info("尝试执行同步回滚操作")
        // 实际项目中实现回滚逻辑
    }
    
    // MARK: - 数据操作
    
    /// 读取本地数据
    /// - Returns: 本地数据
    private func readLocalData() async throws -> SyncData {
        // 在主actor上执行Core Data操作，由于context是nonisolated的，这里安全
        return try await MainActor.run {
            // 创建请求
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SyncEntity")
            fetchRequest.fetchLimit = 1
            
            // 尝试执行查询
            let results = try self.context.fetch(fetchRequest)
            
            // 处理结果，在实际应用中，您会从结果中提取数据
            let timestamp = results.first?.value(forKey: "timestamp") as? Date ?? Date()
            let dataValue = results.first?.value(forKey: "data") as? String ?? "default data"
            
            // 构建并返回同步数据对象
            return SyncData(
                timestamp: timestamp,
                data: ["identifier": "local-data", "content": dataValue]
            )
        }
    }
    
    /// 更新本地数据
    /// - Parameter data: 同步数据
    private func updateLocalData(with data: SyncData) async throws {
        // 在主actor上执行Core Data操作
        try await MainActor.run {
            // 创建请求
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SyncEntity")
            fetchRequest.fetchLimit = 1
            
            // 尝试执行查询
            let results = try self.context.fetch(fetchRequest)
            
            let entity: NSManagedObject
            if let existingEntity = results.first {
                // 更新现有记录
                entity = existingEntity
            } else {
                // 创建新记录
                entity = NSEntityDescription.insertNewObject(
                    forEntityName: "SyncEntity",
                    into: self.context
                )
            }
            
            // 更新属性
            entity.setValue(data.timestamp, forKey: "timestamp")
            // 获取内容和标识符
            let contentData = data.get("data") as? [String: Any]
            entity.setValue(contentData?["content"], forKey: "data")
            entity.setValue(contentData?["identifier"], forKey: "identifier")
            
            // 保存上下文
            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }
    
    // MARK: - 辅助方法
    
    /// 检查数据是否有变化
    /// - Parameters:
    ///   - newData: 新数据
    ///   - oldData: 旧数据
    /// - Returns: 是否有变化
    private func hasChanges(newData: SyncData, comparedTo oldData: SyncData) -> Bool {
        // 获取数据内容
        let newContentData = newData.get("data") as? [String: Any]
        let oldContentData = oldData.get("data") as? [String: Any]
        
        // 检查内容是否有变化
        if let newContent = newContentData?["content"] as? String,
           let oldContent = oldContentData?["content"] as? String,
           newContent != oldContent {
            return true
        }
        
        // 检查时间戳是否更新
        if newData.timestamp > oldData.timestamp {
            return true
        }
        
        return false
    }
    
    // MARK: - 缓存操作
    
    /// 清理缓存
    public func clearCache() {
        objectCache.removeAllObjects()
    }
    
    /// 缓存对象
    /// - Parameters:
    ///   - object: 对象
    ///   - key: 键
    public func cacheObject(_ object: AnyObject, forKey key: String) {
        objectCache.setObject(object, forKey: key as NSString)
    }
    
    /// 获取缓存对象
    /// - Parameter key: 键
    /// - Returns: 缓存对象
    public func cachedObject(forKey key: String) -> AnyObject? {
        return objectCache.object(forKey: key as NSString)
    }
}

// MARK: - 默认创建方法
extension EnhancedSyncManager {
    /// 创建默认实例
    /// - Returns: 默认配置的同步管理器
    public static func createDefault() async -> EnhancedSyncManager {
        // 获取主上下文
        let context = await MainActor.run { CoreDataStack.shared.mainContext }
        
        // 创建同步服务和进度报告器
        let syncService = DefaultSyncService()
        let progressReporter = SyncProgressReporter()
        
        // 创建并返回同步管理器
        return EnhancedSyncManager(
            context: context,
            syncService: syncService,
            progressReporter: progressReporter
        )
    }
}

// MARK: - 同步管理器适配器

/// 同步管理器适配器
@MainActor
public final class SyncManagerAdapter: @unchecked Sendable {
    /// 共享实例
    public static let shared = SyncManagerAdapter()
    
    /// 同步管理器
    private var _syncManager: EnhancedSyncManager?
    
    /// 获取同步管理器，确保懒加载初始化
    public var syncManager: EnhancedSyncManager {
        get async {
            if let manager = _syncManager {
                return manager
            }
            
            // 创建同步管理器
            let manager = await EnhancedSyncManager.createDefault()
            _syncManager = manager
            return manager
        }
    }
    
    /// 初始化适配器
    private init() {
        // 延迟初始化，确保在MainActor上执行
    }
    
    /// 兼容方法：获取当前同步状态
    public func compatibleGetCurrentState() async -> SyncState {
        let manager = await syncManager
        return await manager.getCurrentState()
    }
    
    /// 兼容方法：检查是否正在同步
    public func compatibleIsSyncing() async -> Bool {
        let manager = await syncManager
        return await manager.isSyncingNow()
    }
    
    /// 兼容方法：执行同步
    public func compatibleSync(with options: SyncOptions = .default) async throws -> Bool {
        let manager = await syncManager
        return try await manager.sync(with: options)
    }
}

/// 全局访问函数
@MainActor
public func getSyncManager() async -> EnhancedSyncManager {
    return await SyncManagerAdapter.shared.syncManager
}

// MARK: - 线程安全扩展

extension DispatchQueue {
    func sync<T>(execute work: () -> T) -> T {
        return sync(flags: .barrier, execute: work)
    }
}

// MARK: - 便利初始化器扩展

extension EnhancedSyncManager {
    /// 使用默认参数创建同步管理器
    /// - Parameter context: 托管对象上下文
    /// - Returns: 同步管理器实例
    @MainActor
    public static func createDefault(with context: NSManagedObjectContext) async -> EnhancedSyncManager {
        // 在实际项目中，可以从依赖注入容器中解析这些依赖
        let syncService = DefaultSyncService()
        let progressReporter = SyncProgressReporter()
        // 使用MainActor隔离中创建管理器，确保context不会跨越隔离边界
        return EnhancedSyncManager(
            context: context, 
            syncService: syncService, 
            progressReporter: progressReporter
        )
    }
}

// MARK: - 性能优化扩展

extension EnhancedSyncManager {
    /// 对同步操作进行性能优化
    private func optimizeContextForSync(_ context: NSManagedObjectContext) async {
        // 确保在 MainActor 上运行
        await MainActor.run {
            // 优化上下文配置以提高性能
            context.stalenessInterval = 0 // 避免缓存陈旧对象
            context.shouldDeleteInaccessibleFaults = true // 释放不可访问的错误对象
            context.retainsRegisteredObjects = false // 不保留已注册对象
            
            // 设置批处理获取
            if let persistentStore = context.persistentStoreCoordinator?.persistentStores.first {
                context.persistentStoreCoordinator?.setMetadata(
                    ["NSBatchInsertRequest": true],
                    for: persistentStore
                )
            }
        }
    }
    
    /// 使用分页批处理处理大量数据
    private func processBatchedData<T: NSFetchRequestResult & Sendable>(
        fetchRequest: NSFetchRequest<T>,
        batchSize: Int = 100,
        handler: @escaping @Sendable ([T]) async throws -> Void
    ) async throws {
        // 保存原始的fetch limit和offset
        let originalFetchLimit = fetchRequest.fetchLimit
        let originalFetchOffset = fetchRequest.fetchOffset
        
        // 设置批处理大小
        let localBatchSize = batchSize
                
        var currentBatch = 0
        var moreDataToProcess = true
        
        while moreDataToProcess && !Task.isCancelled {
            // 设置当前批次范围
            let currentOffset = originalFetchOffset + (currentBatch * localBatchSize)
            
            // 创建完全独立的本地请求副本，避免捕获actor隔离的属性
            let localFetchRequest = NSFetchRequest<T>(entityName: fetchRequest.entityName ?? "")
            localFetchRequest.predicate = fetchRequest.predicate
            localFetchRequest.sortDescriptors = fetchRequest.sortDescriptors
            localFetchRequest.fetchLimit = localBatchSize
            localFetchRequest.fetchOffset = currentOffset
            localFetchRequest.fetchBatchSize = localBatchSize
            
            // 使用 MainActor.run 确保在正确的隔离环境中执行
            let results = try await MainActor.run {
                // context 是 nonisolated 的，所以这里可以安全访问
                try self.context.fetch(localFetchRequest)
            }
            
            // 如果没有更多结果，跳出循环
            if results.isEmpty {
                break
            }
            
            // 处理当前批次 - 使用异步处理器
            try await handler(results)
            
            // 判断是否还有更多数据
            moreDataToProcess = results.count == localBatchSize
            
            // 移到下一批次
            currentBatch += 1
            
            // 在批次间添加短暂暂停
            if moreDataToProcess {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
        
        // 恢复原始查询参数
        fetchRequest.fetchLimit = originalFetchLimit
        fetchRequest.fetchOffset = originalFetchOffset
    }
}

// MARK: - 批量保存操作

extension EnhancedSyncManager {
    /// 批量保存操作，优化性能
    private func batchSaveChanges<T: NSManagedObject>(
        entities: [T],
        propertiesToUpdate: [String]
    ) async throws {
        guard !entities.isEmpty else { return }
        
        // 获取实体名称
        let entityName = entities.first!.entity.name!
        
        // 构建批处理请求
        let batchUpdateRequest = NSBatchUpdateRequest(entityName: entityName)
        
        // 获取对象IDs
        let objectIDs = entities.map { $0.objectID }
        batchUpdateRequest.predicate = NSPredicate(format: "SELF IN %@", objectIDs)
        
        // 设置要更新的属性
        var propertyValues: [String: Any] = [:]
        
        for property in propertiesToUpdate {
            if let value = entities.first?.value(forKey: property) {
                propertyValues[property] = value
            }
        }
        
        batchUpdateRequest.propertiesToUpdate = propertyValues
        batchUpdateRequest.resultType = .updatedObjectIDsResultType
        
        // 使用 MainActor.run 确保在正确的隔离环境中执行
        try await MainActor.run {
            // context 是 nonisolated 的，可以安全访问
            let result = try self.context.execute(batchUpdateRequest) as! NSBatchUpdateResult
            
            // 合并变更到上下文
            if let objectIDs = result.result as? [NSManagedObjectID], !objectIDs.isEmpty {
                let changes = [NSUpdatedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.context])
            }
        }
    }
} 