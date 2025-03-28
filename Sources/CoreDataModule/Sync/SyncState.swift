import Foundation
import CoreData
import Combine

/// 同步状态枚举
public enum SyncState: Sendable, Equatable {
    /// 空闲状态，未同步
    case idle
    
    /// 正在准备同步
    case preparing
    
    /// 正在同步数据
    case syncing
    
    /// 正在上传数据
    case uploading(progress: Double)
    
    /// 正在下载数据
    case downloading(progress: Double)
    
    /// 正在合并数据
    case merging
    
    /// 同步完成
    case completed
    
    /// 同步失败，包含相关错误
    case failed(Error)
    
    /// 是否为活动状态（非空闲或完成）
    public var isActive: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        case .preparing, .syncing, .uploading, .downloading, .merging:
            return true
        }
    }
    
    /// 是否为错误状态
    public var isError: Bool {
        if case .failed = self {
            return true
        }
        return false
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
    
    /// 用于Equatable协议实现
    public static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.preparing, .preparing), (.syncing, .syncing), 
             (.merging, .merging), (.completed, .completed):
            return true
        case let (.uploading(lhsProgress), .uploading(rhsProgress)):
            return lhsProgress == rhsProgress
        case let (.downloading(lhsProgress), .downloading(rhsProgress)):
            return lhsProgress == rhsProgress
        case let (.failed(lhsError), .failed(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - 同步选项
/// 同步选项
public struct SyncOptions: Sendable {
    /// 同步方向
    public enum Direction: Sendable {
        /// 上传
        case upload
        /// 下载
        case download
        /// 双向
        case bidirectional
    }
    
    /// 同步方向
    public let direction: Direction
    
    /// 自动冲突解决策略
    public let autoMergeStrategy: AutoMergeStrategy
    
    /// 是否在失败时回滚
    public let rollbackOnFailure: Bool
    
    /// 创建同步选项
    public init(
        direction: Direction = .bidirectional,
        autoMergeStrategy: AutoMergeStrategy = .serverWins,
        rollbackOnFailure: Bool = true
    ) {
        self.direction = direction
        self.autoMergeStrategy = autoMergeStrategy
        self.rollbackOnFailure = rollbackOnFailure
    }
    
    /// 默认选项
    public static let `default` = SyncOptions()
}

// MARK: - 自动合并策略
/// 自动合并冲突解决策略
public enum AutoMergeStrategy: Sendable {
    /// 服务器数据优先
    case serverWins
    /// 本地数据优先
    case localWins
    /// 按最近修改时间
    case mostRecent
    /// 合并冲突字段
    case mergeFields
    /// 手动解决
    case manual
}

// MARK: - 协议定义

/// 同步服务协议
public protocol SyncServiceProtocol: Sendable {
    /// 从服务器获取数据
    func fetchDataFromServer() async throws -> SyncData
    
    /// 上传数据到服务器
    func uploadDataToServer(_ data: SyncData) async throws -> Bool
    
    /// 解决冲突
    func resolveConflicts(
        local: SyncData,
        remote: SyncData,
        strategy: AutoMergeStrategy
    ) async throws -> SyncData
}

/// 存储访问协议
public protocol StoreAccessProtocol: Sendable {
    /// 从存储中读取数据
    func readDataFromStore() async throws -> SyncData
    
    /// 将数据写入存储
    func writeDataToStore(_ data: SyncData) async throws -> Bool
    
    /// 检查数据是否变化
    func hasChanges(_ newData: SyncData, comparedTo oldData: SyncData) -> Bool
}

// MARK: - Dictionary扩展

/// 扩展Dictionary以便对比两个字典是否相等
extension Dictionary where Key == String, Value == Any {
    /// 比较两个字典是否相等
    public func isEqual(to other: [String: Any]) -> Bool {
        // 检查键的数量
        guard self.count == other.count else {
            return false
        }
        
        // 比较每个键值对
        for (key, value) in self {
            guard let otherValue = other[key] else {
                return false
            }
            
            // 根据值的类型比较
            if let selfDict = value as? [String: Any],
               let otherDict = otherValue as? [String: Any] {
                if !selfDict.isEqual(to: otherDict) {
                    return false
                }
            } else if let selfArray = value as? [Any],
                      let otherArray = otherValue as? [Any] {
                // 数组比较需要更复杂的逻辑，这里简化处理
                if selfArray.count != otherArray.count {
                    return false
                }
            } else if String(describing: value) != String(describing: otherValue) {
                return false
            }
        }
        
        return true
    }
}

// MARK: - 为Error类型添加Equatable支持
extension Error {
    var errorCode: Int {
        return (self as NSError).code
    }
    
    var errorDomain: String {
        return (self as NSError).domain
    }
}

// MARK: - 同步进度报告协议
/// 同步进度报告协议
public protocol SyncProgressReporterProtocol {
    /// 报告准备开始
    func reportPreparing()
    
    /// 报告同步中
    func reportSyncing()
    
    /// 报告上传进度
    func reportUploading(progress: Double)
    
    /// 报告下载进度
    func reportDownloading(progress: Double)
    
    /// 报告完成
    func reportCompleted()
    
    /// 报告失败
    func reportFailed(error: Error)
} 