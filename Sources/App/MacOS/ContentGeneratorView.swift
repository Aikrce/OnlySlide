#if os(macOS)
// ContentGeneratorView.swift
// 内容生成器 - 分析文本并自动生成幻灯片

import SwiftUI
import AppKit
import NaturalLanguage

// MARK: - 内容生成器视图
public struct ContentGeneratorView: View {
    @ObservedObject private var viewModel: SlideEditorViewModel
    @ObservedObject private var documentManager: SlideDocumentManager
    
    @State private var inputText: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var analysisResult: [SlideAnalysisItem] = []
    @State private var selectedTemplate: SlideStyle = .standard
    @State private var generatedSlides: [SlideContent] = []
    @State private var generationError: String? = nil
    @State private var showPreview: Bool = false
    @State private var selectedPreviewIndex: Int = 0
    @State private var selectedMaxSlidesCount: Int = 10
    @State private var isCustomizing: Bool = false
    @State private var customizingSlideIndex: Int = 0
    
    @Environment(\.presentationMode) private var presentationMode
    
    public init(viewModel: SlideEditorViewModel, documentManager: SlideDocumentManager) {
        self.viewModel = viewModel
        self.documentManager = documentManager
    }
    
    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 顶部工具栏
                HStack {
                    Text("内容生成器")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("关闭") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                
                if isCustomizing {
                    // 自定义幻灯片视图
                    slideCustomizationView
                } else if showPreview {
                    // 幻灯片预览视图
                    slidePreviewView
                } else {
                    // 主内容区域
                    HSplitView {
                        // 左侧文本输入区域
                        VStack(alignment: .leading, spacing: 12) {
                            Text("输入或粘贴文本内容")
                                .font(.headline)
                            
                            TextEditor(text: $inputText)
                                .font(.system(size: 14))
                                .padding(8)
                                .background(Color(.textBackgroundColor))
                                .cornerRadius(8)
                                .frame(minHeight: 200)
                            
                            // 分析控制区域
                            HStack {
                                Button(action: {
                                    clearInput()
                                }) {
                                    Text("清除")
                                }
                                .disabled(inputText.isEmpty || isAnalyzing)
                                
                                Button(action: {
                                    importFromFile()
                                }) {
                                    Text("从文件导入")
                                }
                                .disabled(isAnalyzing)
                                
                                Spacer()
                                
                                HStack {
                                    Text("最大幻灯片数:")
                                    Picker("", selection: $selectedMaxSlidesCount) {
                                        Text("5").tag(5)
                                        Text("10").tag(10)
                                        Text("15").tag(15)
                                        Text("20").tag(20)
                                        Text("不限").tag(100)
                                    }
                                    .frame(width: 80)
                                }
                                
                                Button(action: {
                                    analyzeContent()
                                }) {
                                    HStack {
                                        if isAnalyzing {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .frame(width: 16, height: 16)
                                        }
                                        Text(isAnalyzing ? "分析中..." : "分析内容")
                                    }
                                }
                                .disabled(inputText.isEmpty || isAnalyzing)
                            }
                        }
                        .padding()
                        .frame(minWidth: geometry.size.width * 0.4)
                        
                        // 右侧分析结果和模板选择
                        VStack(alignment: .leading, spacing: 12) {
                            Text("分析结果")
                                .font(.headline)
                            
                            if analysisResult.isEmpty && !isAnalyzing {
                                VStack {
                                    Text("请输入文本内容并点击分析按钮")
                                        .foregroundColor(.secondary)
                                    
                                    if let error = generationError {
                                        Text(error)
                                            .foregroundColor(.red)
                                            .padding(.top, 10)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                // 分析结果列表
                                List(analysisResult.indices, id: \.self) { index in
                                    let item = analysisResult[index]
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("幻灯片 \(index + 1)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Text(item.title)
                                            .font(.headline)
                                        
                                        Text(item.content.isEmpty ? "无内容" : item.content)
                                            .font(.caption)
                                            .lineLimit(2)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .background(Color(.textBackgroundColor))
                                .listStyle(.plain)
                                
                                // 选择幻灯片模板
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("选择幻灯片样式")
                                        .font(.headline)
                                    
                                    HStack(spacing: 12) {
                                        styleOption(.standard, "标准")
                                        styleOption(.modern, "现代")
                                        styleOption(.light, "轻盈")
                                    }
                                    
                                    HStack {
                                        Spacer()
                                        
                                        Button("生成幻灯片") {
                                            generateSlides()
                                        }
                                        .disabled(analysisResult.isEmpty || isAnalyzing)
                                        
                                        Button("预览") {
                                            showPreview = true
                                            selectedPreviewIndex = 0
                                        }
                                        .disabled(generatedSlides.isEmpty)
                                    }
                                }
                                .padding(.top, 12)
                            }
                        }
                        .padding()
                        .frame(minWidth: geometry.size.width * 0.5)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    // MARK: - 模板选择选项
    private func styleOption(_ style: SlideStyle, _ name: String) -> some View {
        let isSelected = selectedTemplate.backgroundColor == style.backgroundColor
        
        return VStack {
            // 示例预览
            VStack(alignment: .leading, spacing: 4) {
                Text("标题示例")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(style.titleColor)
                    .padding(.bottom, 4)
                
                Text("内容示例")
                    .font(.system(size: 8))
                    .foregroundColor(style.contentColor)
            }
            .padding(10)
            .frame(width: 120, height: 80)
            .background(style.backgroundColor)
            .cornerRadius(style.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .onTapGesture {
                selectedTemplate = style
            }
            
            // 样式名称
            Text(name)
                .font(.caption)
                .foregroundColor(isSelected ? .blue : .primary)
        }
    }
    
    // MARK: - 幻灯片预览视图
    private var slidePreviewView: some View {
        VStack(spacing: 20) {
            Text("预览生成的幻灯片")
                .font(.headline)
            
            if !generatedSlides.isEmpty && selectedPreviewIndex < generatedSlides.count {
                let slide = generatedSlides[selectedPreviewIndex]
                
                // 幻灯片内容
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(slide.style.backgroundColor)
                .cornerRadius(slide.style.cornerRadius)
                .padding(20)
                .overlay(
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                isCustomizing = true
                                customizingSlideIndex = selectedPreviewIndex
                            }) {
                                Text("编辑")
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .padding()
                        }
                        Spacer()
                    }
                )
                
                // 导航控制
                HStack {
                    Text("幻灯片 \(selectedPreviewIndex + 1) / \(generatedSlides.count)")
                    
                    Spacer()
                    
                    Button(action: {
                        if selectedPreviewIndex > 0 {
                            selectedPreviewIndex -= 1
                        }
                    }) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedPreviewIndex <= 0)
                    
                    Button(action: {
                        if selectedPreviewIndex < generatedSlides.count - 1 {
                            selectedPreviewIndex += 1
                        }
                    }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedPreviewIndex >= generatedSlides.count - 1)
                }
                .padding()
                
                // 操作按钮
                HStack {
                    Button("返回") {
                        showPreview = false
                    }
                    
                    Spacer()
                    
                    Button("应用到演示文稿") {
                        applyToPresentation()
                    }
                }
                .padding()
            } else {
                Text("没有生成的幻灯片可预览")
                    .foregroundColor(.secondary)
                
                Button("返回") {
                    showPreview = false
                }
                .padding()
            }
        }
        .padding()
    }
    
    // MARK: - 幻灯片自定义视图
    private var slideCustomizationView: some View {
        VStack(spacing: 20) {
            Text("编辑幻灯片")
                .font(.headline)
            
            if !generatedSlides.isEmpty && customizingSlideIndex < generatedSlides.count {
                let slide = generatedSlides[customizingSlideIndex]
                
                // 编辑表单
                Form {
                    TextField("幻灯片标题", text: Binding(
                        get: { slide.title },
                        set: { newValue in
                            var updatedSlide = slide
                            updatedSlide.title = newValue
                            generatedSlides[customizingSlideIndex] = updatedSlide
                        }
                    ))
                    .font(.headline)
                    .padding()
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(4)
                    
                    TextEditor(text: Binding(
                        get: { slide.content },
                        set: { newValue in
                            var updatedSlide = slide
                            updatedSlide.content = newValue
                            generatedSlides[customizingSlideIndex] = updatedSlide
                        }
                    ))
                    .font(.body)
                    .padding()
                    .frame(height: 200)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(4)
                    
                    // 样式选项
                    VStack(alignment: .leading) {
                        Text("样式:")
                            .font(.subheadline)
                        
                        HStack {
                            styleEditOption(.standard, "标准", slide)
                            styleEditOption(.modern, "现代", slide)
                            styleEditOption(.light, "轻盈", slide)
                        }
                    }
                    .padding(.vertical)
                }
                
                // 操作按钮
                HStack {
                    Button("返回预览") {
                        isCustomizing = false
                    }
                    
                    Spacer()
                    
                    Button("上一张") {
                        if customizingSlideIndex > 0 {
                            customizingSlideIndex -= 1
                        }
                    }
                    .disabled(customizingSlideIndex <= 0)
                    
                    Button("下一张") {
                        if customizingSlideIndex < generatedSlides.count - 1 {
                            customizingSlideIndex += 1
                        }
                    }
                    .disabled(customizingSlideIndex >= generatedSlides.count - 1)
                    
                }
                .padding()
            } else {
                Text("无可编辑的幻灯片")
                    .foregroundColor(.secondary)
                
                Button("返回") {
                    isCustomizing = false
                    showPreview = false
                }
                .padding()
            }
        }
        .padding()
    }
    
    // 样式编辑选项
    private func styleEditOption(_ style: SlideStyle, _ name: String, _ currentSlide: SlideContent) -> some View {
        let isSelected = currentSlide.style.backgroundColor == style.backgroundColor
        
        return VStack {
            // 示例预览
            VStack(alignment: .leading, spacing: 4) {
                Text("示例")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(style.titleColor)
            }
            .padding(10)
            .frame(width: 80, height: 50)
            .background(style.backgroundColor)
            .cornerRadius(style.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .onTapGesture {
                var updatedSlide = generatedSlides[customizingSlideIndex]
                updatedSlide.style = style
                generatedSlides[customizingSlideIndex] = updatedSlide
            }
            
            // 样式名称
            Text(name)
                .font(.caption)
                .foregroundColor(isSelected ? .blue : .primary)
        }
    }
    
    // MARK: - 功能方法
    
    // 清除输入
    private func clearInput() {
        inputText = ""
        analysisResult = []
        generatedSlides = []
        generationError = nil
    }
    
    // 从文件导入
    private func importFromFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType.plainText, UTType.text]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let text = try String(contentsOf: url)
                inputText = text
            } catch {
                generationError = "读取文件失败: \(error.localizedDescription)"
            }
        }
    }
    
    // 分析内容
    private func analyzeContent() {
        isAnalyzing = true
        analysisResult = []
        generatedSlides = []
        generationError = nil
        
        // 使用异步操作避免界面卡顿
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ContentAnalyzer.analyzeText(inputText, maxSlides: selectedMaxSlidesCount)
            
            DispatchQueue.main.async {
                isAnalyzing = false
                analysisResult = result
                
                if result.isEmpty {
                    generationError = "无法从输入的文本中识别有效的内容结构。请尝试提供更结构化的文本，包含明显的标题和内容。"
                }
            }
        }
    }
    
    // 生成幻灯片
    private func generateSlides() {
        generatedSlides = []
        
        for item in analysisResult {
            let slide = SlideContent(
                title: item.title,
                content: item.content,
                style: selectedTemplate,
                notes: item.notes
            )
            generatedSlides.append(slide)
        }
    }
    
    // 应用到演示文稿
    private func applyToPresentation() {
        // 是否替换现有幻灯片或追加
        let alert = NSAlert()
        alert.messageText = "应用生成的幻灯片"
        alert.informativeText = "您想要替换当前演示文稿，还是将生成的幻灯片追加到当前演示文稿？"
        alert.addButton(withTitle: "替换")
        alert.addButton(withTitle: "追加")
        alert.addButton(withTitle: "取消")
        
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            // 替换现有演示文稿
            viewModel.slides = generatedSlides
            viewModel.currentSlideIndex = 0
            documentManager.isDocumentSaved = false
            presentationMode.wrappedValue.dismiss()
            
        case .alertSecondButtonReturn:
            // 追加到当前演示文稿
            viewModel.slides.append(contentsOf: generatedSlides)
            documentManager.isDocumentSaved = false
            presentationMode.wrappedValue.dismiss()
            
        default:
            // 取消操作
            break
        }
    }
}

// MARK: - 内容分析器
struct ContentAnalyzer {
    static func analyzeText(_ text: String, maxSlides: Int) -> [SlideAnalysisItem] {
        // 去除空行和调整格式
        let lines = text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if lines.isEmpty {
            return []
        }
        
        var result: [SlideAnalysisItem] = []
        
        // 使用自然语言处理识别标题
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        
        // 简单的启发式方法识别标题和内容
        if lines.count > 1 {
            // 首行作为总标题
            var currentTitle = lines[0]
            var currentContent = ""
            var currentNotes = ""
            
            for i in 1..<lines.count {
                let line = lines[i]
                
                // 判断是否为新标题的启发式规则
                let isPotentialTitle = line.count < 50 && // 较短
                    !line.contains(". ") && // 不含多个句子
                    (line.hasSuffix("?") || line.hasSuffix("：") || line.hasSuffix(":") || // 常见标题结尾
                     line.first?.isUppercase == true) // 首字母大写
                
                if isPotentialTitle && !currentContent.isEmpty {
                    // 保存当前幻灯片并开始新的
                    result.append(SlideAnalysisItem(
                        title: currentTitle,
                        content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                        notes: currentNotes
                    ))
                    
                    // 重置为新的幻灯片
                    currentTitle = line
                    currentContent = ""
                    currentNotes = ""
                    
                    // 检查是否达到最大幻灯片数
                    if result.count >= maxSlides {
                        break
                    }
                } else if line.hasPrefix("注:") || line.hasPrefix("注：") || line.hasPrefix("Note:") {
                    // 识别备注
                    currentNotes += line + "\n"
                } else {
                    // 添加为当前内容
                    if !currentContent.isEmpty {
                        currentContent += "\n"
                    }
                    currentContent += line
                }
            }
            
            // 添加最后一张幻灯片
            if !currentTitle.isEmpty && !currentContent.isEmpty && result.count < maxSlides {
                result.append(SlideAnalysisItem(
                    title: currentTitle,
                    content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: currentNotes
                ))
            }
        } else if lines.count == 1 {
            // 只有一行，作为标题
            result.append(SlideAnalysisItem(
                title: lines[0],
                content: "请在此处添加内容",
                notes: ""
            ))
        }
        
        return result
    }
}

// MARK: - 分析结果项目
struct SlideAnalysisItem: Identifiable {
    let id = UUID()
    var title: String
    var content: String
    var notes: String
}

// MARK: - 内容生成器窗口管理器
class ContentGeneratorWindowManager {
    private var contentGeneratorWindow: NSWindow?
    private let viewModel: SlideEditorViewModel
    private let documentManager: SlideDocumentManager
    
    init(viewModel: SlideEditorViewModel, documentManager: SlideDocumentManager) {
        self.viewModel = viewModel
        self.documentManager = documentManager
    }
    
    func showContentGenerator() {
        if let window = contentGeneratorWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        // 创建内容生成器视图
        let contentGeneratorView = ContentGeneratorView(viewModel: viewModel, documentManager: documentManager)
        
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.setFrameAutosaveName("ContentGeneratorWindow")
        window.contentView = NSHostingView(rootView: contentGeneratorView)
        window.title = "OnlySlide 内容生成器"
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        
        self.contentGeneratorWindow = window
    }
}

// MARK: - UTType扩展
import UniformTypeIdentifiers

extension UTType {
    static var plainText: UTType { UTType(importedAs: "public.plain-text") }
    static var text: UTType { UTType(importedAs: "public.text") }
}

// MARK: - 预览
#Preview {
    let viewModel = SlideEditorViewModel(
        slides: [
            SlideContent(title: "欢迎使用OnlySlide", content: "创建专业演示文稿的最佳工具"),
            SlideContent(title: "简洁设计", content: "专注于内容，而不是复杂的界面", style: .modern)
        ]
    )
    
    let documentManager = SlideDocumentManager()
    
    return ContentGeneratorView(viewModel: viewModel, documentManager: documentManager)
        .frame(width: 900, height: 700)
}
#endif 