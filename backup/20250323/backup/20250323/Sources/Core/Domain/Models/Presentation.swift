import Foundation

/// 演示文稿模型
public struct Presentation: Codable, Identifiable {
    /// 演示文稿ID
    public let id: UUID
    
    /// 标题
    public let title: String
    
    /// 创建时间
    public let createdAt: Date
    
    /// 更新时间
    public let updatedAt: Date
    
    /// 主题
    public let theme: String
    
    /// 幻灯片
    public let slides: [Slide]
    
    /// 元数据
    public let metadata: [String: String]?
    
    /// 初始化方法
    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        theme: String = "default",
        slides: [Slide] = [],
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.theme = theme
        self.slides = slides
        self.metadata = metadata
    }
}

/// 幻灯片模型
public struct Slide: Codable, Identifiable {
    /// 幻灯片ID
    public let id: UUID
    
    /// 标题
    public let title: String?
    
    /// 内容
    public let content: String?
    
    /// 布局类型
    public let layout: SlideLayout
    
    /// 索引（在演示文稿中的位置）
    public let index: Int
    
    /// 元素列表
    public let elements: [SlideElement]?
    
    /// 注释
    public let notes: String?
    
    /// 初始化方法
    public init(
        id: UUID = UUID(),
        title: String? = nil,
        content: String? = nil,
        layout: SlideLayout = .title,
        index: Int,
        elements: [SlideElement]? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.layout = layout
        self.index = index
        self.elements = elements
        self.notes = notes
    }
}

/// 幻灯片布局类型
public enum SlideLayout: String, Codable {
    case title = "title"
    case titleAndContent = "titleAndContent"
    case twoColumns = "twoColumns"
    case comparison = "comparison"
    case titleOnly = "titleOnly"
    case blank = "blank"
    case custom = "custom"
}

/// 幻灯片元素模型
public struct SlideElement: Codable, Identifiable {
    /// 元素ID
    public let id: UUID
    
    /// 元素类型
    public let type: ElementType
    
    /// 内容
    public let content: String
    
    /// 位置
    public let position: ElementPosition
    
    /// 样式
    public let style: [String: String]?
    
    /// 初始化方法
    public init(
        id: UUID = UUID(),
        type: ElementType,
        content: String,
        position: ElementPosition,
        style: [String: String]? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.position = position
        self.style = style
    }
}

/// 元素类型
public enum ElementType: String, Codable {
    case text = "text"
    case image = "image"
    case chart = "chart"
    case video = "video"
    case code = "code"
    case table = "table"
    case shape = "shape"
}

/// 元素位置
public struct ElementPosition: Codable {
    /// X坐标
    public let x: Double
    
    /// Y坐标
    public let y: Double
    
    /// 宽度
    public let width: Double
    
    /// 高度
    public let height: Double
    
    /// 初始化方法
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct Theme: Codable, Hashable {
    public let id: String
    public let name: String
    public let primaryColor: String
    public let secondaryColor: String
    public let fontFamily: String
    
    public static let `default` = Theme(
        id: "default",
        name: "Default",
        primaryColor: "#000000",
        secondaryColor: "#FFFFFF",
        fontFamily: "Arial"
    )
    
    public init(
        id: String,
        name: String,
        primaryColor: String,
        secondaryColor: String,
        fontFamily: String
    ) {
        self.id = id
        self.name = name
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.fontFamily = fontFamily
    }
} 