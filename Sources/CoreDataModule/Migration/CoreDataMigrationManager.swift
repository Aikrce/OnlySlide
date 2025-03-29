@preconcurrency import CoreData
import Foundation
import Combine

/// 迁移状态
public enum CDMigrationState: Equatable {
    /// 未开始
    case notStarted
    
    /// 准备中
    case preparing
    
    /// 备份中
    case backingUp
    
    /// 迁移中
    case migrating
    
    /// 完成
    case completed
    
    /// 失败
    case failed(Error)
    
    /// 恢复中
    case recovering
    
    /// 实现 Equatable 协议
    public static func == (lhs: CDMigrationState, rhs: CDMigrationState) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted),
             (.preparing, .preparing),
             (.backingUp, .backingUp),
             (.migrating, .migrating),
             (.completed, .completed),
             (.recovering, .recovering):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// 迁移结果
public enum CDMigrationResult: Equatable {
    /// 成功迁移
    case success
    
    /// 不需要迁移
    case notNeeded
    
    /// 迁移失败
    case failure(Error)
    
    /// 实现 Equatable 协议
    public static func == (lhs: CDMigrationResult, rhs: CDMigrationResult) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success), (.notNeeded, .notNeeded):
            return true
        case (.failure(let lhsError), .failure(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

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

/// 用于CoreDataMigrationManager的特化MigrationProgress结构体
public struct CDMigrationProgress: Sendable, Equatable {
    /// 迁移阶段
    public let phase: MigrationPhase
    
    /// 进度值（0.0-1.0）
    public let value: Double
    
    /// 进度百分比
    public var percentage: Double {
        return value * 100.0
    }
    
    /// 进度分数
    public var fraction: Double {
        return value
    }
    
    /// 当前步骤
    public var currentStep: Int {
        return Int(value * 100)
    }
    
    /// 总步骤数
    public var totalSteps: Int {
        return 100
    }
    
    /// 描述信息
    public var description: String {
        switch phase {
        case .preparing:
            return "准备迁移..."
        case .backingUp:
            return "创建备份..."
        case .migrating:
            return "正在迁移数据模型..."
        case .recovering:
            return "恢复备份..."
        case .completed:
            return "迁移已完成"
        case .failed:
            return "迁移失败"
        }
    }
    
    /// 初始化进度
    public init(phase: MigrationPhase, value: Double) {
        self.phase = phase
        self.value = max(0, min(1, value)) // 确保在0-1范围内
    }
}

/// Core Data 迁移管理器
/// 负责协调整个迁移过程
@MainActor public final class CoreDataMigrationManager: @unchecked Sendable, ObservableObject {
    // MARK: - Properties
    
    /// 共享实例
    public static let shared = CoreDataMigrationManager()
    
    /// 当前状态
    @Published public private(set) var state: CDMigrationState = .notStarted
    
    /// 进度报告器
    private let progressReporter: CDMigrationProgressReporterProtocol
    
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
        progressReporter: CDMigrationProgressReporterProtocol = MigrationProgressReporter() as CDMigrationProgressReporterProtocol,
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
            await Task { 
                progressReporter.reportCompleted(entities: 0) 
            }.value
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
        await Task { 
            progressReporter.reset() 
        }.value
        
        // 报告准备开始
        await Task { 
            progressReporter.reportPreparing() 
        }.value
        
        do {
            // 创建迁移计划
            let plan = try await planner.createMigrationPlan(for: storeURL)
            
            // 如果没有迁移步骤，说明不需要迁移
            if plan.steps.isEmpty {
                await Task { 
                    progressReporter.reportCompleted(entities: 0) 
                }.value
                return
            }
            
            // 创建备份
            await Task { 
                progressReporter.reportBackingUp() 
            }.value
            let backupResult = try await backupManager.createBackup(for: storeURL)
            
            if case .failure(let error) = backupResult {
                await Task { 
                    progressReporter.reportFailed(error: error) 
                }.value
                throw error
            }
            
            // 报告迁移开始
            await Task { 
                progressReporter.reportMigrating(steps: plan.steps.count) 
            }.value
            
            // 执行迁移计划
            try await executor.executePlan(plan) { progress in
                // 更新每个步骤进度
                Task { 
                    self.progressReporter.reportMigrationStepProgress(
                        step: 1, 
                        of: plan.steps.count, 
                        progress: Double(progress)
                    ) 
                }
            }
            
            // 报告迁移完成
            await Task { 
                progressReporter.reportCompleted(entities: 100) // 假定迁移了100个实体
            }.value
        } catch {
            // 如果发生错误，尝试从备份恢复
            if let migrationError = error as? MigrationError {
                await Task { 
                    progressReporter.reportFailed(error: migrationError) 
                }.value
                
                // 报告恢复开始
                await Task { 
                    progressReporter.reportRecovering() 
                }.value
                
                // 尝试从最新备份恢复
                let restoreResult = try await backupManager.restoreFromLatestBackup(to: storeURL)
                
                if case .failure(let restoreError) = restoreResult {
                    print("恢复备份失败: \(restoreError.localizedDescription)")
                }
            } else {
                await Task { 
                    progressReporter.reportFailed(error: error) 
                }.value
            }
            
            throw error
        }
    }
    
    /// 获取当前进度
    /// - Returns: 进度信息
    public func getCurrentProgress() -> CDMigrationProgress {
        // 使用同步方式获取cdProgress，该属性已在MigrationProgressReporter中实现为同步方法
        return progressReporter.cdProgress
    }
    
    /// 获取当前状态
    /// - Returns: 迁移状态
    public func getCurrentState() -> EnhancedMigrationState {
        // 使用同步方式获取状态，state属性已在MigrationProgressReporter中实现为同步方法
        return progressReporter.state
    }
    
    /// 重置状态
    public func reset() {
        // 使用同步方式重置状态，reset方法已在MigrationProgressReporter中实现为同步方法
        progressReporter.reset()
    }
} 