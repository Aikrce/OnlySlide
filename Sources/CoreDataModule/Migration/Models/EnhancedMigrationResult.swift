import Foundation

/// 增强型迁移结果
public enum EnhancedMigrationResult: Equatable, Sendable {
    /// 迁移成功
    case success(entitiesMigrated: Int)
    
    /// 迁移失败
    case failure(Error)
    
    /// 迁移取消
    case cancelled
    
    /// 是否成功
    public var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure, .cancelled:
            return false
        }
    }
    
    /// 实现Equatable协议
    public static func == (lhs: EnhancedMigrationResult, rhs: EnhancedMigrationResult) -> Bool {
        switch (lhs, rhs) {
        case let (.success(lhsCount), .success(rhsCount)):
            return lhsCount == rhsCount
        case (.cancelled, .cancelled):
            return true
        case let (.failure(lhsError), .failure(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// 扩展Error以支持Equatable
extension Error {
    var errorDescription: String {
        return localizedDescription
    }
} 