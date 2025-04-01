import Foundation
import SwiftUI
import ZIPFoundation

/// PPT布局和样式提取器，用于从PowerPoint文件中提取布局、样式和设计元素
public class PPTLayoutExtractor {
    
    // MARK: - 错误类型
    
    /// PPT布局提取过程中可能出现的错误
    public enum PPTLayoutExtractionError: Error, LocalizedError {
        case invalidPPTFile
        case xmlParsingFailed
        case layoutExtractionFailed
        case styleExtractionFailed
        case themeExtractionFailed
        case masterSlideExtractionFailed
        case fileSystemError(String)
        case unsupportedPPTVersion
        case contentExtractionFailed
        case previewGenerationFailed
        
        public var errorDescription: String? {
            switch self {
            case .invalidPPTFile:
                return NSLocalizedString("输入的PPT文件无效或已损坏", comment: "")
            case .xmlParsingFailed:
                return NSLocalizedString("解析PPT内部XML结构失败", comment: "")
            case .layoutExtractionFailed:
                return NSLocalizedString("提取幻灯片布局失败", comment: "")
            case .styleExtractionFailed:
                return NSLocalizedString("提取样式信息失败", comment: "")
            case .themeExtractionFailed:
                return NSLocalizedString("提取主题信息失败", comment: "")
            case .masterSlideExtractionFailed:
                return NSLocalizedString("提取母版信息失败", comment: "")
            case .fileSystemError(let message):
                return NSLocalizedString("文件系统操作错误: \(message)", comment: "")
            case .unsupportedPPTVersion:
                return NSLocalizedString("不支持的PPT版本", comment: "")
            case .contentExtractionFailed:
                return NSLocalizedString("提取内容失败", comment: "")
            case .previewGenerationFailed:
                return NSLocalizedString("生成预览图失败", comment: "")
            }
        }
    }
    
    // MARK: - 数据模型
    
    /// 表示PPT文件中提取的模板信息
    public struct PPTTemplateInfo {
        /// 模板名称
        public var name: String
        /// 幻灯片尺寸
        public var slideSize: CGSize
        /// 主题信息
        public var theme: PPTTheme
        /// 母版集合
        public var masterSlides: [PPTMasterSlide]
        /// 布局集合
        public var layouts: [PPTLayout]
        /// 样式集合
        public var styles: PPTStyleCollection
        
        /// 创建空的模板信息实例
        public init(name: String = "未命名模板") {
            self.name = name
            self.slideSize = CGSize(width: 960, height: 540) // 默认16:9
            self.theme = PPTTheme()
            self.masterSlides = []
            self.layouts = []
            self.styles = PPTStyleCollection()
        }
    }
    
    /// 表示PPT主题信息
    public struct PPTTheme {
        /// 主题名称
        public var name: String
        /// 主题ID
        public var id: String
        /// 颜色方案
        public var colorScheme: ColorScheme
        /// 字体方案
        public var fontScheme: FontScheme
        /// 效果方案
        public var effectScheme: EffectScheme
        
        /// 创建默认主题
        public init(name: String = "默认主题", id: String = UUID().uuidString) {
            self.name = name
            self.id = id
            self.colorScheme = ColorScheme()
            self.fontScheme = FontScheme()
            self.effectScheme = EffectScheme()
        }
        
        /// 表示颜色方案
        public struct ColorScheme {
            public var background1: Color
            public var text1: Color
            public var background2: Color
            public var text2: Color
            public var accent1: Color
            public var accent2: Color
            public var accent3: Color
            public var accent4: Color
            public var accent5: Color
            public var accent6: Color
            public var hyperlink: Color
            public var followedHyperlink: Color
            
            public init() {
                // 默认颜色方案
                self.background1 = .white
                self.text1 = .black
                self.background2 = Color(white: 0.95)
                self.text2 = Color(white: 0.3)
                self.accent1 = Color(red: 0.2, green: 0.4, blue: 0.8)
                self.accent2 = Color(red: 0.8, green: 0.2, blue: 0.2)
                self.accent3 = Color(red: 0.2, green: 0.6, blue: 0.2)
                self.accent4 = Color(red: 0.8, green: 0.6, blue: 0.2)
                self.accent5 = Color(red: 0.4, green: 0.2, blue: 0.6)
                self.accent6 = Color(red: 0.2, green: 0.6, blue: 0.8)
                self.hyperlink = Color(red: 0, green: 0, blue: 0.8)
                self.followedHyperlink = Color(red: 0.6, green: 0, blue: 0.8)
            }
        }
        
        /// 表示字体方案
        public struct FontScheme {
            public var majorFont: FontSet
            public var minorFont: FontSet
            
            public init() {
                self.majorFont = FontSet(latinFont: "Arial", eastAsianFont: "SimSun", complexScriptFont: "Arial")
                self.minorFont = FontSet(latinFont: "Arial", eastAsianFont: "SimSun", complexScriptFont: "Arial")
            }
            
            public struct FontSet {
                public var latinFont: String
                public var eastAsianFont: String
                public var complexScriptFont: String
                
                public init(latinFont: String, eastAsianFont: String, complexScriptFont: String) {
                    self.latinFont = latinFont
                    self.eastAsianFont = eastAsianFont
                    self.complexScriptFont = complexScriptFont
                }
            }
        }
        
        /// 表示效果方案
        public struct EffectScheme {
            public var shadowEffects: [String: Any]
            public var glowEffects: [String: Any]
            public var reflectionEffects: [String: Any]
            
            public init() {
                self.shadowEffects = [:]
                self.glowEffects = [:]
                self.reflectionEffects = [:]
            }
        }
    }
    
    /// 表示PPT母版
    public struct PPTMasterSlide {
        /// 母版ID
        public var id: String
        /// 母版名称
        public var name: String
        /// 背景设置
        public var background: SlideBackground
        /// 母版元素
        public var elements: [TemplateElement]
        /// 关联的布局ID
        public var associatedLayoutIds: [String]
        
        public init(id: String = UUID().uuidString, name: String = "默认母版") {
            self.id = id
            self.name = name
            self.background = SlideBackground()
            self.elements = []
            self.associatedLayoutIds = []
        }
    }
    
    /// 表示PPT布局
    public struct PPTLayout {
        /// 布局ID
        public var id: String
        /// 布局名称
        public var name: String
        /// 布局类型
        public var type: LayoutType
        /// 关联的母版ID
        public var masterSlideId: String
        /// 布局元素
        public var elements: [TemplateElement]
        /// 背景设置
        public var background: SlideBackground
        /// 占位符信息
        public var placeholders: [Placeholder]
        
        public init(id: String = UUID().uuidString, name: String = "默认布局", type: LayoutType = .title) {
            self.id = id
            self.name = name
            self.type = type
            self.masterSlideId = ""
            self.elements = []
            self.background = SlideBackground()
            self.placeholders = []
        }
        
        /// 布局类型枚举
        public enum LayoutType: String, CaseIterable {
            case title = "标题幻灯片"
            case titleAndContent = "标题和内容"
            case sectionHeader = "节标题"
            case twoContent = "双栏内容"
            case comparison = "比较"
            case titleOnly = "仅标题"
            case blank = "空白"
            case contentWithCaption = "带说明的内容"
            case pictureWithCaption = "带说明的图片"
            case custom = "自定义"
            
            /// 返回布局类型的本地化名称
            public var localizedName: String {
                return NSLocalizedString(self.rawValue, comment: "")
            }
        }
    }
    
    /// 表示PPT样式集合
    public struct PPTStyleCollection {
        /// 文本样式集合
        public var textStyles: [String: TextStyle]
        /// 形状样式集合
        public var shapeStyles: [String: ShapeStyle]
        /// 表格样式集合
        public var tableStyles: [String: TableStyle]
        
        public init() {
            self.textStyles = [:]
            self.shapeStyles = [:]
            self.tableStyles = [:]
        }
    }
    
    /// 幻灯片背景
    public struct SlideBackground {
        /// 背景类型
        public enum BackgroundType {
            case solid(Color)
            case gradient(GradientBackground)
            case image(URL)
            case pattern(PatternBackground)
            case none
        }
        
        /// 渐变背景
        public struct GradientBackground {
            public var stops: [GradientStop]
            public var direction: GradientDirection
            
            public init() {
                self.stops = []
                self.direction = .linear(angle: 90)
            }
            
            public struct GradientStop {
                public var color: Color
                public var position: Float
                
                public init(color: Color, position: Float) {
                    self.color = color
                    self.position = position
                }
            }
            
            public enum GradientDirection {
                case linear(angle: Float)
                case radial(center: CGPoint)
                case path
            }
        }
        
        /// 图案背景
        public struct PatternBackground {
            public var foreground: Color
            public var background: Color
            public var patternType: String
            
            public init() {
                self.foreground = .black
                self.background = .white
                self.patternType = "dots"
            }
        }
        
        public var type: BackgroundType
        
        public init() {
            self.type = .solid(.white)
        }
    }
    
    /// 表示模板元素
    public struct TemplateElement {
        /// 元素类型
        public enum ElementType {
            case shape
            case textBox
            case picture
            case table
            case chart
            case smartArt
            case media
            case group([TemplateElement])
        }
        
        /// 元素ID
        public var id: String
        /// 元素名称
        public var name: String
        /// 元素类型
        public var type: ElementType
        /// 元素位置
        public var frame: CGRect
        /// 元素层级
        public var zIndex: Int
        /// 元素样式引用
        public var styleReference: String?
        /// 元素属性
        public var properties: [String: Any]
        
        public init(id: String = UUID().uuidString, name: String = "", type: ElementType) {
            self.id = id
            self.name = name
            self.type = type
            self.frame = .zero
            self.zIndex = 0
            self.styleReference = nil
            self.properties = [:]
        }
    }
    
    /// 表示占位符
    public struct Placeholder {
        /// 占位符ID
        public var id: String
        /// 占位符类型
        public var type: PlaceholderType
        /// 占位符位置
        public var frame: CGRect
        /// 占位符索引
        public var index: Int
        /// 占位符样式引用
        public var styleReference: String?
        
        public init(id: String = UUID().uuidString, type: PlaceholderType, frame: CGRect = .zero) {
            self.id = id
            self.type = type
            self.frame = frame
            self.index = 0
            self.styleReference = nil
        }
        
        /// 占位符类型枚举
        public enum PlaceholderType: String, CaseIterable {
            case title
            case subtitle
            case content
            case picture
            case chart
            case table
            case smartArt
            case media
            case date
            case slideNumber
            case footer
            case header
            case custom
            
            /// 返回占位符类型的本地化名称
            public var localizedName: String {
                switch self {
                case .title:
                    return NSLocalizedString("标题", comment: "")
                case .subtitle:
                    return NSLocalizedString("副标题", comment: "")
                case .content:
                    return NSLocalizedString("内容", comment: "")
                case .picture:
                    return NSLocalizedString("图片", comment: "")
                case .chart:
                    return NSLocalizedString("图表", comment: "")
                case .table:
                    return NSLocalizedString("表格", comment: "")
                case .smartArt:
                    return NSLocalizedString("SmartArt", comment: "")
                case .media:
                    return NSLocalizedString("媒体", comment: "")
                case .date:
                    return NSLocalizedString("日期", comment: "")
                case .slideNumber:
                    return NSLocalizedString("幻灯片编号", comment: "")
                case .footer:
                    return NSLocalizedString("页脚", comment: "")
                case .header:
                    return NSLocalizedString("页眉", comment: "")
                case .custom:
                    return NSLocalizedString("自定义", comment: "")
                }
            }
        }
    }
    
    /// 文本样式
    public struct TextStyle {
        /// 字体
        public var fontFamily: String
        /// 字号
        public var fontSize: CGFloat
        /// 字重
        public var fontWeight: Font.Weight
        /// 文字颜色
        public var textColor: Color
        /// 是否粗体
        public var isBold: Bool
        /// 是否斜体
        public var isItalic: Bool
        /// 是否有下划线
        public var hasUnderline: Bool
        /// 是否有删除线
        public var hasStrikethrough: Bool
        /// 字间距
        public var kerning: CGFloat
        /// 段落样式
        public var paragraphStyle: ParagraphStyle
        
        public init() {
            self.fontFamily = ""
            self.fontSize = 12
            self.fontWeight = .regular
            self.textColor = .black
            self.isBold = false
            self.isItalic = false
            self.hasUnderline = false
            self.hasStrikethrough = false
            self.kerning = 0
            self.paragraphStyle = ParagraphStyle()
        }
        
        /// 段落样式
        public struct ParagraphStyle {
            /// 行距
            public var lineSpacing: CGFloat
            /// 段落间距
            public var paragraphSpacing: CGFloat
            /// 对齐方式
            public var alignment: TextAlignment
            /// 首行缩进
            public var firstLineHeadIndent: CGFloat
            /// 左缩进
            public var headIndent: CGFloat
            /// 右缩进
            public var tailIndent: CGFloat
            /// 制表位
            public var tabStops: [CGFloat]
            
            public init() {
                self.lineSpacing = 0
                self.paragraphSpacing = 0
                self.alignment = .leading
                self.firstLineHeadIndent = 0
                self.headIndent = 0
                self.tailIndent = 0
                self.tabStops = []
            }
        }
    }
    
    /// 形状样式
    public struct ShapeStyle {
        /// 填充类型
        public enum FillType {
            case none
            case solid(Color)
            case gradient(GradientFill)
            case pattern(PatternFill)
            case picture(URL)
        }
        
        /// 渐变填充
        public struct GradientFill {
            public var stops: [GradientStop]
            public var type: GradientType
            
            public init() {
                self.stops = []
                self.type = .linear(angle: 90)
            }
            
            public struct GradientStop {
                public var color: Color
                public var position: Float
                
                public init(color: Color, position: Float) {
                    self.color = color
                    self.position = position
                }
            }
            
            public enum GradientType {
                case linear(angle: Float)
                case radial(center: CGPoint)
                case rectangular(center: CGPoint)
                case path
            }
        }
        
        /// 图案填充
        public struct PatternFill {
            public var foreground: Color
            public var background: Color
            public var patternType: String
            
            public init() {
                self.foreground = .black
                self.background = .white
                self.patternType = "dots"
            }
        }
        
        /// 线条样式
        public struct LineStyle {
            /// 线条颜色
            public var color: Color
            /// 线条宽度
            public var width: CGFloat
            /// 线条类型
            public var dashPattern: [CGFloat]
            /// 线帽类型
            public var lineCap: CGLineCap
            /// 线条连接类型
            public var lineJoin: CGLineJoin
            
            public init() {
                self.color = .black
                self.width = 1
                self.dashPattern = []
                self.lineCap = .butt
                self.lineJoin = .miter
            }
        }
        
        /// 阴影样式
        public struct ShadowStyle {
            /// 偏移量
            public var offset: CGSize
            /// 模糊半径
            public var radius: CGFloat
            /// 颜色
            public var color: Color
            /// 透明度
            public var opacity: Float
            
            public init() {
                self.offset = CGSize(width: 0, height: 0)
                self.radius = 0
                self.color = .black
                self.opacity = 0
            }
        }
        
        /// 填充类型
        public var fill: FillType
        /// 线条样式
        public var line: LineStyle
        /// 阴影样式
        public var shadow: ShadowStyle?
        /// 形状类型
        public var shapeType: String
        /// 圆角半径
        public var cornerRadius: CGFloat
        
        public init() {
            self.fill = .solid(.white)
            self.line = LineStyle()
            self.shadow = nil
            self.shapeType = "rectangle"
            self.cornerRadius = 0
        }
    }
    
    /// 表格样式
    public struct TableStyle {
        /// 表格边框样式
        public var borderStyle: ShapeStyle.LineStyle
        /// 表头样式
        public var headerRowStyle: TableCellStyle
        /// 总计行样式
        public var totalRowStyle: TableCellStyle
        /// 第一列样式
        public var firstColumnStyle: TableCellStyle
        /// 最后一列样式
        public var lastColumnStyle: TableCellStyle
        /// 奇数行样式
        public var oddRowStyle: TableCellStyle
        /// 偶数行样式
        public var evenRowStyle: TableCellStyle
        /// 奇数列样式
        public var oddColumnStyle: TableCellStyle
        /// 偶数列样式
        public var evenColumnStyle: TableCellStyle
        
        /// 表格单元格样式
        public struct TableCellStyle {
            /// 填充
            public var fill: ShapeStyle.FillType
            /// 文本样式
            public var textStyle: TextStyle
            /// 边框
            public var borders: [Edge.Set: ShapeStyle.LineStyle]
            
            public init() {
                self.fill = .solid(.white)
                self.textStyle = TextStyle()
                self.borders = [:]
            }
        }
        
        public init() {
            self.borderStyle = ShapeStyle.LineStyle()
            self.headerRowStyle = TableCellStyle()
            self.totalRowStyle = TableCellStyle()
            self.firstColumnStyle = TableCellStyle()
            self.lastColumnStyle = TableCellStyle()
            self.oddRowStyle = TableCellStyle()
            self.evenRowStyle = TableCellStyle()
            self.oddColumnStyle = TableCellStyle()
            self.evenColumnStyle = TableCellStyle()
        }
    }
    
    // MARK: - 属性
    
    /// PPT文件URL
    private let pptFileURL: URL
    /// 临时目录URL
    private var tempDirectoryURL: URL?
    /// 解析到的模板信息
    private var templateInfo: PPTTemplateInfo
    /// XML解析器
    private let xmlParser = PPTXMLParser()
    /// 媒体资源管理器
    private let mediaManager = PPTMediaManager()
    
    // MARK: - 初始化方法
    
    /// 使用PPT文件URL初始化提取器
    /// - Parameter pptFileURL: PPT文件的URL
    public init(pptFileURL: URL) {
        self.pptFileURL = pptFileURL
        self.templateInfo = PPTTemplateInfo()
    }
    
    // MARK: - 公共方法
    
    /// 从PPT文件中提取布局和样式信息
    /// - Returns: 提取的模板信息
    /// - Throws: 提取过程中发生的错误
    public func extractLayoutAndStyle() async throws -> PPTTemplateInfo {
        // 创建临时目录用于解压PPT文件
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
        self.tempDirectoryURL = tempDirectory
        
        defer {
            // 清理临时目录
            if let tempURL = self.tempDirectoryURL {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
        
        // 解压PPT文件
        try await unzipPPTFile()
        
        // 验证文件格式
        try validatePPTXFormat()
        
        // 初始化媒体管理器
        if let tempURL = self.tempDirectoryURL {
            mediaManager.initialize(with: tempURL)
        }
        
        // 解析PPT内容
        try await parsePPTContent()
        
        return templateInfo
    }
    
    // MARK: - 私有方法
    
    /// 解压PPT文件到临时目录
    private func unzipPPTFile() async throws {
        guard let tempDirectory = self.tempDirectoryURL else {
            throw PPTLayoutExtractionError.fileSystemError("无法创建临时目录")
        }
        
        do {
            try FileManager.default.unzipItem(at: pptFileURL, to: tempDirectory)
        } catch {
            throw PPTLayoutExtractionError.invalidPPTFile
        }
    }
    
    /// 验证PPTX格式
    private func validatePPTXFormat() throws {
        guard let tempDirectory = self.tempDirectoryURL else {
            throw PPTLayoutExtractionError.fileSystemError("临时目录不存在")
        }
        
        // 检查[Content_Types].xml文件是否存在
        let contentTypesURL = tempDirectory.appendingPathComponent("[Content_Types].xml")
        guard FileManager.default.fileExists(atPath: contentTypesURL.path) else {
            throw PPTLayoutExtractionError.invalidPPTFile
        }
        
        // 检查ppt目录是否存在
        let pptDirectoryURL = tempDirectory.appendingPathComponent("ppt")
        guard FileManager.default.fileExists(atPath: pptDirectoryURL.path) else {
            throw PPTLayoutExtractionError.invalidPPTFile
        }
        
        // 检查presentation.xml文件是否存在
        let presentationURL = pptDirectoryURL.appendingPathComponent("presentation.xml")
        guard FileManager.default.fileExists(atPath: presentationURL.path) else {
            throw PPTLayoutExtractionError.invalidPPTFile
        }
    }
    
    /// 解析PPT内容
    private func parsePPTContent() async throws {
        guard let tempDirectory = self.tempDirectoryURL else {
            throw PPTLayoutExtractionError.fileSystemError("临时目录不存在")
        }
        
        // 设置模板名称
        templateInfo.name = pptFileURL.deletingPathExtension().lastPathComponent
        
        // 解析演示文稿信息
        try parsePresentation()
        
        // 解析主题
        try parseThemes()
        
        // 解析母版
        try parseMasterSlides()
        
        // 解析布局
        try parseLayouts()
        
        // 解析样式
        try parseStyles()
        
        // 关联母版和布局
        linkMastersAndLayouts()
        
        // 处理媒体资源
        try processMediaResources()
    }
    
    /// 解析演示文稿信息
    private func parsePresentation() throws {
        guard let tempDirectory = self.tempDirectoryURL else {
            throw PPTLayoutExtractionError.fileSystemError("临时目录不存在")
        }
        
        let presentationURL = tempDirectory.appendingPathComponent("ppt/presentation.xml")
        
        do {
            let presentationData = try Data(contentsOf: presentationURL)
            let presentationInfo = try xmlParser.parsePresentation(data: presentationData)
            
            // 设置幻灯片尺寸
            templateInfo.slideSize = presentationInfo.slideSize
            
            // 设置其他演示文稿信息
            // ...
            
        } catch {
            print("解析演示文稿信息出错: \(error)")
            throw PPTLayoutExtractionError.xmlParsingFailed
        }
    }
    
    /// 解析主题信息
    private func parseThemes() throws {
        guard let tempDirectory = self.tempDirectoryURL else {
            throw PPTLayoutExtractionError.fileSystemError("临时目录不存在")
        }
        
        let themesDirectoryURL = tempDirectory.appendingPathComponent("ppt/theme")
        
        do {
            // 检查主题目录是否存在
            if FileManager.default.fileExists(atPath: themesDirectoryURL.path) {
                let themeFileURLs = try FileManager.default.contentsOfDirectory(at: themesDirectoryURL, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "xml" }
                
                // 至少应该有一个主题文件
                if let themeURL = themeFileURLs.first {
                    let themeData = try Data(contentsOf: themeURL)
                    let theme = try xmlParser.parseTheme(data: themeData)
                    templateInfo.theme = theme
                }
            }
        } catch {
            print("解析主题信息出错: \(error)")
            throw PPTLayoutExtractionError.themeExtractionFailed
        }
    }
    
    /// 解析母版信息
    private func parseMasterSlides() throws {
        guard let tempDirectory = self.tempDirectoryURL else {
            throw PPTLayoutExtractionError.fileSystemError("临时目录不存在")
        }
        
        let mastersDirectoryURL = tempDirectory.appendingPathComponent("ppt/slideMasters")
        
        do {
            // 检查母版目录是否存在
            if FileManager.default.fileExists(atPath: mastersDirectoryURL.path) {
                let masterFileURLs = try FileManager.default.contentsOfDirectory(at: mastersDirectoryURL, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "xml" }
                
                for masterURL in masterFileURLs {
                    let masterData = try Data(contentsOf: masterURL)
                    let masterRelationshipsURL = mastersDirectoryURL.appendingPathComponent("_rels").appendingPathComponent(masterURL.lastPathComponent + ".rels")
                    
                    // 如果存在关系文件，则加载它
                    var relationships: [String: String] = [:]
                    if FileManager.default.fileExists(atPath: masterRelationshipsURL.path) {
                        let relationshipsData = try Data(contentsOf: masterRelationshipsURL)
                        relationships = try xmlParser.parseRelationships(data: relationshipsData)
                    }
                    
                    let masterSlide = try xmlParser.parseMasterSlide(data: masterData, relationships: relationships)
                    templateInfo.masterSlides.append(masterSlide)
                }
            }
        } catch {
            print("解析母版信息出错: \(error)")
            throw PPTLayoutExtractionError.masterSlideExtractionFailed
        }
    }
    
    /// 解析布局信息
    private func parseLayouts() throws {
        guard let tempDirectory = self.tempDirectoryURL else {
            throw PPTLayoutExtractionError.fileSystemError("临时目录不存在")
        }
        
        let layoutsDirectoryURL = tempDirectory.appendingPathComponent("ppt/slideLayouts")
        
        do {
            // 检查布局目录是否存在
            if FileManager.default.fileExists(atPath: layoutsDirectoryURL.path) {
                let layoutFileURLs = try FileManager.default.contentsOfDirectory(at: layoutsDirectoryURL, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "xml" }
                
                for layoutURL in layoutFileURLs {
                    let layoutData = try Data(contentsOf: layoutURL)
                    let layoutRelationshipsURL = layoutsDirectoryURL.appendingPathComponent("_rels").appendingPathComponent(layoutURL.lastPathComponent + ".rels")
                    
                    // 如果存在关系文件，则加载它
                    var relationships: [String: String] = [:]
                    if FileManager.default.fileExists(atPath: layoutRelationshipsURL.path) {
                        let relationshipsData = try Data(contentsOf: layoutRelationshipsURL)
                        relationships = try xmlParser.parseRelationships(data: relationshipsData)
                    }
                    
                    let layout = try xmlParser.parseLayout(data: layoutData, relationships: relationships)
                    templateInfo.layouts.append(layout)
                }
            }
        } catch {
            print("解析布局信息出错: \(error)")
            throw PPTLayoutExtractionError.layoutExtractionFailed
        }
    }
    
    /// 解析样式信息
    private func parseStyles() throws {
        // 样式信息来自主题文件和其他XML文件的组合
        // 已经在解析主题和布局时部分加载了样式信息
        
        // 创建默认样式（如果缺少某些样式）
        ensureDefaultStyles()
    }
    
    /// 关联母版和布局
    private func linkMastersAndLayouts() {
        // 为每个布局找到对应的母版
        for i in 0..<templateInfo.layouts.count {
            let masterSlideId = templateInfo.layouts[i].masterSlideId
            
            // 更新母版的关联布局ID列表
            if !masterSlideId.isEmpty {
                for j in 0..<templateInfo.masterSlides.count {
                    if templateInfo.masterSlides[j].id == masterSlideId {
                        templateInfo.masterSlides[j].associatedLayoutIds.append(templateInfo.layouts[i].id)
                        break
                    }
                }
            }
        }
    }
    
    /// 处理媒体资源
    private func processMediaResources() throws {
        // 处理PPT中的媒体资源（图片等）
        guard let tempDirectory = self.tempDirectoryURL else {
            return
        }
        
        let mediaDirectoryURL = tempDirectory.appendingPathComponent("ppt/media")
        
        // 如果存在媒体目录，则处理媒体文件
        if FileManager.default.fileExists(atPath: mediaDirectoryURL.path) {
            try mediaManager.processMediaDirectory(mediaDirectoryURL)
        }
    }
    
    /// 确保有默认样式
    private func ensureDefaultStyles() {
        // 文本样式
        if templateInfo.styles.textStyles.isEmpty {
            // 标题样式
            var titleStyle = TextStyle()
            titleStyle.fontFamily = "Arial"
            titleStyle.fontSize = 44
            titleStyle.fontWeight = .bold
            titleStyle.textColor = .black
            titleStyle.paragraphStyle.alignment = .center
            
            // 正文样式
            var bodyStyle = TextStyle()
            bodyStyle.fontFamily = "Arial"
            bodyStyle.fontSize = 24
            bodyStyle.textColor = Color(white: 0.2)
            bodyStyle.paragraphStyle.lineSpacing = 6
            
            templateInfo.styles.textStyles["title"] = titleStyle
            templateInfo.styles.textStyles["body"] = bodyStyle
        }
        
        // 形状样式
        if templateInfo.styles.shapeStyles.isEmpty {
            var primaryShapeStyle = ShapeStyle()
            primaryShapeStyle.fill = .solid(Color(red: 0.2, green: 0.4, blue: 0.8, opacity: 0.1))
            primaryShapeStyle.line.color = Color(red: 0.2, green: 0.4, blue: 0.8)
            primaryShapeStyle.line.width = 2
            primaryShapeStyle.cornerRadius = 4
            
            templateInfo.styles.shapeStyles["primary"] = primaryShapeStyle
        }
    }
}

// MARK: - XML解析器

/// 解析PPTX文件中的XML内容
class PPTXMLParser {
    
    /// 解析演示文稿XML
    func parsePresentation(data: Data) throws -> (slideSize: CGSize, otherInfo: [String: Any]) {
        let parser = XMLParser(data: data)
        let presentationHandler = PresentationXMLHandler()
        parser.delegate = presentationHandler
        
        if parser.parse() {
            return (presentationHandler.slideSize, presentationHandler.otherInfo)
        } else {
            throw PPTLayoutExtractionError.xmlParsingFailed
        }
    }
    
    /// 解析主题XML
    func parseTheme(data: Data) throws -> PPTLayoutExtractor.PPTTheme {
        let parser = XMLParser(data: data)
        let themeHandler = ThemeXMLHandler()
        parser.delegate = themeHandler
        
        if parser.parse() {
            return themeHandler.theme
        } else {
            throw PPTLayoutExtractionError.themeExtractionFailed
        }
    }
    
    /// 解析母版XML
    func parseMasterSlide(data: Data, relationships: [String: String]) throws -> PPTLayoutExtractor.PPTMasterSlide {
        let parser = XMLParser(data: data)
        let masterHandler = MasterSlideXMLHandler(relationships: relationships)
        parser.delegate = masterHandler
        
        if parser.parse() {
            return masterHandler.masterSlide
        } else {
            throw PPTLayoutExtractionError.masterSlideExtractionFailed
        }
    }
    
    /// 解析布局XML
    func parseLayout(data: Data, relationships: [String: String]) throws -> PPTLayoutExtractor.PPTLayout {
        let parser = XMLParser(data: data)
        let layoutHandler = LayoutXMLHandler(relationships: relationships)
        parser.delegate = layoutHandler
        
        if parser.parse() {
            return layoutHandler.layout
        } else {
            throw PPTLayoutExtractionError.layoutExtractionFailed
        }
    }
    
    /// 解析关系XML
    func parseRelationships(data: Data) throws -> [String: String] {
        let parser = XMLParser(data: data)
        let relationshipsHandler = RelationshipsXMLHandler()
        parser.delegate = relationshipsHandler
        
        if parser.parse() {
            return relationshipsHandler.relationships
        } else {
            throw PPTLayoutExtractionError.xmlParsingFailed
        }
    }
    
    // MARK: - XML处理器类
    
    /// 处理演示文稿XML
    class PresentationXMLHandler: NSObject, XMLParserDelegate {
        var slideSize = CGSize(width: 960, height: 540)
        var otherInfo: [String: Any] = [:]
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            // 解析幻灯片尺寸
            if elementName == "p:sldSz" {
                if let cx = attributeDict["cx"], let cy = attributeDict["cy"] {
                    if let cxVal = Double(cx), let cyVal = Double(cy) {
                        // 从EMU转换为点 (1 英寸 = 914400 EMU, 1 英寸 = 72 点)
                        let width = cxVal * 72 / 914400
                        let height = cyVal * 72 / 914400
                        slideSize = CGSize(width: width, height: height)
                    }
                }
            }
        }
    }
    
    /// 处理主题XML
    class ThemeXMLHandler: NSObject, XMLParserDelegate {
        var theme = PPTLayoutExtractor.PPTTheme()
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            // 解析主题名称
            if elementName == "a:theme" {
                if let name = attributeDict["name"] {
                    theme.name = name
                }
            }
            
            // 解析颜色方案
            else if elementName == "a:clrScheme" {
                if let name = attributeDict["name"] {
                    // 可以设置颜色方案名称
                }
            }
            
            // 解析字体方案
            else if elementName == "a:fontScheme" {
                if let name = attributeDict["name"] {
                    // 可以设置字体方案名称
                }
            }
            
            // 在这里可以添加对颜色和字体的详细解析
            // ...
        }
    }
    
    /// 处理母版XML
    class MasterSlideXMLHandler: NSObject, XMLParserDelegate {
        var masterSlide = PPTLayoutExtractor.PPTMasterSlide()
        var relationships: [String: String]
        
        init(relationships: [String: String]) {
            self.relationships = relationships
            super.init()
        }
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            // 解析母版ID
            if elementName == "p:sldMaster" {
                if let id = attributeDict["id"] {
                    masterSlide.id = id
                }
            }
            
            // 解析占位符信息
            else if elementName == "p:sp" {
                // 开始解析形状元素
                // 在实际实现中，需要收集更多信息来完成解析
            }
            
            // 在这里可以添加对背景、元素等的详细解析
            // ...
        }
    }
    
    /// 处理布局XML
    class LayoutXMLHandler: NSObject, XMLParserDelegate {
        var layout = PPTLayoutExtractor.PPTLayout()
        var relationships: [String: String]
        
        init(relationships: [String: String]) {
            self.relationships = relationships
            super.init()
        }
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            // 解析布局ID和类型
            if elementName == "p:sldLayout" {
                if let id = attributeDict["id"] {
                    layout.id = id
                }
                
                if let type = attributeDict["type"] {
                    // 设置布局类型
                    switch type {
                    case "title":
                        layout.type = .title
                    case "obj":
                        layout.type = .titleAndContent
                    case "sectTitle":
                        layout.type = .sectionHeader
                                                
                    // 更多类型映射...
                    
                    default:
                        layout.type = .custom
                    }
                }
            }
            
            // 解析母版引用
            else if elementName == "p:cSld" {
                if let masterIdRef = attributeDict["masterIdRef"] {
                    layout.masterSlideId = masterIdRef
                }
            }
            
            // 解析占位符
            else if elementName == "p:sp" {
                // 开始解析形状元素
                // 在实际实现中，需要收集更多信息来完成解析
            }
            
            // 在这里可以添加对背景、元素等的详细解析
            // ...
        }
    }
    
    /// 处理关系XML
    class RelationshipsXMLHandler: NSObject, XMLParserDelegate {
        var relationships: [String: String] = [:]
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            if elementName == "Relationship" {
                if let id = attributeDict["Id"], let target = attributeDict["Target"] {
                    relationships[id] = target
                }
            }
        }
    }
}

// MARK: - 媒体资源管理器

/// 管理PPT中的媒体资源
class PPTMediaManager {
    private var mediaCache: [String: URL] = [:]
    private var baseURL: URL?
    
    /// 初始化媒体管理器
    func initialize(with baseURL: URL) {
        self.baseURL = baseURL
    }
    
    /// 处理媒体目录
    func processMediaDirectory(_ directoryURL: URL) throws {
        let mediaFiles = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        
        for mediaURL in mediaFiles {
            let filename = mediaURL.lastPathComponent
            mediaCache[filename] = mediaURL
        }
    }
    
    /// 获取媒体文件URL
    func getMediaURL(forFilename filename: String) -> URL? {
        return mediaCache[filename]
    }
}

/// 从PPT文件提取布局和样式的公共接口扩展
public extension PPTLayoutExtractor {
    
    /// 从PPT文件提取布局和样式
    /// - Parameter fileURL: PPT文件的URL
    /// - Returns: 提取的模板信息
    /// - Throws: 提取过程中的错误
    static func extractFrom(fileURL: URL) async throws -> PPTTemplateInfo {
        let extractor = PPTLayoutExtractor(pptFileURL: fileURL)
        return try await extractor.extractLayoutAndStyle()
    }
    
    /// 从PPT文件提取预览图
    /// - Parameters:
    ///   - fileURL: PPT文件的URL
    ///   - maxWidth: 预览图最大宽度
    /// - Returns: 预览图图像
    /// - Throws: 提取过程中的错误
    static func extractPreviewImageFrom(fileURL: URL, maxWidth: CGFloat = 400) async throws -> UIImage? {
        // 创建一个临时目录
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
        
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        
        // 解压PPT文件
        try FileManager.default.unzipItem(at: fileURL, to: tempDirectory)
        
        // 查找第一张幻灯片的图片
        let slidesDirectory = tempDirectory.appendingPathComponent("ppt/slides")
        if FileManager.default.fileExists(atPath: slidesDirectory.path) {
            let slideFiles = try FileManager.default.contentsOfDirectory(at: slidesDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "xml" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            if let firstSlideFile = slideFiles.first {
                // 这里可以实现复杂的解析和渲染逻辑
                // 在实际应用中，可能需要使用第三方库来渲染幻灯片
                
                // 暂时返回占位图像
                let size = CGSize(width: maxWidth, height: maxWidth * 9 / 16) // 16:9比例
                let renderer = UIGraphicsImageRenderer(size: size)
                
                return renderer.image { ctx in
                    // 填充背景
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))
                    
                    // 绘制边框
                    UIColor.gray.setStroke()
                    ctx.stroke(CGRect(origin: .zero, size: size))
                    
                    // 绘制文本
                    let text = "预览图"
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 20),
                        .foregroundColor: UIColor.black
                    ]
                    
                    let textSize = text.size(withAttributes: attributes)
                    let textRect = CGRect(
                        x: (size.width - textSize.width) / 2,
                        y: (size.height - textSize.height) / 2,
                        width: textSize.width,
                        height: textSize.height
                    )
                    
                    text.draw(in: textRect, withAttributes: attributes)
                }
            }
        }
        
        return nil
    }
}
