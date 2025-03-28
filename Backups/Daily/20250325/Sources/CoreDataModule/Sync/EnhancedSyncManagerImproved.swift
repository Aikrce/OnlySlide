import Foundation
import CoreData
import Combine
import os

// MARK: - 同步选项
/// 同步选项
public struct SyncOptions: Sendable {
    /// 同步方向
    public enum Direction: Sendable {
        /// 上传
        case upload
        /// 下载
        case download
        /// 双向
        case bidirectional
    }
    
    /// 同步方向
    public let direction: Direction
    
    /// 自动冲突解决策略
    public let autoMergeStrategy: AutoMergeStrategy
    
    /// 是否在失败时回滚
    public let rollbackOnFailure: Bool
    
    /// 创建同步选项
    public init(
        direction: Direction = .bidirectional,
        autoMergeStrategy: AutoMergeStrategy = .serverWins,
        rollbackOnFailure: Bool = true
    ) {
        self.direction = direction
        self.autoMergeStrategy = autoMergeStrategy
        self.rollbackOnFailure = rollbackOnFailure
    }
    
    /// 默认选项
    public static let `default` = SyncOptions()
}

// MARK: - 自动合并策略
/// 自动合并冲突解决策略
public enum AutoMergeStrategy: Sendable {
    /// 服务器数据优先
    case serverWins
    /// 本地数据优先
    case localWins
    /// 按最近修改时间
    case mostRecent
    /// 合并冲突字段
    case mergeFields
    /// 手动解决
    case manual
}

// MARK: - 增强同步管理器
/// 并发安全的增强型 Core Data 同步管理器
public actor EnhancedSyncManagerImproved {
    // MARK: - 属性
    
    /// 当前同步状态
    private var state: SyncState = .idle
    
    /// 当前同步进度
    private var progress: Double = 0.0
    
    /// 最后同步日期
    private var lastSyncDate: Date?
    
    /// 同步服务
    private let syncService: SyncServiceProtocol
    
    /// 存储访问
    private let storeAccess: StoreAccessProtocol
    
    /// 状态发布者
    private let stateSubject = CurrentValueSubject<SyncState, Never>(.idle)
    
    /// 进度发布者
    private let progressSubject = CurrentValueSubject<Double, Never>(0.0)
    
    // MARK: - 初始化
    
    /// 初始化同步管理器
    public init(
        syncService: SyncServiceProtocol,
        storeAccess: StoreAccessProtocol
    ) {
        self.syncService = syncService
        self.storeAccess = storeAccess
    }
    
    // MARK: - 发布者访问

    /// 获取状态发布者
    public func statePublisher() -> AnyPublisher<SyncState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    /// 获取进度发布者
    public func progressPublisher() -> AnyPublisher<Double, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 状态访问
    
    /// 获取当前同步状态
    public func currentState() -> SyncState {
        return state
    }
    
    /// 获取当前同步进度
    public func currentProgress() -> Double {
        return progress
    }
    
    /// 获取最后同步日期
    public func getLastSyncDate() -> Date? {
        return lastSyncDate
    }
    
    /// 检查是否正在同步
    public func isCurrentlySyncing() -> Bool {
        return state.isActive
    }
    
    // MARK: - 同步操作
    
    /// 执行同步操作
    public func sync(with options: SyncOptions = .default) async throws -> Bool {
        // 确保不会重复同步
        if state.isActive {
            return false
        }
        
        // 更新状态
        updateState(.preparing)
        updateProgress(0.1)
        
        do {
            // 根据同步方向执行不同操作
            switch options.direction {
            case .bidirectional:
                try await executeBidirectionalSync(options: options)
            case .upload:
                try await executeUploadSync(options: options)
            case .download:
                try await executeDownloadSync(options: options)
            }
            
            // 更新状态
            updateState(.completed)
            updateProgress(1.0)
            
            // 更新最后同步日期
            lastSyncDate = Date()
            
            return true
        } catch {
            // 更新状态
            updateState(.failed(error))
            
            // 如果配置了回滚，执行回滚
            if options.rollbackOnFailure {
                await attemptRollback()
            }
            
            // 重新抛出错误
            throw error
        }
    }
    
    /// 取消同步
    public func cancelSync() {
        // 只有在同步中才可以取消
        guard state.isActive else {
            return
        }
        
        // 更新状态
        updateState(.idle)
        updateProgress(0.0)
    }
    
    // MARK: - 私有方法
    
    /// 执行双向同步
    private func executeBidirectionalSync(options: SyncOptions) async throws {
        // 从存储读取本地数据
        let localData = try await storeAccess.readDataFromStore()
        updateProgress(0.3)
        
        // 从服务器获取数据
        let remoteData = try await syncService.fetchDataFromServer()
        updateProgress(0.5)
        
        // 解决冲突
        let mergedData = try await syncService.resolveConflicts(
            local: localData,
            remote: remoteData,
            strategy: options.autoMergeStrategy
        )
        updateProgress(0.7)
        
        // 如果有变化，写入存储
        if storeAccess.hasChanges(mergedData, comparedTo: localData) {
            _ = try await storeAccess.writeDataToStore(mergedData)
        }
        
        // 上传合并后的数据
        updateState(.syncing)
        updateProgress(0.8)
        _ = try await syncService.uploadDataToServer(mergedData)
        updateProgress(0.9)
    }
    
    /// 执行上传同步
    private func executeUploadSync(options: SyncOptions) async throws {
        // 从存储读取本地数据
        let localData = try await storeAccess.readDataFromStore()
        updateProgress(0.4)
        
        // 上传数据
        updateState(.syncing)
        updateProgress(0.6)
        _ = try await syncService.uploadDataToServer(localData)
        updateProgress(0.9)
    }
    
    /// 执行下载同步
    private func executeDownloadSync(options: SyncOptions) async throws {
        // 从服务器获取数据
        let remoteData = try await syncService.fetchDataFromServer()
        updateProgress(0.5)
        
        // 写入存储
        updateState(.syncing)
        updateProgress(0.8)
        _ = try await storeAccess.writeDataToStore(remoteData)
        updateProgress(0.9)
    }
    
    /// 尝试回滚操作
    private func attemptRollback() async {
        // 简单的回滚实现，实际项目中可能需要更复杂的逻辑
        // 这里只是示例
    }
    
    /// 更新同步状态
    private func updateState(_ newState: SyncState) {
        state = newState
        stateSubject.send(newState)
    }
    
    /// 更新同步进度
    private func updateProgress(_ newProgress: Double) {
        progress = newProgress
        progressSubject.send(newProgress)
    }
    
    /// 使用默认依赖创建同步管理器
    public static func createDefault() -> EnhancedSyncManagerImproved {
        // 在实际项目中，应该从 DependencyRegistry 解析这些依赖
        let syncService = DefaultSyncService()
        let storeAccess = DefaultStoreAccess()
        
        return EnhancedSyncManagerImproved(
            syncService: syncService,
            storeAccess: storeAccess
        )
    }
}

// MARK: - 默认实现

/// 默认同步服务实现
class DefaultSyncService: SyncServiceProtocol {
    /// 从服务器获取数据
    func fetchDataFromServer() async throws -> [String: Any] {
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return ["timestamp": Date(), "data": "示例数据"]
    }
    
    /// 上传数据到服务器
    func uploadDataToServer(_ data: [String: Any]) async throws -> Bool {
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return true
    }
    
    /// 解决冲突
    func resolveConflicts(
        local: [String: Any],
        remote: [String: Any],
        strategy: AutoMergeStrategy
    ) async throws -> [String: Any] {
        // 根据策略解决冲突
        switch strategy {
        case .serverWins:
            return remote
        case .localWins:
            return local
        case .mostRecent:
            // 简单实现，实际项目中可能需要更复杂的逻辑
            let localDate = local["timestamp"] as? Date ?? Date.distantPast
            let remoteDate = remote["timestamp"] as? Date ?? Date.distantPast
            return localDate > remoteDate ? local : remote
        case .mergeFields:
            // 简单实现，实际项目中可能需要更复杂的逻辑
            var merged = local
            for (key, value) in remote {
                merged[key] = value
            }
            return merged
        case .manual:
            // 简单实现，实际项目中可能需要用户交互
            throw NSError(domain: "com.onlyslide.sync", code: 100, userInfo: [
                NSLocalizedDescriptionKey: "需要手动解决冲突"
            ])
        }
    }
}

/// 默认存储访问实现
class DefaultStoreAccess: StoreAccessProtocol {
    /// 从存储中读取数据
    func readDataFromStore() async throws -> [String: Any] {
        // 模拟读取延迟
        try await Task.sleep(nanoseconds: 500_000_000)
        return ["timestamp": Date(), "data": "本地数据"]
    }
    
    /// 将数据写入存储
    func writeDataToStore(_ data: [String: Any]) async throws -> Bool {
        // 模拟写入延迟
        try await Task.sleep(nanoseconds: 500_000_000)
        return true
    }
    
    /// 检查数据是否变化
    func hasChanges(_ newData: [String: Any], comparedTo oldData: [String: Any]) -> Bool {
        // 简单实现，实际项目中可能需要更复杂的逻辑
        return newData != oldData
    }
}

// MARK: - 同步管理器适配器

/// 同步管理器适配器，提供与原始API兼容的接口
@MainActor
public struct SyncManagerAdapterImproved: Sendable {
    /// 共享实例
    public static let shared = SyncManagerAdapterImproved()
    
    /// 增强同步管理器
    private let enhancedManager: EnhancedSyncManagerImproved
    
    /// 初始化适配器
    public init(manager: EnhancedSyncManagerImproved = EnhancedSyncManagerImproved.createDefault()) {
        self.enhancedManager = manager
    }
    
    /// 获取管理器
    public func manager() -> EnhancedSyncManagerImproved {
        return enhancedManager
    }
    
    /// 兼容方法：执行同步
    public func compatibleSync() async throws -> Bool {
        return try await enhancedManager.sync()
    }
    
    /// 兼容方法：获取同步状态
    public func compatibleSyncState() -> String {
        let state = Task {
            await enhancedManager.currentState()
        }.result.value ?? .idle
        
        switch state {
        case .idle:
            return "idle"
        case .preparing:
            return "preparing"
        case .syncing:
            return "syncing"
        case .completed:
            return "completed"
        case .failed:
            return "failed"
        }
    }
    
    /// 兼容方法：检查是否正在同步
    public func compatibleIsSyncing() -> Bool {
        return Task {
            await enhancedManager.isCurrentlySyncing()
        }.result.value ?? false
    }
}

/// 全局访问函数
@MainActor
public func getImprovedSyncManager() -> EnhancedSyncManagerImproved {
    return SyncManagerAdapterImproved.shared.manager()
} 