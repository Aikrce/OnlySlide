@preconcurrency import CoreData
@preconcurrency import Foundation
@preconcurrency import Combine
@preconcurrency import os
@preconcurrency import os.log

// 使用标准的 CoreDataModule 模块
@preconcurrency import CoreDataModule

// MARK: - Migration Configuration

/// 迁移配置结构体
public struct MigrationOptions: Sendable, Equatable {
    /// 是否创建备份
    public let shouldCreateBackup: Bool
    
    /// 是否在失败时从备份恢复
    public let shouldRestoreFromBackupOnFailure: Bool
    
    /// 是否删除旧备份
    public let shouldRemoveOldBackups: Bool
    
    /// 要保留的最大备份数量
    public let maxBackupsToKeep: Int
    
    /// 迁移模式
    public let mode: EMigrationMode
    
    /// 初始化迁移配置
    public init(
        shouldCreateBackup: Bool = true,
        shouldRestoreFromBackupOnFailure: Bool = true,
        shouldRemoveOldBackups: Bool = true,
        maxBackupsToKeep: Int = 5,
        mode: EMigrationMode = .automatic
    ) {
        self.shouldCreateBackup = shouldCreateBackup
        self.shouldRestoreFromBackupOnFailure = shouldRestoreFromBackupOnFailure
        self.shouldRemoveOldBackups = shouldRemoveOldBackups
        self.maxBackupsToKeep = maxBackupsToKeep
        self.mode = mode
    }
    
    /// 默认配置
    public static let `default` = MigrationOptions()
}

/// 迁移模式
public enum EMigrationMode: Sendable, Equatable {
    /// 自动迁移（推断映射模型）
    case automatic
    
    /// 使用自定义映射模型
    case customMapping
    
    /// 逐步迁移（一次只迁移一个版本）
    case stepByStep
    
    /// 使用轻量级迁移，由 Core Data 自动处理
    case lightweight
}

// MARK: - Migration Protocols

/// 迁移规划器协议
public protocol MigrationPlannerProtocol: Sendable {
    /// 检查是否需要迁移
    func requiresMigration(at storeURL: URL) async throws -> Bool
    
    /// 创建迁移计划
    func createMigrationPlan(for storeURL: URL, options: ExecutorMigrationOptions) async throws -> MigrationPlan
}

/// 迁移执行器协议
public protocol MigrationExecutorProtocol: Sendable {
    /// 执行迁移计划
    func executePlan(_ plan: MigrationPlan, options: ExecutorMigrationOptions, progressHandler: @escaping @Sendable (Float) -> Void) async throws
}

/// 备份管理器协议
public protocol BackupManagerProtocol: Sendable {
    /// 创建备份
    func createBackup(for storeURL: URL, options: ExecutorMigrationOptions) async throws -> ManagerBackupResult
    
    /// 从最新备份恢复
    func restoreFromLatestBackup(to storeURL: URL) async throws -> RestoreResult
    
    /// 清理旧备份
    func cleanupOldBackups(for storeURL: URL, keeping: Int) async throws
}

/// 进度报告协议
@MainActor
public protocol EMProgressReporterProtocol: AnyObject, Sendable {
    var state: EnhancedMigrationState { get async }
    var progress: MigrationProgress? { get async }
    
    func reset() async
    func reportPreparationStarted() async
    func reportBackupStarted() async
    func reportMigrationStarted() async
    func updateProgress(_ progress: Float) async
    func reportMigrationCompleted(result: EnhancedMigrationResult) async
    func reportMigrationFailed(error: Error) async
    func reportRestorationStarted() async
    func reportRestorationCompleted(success: Bool) async
}

// MARK: - Enhanced Migration Manager

/// 优化的 Core Data 迁移管理器
@MainActor
public struct EnhancedMigrationManager: Sendable {
    // MARK: - Dependencies
    
    private let planner: MigrationPlannerProtocol
    private let executor: MigrationExecutorProtocol
    private let backupManager: BackupManagerProtocol
    private let progressReporter: EMProgressReporterProtocol
    
    // MARK: - Publishers
    
    private let stateSubject = CurrentValueSubject<EnhancedMigrationState, Never>(.idle)
    private let progressSubject = CurrentValueSubject<MigrationProgress?, Never>(nil)
    
    /// 当前状态发布者
    public var statePublisher: AnyPublisher<EnhancedMigrationState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    /// 当前进度发布者
    public var progressPublisher: AnyPublisher<MigrationProgress?, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    /// 初始化迁移管理器
    /// - Parameters:
    ///   - planner: 迁移规划器
    ///   - executor: 迁移执行器
    ///   - backupManager: 备份管理器
    ///   - progressReporter: 进度报告器
    public init(
        planner: MigrationPlannerProtocol,
        executor: MigrationExecutorProtocol,
        backupManager: BackupManagerProtocol,
        progressReporter: EMProgressReporterProtocol
    ) {
        self.planner = planner
        self.executor = executor
        self.backupManager = backupManager
        self.progressReporter = progressReporter
        
        // 开始监听进度报告器状态变更
        Task { [progressReporter] in
            while true {
                // 更新状态和进度
                await MainActor.run {
                    let state = await progressReporter.state
                    let progress = await progressReporter.progress
                    stateSubject.send(state)
                    progressSubject.send(progress)
                }
                
                // 防止过于频繁的更新
                try? await Task.sleep(nanoseconds: 100_000_000) // 100毫秒
            }
        }
    }
    
    // MARK: - Factory Method
    
    /// 创建使用默认依赖的迁移管理器
    /// - Returns: 配置好的迁移管理器
    @MainActor
    public static func createDefault() -> EnhancedMigrationManager {
        // 使用现有的实现作为默认值
        let planner = DefaultMigrationPlanner()
        let executor = DefaultMigrationExecutor()
        let backupManager = DefaultBackupManager()
        let progressReporter = MigrationProgressReporter()
        
        return EnhancedMigrationManager(
            planner: planner,
            executor: executor,
            backupManager: backupManager,
            progressReporter: progressReporter as EMProgressReporterProtocol
        )
    }
    
    // MARK: - Migration Methods
    
    /// 检查是否需要迁移
    /// - Parameter storeURL: 存储文件URL
    /// - Returns: 是否需要迁移
    public func needsMigration(at storeURL: URL) async throws -> Bool {
        return try await planner.requiresMigration(at: storeURL)
    }
    
    /// 迁移持久化存储
    /// - Parameters:
    ///   - storeURL: 存储URL
    ///   - options: 迁移选项
    /// - Returns: 迁移结果
    public func migrate(
        storeAt storeURL: URL,
        options: MigrationOptions = .default
    ) async throws -> EnhancedMigrationResult {
        // 重置之前的状态
        await progressReporter.reset()
        
        // 检查是否需要迁移
        let needsMigration = try await planner.requiresMigration(at: storeURL)
        if !needsMigration {
            return .success(entitiesMigrated: 0)
        }
        
        // 开始准备迁移
        await progressReporter.reportPreparationStarted()
        
        // 创建迁移计划
        let executorOptions = ExecutorMigrationOptions(
            shouldCreateBackup: options.shouldCreateBackup,
            shouldRestoreFromBackupOnFailure: options.shouldRestoreFromBackupOnFailure,
            shouldRemoveOldBackups: options.shouldRemoveOldBackups,
            maxBackupsToKeep: options.maxBackupsToKeep,
            mode: convertMigrationMode(options.mode)
        )
        
        let plan = try await planner.createMigrationPlan(for: storeURL, options: executorOptions)
        
        // 如果需要，创建备份
        var backupResult: ManagerBackupResult?
        if options.shouldCreateBackup {
            await progressReporter.reportBackupStarted()
            backupResult = try await backupManager.createBackup(for: storeURL, options: executorOptions)
        }
        
        // 开始迁移
        await progressReporter.reportMigrationStarted()
        
        do {
            // 执行迁移计划
            try await executor.executePlan(plan, options: executorOptions) { progress in
                // 确保在MainActor上运行
                Task { @MainActor in
                    await self.progressReporter.updateProgress(progress)
                }
            }
            
            // 清理旧备份
            if options.shouldRemoveOldBackups {
                try await backupManager.cleanupOldBackups(for: storeURL, keeping: options.maxBackupsToKeep)
            }
            
            // 报告迁移完成
            let migratedEntities = plan.steps.count
            let result = EnhancedMigrationResult.success(entitiesMigrated: migratedEntities)
            await progressReporter.reportMigrationCompleted(result: result)
            return result
            
        } catch {
            // 发生错误，进行错误恢复
            await progressReporter.reportMigrationFailed(error: error)
            
            // 如果配置了恢复备份，则尝试恢复
            if options.shouldRestoreFromBackupOnFailure {
                await progressReporter.reportRestorationStarted()
                
                do {
                    let restorationResult = try await backupManager.restoreFromLatestBackup(to: storeURL)
                
                    // 根据恢复结果更新状态
                    switch restorationResult {
                    case .success:
                        await progressReporter.reportRestorationCompleted(success: true)
                        return .cancelled
                    case .failure:
                        await progressReporter.reportRestorationCompleted(success: false)
                    }
                } catch {
                    await progressReporter.reportRestorationCompleted(success: false)
                }
            }
            
            // 返回错误结果
            return .failure(error)
        }
    }
    
    /// 获取当前状态
    /// - Returns: 迁移状态
    public func getCurrentState() async -> EnhancedMigrationState {
        return await progressReporter.state
    }
    
    /// 获取当前迁移进度
    /// - Returns: 迁移进度信息
    public func getCurrentProgress() async -> MigrationProgress? {
        return await progressReporter.progress
    }
    
    /// 重置迁移管理器状态
    public func reset() async {
        await progressReporter.reset()
    }
    
    // MARK: - Private Methods
    
    /// 将自定义迁移模式转换为执行器使用的迁移模式
    private func convertMigrationMode(_ mode: EMigrationMode) -> MigrationMode {
        switch mode {
        case .automatic:
            return .automatic
        case .customMapping:
            return .customMapping
        case .stepByStep:
            return .stepByStep
        case .lightweight:
            return .lightweight
        }
    }
}

// MARK: - Default Implementations (Adapters)

/// 默认迁移规划器
fileprivate struct DefaultMigrationPlanner: MigrationPlannerProtocol {
    func requiresMigration(at storeURL: URL) async throws -> Bool {
        // 使用现有的迁移规划器实现
        let existingPlanner = await MigrationPlanner()
        return try await existingPlanner.requiresMigration(at: storeURL)
    }
    
    func createMigrationPlan(for storeURL: URL, options: ExecutorMigrationOptions) async throws -> MigrationPlan {
        // 使用现有的迁移规划器实现
        let existingPlanner = await MigrationPlanner()
        return try await existingPlanner.createMigrationPlan(for: storeURL, options: options)
    }
}

/// 默认迁移执行器
fileprivate struct DefaultMigrationExecutor: MigrationExecutorProtocol {
    func executePlan(_ plan: MigrationPlan, options: ExecutorMigrationOptions, progressHandler: @escaping @Sendable (Float) -> Void) async throws {
        // 使用现有的迁移执行器实现
        let existingExecutor = await MigrationExecutor()
        try await existingExecutor.executePlan(plan, options: options, progressHandler: progressHandler)
    }
}

/// 使用公共DefaultBackupManager类，不再使用私有实现

/// 迁移管理器适配器，提供与原始API兼容的接口
@MainActor
public struct MigrationManagerAdapter: Sendable {
    /// 共享实例
    public static let shared = MigrationManagerAdapter()
    
    /// 内部使用的增强迁移管理器
    private let enhancedManager: EnhancedMigrationManager
    
    /// 初始化适配器
    /// - Parameter manager: 增强迁移管理器
    public init(manager: EnhancedMigrationManager = EnhancedMigrationManager.createDefault()) {
        self.enhancedManager = manager
    }
    
    /// 获取管理器
    /// - Returns: 增强迁移管理器
    public func manager() -> EnhancedMigrationManager {
        return enhancedManager
    }
    
    /// 兼容方法：检查并在需要时迁移存储
    public func compatibleCheckAndMigrateStoreIfNeeded(at storeURL: URL) async throws -> Bool {
        let needsMigration = try await enhancedManager.needsMigration(at: storeURL)
        
        if needsMigration {
            let result = try await enhancedManager.migrate(storeAt: storeURL)
            return result.isSuccess
        }
        
        return true
    }
    
    /// 兼容方法：执行迁移
    public func compatiblePerformMigration(at storeURL: URL) async throws -> Bool {
        let result = try await enhancedManager.migrate(storeAt: storeURL)
        return result.isSuccess
    }
    
    /// 获取迁移状态
    public var migrationState: EnhancedMigrationState {
        var currentState: EnhancedMigrationState = .idle
        
        // 为了避免引用类型依赖，使用一次性订阅
        let cancellable = enhancedManager.statePublisher
            .receive(on: RunLoop.main)
            .sink { state in
                currentState = state
            }
        
        defer { cancellable.cancel() }
        
        // 返回状态
        return currentState
    }
}

/// 全局访问函数
@MainActor
public func getMigrationManager() -> EnhancedMigrationManager {
    return MigrationManagerAdapter.shared.manager()
}

// MARK: - Result Extension

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
} 