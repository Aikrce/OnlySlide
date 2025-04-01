import Foundation
import SwiftUI

/// 定义文档分析的结果类型
public struct DocumentAnalysisResult: Identifiable, Codable, Sendable {
    public let id = UUID()
    public var title: String
    public var sections: [DocumentSection]
    public var metadata: [String: String]
    public var sourceType: DocumentSourceType
    public var createdAt: Date
    
    public init(
        title: String = "",
        sections: [DocumentSection] = [],
        metadata: [String: String] = [:],
        sourceType: DocumentSourceType = .text,
        createdAt: Date = Date()
    ) {
        self.title = title
        self.sections = sections
        self.metadata = metadata
        self.sourceType = sourceType
        self.createdAt = createdAt
    }
    
    /// 获取总的内容项数量
    public var totalContentItemCount: Int {
        sections.reduce(0) { $0 + $1.contentItems.count }
    }
    
    /// 估算总的幻灯片数量
    public var estimatedSlideCount: Int {
        // 标题页 + 每个部分至少一页
        var count = 1 + sections.count
        
        // 根据内容项数量估算额外需要的幻灯片
        for section in sections {
            // 复杂内容项（例如大段文字、表格、图片）可能需要额外幻灯片
            let complexItems = section.contentItems.filter { 
                $0.complexity.rawValue > ContentComplexity.simple.rawValue 
            }
            count += complexItems.count / 2 // 假设每2个复杂项需要1个额外幻灯片
        }
        
        return count
    }
}

/// 文档部分（例如章节、标题下的内容块等）
public struct DocumentSection: Identifiable, Codable, Sendable {
    public let id = UUID()
    public var title: String
    public var level: Int
    public var contentItems: [ContentItem]
    
    public init(
        title: String = "",
        level: Int = 1,
        contentItems: [ContentItem] = []
    ) {
        self.title = title
        self.level = level
        self.contentItems = contentItems
    }
}

/// 内容项（段落、列表项、图片、表格等）
public struct ContentItem: Identifiable, Codable, Sendable {
    public let id = UUID()
    public var type: ContentType
    public var text: String
    public var attributes: [String: String]
    public var children: [ContentItem]
    
    public init(
        type: ContentType = .paragraph,
        text: String = "",
        attributes: [String: String] = [:],
        children: [ContentItem] = []
    ) {
        self.type = type
        self.text = text
        self.attributes = attributes
        self.children = children
    }
    
    /// 内容复杂度评估
    public var complexity: ContentComplexity {
        switch type {
        case .paragraph:
            // 根据文本长度判断
            if text.count < 100 {
                return .simple
            } else if text.count < 300 {
                return .medium
            } else {
                return .complex
            }
        case .listItem:
            return children.isEmpty ? .simple : .medium
        case .table:
            return .complex
        case .image:
            return .medium
        case .code:
            return .medium
        case .quote:
            return text.count < 100 ? .simple : .medium
        }
    }
}

/// 内容项类型
public enum ContentType: String, Codable, Sendable {
    case paragraph
    case listItem
    case table
    case image
    case code
    case quote
}

/// 内容复杂度评估
public enum ContentComplexity: String, Codable, Comparable, Sendable {
    case simple
    case medium
    case complex
    
    // 实现Comparable
    public static func < (lhs: ContentComplexity, rhs: ContentComplexity) -> Bool {
        let order: [ContentComplexity] = [.simple, .medium, .complex]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

/// 文档源类型
public enum DocumentSourceType: String, Codable, Sendable {
    case text
    case markdown
    case word
    case pdf
    case html
    case unknown
    
    /// 获取文档类型的显示名称
    public var displayName: String {
        switch self {
        case .text:
            return "文本文档"
        case .markdown:
            return "Markdown文档"
        case .word:
            return "Word文档"
        case .pdf:
            return "PDF文档"
        case .html:
            return "HTML文档"
        case .unknown:
            return "未知类型"
        }
    }
    
    /// 获取文档类型的图标名称
    public var iconName: String {
        switch self {
        case .text:
            return "doc.text"
        case .markdown:
            return "doc.plaintext"
        case .word:
            return "doc.richtext"
        case .pdf:
            return "doc.text.viewfinder"
        case .html:
            return "doc.text.image"
        case .unknown:
            return "doc.questionmark"
        }
    }
} 