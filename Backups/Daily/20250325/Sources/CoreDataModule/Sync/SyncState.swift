import Foundation

/// 同步状态枚举
public enum SyncState: Sendable {
    /// 空闲状态，未同步
    case idle
    
    /// 正在准备同步
    case preparing
    
    /// 正在同步数据
    case syncing
    
    /// 同步完成
    case completed
    
    /// 同步失败，包含相关错误
    case failed(Error)
    
    /// 是否为活动状态（非空闲或完成）
    public var isActive: Bool {
        switch self {
        case .idle, .completed:
            return false
        case .preparing, .syncing, .failed:
            return true
        }
    }
    
    /// 是否为错误状态
    public var isError: Bool {
        switch self {
        case .failed:
            return true
        default:
            return false
        }
    }
    
    /// 获取相关错误（如果存在）
    public var error: Error? {
        switch self {
        case .failed(let error):
            return error
        default:
            return nil
        }
    }
}

// MARK: - 协议定义

/// 同步服务协议
public protocol SyncServiceProtocol: Sendable {
    /// 从服务器获取数据
    func fetchDataFromServer() async throws -> [String: Any]
    
    /// 上传数据到服务器
    func uploadDataToServer(_ data: [String: Any]) async throws -> Bool
    
    /// 解决冲突
    func resolveConflicts(
        local: [String: Any],
        remote: [String: Any],
        strategy: AutoMergeStrategy
    ) async throws -> [String: Any]
}

/// 存储访问协议
public protocol StoreAccessProtocol: Sendable {
    /// 从存储中读取数据
    func readDataFromStore() async throws -> [String: Any]
    
    /// 将数据写入存储
    func writeDataToStore(_ data: [String: Any]) async throws -> Bool
    
    /// 检查数据是否变化
    func hasChanges(_ newData: [String: Any], comparedTo oldData: [String: Any]) -> Bool
} 