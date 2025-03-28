import Foundation
@preconcurrency import CoreDataModule

/// 迁移状态
public enum MigrationState: Equatable, Sendable {
    /// 未开始
    case notStarted
    /// 准备中
    case preparing
    /// 进行中
    case inProgress(progress: MigrationProgress)
    /// 备份中
    case backingUp
    /// 恢复中
    case restoring
    /// 已完成
    case completed(result: MigrationResult)
    /// 失败
    case failed(error: MigrationError)
    
    /// 是否已完成（无论成功或失败）
    public var isFinished: Bool {
        switch self {
        case .completed, .failed:
            return true
        default:
            return false
        }
    }
    
    /// 是否成功完成
    public var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
    
    /// 是否失败
    public var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
    
    /// 是否正在进行中
    public var isInProgress: Bool {
        switch self {
        case .preparing, .inProgress, .backingUp, .restoring:
            return true
        default:
            return false
        }
    }
    
    /// 获取当前进度（如果有）
    public var progress: MigrationProgress? {
        if case .inProgress(let progress) = self {
            return progress
        }
        return nil
    }
    
    /// 获取错误（如果有）
    public var error: MigrationError? {
        if case .failed(let error) = self {
            return error
        }
        return nil
    }
    
    /// 获取结果（如果有）
    public var result: MigrationResult? {
        if case .completed(let result) = self {
            return result
        }
        return nil
    }
}

/// 迁移计划
public struct MigrationPlan: Equatable, Sendable {
    /// 源版本
    public let sourceVersion: ModelVersion
    /// 目标版本
    public let destinationVersion: ModelVersion
    /// 迁移步骤
    public let steps: [MigrationStep]
    /// 存储 URL
    public let storeURL: URL
    
    /// 创建迁移计划
    /// - Parameters:
    ///   - sourceVersion: 源版本
    ///   - destinationVersion: 目标版本
    ///   - steps: 迁移步骤
    ///   - storeURL: 存储 URL
    public init(sourceVersion: ModelVersion, destinationVersion: ModelVersion, steps: [MigrationStep], storeURL: URL) {
        self.sourceVersion = sourceVersion
        self.destinationVersion = destinationVersion
        self.steps = steps
        self.storeURL = storeURL
    }
    
    /// 计划是否为空
    public var isEmpty: Bool {
        return steps.isEmpty
    }
    
    /// 步骤数量
    public var stepCount: Int {
        return steps.count
    }
    
    /// 是否为单步迁移
    public var isSingleStep: Bool {
        return steps.count == 1
    }
}

/// 迁移步骤

/// 迁移进度
