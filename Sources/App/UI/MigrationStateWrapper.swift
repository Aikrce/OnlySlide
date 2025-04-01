import Foundation

/// 迁移状态包装器
/// 用于在UI层表示迁移的各种状态
/// 避免UI组件直接依赖CoreDataModule定义的状态
public enum MigrationStateWrapper: Equatable {
    /// 未开始迁移
    case notStarted
    /// 准备中
    case preparing
    /// 迁移中
    case migrating
    /// 迁移完成
    case completed
    /// 迁移失败
    case failed
    
    public static func ==(lhs: MigrationStateWrapper, rhs: MigrationStateWrapper) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted),
             (.preparing, .preparing),
             (.migrating, .migrating),
             (.completed, .completed),
             (.failed, .failed):
            return true
        default:
            return false
        }
    }
} 