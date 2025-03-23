import Foundation

/// 文档存储库接口
public protocol IDocumentRepository {
    /// 通过ID查找文档
    /// - Parameter id: 文档ID
    /// - Returns: 查找到的文档，如果不存在则返回nil
    func find(byID id: UUID) async throws -> Document?
    
    /// 查找所有文档
    /// - Returns: 文档列表
    func findAll() async throws -> [Document]
    
    /// 保存文档
    /// - Parameter document: 要保存的文档
    /// - Returns: 保存后的文档（可能包含新的ID等信息）
    func save(_ document: Document) async throws -> Document
    
    /// 更新文档
    /// - Parameter document: 要更新的文档
    /// - Returns: 更新后的文档
    func update(_ document: Document) async throws -> Document
    
    /// 删除文档
    /// - Parameter id: 要删除的文档ID
    func delete(byID id: UUID) async throws
} 