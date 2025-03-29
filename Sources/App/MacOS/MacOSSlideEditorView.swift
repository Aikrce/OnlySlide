#if os(macOS)
// MacOSSlideEditorView.swift
// macOS特有的幻灯片编辑器视图，集成导航器面板和工具栏

import SwiftUI
import AppKit

// MARK: - macOS幻灯片编辑器视图
public struct MacOSSlideEditorView: View {
    @ObservedObject private var viewModel: SlideEditorViewModel
    @ObservedObject private var documentManager: SlideDocumentManager
    @State private var showNavigator: Bool = true
    @State private var showInspector: Bool = true
    @State private var showFormatPanel: Bool = false
    @State private var showColorPanel: Bool = false
    @State private var selectedStyleIndex: Int = 0
    
    private let availableStyles: [SlideStyle] = [.standard, .modern, .light]
    
    public init(viewModel: SlideEditorViewModel, documentManager: SlideDocumentManager) {
        self.viewModel = viewModel
        self.documentManager = documentManager
    }
    
    public var body: some View {
        NavigationView {
            // 左侧导航器
            if showNavigator {
                MacOSNavigatorPanel(viewModel: viewModel)
                    .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            }
            
            // 主编辑区
            VStack(spacing: 0) {
                // 工具栏
                macOSToolbar
                
                // 编辑区
                ZStack {
                    // 背景
                    Color(.windowBackgroundColor)
                    
                    // 幻灯片内容
                    slideView(slide: viewModel.currentSlide)
                        .scaleEffect(viewModel.zoomLevel)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 底部状态栏
                macOSStatusBar
            }
            
            // 右侧检查器
            if showInspector {
                macOSInspector
                    .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            }
        }
        .toolbar {
            // 显示/隐藏导航器
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    showNavigator.toggle()
                }) {
                    Image(systemName: showNavigator ? "sidebar.left" : "sidebar.left.fill")
                }
                .help(showNavigator ? "隐藏导航器" : "显示导航器")
            }
            
            // 保存按钮
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    saveDocument()
                }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("保存演示文稿")
                .disabled(documentManager.isDocumentSaved)
            }
            
            // 添加幻灯片
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.addNewSlide()
                }) {
                    Image(systemName: "plus.square")
                }
                .help("添加幻灯片")
            }
            
            // 演示按钮
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    startPresentation()
                }) {
                    Image(systemName: "play.fill")
                }
                .help("开始演示")
            }
            
            // 显示/隐藏检查器
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showInspector.toggle()
                }) {
                    Image(systemName: showInspector ? "sidebar.right" : "sidebar.right.fill")
                }
                .help(showInspector ? "隐藏检查器" : "显示检查器")
            }
        }
        .navigationTitle(viewModel.documentTitle)
        .navigationSubtitle(documentManager.isDocumentSaved ? "" : "已修改")
        .sheet(isPresented: $showFormatPanel) {
            formatPanel
        }
    }
    
    // MARK: - 工具栏
    private var macOSToolbar: some View {
        AdaptiveToolbar(position: .top) {
            HStack {
                // 样式选择
                Picker("样式", selection: $selectedStyleIndex) {
                    Text("标准").tag(0)
                    Text("现代").tag(1)
                    Text("轻盈").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                .onChange(of: selectedStyleIndex) { newValue in
                    // 更新当前幻灯片样式
                    var currentSlide = viewModel.currentSlide
                    currentSlide.style = availableStyles[newValue]
                    viewModel.currentSlide = currentSlide
                }
                
                Divider()
                    .frame(height: 20)
                
                // 字体按钮
                Button(action: {
                    NSFontManager.shared.orderFrontFontPanel(nil)
                }) {
                    Image(systemName: "textformat")
                }
                .buttonStyle(.borderless)
                .help("字体选项")
                
                // 颜色按钮
                Button(action: {
                    if let panel = NSColorPanel.shared {
                        panel.isVisible = true
                        panel.isContinuous = true
                        showColorPanel = true
                    }
                }) {
                    Image(systemName: "paintpalette")
                }
                .buttonStyle(.borderless)
                .help("颜色选项")
                
                // 对齐按钮
                Button(action: {
                    // 左对齐
                }) {
                    Image(systemName: "text.alignleft")
                }
                .buttonStyle(.borderless)
                .help("左对齐")
                
                Button(action: {
                    // 居中对齐
                }) {
                    Image(systemName: "text.aligncenter")
                }
                .buttonStyle(.borderless)
                .help("居中对齐")
                
                Button(action: {
                    // 右对齐
                }) {
                    Image(systemName: "text.alignright")
                }
                .buttonStyle(.borderless)
                .help("右对齐")
                
                Divider()
                    .frame(height: 20)
                
                // 格式化面板
                Button(action: {
                    showFormatPanel = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)
                .help("格式选项")
                
                // 添加内容生成器按钮
                Button(action: {
                    showContentGenerator()
                }) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .help("内容生成器")
                
                Divider()
                    .frame(height: 20)
                
                Spacer()
                
                // 缩放控制
                HStack {
                    Button(action: {
                        viewModel.zoomLevel = max(0.5, viewModel.zoomLevel - 0.1)
                    }) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .help("缩小")
                    
                    Text("\(Int(viewModel.zoomLevel * 100))%")
                        .frame(width: 50, alignment: .center)
                    
                    Button(action: {
                        viewModel.zoomLevel = min(2.0, viewModel.zoomLevel + 0.1)
                    }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("放大")
                }
            }
        }
        .padding(10)
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - 状态栏
    private var macOSStatusBar: some View {
        HStack {
            // 幻灯片导航
            Button(action: {
                viewModel.previousSlide()
            }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.currentSlideIndex <= 0)
            
            Text("\(viewModel.currentSlideIndex + 1) / \(viewModel.slides.count)")
                .font(.system(size: 12))
                .frame(width: 60)
            
            Button(action: {
                viewModel.nextSlide()
            }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.currentSlideIndex >= viewModel.slides.count - 1)
            
            Spacer()
            
            // 文档状态
            DocumentStatusView(documentManager: documentManager)
            
            Spacer()
            
            // 最后修改时间
            Text("最后修改：\(formatDate(documentManager.currentDocument.lastModified))")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.windowBackgroundColor))
        .overlay(Divider(), alignment: .top)
    }
    
    // MARK: - 检查器面板
    private var macOSInspector: some View {
        VStack(spacing: 0) {
            // 检查器标题
            Text("幻灯片检查器")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // 样式选择
            VStack(alignment: .leading, spacing: 12) {
                Text("幻灯片样式")
                    .font(.subheadline)
                    .bold()
                
                ForEach(0..<availableStyles.count, id: \.self) { index in
                    stylePreview(style: availableStyles[index], name: ["标准", "现代", "轻盈"][index], isSelected: selectedStyleIndex == index)
                        .onTapGesture {
                            selectedStyleIndex = index
                            
                            // 更新当前幻灯片样式
                            var currentSlide = viewModel.currentSlide
                            currentSlide.style = availableStyles[index]
                            viewModel.currentSlide = currentSlide
                        }
                }
            }
            .padding()
            
            Divider()
            
            // 当前幻灯片属性
            VStack(alignment: .leading, spacing: 12) {
                Text("幻灯片属性")
                    .font(.subheadline)
                    .bold()
                
                // 标题
                VStack(alignment: .leading, spacing: 4) {
                    Text("标题")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("幻灯片标题", text: Binding(
                        get: { viewModel.currentSlide.title },
                        set: { newValue in
                            var slide = viewModel.currentSlide
                            slide.title = newValue
                            viewModel.currentSlide = slide
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                
                // 内容
                VStack(alignment: .leading, spacing: 4) {
                    Text("内容")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: Binding(
                        get: { viewModel.currentSlide.content },
                        set: { newValue in
                            var slide = viewModel.currentSlide
                            slide.content = newValue
                            viewModel.currentSlide = slide
                        }
                    ))
                    .font(.body)
                    .frame(height: 100)
                    .border(Color.gray.opacity(0.3), width: 1)
                }
            }
            .padding()
            
            Spacer()
        }
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - 格式面板
    private var formatPanel: some View {
        VStack {
            Text("格式选项")
                .font(.title2)
                .bold()
                .padding()
            
            // 样式选择
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("幻灯片主题")
                        .font(.headline)
                    
                    HStack {
                        ForEach(0..<availableStyles.count, id: \.self) { index in
                            stylePreview(style: availableStyles[index], name: ["标准", "现代", "轻盈"][index], isSelected: selectedStyleIndex == index)
                                .onTapGesture {
                                    selectedStyleIndex = index
                                    
                                    // 更新当前幻灯片样式
                                    var currentSlide = viewModel.currentSlide
                                    currentSlide.style = availableStyles[index]
                                    viewModel.currentSlide = currentSlide
                                }
                        }
                    }
                }
                
                Divider()
                
                // 幻灯片设置
                VStack(alignment: .leading, spacing: 8) {
                    Text("幻灯片设置")
                        .font(.headline)
                    
                    // 过渡效果
                    HStack {
                        Text("过渡效果:")
                            .frame(width: 80, alignment: .leading)
                        
                        Picker("过渡效果", selection: .constant(0)) {
                            Text("无").tag(0)
                            Text("淡入淡出").tag(1)
                            Text("滑动").tag(2)
                            Text("缩放").tag(3)
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // 自动播放
                    HStack {
                        Text("自动播放:")
                            .frame(width: 80, alignment: .leading)
                        
                        Picker("自动播放", selection: .constant(0)) {
                            Text("关闭").tag(0)
                            Text("3秒").tag(3)
                            Text("5秒").tag(5)
                            Text("10秒").tag(10)
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .padding()
            
            Divider()
            
            // 确认按钮
            Button("完成") {
                showFormatPanel = false
            }
            .keyboardShortcut(.defaultAction)
            .padding()
        }
        .frame(width: 500, height: 400)
    }
    
    // MARK: - 幻灯片视图
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
    
    // 样式预览
    private func stylePreview(style: SlideStyle, name: String, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            // 预览
            VStack(alignment: .leading, spacing: 4) {
                Text("示例标题")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(style.titleColor)
                
                Text("示例内容")
                    .font(.system(size: 6))
                    .foregroundColor(style.contentColor)
            }
            .padding(8)
            .frame(width: 80, height: 50)
            .background(style.backgroundColor)
            .cornerRadius(style.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            
            // 名称
            Text(name)
                .font(.caption)
                .foregroundColor(isSelected ? .blue : .primary)
        }
    }
    
    // MARK: - 辅助方法
    
    // 保存文档
    private func saveDocument() {
        Task {
            // 先从视图模型更新文档
            documentManager.updateFromViewModel(viewModel)
            
            // 保存文档
            _ = await documentManager.saveDocument()
        }
    }
    
    // 开始演示
    private func startPresentation() {
        let launcher = PresentationLauncher(viewModel: viewModel)
        launcher.startPresentation()
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - 内容生成器
    private func showContentGenerator() {
        let contentGeneratorManager = ContentGeneratorWindowManager(viewModel: viewModel, documentManager: documentManager)
        contentGeneratorManager.showContentGenerator()
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
    
    let documentManager = SlideDocumentManager()
    
    return MacOSSlideEditorView(viewModel: viewModel, documentManager: documentManager)
        .frame(width: 1200, height: 800)
}
#endif 