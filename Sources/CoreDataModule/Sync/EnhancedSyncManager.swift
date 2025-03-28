import Foundation
import CoreData
@preconcurrency import Combine
import os

// MARK: - 同步管理器类
/// CoreData 同步管理器类
public actor EnhancedSyncManager: Sendable {
    // MARK: - 属性
    
    /// 是否正在同步
    private var isSyncing = false
    
    /// 最后同步日期
    private var lastSyncDate: Date?
    
    /// 当前同步状态
    private var state: SyncState = .idle
    
    /// 状态发布者 - 需要特殊处理，因为发布者需要从非actor上下文访问
    private let stateSubject = CurrentValueSubject<SyncState, Never>(.idle)
    
    /// 上下文
    private let context: NSManagedObjectContext
    
    /// 同步服务
    private let syncService: SyncServiceProtocol
    
    /// 进度报告器
    private let progressReporter: SyncProgressReporterProtocol
    
    // MARK: - 初始化
    
    /// 初始化同步管理器
    /// - Parameters:
    ///   - context: 托管对象上下文
    ///   - syncService: 同步服务
    public init(
        context: NSManagedObjectContext,
        syncService: SyncServiceProtocol
    ) {
        self.context = context
        self.syncService = syncService
        
        // 创建一个临时变量，避免self在初始化过程中产生循环引用
        let reporter = DefaultSyncProgressReporter { [weak self] state in
            guard let self = self else { return }
            // 使用Task捕获self并调用actor方法
            Task { await self.updateState(state) }
        }
        self.progressReporter = reporter
    }
    
    // MARK: - 状态管理
    
    /// 更新同步状态
    /// - Parameter newState: 新状态
    private func updateState(_ newState: SyncState) {
        state = newState
        
        // 由于stateSubject需要在非actor上下文中访问，使用Task隔离到主线程
        Task { @MainActor in
            self.stateSubject.send(newState)
        }
        
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
    
    // MARK: - 发布者
    
    /// 获取状态发布者 - 使用nonisolated让它可以从非actor上下文访问
    /// - Returns: 状态发布者
    nonisolated public func statePublisher() -> AnyPublisher<SyncState, Never> {
        return stateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 同步操作
    
    /// 执行同步操作
    /// - Parameters:
    ///   - options: 同步选项
    /// - Returns: 操作是否成功
    public func sync(with options: SyncOptions = .default) async throws -> Bool {
        // 确保不会重复同步
        guard !isSyncing else {
            return false
        }
        
        // 报告准备状态
        progressReporter.reportPreparing()
        
        do {
            // 从存储中读取当前数据
            let localData = try await readLocalData()
            
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
            progressReporter.reportCompleted()
            
            return true
        } catch {
            // 报告失败
            progressReporter.reportFailed(error: error)
            
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
        progressReporter.reportSyncing()
        
        // 从服务器获取数据
        progressReporter.reportDownloading(progress: 0.3)
        let remoteData = try await syncService.fetchDataFromServer()
        progressReporter.reportDownloading(progress: 0.5)
        
        // 解决冲突
        progressReporter.reportSyncing()
        let mergedData = try await syncService.resolveConflicts(
            local: localData,
            remote: remoteData,
            strategy: options.autoMergeStrategy
        )
        
        // 检查数据是否有变化
        guard hasChanges(newData: mergedData, comparedTo: localData) else {
            // 没有变化，直接返回
            return
        }
        
        // 上传合并数据
        progressReporter.reportUploading(progress: 0.7)
        _ = try await syncService.uploadDataToServer(mergedData)
        progressReporter.reportUploading(progress: 0.9)
        
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
        // 报告同步状态
        progressReporter.reportSyncing()
        
        // 上传数据
        progressReporter.reportUploading(progress: 0.5)
        _ = try await syncService.uploadDataToServer(localData)
        progressReporter.reportUploading(progress: 1.0)
    }
    
    /// 执行下载同步
    /// - Parameters:
    ///   - options: 同步选项
    private func executeDownloadSync(options: SyncOptions) async throws {
        // 报告同步状态
        progressReporter.reportSyncing()
        
        // 从服务器获取数据
        progressReporter.reportDownloading(progress: 0.3)
        let remoteData = try await syncService.fetchDataFromServer()
        progressReporter.reportDownloading(progress: 0.7)
        
        // 更新本地存储
        try await updateLocalData(with: remoteData)
        progressReporter.reportDownloading(progress: 1.0)
    }
    
    /// 尝试回滚
    private func attemptRollback() async {
        // 实际项目中实现回滚逻辑
    }
    
    // MARK: - 数据操作
    
    /// 读取本地数据
    /// - Returns: 本地数据
    private func readLocalData() async throws -> SyncData {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // 模拟从CoreData读取数据
                    // 在实际项目中，这里会有可能抛出错误的代码
                    // 例如查询CoreData或解析数据
                    
                    let result = SyncData(timestamp: Date(), data: "local data")
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 更新本地数据
    /// - Parameter data: 要写入的数据
    private func updateLocalData(with data: SyncData) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // 模拟写入CoreData
                    // 在实际项目中，这里应该执行实际的CoreData更新操作
                    
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 检查数据是否有变化
    /// - Parameters:
    ///   - newData: 新数据
    ///   - oldData: 旧数据
    /// - Returns: 是否有变化
    private func hasChanges(newData: SyncData, comparedTo oldData: SyncData) -> Bool {
        return newData != oldData
    }
    
    // MARK: - 公共访问方法
    
    /// 获取当前同步状态
    /// - Returns: 当前状态
    public func currentState() -> SyncState {
        return state
    }
    
    /// 获取最后同步时间
    /// - Returns: 最后同步时间
    public func lastSync() -> Date? {
        return lastSyncDate
    }
    
    /// 检查是否正在同步
    /// - Returns: 是否正在同步
    public func isCurrentlySyncing() -> Bool {
        return isSyncing
    }
    
    /// 取消同步
    public func cancelSync() {
        guard isSyncing else {
            return
        }
        
        updateState(SyncState.idle)
    }
    
    /// 清理资源
    public func cleanupResources() {
        clearCache()
    }
}

// MARK: - 默认同步进度报告器
/// 默认同步进度报告器实现
public class DefaultSyncProgressReporter: SyncProgressReporterProtocol {
    private let stateHandler: (SyncState) -> Void
    
    public init(stateHandler: @escaping (SyncState) -> Void) {
        self.stateHandler = stateHandler
    }
    
    public func reportPreparing() {
        stateHandler(SyncState.preparing)
    }
    
    public func reportSyncing() {
        stateHandler(SyncState.syncing)
    }
    
    public func reportUploading(progress: Double) {
        stateHandler(SyncState.uploading(progress: progress))
    }
    
    public func reportDownloading(progress: Double) {
        stateHandler(SyncState.downloading(progress: progress))
    }
    
    public func reportCompleted() {
        stateHandler(SyncState.completed)
    }
    
    public func reportFailed(error: Error) {
        stateHandler(SyncState.failed(error))
    }
}

// MARK: - 同步管理器适配器

/// 同步管理器适配器
@MainActor
public final class SyncManagerAdapter: @unchecked Sendable {
    /// 共享实例
    public static let shared = SyncManagerAdapter()
    
    /// 同步管理器
    public let syncManager: EnhancedSyncManager
    
    /// 初始化适配器
    private init() {
        // 在实际项目中，应该从依赖注入容器获取 NSManagedObjectContext
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        self.syncManager = EnhancedSyncManager.createDefault(with: context)
    }
}

/// 全局访问函数
@MainActor
public func getSyncManager() -> EnhancedSyncManager {
    return SyncManagerAdapter.shared.syncManager
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
    public static func createDefault(with context: NSManagedObjectContext) -> EnhancedSyncManager {
        // 在实际项目中，可以从依赖注入容器中解析这些依赖
        let syncService = DefaultSyncService()
        return EnhancedSyncManager(context: context, syncService: syncService)
    }
}

// MARK: - 性能优化扩展

extension EnhancedSyncManager {
    /// 对同步操作进行性能优化
    private func optimizeContextForSync(_ context: NSManagedObjectContext) {
        // 优化上下文配置以提高性能
        context.stalenessInterval = 0 // 避免缓存陈旧对象
        context.shouldDeleteInaccessibleFaults = true // 释放不可访问的错误对象
        context.retainsRegisteredObjects = false // 不保留已注册对象
        
        // 设置批处理获取
        context.persistentStoreCoordinator?.setMetadata(
            ["NSBatchInsertRequest": true],
            for: context.persistentStoreCoordinator?.persistentStores.first ?? NSPersistentStore()
        )
    }
    
    /// 使用分页批处理处理大量数据
    private func processBatchedData<T>(
        fetchRequest: NSFetchRequest<T>,
        batchSize: Int = 100,
        handler: @escaping ([T]) throws -> Void
    ) async throws where T: NSFetchRequestResult {
        // 保存原始的fetch limit和offset
        let originalFetchLimit = fetchRequest.fetchLimit
        let originalFetchOffset = fetchRequest.fetchOffset
        
        // 设置批处理大小
        fetchRequest.fetchBatchSize = batchSize
        
        var currentBatch = 0
        var moreDataToProcess = true
        
        while moreDataToProcess && !Task.isCancelled {
            // 设置当前批次范围
            fetchRequest.fetchOffset = originalFetchOffset + (currentBatch * batchSize)
            fetchRequest.fetchLimit = batchSize
            
            // 执行获取
            let results = try await withCheckedThrowingContinuation { continuation in
                context.perform {
                    do {
                        let batchResults = try self.context.fetch(fetchRequest)
                        continuation.resume(returning: batchResults)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // 如果没有更多结果，跳出循环
            if results.isEmpty {
                break
            }
            
            // 处理当前批次
            try handler(results)
            
            // 判断是否还有更多数据
            moreDataToProcess = results.count == batchSize
            
            // 移到下一批次
            currentBatch += 1
            
            // 在批次间添加短暂暂停
            if moreDataToProcess {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50毫秒
            }
        }
        
        // 恢复原始设置
        fetchRequest.fetchLimit = originalFetchLimit
        fetchRequest.fetchOffset = originalFetchOffset
    }
    
    /// 缓存改进：使用NSCache进行临时对象缓存
    private lazy var objectCache: NSCache<NSString, AnyObject> = {
        let cache = NSCache<NSString, AnyObject>()
        cache.name = "com.onlyslide.enhancedsyncmanager.cache"
        cache.countLimit = 1000  // 最多缓存1000个对象
        cache.totalCostLimit = 10 * 1024 * 1024  // 最大10MB
        return cache
    }()
    
    /// 从缓存中获取对象
    private func cachedObject<T: AnyObject>(forKey key: String) -> T? {
        return objectCache.object(forKey: key as NSString) as? T
    }
    
    /// 将对象放入缓存
    private func cacheObject(_ object: AnyObject, forKey key: String, cost: Int = 1) {
        objectCache.setObject(object, forKey: key as NSString, cost: cost)
    }
    
    /// 清除缓存
    private func clearCache() {
        objectCache.removeAllObjects()
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
        
        // 执行批量更新
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let result = try self.context.execute(batchUpdateRequest) as! NSBatchUpdateResult
                    
                    // 合并变更到上下文
                    if let objectIDs = result.result as? [NSManagedObjectID], !objectIDs.isEmpty {
                        let changes = [NSUpdatedObjectsKey: objectIDs]
                        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.context])
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
} 