import Foundation
import CoreData

/// 迁移相关错误
public enum MigrationError: Error, Equatable {
    /// 模型未找到
    case modelNotFound(description: String)
    
    /// 映射模型未找到
    case mappingModelNotFound(description: String)
    
    /// 未支持的迁移路径
    case unsupportedMigrationPath(description: String)
    
    /// 步骤执行失败
    case stepExecutionFailed(step: MigrationStep, description: String)
    
    /// 迁移计划创建失败
    case planCreationFailed(description: String)
    
    /// 未知错误
    case unknown(description: String)
    
    /// 错误描述
    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let description):
            return "模型未找到: \(description)"
        case .mappingModelNotFound(let description):
            return "映射模型未找到: \(description)"
        case .unsupportedMigrationPath(let description):
            return "未支持的迁移路径: \(description)"
        case .stepExecutionFailed(let step, let description):
            let stepString = "[\(step.index): \(step.sourceVersion) -> \(step.destinationVersion)]"
            return "步骤执行失败: \(stepString), \(description)"
        case .planCreationFailed(let description):
            return "迁移计划创建失败: \(description)"
        case .unknown(let description):
            return "未知错误: \(description)"
        }
    }
    
    /// 判断两个错误是否相等
    public static func == (lhs: MigrationError, rhs: MigrationError) -> Bool {
        switch (lhs, rhs) {
        case (.modelNotFound(let lhsDesc), .modelNotFound(let rhsDesc)):
            return lhsDesc == rhsDesc
        case (.mappingModelNotFound(let lhsDesc), .mappingModelNotFound(let rhsDesc)):
            return lhsDesc == rhsDesc
        case (.unsupportedMigrationPath(let lhsDesc), .unsupportedMigrationPath(let rhsDesc)):
            return lhsDesc == rhsDesc
        case (.stepExecutionFailed(let lhsStep, let lhsDesc), .stepExecutionFailed(let rhsStep, let rhsDesc)):
            return lhsStep == rhsStep && lhsDesc == rhsDesc
        case (.planCreationFailed(let lhsDesc), .planCreationFailed(let rhsDesc)):
            return lhsDesc == rhsDesc
        case (.unknown(let lhsDesc), .unknown(let rhsDesc)):
            return lhsDesc == rhsDesc
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
    
    /// 初始化迁移步骤
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