import Foundation

/// 文档存储接口
protocol DocumentStorage {
    /// 保存文档
    /// - Parameter document: 要保存的文档
    func save(_ document: Document) async throws
    
    /// 获取文档
    /// - Parameter id: 文档ID
    /// - Returns: 文档实例
    func fetch(id: UUID) async throws -> Document
    
    /// 更新文档
    /// - Parameter document: 要更新的文档
    func update(_ document: Document) async throws
    
    /// 删除文档
    /// - Parameter id: 文档ID
    func delete(id: UUID) async throws
    
    /// 获取所有文档
    /// - Returns: 文档列表
    func fetchAll() async throws -> [Document]
    
    /// 搜索文档
    /// - Parameter query: 搜索关键词
    /// - Returns: 匹配的文档列表
    func search(query: String) async throws -> [Document]
}

// MARK: - Errors
enum StorageError: Error {
    case documentNotFound
    case invalidData
    case databaseError(Error)
} 