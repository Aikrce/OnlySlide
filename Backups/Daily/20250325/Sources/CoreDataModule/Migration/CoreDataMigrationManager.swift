@preconcurrency import CoreData
import Foundation

/// 迁移配置
public struct MigrationConfiguration: Sendable {
    /// 是否创建备份
    public let shouldCreateBackup: Bool
    
    /// 是否在失败时从备份恢复
    public let shouldRestoreFromBackupOnFailure: Bool
    
    /// 是否删除旧备份
    public let shouldRemoveOldBackups: Bool
    
    /// 要保留的最大备份数量
    public let maxBackupsToKeep: Int
    
    /// 初始化迁移配置
    /// - Parameters:
    ///   - shouldCreateBackup: 是否创建备份
    ///   - shouldRestoreFromBackupOnFailure: 是否在失败时从备份恢复
    ///   - shouldRemoveOldBackups: 是否删除旧备份
    ///   - maxBackupsToKeep: 要保留的最大备份数量
    public init(
        shouldCreateBackup: Bool,
        shouldRestoreFromBackupOnFailure: Bool,
        shouldRemoveOldBackups: Bool,
        maxBackupsToKeep: Int
    ) {
        self.shouldCreateBackup = shouldCreateBackup
        self.shouldRestoreFromBackupOnFailure = shouldRestoreFromBackupOnFailure
        self.shouldRemoveOldBackups = shouldRemoveOldBackups
        self.maxBackupsToKeep = maxBackupsToKeep
    }
    
    /// 默认配置
    @MainActor public static let `default` = MigrationConfiguration(
        shouldCreateBackup: true,
        shouldRestoreFromBackupOnFailure: true,
        shouldRemoveOldBackups: true,
        maxBackupsToKeep: 5
    )
}

/// Core Data 迁移管理器
/// 负责协调整个迁移过程
@MainActor public final class CoreDataMigrationManager: @unchecked Sendable, ObservableObject {
    // MARK: - Properties
    
    /// 共享实例
    public static let shared = CoreDataMigrationManager()
    
    /// 当前状态
    @Published public private(set) var state: MigrationState = .notStarted
    
    /// 进度报告器
    private let progressReporter: MigrationProgressReporter
    
    /// 备份管理器
    private let backupManager: BackupManager
    
    /// 迁移计划器
    private let planner: MigrationPlanner
    
    /// 迁移执行器
    private let executor: MigrationExecutor
    
    // MARK: - Initialization
    
    /// 初始化迁移管理器
    /// - Parameters:
    ///   - progressReporter: 进度报告器
    ///   - backupManager: 备份管理器
    ///   - planner: 迁移计划器
    ///   - executor: 迁移执行器
    public init(
        progressReporter: MigrationProgressReporter = MigrationProgressReporter(),
        backupManager: BackupManager = BackupManager(),
        planner: MigrationPlanner = MigrationPlanner(),
        executor: MigrationExecutor = MigrationExecutor()
    ) {
        self.progressReporter = progressReporter
        self.backupManager = backupManager
        self.planner = planner
        self.executor = executor
    }
    
    // MARK: - Public Methods
    
    /// 检查并迁移存储
    /// - Parameter storeURL: 存储 URL
    /// - Returns: 是否成功迁移（如果返回 false，则说明不需要迁移）
    public func checkAndMigrateStoreIfNeeded(at storeURL: URL) async throws -> Bool {
        // 检查是否需要迁移
        guard try await planner.requiresMigration(at: storeURL) else {
            progressReporter.reportMigrationCompleted(result: .notNeeded)
            return false
        }
        
        // 如果需要迁移，执行迁移
        try await performMigration(at: storeURL)
        return true
    }
    
    /// 执行迁移
    /// - Parameter storeURL: 存储 URL
    /// - Returns: 是否成功迁移
    public func performMigration(at storeURL: URL) async throws {
        // 重置状态
        progressReporter.reset()
        
        // 报告准备开始
        progressReporter.reportPreparationStarted()
        
        do {
            // 创建迁移计划
            let plan = try await planner.createMigrationPlan(for: storeURL)
            
            // 如果没有迁移步骤，说明不需要迁移
            if plan.steps.isEmpty {
                progressReporter.reportMigrationCompleted(result: .notNeeded)
                return
            }
            
            // 创建备份
            progressReporter.reportBackupStarted()
            let backupResult = try await backupManager.createBackup(for: storeURL)
            
            if case .failure(let error) = backupResult {
                progressReporter.reportMigrationFailed(error: error)
                throw error
            }
            
            // 报告迁移开始
            progressReporter.reportMigrationStarted()
            
            // 执行迁移计划
            try await executor.executePlan(plan) { progress in
                // 更新进度
                self.progressReporter.updateProgress(progress)
            }
            
            // 报告迁移完成
            progressReporter.reportMigrationCompleted(result: .success)
        } catch {
            // 如果发生错误，尝试从备份恢复
            if let migrationError = error as? MigrationError {
                progressReporter.reportMigrationFailed(error: migrationError)
                
                // 报告恢复开始
                progressReporter.reportRestorationStarted()
                
                // 尝试从最新备份恢复
                let restoreResult = try await backupManager.restoreFromLatestBackup(to: storeURL)
                
                if case .failure(let restoreError) = restoreResult {
                    print("恢复备份失败: \(restoreError.localizedDescription)")
                }
            } else {
                progressReporter.reportMigrationFailed(error: error)
            }
            
            throw error
        }
    }
    
    /// 获取当前进度
    /// - Returns: 进度信息
    public func getCurrentProgress() -> MigrationProgress? {
        return progressReporter.progress
    }
    
    /// 获取当前状态
    /// - Returns: 迁移状态
    public func getCurrentState() -> MigrationState {
        return progressReporter.state
    }
    
    /// 重置状态
    public func reset() {
        progressReporter.reset()
    }
} 