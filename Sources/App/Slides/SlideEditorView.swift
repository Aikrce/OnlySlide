// SlideEditorView.swift
// 幻灯片编辑器自适应视图

import SwiftUI

// MARK: - 幻灯片样式
public struct SlideStyle {
    public var backgroundColor: Color
    public var titleFont: Font
    public var contentFont: Font
    public var titleColor: Color
    public var contentColor: Color
    public var cornerRadius: CGFloat
    
    public static let standard = SlideStyle(
        backgroundColor: .white,
        titleFont: .system(size: 32, weight: .bold),
        contentFont: .system(size: 24),
        titleColor: .black,
        contentColor: .black,
        cornerRadius: 0
    )
    
    public static let modern = SlideStyle(
        backgroundColor: Color(red: 0.15, green: 0.15, blue: 0.2),
        titleFont: .system(size: 32, weight: .bold),
        contentFont: .system(size: 24),
        titleColor: .white,
        contentColor: Color(white: 0.9),
        cornerRadius: 10
    )
    
    public static let light = SlideStyle(
        backgroundColor: Color(red: 0.95, green: 0.95, blue: 0.97),
        titleFont: .system(size: 32, weight: .semibold),
        contentFont: .system(size: 24),
        titleColor: Color(red: 0.1, green: 0.1, blue: 0.1),
        contentColor: Color(red: 0.2, green: 0.2, blue: 0.2),
        cornerRadius: 8
    )
}

// MARK: - 幻灯片内容
public struct SlideContent: Identifiable {
    public let id = UUID()
    public var title: String
    public var content: String
    public var style: SlideStyle
    
    public init(title: String, content: String, style: SlideStyle = .standard) {
        self.title = title
        self.content = content
        self.style = style
    }
}

// MARK: - 幻灯片编辑器视图模型
public class SlideEditorViewModel: ObservableObject {
    @Published public var slides: [SlideContent]
    @Published public var currentSlideIndex: Int
    @Published public var zoomLevel: Double
    @Published public var isEditing: Bool
    @Published public var documentTitle: String
    
    public init(
        slides: [SlideContent] = [],
        currentSlideIndex: Int = 0,
        zoomLevel: Double = 1.0,
        isEditing: Bool = false,
        documentTitle: String = "未命名演示文稿"
    ) {
        self.slides = slides.isEmpty ? [SlideContent(title: "幻灯片标题", content: "在此处添加内容")] : slides
        self.currentSlideIndex = currentSlideIndex
        self.zoomLevel = zoomLevel
        self.isEditing = isEditing
        self.documentTitle = documentTitle
    }
    
    public var currentSlide: SlideContent {
        get {
            guard currentSlideIndex < slides.count else {
                return SlideContent(title: "错误", content: "幻灯片不存在")
            }
            return slides[currentSlideIndex]
        }
        set {
            guard currentSlideIndex < slides.count else { return }
            slides[currentSlideIndex] = newValue
        }
    }
    
    // 添加新幻灯片
    public func addNewSlide() {
        let newSlide = SlideContent(
            title: "新幻灯片",
            content: "在此处添加内容",
            style: currentSlide.style
        )
        slides.append(newSlide)
        currentSlideIndex = slides.count - 1
    }
    
    // 删除当前幻灯片
    public func deleteCurrentSlide() {
        guard slides.count > 1 else { return }
        slides.remove(at: currentSlideIndex)
        if currentSlideIndex >= slides.count {
            currentSlideIndex = slides.count - 1
        }
    }
    
    // 移动到下一张幻灯片
    public func nextSlide() {
        if currentSlideIndex < slides.count - 1 {
            currentSlideIndex += 1
        }
    }
    
    // 移动到上一张幻灯片
    public func previousSlide() {
        if currentSlideIndex > 0 {
            currentSlideIndex -= 1
        }
    }
}

// MARK: - 幻灯片编辑器自适应视图
public struct SlideEditorView: AdaptiveView {
    @ObservedObject private var viewModel: SlideEditorViewModel
    
    public init(viewModel: SlideEditorViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - macOS版本
    public func macView() -> some View {
        HSplitView {
            // 左侧幻灯片缩略图列表
            VStack {
                Text("幻灯片清单")
                    .font(.headline)
                    .padding()
                
                List(Array(viewModel.slides.enumerated()), id: \.element.id) { index, slide in
                    slideThumbView(slide: slide, index: index)
                        .padding(.vertical, 8)
                        .listRowInsets(EdgeInsets())
                        .background(index == viewModel.currentSlideIndex ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                        .onTapGesture {
                            viewModel.currentSlideIndex = index
                        }
                }
                
                // 底部控制区
                HStack {
                    Button(action: {
                        viewModel.addNewSlide()
                    }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.deleteCurrentSlide()
                    }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.slides.count <= 1)
                    
                    Spacer()
                    
                    // macOS特有的缩放控制
                    HStack {
                        Text("缩放:")
                        Slider(value: $viewModel.zoomLevel, in: 0.5...2.0)
                            .frame(width: 80)
                        Text("\(Int(viewModel.zoomLevel * 100))%")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .padding()
            }
            .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            
            // 右侧主编辑区
            VStack {
                // 顶部工具栏
                AdaptiveToolbar(position: .top) {
                    HStack {
                        TextField("演示文稿标题", text: $viewModel.documentTitle)
                            .font(.headline)
                            .textFieldStyle(.plain)
                        
                        Spacer()
                        
                        Button("格式") {
                            // 格式操作
                        }
                        .buttonStyle(.borderless)
                        
                        Button("插入") {
                            // 插入操作
                        }
                        .buttonStyle(.borderless)
                        
                        Button("演示") {
                            // 演示操作
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                // 幻灯片编辑区
                ZStack {
                    // 背景
                    Color(.windowBackgroundColor)
                    
                    // 幻灯片内容
                    slideView(slide: viewModel.currentSlide)
                        .scaleEffect(viewModel.zoomLevel)
                        .frame(width: 800, height: 450)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 底部工具栏
                AdaptiveToolbar(position: .bottom) {
                    HStack {
                        Button(action: {
                            viewModel.previousSlide()
                        }) {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.currentSlideIndex <= 0)
                        
                        Text("\(viewModel.currentSlideIndex + 1) / \(viewModel.slides.count)")
                        
                        Button(action: {
                            viewModel.nextSlide()
                        }) {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.currentSlideIndex >= viewModel.slides.count - 1)
                        
                        Spacer()
                        
                        AdaptiveButton("新建幻灯片", icon: "plus", style: .secondary) {
                            viewModel.addNewSlide()
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.addNewSlide()
                }) {
                    Label("新建幻灯片", systemImage: "plus")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    // 开始演示
                }) {
                    Label("演示", systemImage: "play.fill")
                }
            }
        }
    }
    
    // MARK: - iOS版本
    public func iosView() -> some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            AdaptiveToolbar(position: .top) {
                HStack {
                    Text(viewModel.documentTitle)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.isEditing.toggle()
                    }) {
                        Text(viewModel.isEditing ? "完成" : "编辑")
                    }
                }
            }
            
            // 幻灯片编辑区
            ZStack {
                // 背景
                Color(UIColor.systemGroupedBackground)
                
                // 幻灯片内容
                slideView(slide: viewModel.currentSlide)
                    .scaleEffect(viewModel.zoomLevel)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 底部工具栏 - iOS特有
            AdaptiveToolbar(position: .bottom) {
                HStack(spacing: 20) {
                    Button(action: {
                        // 插入操作
                    }) {
                        VStack {
                            Image(systemName: "plus.square")
                            Text("插入").font(.caption)
                        }
                    }
                    
                    Button(action: {
                        // 格式操作
                    }) {
                        VStack {
                            Image(systemName: "paintbrush")
                            Text("格式").font(.caption)
                        }
                    }
                    
                    Button(action: {
                        // 演示操作
                    }) {
                        VStack {
                            Image(systemName: "play.fill")
                            Text("演示").font(.caption)
                        }
                    }
                    
                    Spacer()
                    
                    HStack {
                        Button(action: {
                            viewModel.previousSlide()
                        }) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(viewModel.currentSlideIndex <= 0)
                        
                        Text("\(viewModel.currentSlideIndex + 1)/\(viewModel.slides.count)")
                            .frame(width: 40, alignment: .center)
                        
                        Button(action: {
                            viewModel.nextSlide()
                        }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(viewModel.currentSlideIndex >= viewModel.slides.count - 1)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isEditing) {
            // 幻灯片管理页面
            NavigationView {
                List {
                    ForEach(Array(viewModel.slides.enumerated()), id: \.element.id) { index, slide in
                        slideThumbView(slide: slide, index: index)
                            .padding(.vertical, 8)
                            .background(index == viewModel.currentSlideIndex ? Color.blue.opacity(0.2) : Color.clear)
                            .cornerRadius(4)
                            .onTapGesture {
                                viewModel.currentSlideIndex = index
                                viewModel.isEditing = false
                            }
                    }
                    .onDelete { indexSet in
                        guard viewModel.slides.count > 1 else { return }
                        viewModel.slides.remove(atOffsets: indexSet)
                        if viewModel.currentSlideIndex >= viewModel.slides.count {
                            viewModel.currentSlideIndex = viewModel.slides.count - 1
                        }
                    }
                }
                .navigationTitle("幻灯片管理")
                .navigationBarItems(
                    leading: Button("取消") {
                        viewModel.isEditing = false
                    },
                    trailing: Button(action: {
                        viewModel.addNewSlide()
                    }) {
                        Image(systemName: "plus")
                    }
                )
            }
        }
    }
    
    // MARK: - 共享视图组件
    
    // 幻灯片视图
    private func slideView(slide: SlideContent) -> some View {
        VStack(alignment: .leading) {
            Text(slide.title)
                .font(slide.style.titleFont)
                .foregroundColor(slide.style.titleColor)
                .padding(.bottom, 20)
            
            Text(slide.content)
                .font(slide.style.contentFont)
                .foregroundColor(slide.style.contentColor)
        }
        .padding(40)
        .frame(width: 800, height: 450)
        .background(slide.style.backgroundColor)
        .cornerRadius(slide.style.cornerRadius)
    }
    
    // 幻灯片缩略图
    private func slideThumbView(slide: SlideContent, index: Int) -> some View {
        VStack(alignment: .leading) {
            Text(slide.title)
                .font(.system(size: 10))
                .foregroundColor(slide.style.titleColor)
                .lineLimit(1)
                .padding(.bottom, 4)
            
            Text(slide.content)
                .font(.system(size: 8))
                .foregroundColor(slide.style.contentColor)
                .lineLimit(2)
        }
        .padding(10)
        .frame(height: 60)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(slide.style.backgroundColor)
        .cornerRadius(slide.style.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: slide.style.cornerRadius)
                .stroke(index == viewModel.currentSlideIndex ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - 适配视图协议
public protocol AdaptiveView {
    associatedtype MacContent: View
    associatedtype IOSContent: View
    
    @ViewBuilder
    func macView() -> MacContent
    
    @ViewBuilder
    func iosView() -> IOSContent
}

// MARK: - 适配视图包装器
public struct AdaptiveViewWrapper<Content: AdaptiveView>: View {
    private let content: Content
    
    public init(content: Content) {
        self.content = content
    }
    
    public var body: some View {
        #if os(macOS)
        content.macView()
        #else
        content.iosView()
        #endif
    }
}

// MARK: - 预览
#Preview {
    let viewModel = SlideEditorViewModel(
        slides: [
            SlideContent(title: "欢迎使用OnlySlide", content: "创建专业演示文稿的最佳工具"),
            SlideContent(title: "简洁设计", content: "专注于内容，而不是复杂的界面", style: .modern),
            SlideContent(title: "跨平台", content: "在macOS和iOS上享受一致的体验", style: .light)
        ]
    )
    
    return AdaptiveViewWrapper(content: SlideEditorView(viewModel: viewModel))
        .frame(minWidth: 800, minHeight: 600)
} 