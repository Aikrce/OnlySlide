import Foundation
import SwiftUI
import Combine

/// 幻灯片内容模型
struct SlideContent: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var content: String
    var style: SlideStyle
    var notes: String = ""
    var order: Int = 0
    var isHidden: Bool = false
    
    init(id: UUID = UUID(), 
         title: String, 
         content: String, 
         style: SlideStyle = .standard, 
         notes: String = "", 
         order: Int = 0, 
         isHidden: Bool = false) {
        self.id = id
        self.title = title
        self.content = content
        self.style = style
        self.notes = notes
        self.order = order
        self.isHidden = isHidden
    }
}

/// 幻灯片样式
struct SlideStyle: Codable {
    var backgroundColor: Color
    var titleColor: Color
    var contentColor: Color
    var cornerRadius: CGFloat
    var titleFont: Font
    var contentFont: Font
    
    // 标准样式
    static let standard = SlideStyle(
        backgroundColor: Color.white,
        titleColor: Color.black,
        contentColor: Color.black,
        cornerRadius: 0,
        titleFont: .system(size: 36, weight: .bold),
        contentFont: .system(size: 24)
    )
    
    // 现代样式
    static let modern = SlideStyle(
        backgroundColor: Color.blue.opacity(0.1),
        titleColor: Color.blue,
        contentColor: Color.black,
        cornerRadius: 8,
        titleFont: .system(size: 36, weight: .semibold),
        contentFont: .system(size: 24)
    )
    
    // 轻盈样式
    static let light = SlideStyle(
        backgroundColor: Color.gray.opacity(0.05),
        titleColor: Color.purple,
        contentColor: Color.black,
        cornerRadius: 12,
        titleFont: .system(size: 36, weight: .light),
        contentFont: .system(size: 24, weight: .light)
    )
}

// 使Color可编码
extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let r = try container.decode(Double.self, forKey: .red)
        let g = try container.decode(Double.self, forKey: .green)
        let b = try container.decode(Double.self, forKey: .blue)
        let o = try container.decode(Double.self, forKey: .opacity)
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: o)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var o: CGFloat = 0
        
        #if os(macOS)
        NSColor(self).getRed(&r, green: &g, blue: &b, alpha: &o)
        #else
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &o)
        #endif
        
        try container.encode(r, forKey: .red)
        try container.encode(g, forKey: .green)
        try container.encode(b, forKey: .blue)
        try container.encode(o, forKey: .opacity)
    }
}

// 使Font可编码
extension Font: Codable {
    enum CodingKeys: String, CodingKey {
        case size, weight, design
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let size = try container.decode(Double.self, forKey: .size)
        
        // 默认采用system字体
        self = Font.system(size: size)
    }
    
    public func encode(to encoder: Encoder) throws {
        // 由于Font是不透明类型，我们只能粗略地编码基本信息
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // 默认大小为14
        try container.encode(14.0, forKey: .size)
    }
}

/// 幻灯片编辑视图模型
class SlideEditorViewModel: ObservableObject {
    // 幻灯片数据
    @Published var slides: [SlideContent]
    @Published var currentSlideIndex: Int = 0
    @Published var documentTitle: String = "未命名演示文稿"
    @Published var zoomLevel: CGFloat = 1.0
    @Published var isEditing: Bool = false
    @Published var showGrid: Bool = false
    @Published var showRulers: Bool = false
    
    // 当前选中的幻灯片
    var currentSlide: SlideContent {
        get {
            if slides.isEmpty || currentSlideIndex >= slides.count {
                return SlideContent(
                    title: "空白幻灯片", 
                    content: "添加内容", 
                    style: .standard
                )
            }
            return slides[currentSlideIndex]
        }
        set {
            if !slides.isEmpty && currentSlideIndex < slides.count {
                slides[currentSlideIndex] = newValue
            }
        }
    }
    
    // 取消订阅存储
    private var cancellables = Set<AnyCancellable>()
    
    init(slides: [SlideContent] = [], title: String = "未命名演示文稿") {
        self.slides = slides
        self.documentTitle = title
        
        // 如果没有幻灯片，添加一个默认幻灯片
        if slides.isEmpty {
            self.slides = [
                SlideContent(
                    title: "欢迎使用OnlySlide", 
                    content: "创建专业演示文稿的最佳工具", 
                    style: .standard
                )
            ]
        }
        
        // 监听幻灯片变化
        $slides
            .dropFirst()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // 添加新幻灯片
    func addNewSlide() {
        let newSlide = SlideContent(
            title: "新幻灯片",
            content: "添加内容",
            style: currentSlide.style, // 使用当前幻灯片样式
            order: slides.count
        )
        
        // 在当前幻灯片后添加
        if currentSlideIndex < slides.count - 1 {
            slides.insert(newSlide, at: currentSlideIndex + 1)
        } else {
            slides.append(newSlide)
        }
        
        // 切换到新幻灯片
        currentSlideIndex = slides.count - 1
    }
    
    // 删除当前幻灯片
    func deleteCurrentSlide() {
        guard slides.count > 1 else { return } // 保留至少一张幻灯片
        
        slides.remove(at: currentSlideIndex)
        
        // 如果删除的是最后一张，选择前一张
        if currentSlideIndex >= slides.count {
            currentSlideIndex = slides.count - 1
        }
    }
    
    // 移动到下一张幻灯片
    func nextSlide() {
        if currentSlideIndex < slides.count - 1 {
            currentSlideIndex += 1
        }
    }
    
    // 移动到上一张幻灯片
    func previousSlide() {
        if currentSlideIndex > 0 {
            currentSlideIndex -= 1
        }
    }
    
    // 移动到指定幻灯片
    func moveToSlide(at index: Int) {
        guard index >= 0 && index < slides.count else { return }
        currentSlideIndex = index
    }
    
    // 移动幻灯片顺序
    func moveSlide(from source: Int, to destination: Int) {
        guard source >= 0 && source < slides.count,
              destination >= 0 && destination < slides.count else { return }
        
        let slide = slides.remove(at: source)
        slides.insert(slide, at: destination)
        
        // 更新顺序
        for (index, var slide) in slides.enumerated() {
            slide.order = index
            slides[index] = slide
        }
        
        // 更新当前索引
        if source == currentSlideIndex {
            currentSlideIndex = destination
        }
    }
    
    // 复制当前幻灯片
    func duplicateCurrentSlide() {
        var newSlide = currentSlide
        newSlide.id = UUID() // 新ID
        newSlide.title += " (副本)"
        
        // 在当前幻灯片后添加
        slides.insert(newSlide, at: currentSlideIndex + 1)
        
        // 切换到新副本
        currentSlideIndex += 1
    }
    
    // 更新幻灯片标题
    func updateSlideTitle(_ title: String) {
        var slide = currentSlide
        slide.title = title
        currentSlide = slide
    }
    
    // 更新幻灯片内容
    func updateSlideContent(_ content: String) {
        var slide = currentSlide
        slide.content = content
        currentSlide = slide
    }
    
    // 更新幻灯片备注
    func updateSlideNotes(_ notes: String) {
        var slide = currentSlide
        slide.notes = notes
        currentSlide = slide
    }
    
    // 更新幻灯片样式
    func updateSlideStyle(_ style: SlideStyle) {
        var slide = currentSlide
        slide.style = style
        currentSlide = slide
    }
} 