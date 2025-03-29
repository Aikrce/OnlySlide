import Foundation
import Combine

// MARK: - Migration Phase Enum

/// 迁移阶段
public enum MigrationPhase: String, Sendable {
    /// 准备中
    case preparing
    
    /// 备份中
    case backingUp
    
    /// 迁移中
    case migrating
    
    /// 恢复中
    case recovering
    
    /// 完成
    case completed
    
    /// 失败
    case failed
}

// MARK: - Enhanced Migration State Enum

/// 增强型迁移状态
public enum EnhancedMigrationState: Sendable, Equatable {
    /// 空闲
    case idle
    
    /// 正在准备
    case preparing
    
    /// 正在备份
    case backingUp
    
    /// 正在迁移
    case inProgress
    
    /// 正在完成
    case finishing
    
    /// 完成
    case completed
    
    /// 失败
    case failed(Error)
    
    /// 恢复中
    case recovering
    
    public static func == (lhs: EnhancedMigrationState, rhs: EnhancedMigrationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.preparing, .preparing),
             (.backingUp, .backingUp),
             (.inProgress, .inProgress),
             (.finishing, .finishing),
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

// MARK: - Migration Progress Struct

/// 迁移进度
public struct MigrationProgress: Sendable, Equatable {
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

/// 迁移进度报告器协议
@MainActor
public protocol MigrationProgressReporterProtocol: Sendable {
    /// 当前状态
    var state: EnhancedMigrationState { get async }
    
    /// 当前进度
    var progress: MigrationProgress { get async }
    
    /// 当前错误
    var error: Error? { get async }
    
    /// 重置报告器
    func reset() async
    
    /// 报告迁移准备开始
    func reportPreparing() async
    
    /// 报告备份开始
    func reportBackingUp() async
    
    /// 报告迁移开始
    func reportMigrating(steps: Int) async
    
    /// 报告迁移步骤进度
    func reportMigrationStepProgress(step: Int, of totalSteps: Int, progress: Double) async
    
    /// 报告恢复开始
    func reportRecovering() async
    
    /// 报告迁移完成
    func reportCompleted(entities: Int) async
    
    /// 报告迁移失败
    func reportFailed(error: Error) async
}

/// 迁移进度报告器协议（特定于CoreDataMigrationManager使用）
@MainActor
public protocol CDMigrationProgressReporterProtocol: Sendable {
    /// 当前状态
    var state: EnhancedMigrationState { get async }
    
    /// 当前进度
    var progress: CDMigrationProgress { get async }
    
    /// 当前错误
    var error: Error? { get async }
    
    /// CD特定的进度对象
    var cdProgress: CDMigrationProgress { get async }
    
    /// 重置报告器
    func reset() async
    
    /// 报告迁移准备开始
    func reportPreparing() async
    
    /// 报告备份开始
    func reportBackingUp() async
    
    /// 报告迁移开始
    func reportMigrating(steps: Int) async
    
    /// 报告迁移步骤进度
    func reportMigrationStepProgress(step: Int, of totalSteps: Int, progress: Double) async
    
    /// 报告恢复开始
    func reportRecovering() async
    
    /// 报告迁移完成
    func reportCompleted(entities: Int) async
    
    /// 报告迁移失败
    func reportFailed(error: Error) async
}

/// 迁移进度报告器
@MainActor
public final class MigrationProgressReporter: MigrationProgressReporterProtocol, CDMigrationProgressReporterProtocol, EMProgressReporterProtocol {
    /// 状态管理Actor
    private actor StateActor {
        var stateValue = EnhancedMigrationState.idle
        var progressValue = MigrationProgress(phase: .preparing, value: 0)
        var errorValue: Error? = nil
        
        func setState(_ state: EnhancedMigrationState) {
            stateValue = state
        }
        
        func setProgress(_ progress: MigrationProgress) {
            progressValue = progress
        }
        
        func setError(_ error: Error?) {
            errorValue = error
        }
        
        func getState() -> EnhancedMigrationState {
            return stateValue
        }
        
        func getProgress() -> MigrationProgress {
            return progressValue
        }
        
        func getError() -> Error? {
            return errorValue
        }
        
        func reset() {
            stateValue = .idle
            progressValue = MigrationProgress(phase: .preparing, value: 0)
            errorValue = nil
        }
    }
    
    /// 状态Actor实例
    private let stateActor = StateActor()
    
    /// 初始化迁移进度报告器
    public init() {}
    
    /// 当前状态
    nonisolated public var state: EnhancedMigrationState {
        get {
            Task {
                return await stateActor.getState()
            }.value
        }
    }
    
    /// 当前进度
    nonisolated public var progress: MigrationProgress {
        get {
            Task {
                return await stateActor.getProgress()
            }.value
        }
    }
    
    /// 获取CD特定的进度
    public var cdProgress: CDMigrationProgress {
        get {
            Task {
                let p = await stateActor.getProgress()
                return CDMigrationProgress(phase: p.phase, value: p.value)
            }.value
        }
    }
    
    /// 当前错误
    nonisolated public var error: Error? {
        get {
            Task {
                return await stateActor.getError()
            }.value
        }
    }
    
    /// 重置报告器
    public func reset() {
        Task { 
            await stateActor.reset() 
        }
    }
    
    /// 更新状态
    private func updateState(_ state: EnhancedMigrationState) async {
        await stateActor.setState(state)
    }
    
    /// 更新进度
    private func updateProgress(_ progress: MigrationProgress) async {
        await stateActor.setProgress(progress)
    }
    
    /// 报告迁移准备开始
    public func reportPreparing() async {
        await updateState(.preparing)
        await updateProgress(MigrationProgress(phase: .preparing, value: 0))
    }
    
    /// 报告备份开始
    public func reportBackingUp() async {
        await updateState(.backingUp)
        await updateProgress(MigrationProgress(phase: .backingUp, value: 0))
    }
    
    /// 报告迁移开始
    public func reportMigrating(steps: Int) async {
        await updateState(.inProgress)
        await updateProgress(MigrationProgress(phase: .migrating, value: 0))
    }
    
    /// 报告迁移步骤进度
    public func reportMigrationStepProgress(step: Int, of totalSteps: Int, progress: Double) async {
        let overallProgress = (Double(step - 1) + progress) / Double(totalSteps)
        await updateProgress(MigrationProgress(phase: .migrating, value: overallProgress))
    }
    
    /// 报告恢复开始
    public func reportRecovering() async {
        await updateState(.recovering)
        await updateProgress(MigrationProgress(phase: .recovering, value: 0))
    }
    
    /// 报告迁移完成
    public func reportCompleted(entities: Int) async {
        await updateState(.completed)
        await updateProgress(MigrationProgress(phase: .completed, value: 1.0))
    }
    
    /// 报告迁移失败
    public func reportFailed(error: Error) async {
        await updateState(.failed(error))
        await updateProgress(MigrationProgress(phase: .failed, value: 0))
        await stateActor.setError(error)
    }
    
    // MARK: - EMProgressReporterProtocol
    
    /// 报告准备开始
    public func reportPreparationStarted() async {
        await updateState(.preparing)
        await updateProgress(MigrationProgress(phase: .preparing, value: 0))
    }
    
    /// 报告备份开始
    public func reportBackupStarted() async {
        await updateState(.backingUp)
        await updateProgress(MigrationProgress(phase: .backingUp, value: 0))
    }
    
    /// 报告迁移开始
    public func reportMigrationStarted() async {
        await updateState(.inProgress)
        await updateProgress(MigrationProgress(phase: .migrating, value: 0))
    }
    
    /// 更新进度
    public func updateProgress(_ progress: Float) async {
        await reportMigrationStepProgress(step: 1, of: 1, progress: Double(progress))
    }
    
    /// 报告迁移完成
    public func reportMigrationCompleted(result: EnhancedMigrationResult) async {
        await updateState(.completed)
        await updateProgress(MigrationProgress(phase: .completed, value: 1.0))
    }
    
    /// 报告迁移失败
    public func reportMigrationFailed(error: Error) async {
        await updateState(.failed(error))
        await updateProgress(MigrationProgress(phase: .failed, value: 0))
        await stateActor.setError(error)
    }
    
    /// 报告恢复开始
    public func reportRestorationStarted() async {
        await updateState(.recovering)
        await updateProgress(MigrationProgress(phase: .recovering, value: 0))
    }
    
    /// 报告恢复完成
    public func reportRestorationCompleted(success: Bool) async {
        // 根据恢复结果设置状态
        if success {
            await updateState(.completed)
            await updateProgress(MigrationProgress(phase: .completed, value: 1.0))
        } else {
            // 恢复失败，保持失败状态
        }
    }
} 