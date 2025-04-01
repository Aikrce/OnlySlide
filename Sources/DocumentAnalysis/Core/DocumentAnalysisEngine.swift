import Foundation
import UniformTypeIdentifiers

/// 文档分析策略协议 - 定义不同类型文档的分析方法
public protocol DocumentAnalysisStrategy {
    /// 支持的文档类型
    func supportedTypes() -> [UTType]
    
    /// 分析文档内容
    func analyze(content: Data, filename: String?) async throws -> DocumentAnalysisResult
    
    /// 提供策略的描述信息
    var description: String { get }
}

/// 文档分析错误类型
public enum DocumentAnalysisError: Error, LocalizedError {
    case unsupportedDocumentType
    case invalidDocumentFormat
    case analysisFailure(String)
    case documentTooLarge(Int)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedDocumentType:
            return "不支持的文档类型"
        case .invalidDocumentFormat:
            return "无效的文档格式"
        case .analysisFailure(let message):
            return "分析失败: \(message)"
        case .documentTooLarge(let size):
            return "文档过大 (\(size/1024/1024) MB)"
        }
    }
}

/// 文档分析配置选项
public struct DocumentAnalysisOptions {
    /// 最大处理文档大小（字节）
    public var maxDocumentSize: Int = 10 * 1024 * 1024  // 默认10MB
    
    /// 是否提取标题结构
    public var extractTitleStructure: Bool = true
    
    /// 是否提取图片
    public var extractImages: Bool = true
    
    /// 是否提取表格
    public var extractTables: Bool = true
    
    /// 最大处理页数/幻灯片数（对PDF/PPT有效）
    public var maxPageCount: Int = 100
    
    /// 自定义元数据提取键
    public var metadataKeys: [String] = []
    
    public init(
        maxDocumentSize: Int = 10 * 1024 * 1024,
        extractTitleStructure: Bool = true,
        extractImages: Bool = true,
        extractTables: Bool = true,
        maxPageCount: Int = 100,
        metadataKeys: [String] = []
    ) {
        self.maxDocumentSize = maxDocumentSize
        self.extractTitleStructure = extractTitleStructure
        self.extractImages = extractImages
        self.extractTables = extractTables
        self.maxPageCount = maxPageCount
        self.metadataKeys = metadataKeys
    }
}

/// 文档分析引擎 - 协调各种文档分析策略
public class DocumentAnalysisEngine {
    // 已注册的分析策略
    private var strategies: [DocumentAnalysisStrategy] = []
    
    // 分析选项
    public var options: DocumentAnalysisOptions
    
    public init(options: DocumentAnalysisOptions = DocumentAnalysisOptions()) {
        self.options = options
    }
    
    /// 注册文档分析策略
    public func register(strategy: DocumentAnalysisStrategy) {
        strategies.append(strategy)
    }
    
    /// 获取支持的所有文档类型
    public func supportedDocumentTypes() -> [UTType] {
        return strategies.flatMap { $0.supportedTypes() }
    }
    
    /// 查找适用于特定UTType的策略
    public func findStrategy(for fileType: UTType) -> DocumentAnalysisStrategy? {
        return strategies.first { strategy in
            strategy.supportedTypes().contains { $0.conforms(to: fileType) }
        }
    }
    
    /// 查找适用于文件名的策略
    public func findStrategy(forFilename filename: String) -> DocumentAnalysisStrategy? {
        guard let fileExtension = URL(string: filename)?.pathExtension.lowercased() else {
            return nil
        }
        
        let possibleUTTypes: [String: UTType] = [
            "txt": .plainText,
            "md": .plainText,
            "docx": .data,
            "doc": .data,
            "pdf": .pdf,
            "html": .html,
            "htm": .html
        ]
        
        if let uttype = possibleUTTypes[fileExtension] {
            return findStrategy(for: uttype)
        }
        
        return nil
    }
    
    /// 分析文档内容
    public func analyze(content: Data, filename: String? = nil) async throws -> DocumentAnalysisResult {
        // 检查文档大小
        guard content.count <= options.maxDocumentSize else {
            throw DocumentAnalysisError.documentTooLarge(content.count)
        }
        
        // 尝试通过文件名找到合适的策略
        if let filename = filename, let strategy = findStrategy(forFilename: filename) {
            return try await strategy.analyze(content: content, filename: filename)
        }
        
        // 如果无法通过文件名确定，尝试通过内容类型猜测
        if let contentType = try? UTType(filenameExtension: filename ?? ""),
           let strategy = findStrategy(for: contentType) {
            return try await strategy.analyze(content: content, filename: filename)
        }
        
        // 如果还是找不到合适的策略，尝试使用纯文本策略（如果已注册）
        if let textStrategy = findStrategy(for: .plainText) {
            return try await textStrategy.analyze(content: content, filename: filename)
        }
        
        throw DocumentAnalysisError.unsupportedDocumentType
    }
} 