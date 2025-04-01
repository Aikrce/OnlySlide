import Foundation
import AppKit

// MARK: - 文档分析相关模型

/// 原始内容类型
enum ContentType {
    case text
    case pdf
    case html
    case markdown
    case unknown
}

/// 原始内容
struct RawContent {
    let type: ContentType
    let title: String?
    let content: String
    let metadata: [String: Any]
}

/// 内容项类型
enum ContentItemType {
    case text
    case list
    case image
    case chart
    case table
    case code
}

/// 内容项
struct ContentItem {
    let id: String
    let type: ContentItemType
    let title: String
    let content: Any?
    let importance: Int // 1-10
    let metadata: [String: Any]
}

/// 内容章节
struct ContentSection {
    let id: String
    let title: String
    let items: [ContentItem]
    let importance: Int // 1-10
}

/// 分析后的内容
struct AnalyzedContent {
    let title: String
    let subtitle: String?
    let author: String?
    let date: String?
    let summary: String
    let sections: [ContentSection]
    let keywords: [String]
    let metadata: [String: Any]
}

// MARK: - 演示文稿相关模型

/// 对齐方式
enum TextAlignment {
    case left
    case center
    case right
    case justified
}

/// 文本样式
struct TextStyle {
    let fontName: String
    let fontSize: CGFloat
    let color: NSColor
    let alignment: TextAlignment
}

/// 幻灯片布局类型
enum SlideLayoutType {
    case cover
    case tableOfContents
    case sectionHeader
    case content
    case transition
    case summary
    case thankYou
    case custom
}

/// 幻灯片布局
struct SlideLayout {
    let type: SlideLayoutType
    let background: NSColor?
    let textStyle: TextStyle?
}

/// 幻灯片元素类型
enum SlideElementType {
    case title
    case subtitle
    case text
    case bulletList
    case image
    case chart
    case table
    case code
}

/// 幻灯片元素
struct SlideElement {
    let type: SlideElementType
    let content: Any?
    let position: CGRect // 相对位置 (0.0-1.0)
    let style: Any?
}

/// 演示文稿幻灯片
struct PresentationSlide {
    let id: String
    let title: String
    let elements: [SlideElement]
    let layout: SlideLayout
    let notes: String?
}

/// 演示文稿文档
struct PresentationDocument {
    let title: String
    var slides: [PresentationSlide]
}

// MARK: - 视觉主题相关模型

/// 视觉主题
struct VisualTheme {
    let name: String
    let description: String
    
    // 背景
    let coverSlideBackground: NSColor
    let contentSlideBackground: NSColor
    let sectionHeaderBackground: NSColor
    let transitionSlideBackground: NSColor
    let summarySlideBackground: NSColor
    let endSlideBackground: NSColor
    
    // 文本样式
    let titleTextStyle: TextStyle
    let subtitleTextStyle: TextStyle
    let sectionTitleStyle: TextStyle
    let slideTitleStyle: TextStyle
    let bodyTextStyle: TextStyle
    let captionTextStyle: TextStyle
    let listStyle: TextStyle
    let tocItemStyle: TextStyle
    
    // 特殊样式
    let codeStyle: TextStyle
    let chartStyle: TextStyle
    let tableStyle: TextStyle
    
    // 装饰元素
    let decorativeElements: [String: String] // 名称到图像路径的映射
}

// MARK: - 模板相关模型

/// 模板映射规则
struct TemplateMappingRule {
    let contentType: ContentItemType
    let importanceThreshold: Int // 最低重要性
    let maxItems: Int? // 最大项目数量
    let targetElement: SlideElementType
    let position: CGRect? // 目标位置
}

/// 幻灯片模板
struct SlideTemplate {
    let id: String
    let name: String
    let layoutType: SlideLayoutType
    let supportedContentTypes: [ContentItemType]
    let mappingRules: [TemplateMappingRule]
    
    /// 根据内容和主题创建幻灯片
    func createSlide(withContent mappings: [ContentItemToElementMapping], theme: VisualTheme) -> PresentationSlide {
        // 根据布局类型选择背景色
        let background: NSColor
        switch layoutType {
        case .cover:
            background = theme.coverSlideBackground
        case .tableOfContents:
            background = theme.contentSlideBackground
        case .sectionHeader:
            background = theme.sectionHeaderBackground
        case .transition:
            background = theme.transitionSlideBackground
        case .summary:
            background = theme.summarySlideBackground
        case .thankYou:
            background = theme.endSlideBackground
        case .content, .custom:
            background = theme.contentSlideBackground
        }
        
        // 创建布局
        let layout = SlideLayout(
            type: layoutType,
            background: background,
            textStyle: theme.bodyTextStyle
        )
        
        // 转换内容项到幻灯片元素
        var elements: [SlideElement] = []
        
        for mapping in mappings {
            // 获取对应的映射规则
            if let rule = mappingRules.first(where: { $0.contentType == mapping.contentItem.type }) {
                // 确定元素位置
                let position = rule.position ?? CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
                
                // 选择适当的样式
                let style: Any?
                switch rule.targetElement {
                case .title:
                    style = theme.titleTextStyle
                case .subtitle:
                    style = theme.subtitleTextStyle
                case .text:
                    style = theme.bodyTextStyle
                case .bulletList:
                    style = theme.listStyle
                case .chart:
                    style = theme.chartStyle
                case .table:
                    style = theme.tableStyle
                case .code:
                    style = theme.codeStyle
                case .image:
                    style = nil
                }
                
                // 创建幻灯片元素
                let element = SlideElement(
                    type: rule.targetElement,
                    content: mapping.contentItem.content,
                    position: position,
                    style: style
                )
                
                elements.append(element)
            }
        }
        
        // 如果没有元素，添加默认的标题元素
        if elements.isEmpty {
            let titleElement = SlideElement(
                type: .title,
                content: name,
                position: CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.2),
                style: theme.titleTextStyle
            )
            elements.append(titleElement)
        }
        
        // 创建幻灯片
        return PresentationSlide(
            id: UUID().uuidString,
            title: name,
            elements: elements,
            layout: layout,
            notes: "幻灯片笔记"
        )
    }
}

/// 内容到元素的映射
struct ContentItemToElementMapping {
    let contentItem: ContentItem
    let template: SlideTemplate
    let targetElement: SlideElementType
    let position: CGRect?
}

/// 模板映射结果
struct TemplateMappingResult {
    let template: SlideTemplate
    let sectionIndex: Int
    let contentMappings: [ContentItemToElementMapping]
} 