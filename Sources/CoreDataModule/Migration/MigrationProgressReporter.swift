import Foundation
import Combine

/// 负责报告迁移进度
@MainActor public final class MigrationProgressReporter: MigrationProgressReporterProtocol, ObservableObject {
    // MARK: - Properties
    
    /// 当前状态
    @Published public private(set) var state: EnhancedMigrationState = .idle
    
    /// 当前进度
    @Published public private(set) var progress: MigrationProgress?
    
    /// 当前错误
    @Published public private(set) var error: MigrationError?
    
    /// 是否正在迁移
    public var isInProgress: Bool {
        switch state {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }
    
    /// 是否已完成
    public var isCompleted: Bool {
        if case .completed = state {
            return true
        }
        return false
    }
    
    /// 是否失败
    public var isFailed: Bool {
        if case .failed = state {
            return true
        }
        return false
    }
    
    /// 进度百分比
    public var progressPercentage: Double {
        return progress?.percentage ?? 0
    }
    
    /// 进度分数
    public var progressFraction: Double {
        return progress?.fraction ?? 0
    }
    
    /// 当前步骤描述
    public var stepDescription: String {
        return progress?.description ?? "准备迁移..."
    }
    
    // MARK: - Initialization
    
    /// 初始化进度报告器
    public init() {}
    
    // MARK: - Public Methods
    
    /// 更新状态
    /// - Parameter state: 新状态
    public func updateState(_ state: EnhancedMigrationState) {
        self.state = state
    }
    
    /// 更新进度
    /// - Parameter progress: 新进度值 (0.0 - 1.0)
    public func updateProgress(_ progress: Float) {
        let newProgress = MigrationProgress(fraction: Double(progress), description: "正在迁移...")
        self.progress = newProgress
        
        // 如果不是在迁移状态，则更新状态
        if case .inProgress = self.state {} else {
            self.state = .inProgress
        }
    }
    
    /// 更新进度
    /// - Parameter progress: 新进度对象
    public func updateProgress(_ progress: MigrationProgress) {
        self.progress = progress
        
        // 如果不是在迁移状态，则更新状态
        if case .inProgress = self.state {} else {
            self.state = .inProgress
        }
    }
    
    /// 报告备份开始
    public func reportBackupStarted() {
        self.state = .backingUp
    }
    
    /// 报告恢复开始
    public func reportRestorationStarted() {
        self.state = .recovering
    }
    
    /// 报告准备开始
    public func reportPreparationStarted() {
        self.state = .preparing
    }
    
    /// 报告迁移开始
    public func reportMigrationStarted() {
        self.state = .inProgress
        updateProgress(0.0)
    }
    
    /// 报告迁移完成
    /// - Parameter result: 迁移结果
    public func reportMigrationCompleted(result: MigrationResult) {
        updateProgress(1.0)
        self.state = .completed
    }
    
    /// 报告迁移失败
    /// - Parameter error: 迁移错误
    public func reportMigrationFailed(error: MigrationError) {
        self.error = error
        self.state = .failed(error)
    }
    
    /// 报告迁移失败
    /// - Parameter error: 普通错误
    public func reportMigrationFailed(error: Error) {
        let migrationError = MigrationError.from(error)
        reportMigrationFailed(error: migrationError)
    }
    
    /// 报告恢复完成
    /// - Parameter success: 是否成功
    public func reportRestorationCompleted(success: Bool) {
        if success {
            self.state = .completed
        } else {
            // 如果恢复失败，保持失败状态
            if case .failed(let error) = self.state {
                // 已经在失败状态，无需更改
            } else {
                // 创建一个通用恢复失败错误
                let error = MigrationError.restorationFailed
                self.state = .failed(error)
            }
        }
    }
    
    /// 重置状态
    public func reset() {
        self.state = .idle
        self.progress = nil
        self.error = nil
    }
} 