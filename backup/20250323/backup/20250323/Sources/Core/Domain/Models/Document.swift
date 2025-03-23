import Foundation

/// 文档模型
public struct Document: Codable, Identifiable, Hashable {
    /// 文档ID
    public let id: UUID
    
    /// 标题
    public var title: String
    
    /// 内容
    public var content: String?
    
    /// 创建时间
    public let createdAt: Date
    
    /// 更新时间
    public var updatedAt: Date
    
    /// 元数据
    public var metadata: String?
    
    /// 处理状态
    public var status: DocumentStatus
    
    /// 源URL
    public var sourceURL: URL?
    
    /// 文档类型
    public var type: DocumentType
    
    /// 标签
    public var tags: [String]?
    
    /// 初始化方法
    public init(
        id: UUID = UUID(),
        title: String,
        content: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadata: String? = nil,
        status: DocumentStatus = .draft,
        sourceURL: URL? = nil,
        type: DocumentType = .text,
        tags: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.status = status
        self.sourceURL = sourceURL
        self.type = type
        self.tags = tags
    }
    
    // MARK: - Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    public static func == (lhs: Document, rhs: Document) -> Bool {
        return lhs.id == rhs.id
    }
}

/// 文档状态
public enum DocumentStatus: Int, Codable {
    case draft = 0
    case processing = 1
    case completed = 2
    case error = 3
    case failed = 4
}

/// 文档类型
public enum DocumentType: String, Codable {
    case text = "text"
    case pdf = "pdf"
    case markdown = "markdown"
    case html = "html"
    case word = "word"
    case excel = "excel"
    case powerpoint = "powerpoint"
    case image = "image"
} 