import Foundation
import os.log

/// 统一的文档存储接口
/// 整合了之前分散在不同文件中的 DocumentStorage 定义
public protocol UnifiedDocumentStorage {
    // 从 RealmDocumentStorage.swift 中的 DocumentStorage
    func fetchDocument(withID id: UUID) async throws -> Document?
    func fetchAllDocuments() async throws -> [Document]
    func saveDocument(_ document: Document) async throws -> Document
    func updateDocument(_ document: Document) async throws -> Document
    func deleteDocument(withID id: UUID) async throws
    
    // 从 Infrastructure/DataSources/DocumentStorage.swift 中添加的方法
    func search(query: String) async throws -> [Document]
}

// MARK: - Errors
public enum StorageError: Error, LocalizedError {
    case documentNotFound
    case invalidData
    case databaseError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "文档未找到"
        case .invalidData:
            return "无效的数据"
        case .databaseError(let error):
            return "数据库错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - 适配器
/// 帮助现有实现适配新接口的扩展
public extension UnifiedDocumentStorage {
    // 提供默认实现，帮助现有代码适配新接口
    func search(query: String) async throws -> [Document] {
        let allDocuments = try await fetchAllDocuments()
        // 简单实现：标题或内容包含查询词
        return allDocuments.filter { 
            $0.title.localizedCaseInsensitiveContains(query) || 
            ($0.content?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
} 