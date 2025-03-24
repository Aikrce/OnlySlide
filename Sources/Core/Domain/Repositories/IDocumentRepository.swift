import Foundation
import Combine

/// 文档仓库协议
/// 遵循依赖倒置原则，定义领域模型和业务逻辑对数据层的需求
public protocol IDocumentRepository {
    // MARK: - CRUD 操作
    
    /// 获取所有文档
    /// - Returns: 文档列表
    /// - Throws: 如果操作失败则抛出错误
    func getAllDocuments() async throws -> [Document]
    
    /// 获取特定文档
    /// - Parameter id: 文档ID
    /// - Returns: 找到的文档，如果不存在则返回nil
    /// - Throws: 如果操作失败则抛出错误
    func getDocument(id: UUID) async throws -> Document?
    
    /// 创建新文档
    /// - Parameter document: 要创建的文档
    /// - Returns: 创建后的文档（包含服务器生成的ID等）
    /// - Throws: 如果操作失败则抛出错误
    func createDocument(_ document: Document) async throws -> Document
    
    /// 更新文档
    /// - Parameter document: 要更新的文档
    /// - Returns: 更新后的文档
    /// - Throws: 如果操作失败则抛出错误
    func updateDocument(_ document: Document) async throws -> Document
    
    /// 删除文档
    /// - Parameter id: 要删除的文档ID
    /// - Throws: 如果操作失败则抛出错误
    func deleteDocument(id: UUID) async throws
    
    // MARK: - 批量操作
    
    /// 批量创建文档
    /// - Parameter documents: 要创建的文档列表
    /// - Returns: 创建后的文档列表
    /// - Throws: 如果操作失败则抛出错误
    func createDocuments(_ documents: [Document]) async throws -> [Document]
    
    /// 批量更新文档
    /// - Parameter documents: 要更新的文档列表
    /// - Returns: 更新后的文档列表
    /// - Throws: 如果操作失败则抛出错误
    func updateDocuments(_ documents: [Document]) async throws -> [Document]
    
    /// 批量删除文档
    /// - Parameter ids: 要删除的文档ID列表
    /// - Throws: 如果操作失败则抛出错误
    func deleteDocuments(ids: [UUID]) async throws
    
    // MARK: - 查询操作
    
    /// 搜索文档
    /// - Parameter query: 搜索查询
    /// - Returns: 匹配的文档列表
    /// - Throws: 如果操作失败则抛出错误
    func searchDocuments(query: DocumentSearchQuery) async throws -> [Document]
    
    /// 根据标签获取文档
    /// - Parameter tags: 标签列表
    /// - Returns: 包含指定标签的文档列表
    /// - Throws: 如果操作失败则抛出错误
    func getDocumentsByTags(_ tags: [String]) async throws -> [Document]
    
    // MARK: - 同步操作
    
    /// 同步文档
    /// - Returns: 同步后的文档列表
    /// - Throws: 如果操作失败则抛出错误
    func syncDocuments() async throws -> [Document]
    
    /// 获取同步状态
    /// - Returns: 当前同步状态
    var syncState: SyncState { get async }
    
    /// 解决冲突
    /// - Parameters:
    ///   - document: 冲突的文档
    ///   - resolution: 冲突解决策略
    /// - Returns: 解决冲突后的文档
    /// - Throws: 如果操作失败则抛出错误
    func resolveConflict(document: Document, resolution: ConflictResolution) async throws -> Document
    
    // MARK: - 观察操作
    
    /// 观察文档变更
    /// - Returns: 文档变更事件的发布者
    func observeDocuments() -> AnyPublisher<DocumentChangeEvent, Never>
    
    /// 观察特定文档的变更
    /// - Parameter id: 文档ID
    /// - Returns: 指定文档变更事件的发布者
    func observeDocument(id: UUID) -> AnyPublisher<DocumentChangeEvent, Never>
}

/// 文档查询参数
public struct DocumentSearchQuery {
    /// 搜索文本
    public let text: String?
    
    /// 文档类型过滤
    public let types: [DocumentType]?
    
    /// 创建日期范围
    public let dateRange: Range<Date>?
    
    /// 排序字段
    public let sortBy: DocumentSortField
    
    /// 排序方向
    public let sortOrder: SortOrder
    
    public init(
        text: String? = nil,
        types: [DocumentType]? = nil,
        dateRange: Range<Date>? = nil,
        sortBy: DocumentSortField = .updatedAt,
        sortOrder: SortOrder = .descending
    ) {
        self.text = text
        self.types = types
        self.dateRange = dateRange
        self.sortBy = sortBy
        self.sortOrder = sortOrder
    }
}

/// 文档排序字段
public enum DocumentSortField {
    case title
    case createdAt
    case updatedAt
}

/// 排序方向
public enum SortOrder {
    case ascending
    case descending
}

/// 文档变更事件
public enum DocumentChangeEvent {
    case added(Document)
    case updated(Document)
    case deleted(UUID)
    case refreshed([Document])
}

/// 冲突解决策略
public enum ConflictResolution {
    /// 保留本地版本
    case keepLocal
    
    /// 使用远程版本
    case useRemote
    
    /// 合并变更
    case merge
    
    /// 自定义合并
    case custom(Document)
} 