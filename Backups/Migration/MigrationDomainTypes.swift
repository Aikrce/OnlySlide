@preconcurrency import CoreData
import Foundation

/// 迁移进度
public struct MigrationProgress: Equatable, Sendable {
    /// 当前步骤
    public let currentStep: Int
    /// 总步骤数
    public let totalSteps: Int
    /// 描述信息
    public let description: String
    /// 源版本
    public let sourceVersion: ModelVersion
    /// 目标版本
    public let destinationVersion: ModelVersion
    
    /// 进度百分比（0-100）
    public var percentage: Double {
        return Double(currentStep) / Double(totalSteps) * 100
    }
    
    /// 进度比例（0-1）
    public var fraction: Double {
        return Double(currentStep) / Double(totalSteps)
    }
    
    /// 创建迁移进度
    /// - Parameters:
    ///   - currentStep: 当前步骤
    ///   - totalSteps: 总步骤数
    ///   - description: 描述信息
    ///   - sourceVersion: 源版本
    ///   - destinationVersion: 目标版本
    public init(
        currentStep: Int,
        totalSteps: Int,
        description: String,
        sourceVersion: ModelVersion,
        destinationVersion: ModelVersion
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.description = description
        self.sourceVersion = sourceVersion
        self.destinationVersion = destinationVersion
    }
}

/// 迁移结果
public enum MigrationResult: Equatable, Sendable {
    /// 成功完成迁移
    case success
    /// 不需要迁移
    case notNeeded
    /// 迁移失败
    case failure(Error)
    
    /// 简短描述
    public var description: String {
        switch self {
        case .success:
            return "迁移成功完成"
        case .notNeeded:
            return "无需迁移"
        case .failure(let error):
            return "迁移失败：\(error.localizedDescription)"
        }
    }
    
    public static func == (lhs: MigrationResult, rhs: MigrationResult) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success),
             (.notNeeded, .notNeeded):
            return true
        case (.failure(let lhsError), .failure(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// 迁移步骤
public struct MigrationStep: Equatable, Sendable {
    /// 步骤索引
    public let index: Int
    /// 源版本
    public let sourceVersion: ModelVersion
    /// 目标版本
    public let destinationVersion: ModelVersion
    
    /// 创建迁移步骤
    /// - Parameters:
    ///   - index: 步骤索引
    ///   - sourceVersion: 源版本
    ///   - destinationVersion: 目标版本
    public init(index: Int, sourceVersion: ModelVersion, destinationVersion: ModelVersion) {
        self.index = index
        self.sourceVersion = sourceVersion
        self.destinationVersion = destinationVersion
    }
} 