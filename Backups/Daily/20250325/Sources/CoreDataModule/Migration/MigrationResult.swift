import Foundation

/// 统一的迁移结果枚举，表示迁移操作的各种可能结果
/// 此版本是原有多个定义的统一版本，提供完整的功能集
public enum MigrationResult: Equatable, Sendable {
    /// 迁移成功，可选包含迁移的对象计数
    case success(entitiesMigrated: Int = 0)
    
    /// 迁移失败，包含错误信息
    case failure(Error)
    
    /// 迁移需要用户确认
    case requiresConfirmation(MigrationType)
    
    /// 迁移被用户取消
    case cancelled
    
    /// 迁移不需要（已经是最新版本）
    case notNeeded
    
    // MARK: - 辅助属性
    
    /// 是否为成功状态
    public var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    /// 是否为失败状态
    public var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }
    
    /// 是否需要用户确认
    public var requiresUserConfirmation: Bool {
        if case .requiresConfirmation = self {
            return true
        }
        return false
    }
    
    /// 获取迁移类型（如果适用）
    public var migrationType: MigrationType? {
        if case .requiresConfirmation(let type) = self {
            return type
        }
        return nil
    }
    
    /// 获取错误（如果适用）
    public var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
    
    /// 获取迁移的实体数量（如果适用）
    public var entitiesCount: Int? {
        if case .success(let count) = self {
            return count
        }
        return nil
    }
    
    // MARK: - 静态工厂方法
    
    /// 创建成功结果
    public static func createSuccess(entitiesMigrated: Int = 0) -> MigrationResult {
        return .success(entitiesMigrated: entitiesMigrated)
    }
    
    /// 创建失败结果
    public static func createFailure(_ error: Error) -> MigrationResult {
        return .failure(error)
    }
    
    // MARK: - Equatable 实现
    
    public static func == (lhs: MigrationResult, rhs: MigrationResult) -> Bool {
        switch (lhs, rhs) {
        case (.success(let lhsCount), .success(let rhsCount)):
            return lhsCount == rhsCount
        case (.notNeeded, .notNeeded), (.cancelled, .cancelled):
            return true
        case (.requiresConfirmation(let lhsType), .requiresConfirmation(let rhsType)):
            return lhsType == rhsType
        case (.failure(let lhsError), .failure(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - CustomStringConvertible 实现

extension MigrationResult: CustomStringConvertible {
    /// 获取描述
    public var description: String {
        switch self {
        case .success(let count):
            return "迁移成功完成 (已迁移\(count)个实体)"
        case .notNeeded:
            return "无需迁移 (已是最新版本)"
        case .failure(let error):
            return "迁移失败：\(error.localizedDescription)"
        case .requiresConfirmation(let type):
            return "需要用户确认 (\(type.description))"
        case .cancelled:
            return "迁移已取消"
        }
    }
}

/// 迁移类型枚举
public enum MigrationType: String, Equatable, Sendable {
    /// 轻量级迁移
    case lightweight = "lightweight"
    
    /// 标准迁移
    case standard = "standard"
    
    /// 重型迁移
    case heavyweight = "heavyweight"
    
    /// 是否为轻量级迁移
    public var isLightweight: Bool {
        return self == .lightweight
    }
    
    /// 是否为标准迁移
    public var isStandard: Bool {
        return self == .standard
    }
    
    /// 是否为重型迁移
    public var isHeavyweight: Bool {
        return self == .heavyweight
    }
    
    /// 获取友好描述
    public var description: String {
        switch self {
        case .lightweight:
            return "轻量级迁移"
        case .standard:
            return "标准迁移"
        case .heavyweight:
            return "重型迁移"
        }
    }
} 