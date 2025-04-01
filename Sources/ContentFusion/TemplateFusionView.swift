import SwiftUI

/// 内容与模板融合视图，用于选择模板并应用到文档内容
public struct TemplateFusionView: View {
    /// 文档内容
    private let documentContent: DocumentContent
    /// 模板管理器
    @StateObject private var templateManager = TemplateManager.shared
    /// 选中的模板ID
    @State private var selectedTemplateId: String?
    /// 融合选项
    @State private var fusionOptions = TemplateFusionManager.FusionOptions()
    /// 显示高级选项
    @State private var showAdvancedOptions = false
    /// 正在处理中
    @State private var isProcessing = false
    /// 融合进度
    @State private var progress: TemplateFusionManager.FusionProgress?
    /// 融合结果
    @State private var fusionResult: TemplateFusionManager.FusionResult?
    /// 是否显示结果视图
    @State private var showingResult = false
    /// 错误消息
    @State private var errorMessage: String?
    /// 是否显示错误警告
    @State private var showingError = false
    /// 完成回调
    var onComplete: ((TemplateFusionManager.FusionResult?) -> Void)?
    
    /// 初始化方法
    /// - Parameters:
    ///   - documentContent: 文档内容
    ///   - onComplete: 完成回调
    public init(documentContent: DocumentContent, onComplete: ((TemplateFusionManager.FusionResult?) -> Void)? = nil) {
        self.documentContent = documentContent
        self.onComplete = onComplete
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 内容概览
                contentOverview
                
                // 模板选择
                templateSelector
                
                // 融合选项
                fusionOptionsView
                
                Spacer()
                
                // 操作按钮
                actionButtons
            }
            .navigationTitle("应用模板")
            .padding()
            .disabled(isProcessing)
            .overlay(progressOverlay)
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .sheet(isPresented: $showingResult) {
                if let result = fusionResult {
                    TemplateFusionResultView(result: result) {
                        showingResult = false
                        onComplete?(result)
                    }
                }
            }
            .onAppear {
                loadTemplates()
            }
        }
    }
    
    // MARK: - 视图组件
    
    /// 内容概览视图
    private var contentOverview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("文档内容")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("标题: \(documentContent.title)")
                        .fontWeight(.medium)
                    
                    Text("部分数量: \(documentContent.sections.count)")
                    
                    let totalItems = documentContent.sections.reduce(0) { $0 + $1.items.count }
                    Text("内容项数量: \(totalItems)")
                }
                
                Spacer()
                
                // 内容类型分布
                contentTypeDistribution
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding(.bottom)
    }
    
    /// 内容类型分布视图
    private var contentTypeDistribution: some View {
        HStack(spacing: 15) {
            // 计算各种内容类型的数量
            let typeCounts = calculateContentTypeCounts()
            
            ForEach(typeCounts.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { type, count in
                VStack {
                    Image(systemName: iconForContentType(type))
                        .font(.title2)
                    
                    Text("\(count)")
                        .font(.caption)
                }
            }
        }
    }
    
    /// 模板选择器视图
    private var templateSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择模板")
                .font(.headline)
            
            if templateManager.isLoading {
                HStack {
                    ProgressView()
                    Text("加载模板中...")
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else if templateManager.templates.isEmpty {
                Text("没有可用模板")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(templateManager.templates) { template in
                            templateCard(for: template)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                .frame(height: 180)
            }
        }
        .padding(.bottom)
    }
    
    /// 模板卡片视图
    private func templateCard(for template: TemplateManager.TemplateInfo) -> some View {
        let isSelected = selectedTemplateId == template.id
        
        return VStack {
            ZStack {
                if let previewImage = template.previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.gray.opacity(0.1)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            Image(systemName: "doc.richtext")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
                
                if isSelected {
                    Color.blue.opacity(0.3)
                        .overlay(
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 140, height: 80)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            
            Text(template.name)
                .font(.subheadline)
                .lineLimit(1)
                .frame(width: 140, alignment: .center)
        }
        .onTapGesture {
            selectedTemplateId = template.id
        }
    }
    
    /// 融合选项视图
    private var fusionOptionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("融合选项")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showAdvancedOptions.toggle()
                    }
                }) {
                    Label(showAdvancedOptions ? "隐藏高级选项" : "显示高级选项", 
                          systemImage: showAdvancedOptions ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            
            // 基本选项
            VStack(alignment: .leading, spacing: 8) {
                Picker("内容分配", selection: $fusionOptions.distributionStrategy) {
                    Text("按内容类型").tag(TemplateFusionManager.FusionOptions.ContentDistributionStrategy.byContentType)
                    Text("按内容长度").tag(TemplateFusionManager.FusionOptions.ContentDistributionStrategy.byContentLength)
                    Text("固定数量").tag(TemplateFusionManager.FusionOptions.ContentDistributionStrategy.fixedItemsPerSlide(3))
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Toggle("保留图片原始比例", isOn: $fusionOptions.preserveImageAspectRatio)
                
                Toggle("自动生成封面幻灯片", isOn: $fusionOptions.generateCoverSlide)
                
                Toggle("自动生成目录", isOn: $fusionOptions.generateTableOfContents)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // 高级选项
            if showAdvancedOptions {
                VStack(alignment: .leading, spacing: 8) {
                    // 风格匹配选项
                    Text("风格匹配")
                        .font(.subheadline)
                    
                    Toggle("匹配颜色主题", isOn: $fusionOptions.styleMatch.matchColorTheme)
                    
                    Toggle("匹配字体", isOn: $fusionOptions.styleMatch.matchFonts)
                    
                    Toggle("自动调整文本大小", isOn: $fusionOptions.styleMatch.adjustTextSize)
                    
                    HStack {
                        Text("匹配强度")
                        Slider(value: $fusionOptions.styleMatch.matchingStrength, in: 0...1)
                        Text("\(Int(fusionOptions.styleMatch.matchingStrength * 100))%")
                            .frame(width: 40)
                    }
                    
                    // 文本溢出处理选项
                    Text("文本溢出处理")
                        .font(.subheadline)
                        .padding(.top, 8)
                    
                    Picker("处理方式", selection: $fusionOptions.textOverflowHandling) {
                        Text("调整字体大小").tag(TemplateFusionManager.FusionOptions.TextOverflowHandling.adjustFontSize)
                        Text("创建新幻灯片").tag(TemplateFusionManager.FusionOptions.TextOverflowHandling.createNewSlide)
                        Text("裁剪文本").tag(TemplateFusionManager.FusionOptions.TextOverflowHandling.truncate)
                        Text("显示溢出指示器").tag(TemplateFusionManager.FusionOptions.TextOverflowHandling.showOverflowIndicator)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding(.bottom)
    }
    
    /// 操作按钮
    private var actionButtons: some View {
        HStack {
            Button("取消") {
                onComplete?(nil)
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("快速应用") {
                applyTemplateQuickly()
            }
            .buttonStyle(.bordered)
            .disabled(selectedTemplateId == nil)
            
            Button("应用模板") {
                applyTemplate()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedTemplateId == nil)
        }
        .padding(.top)
    }
    
    /// 进度显示覆盖
    private var progressOverlay: some View {
        Group {
            if isProcessing, let progress = progress {
                ZStack {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        ProgressView(value: progress.percentage, total: 100)
                            .frame(width: 200)
                        
                        Text(progress.detail)
                            .font(.caption)
                        
                        Text("\(Int(progress.percentage))%")
                            .font(.title3)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    /// 加载模板
    private func loadTemplates() {
        Task {
            await templateManager.loadTemplates()
            
            // 如果有默认模板，自动选择第一个
            if let defaultId = templateManager.defaultTemplateIds.first {
                await MainActor.run {
                    selectedTemplateId = defaultId
                }
            } else if !templateManager.templates.isEmpty {
                await MainActor.run {
                    selectedTemplateId = templateManager.templates.first?.id
                }
            }
        }
    }
    
    /// 计算内容类型分布
    private func calculateContentTypeCounts() -> [ContentType: Int] {
        var counts: [ContentType: Int] = [:]
        
        for section in documentContent.sections {
            for item in section.items {
                let type = contentTypeForItem(item)
                counts[type, default: 0] += 1
            }
        }
        
        return counts
    }
    
    /// 获取内容项的类型
    private func contentTypeForItem(_ item: DocumentContent.ContentItem) -> ContentType {
        switch item {
        case .text:
            return .text
        case .image:
            return .image
        case .list:
            return .list
        case .table:
            return .table
        case .code:
            return .code
        case .quote:
            return .quote
        }
    }
    
    /// 内容类型枚举
    private enum ContentType: String {
        case text
        case image
        case list
        case table
        case code
        case quote
    }
    
    /// 获取内容类型对应的图标
    private func iconForContentType(_ type: ContentType) -> String {
        switch type {
        case .text:
            return "text.justify"
        case .image:
            return "photo"
        case .list:
            return "list.bullet"
        case .table:
            return "tablecells"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .quote:
            return "quote.bubble"
        }
    }
    
    /// 应用模板
    private func applyTemplate() {
        guard let templateId = selectedTemplateId else {
            showError("请选择模板")
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                let result = try await TemplateFusionManager.shared.applyTemplate(
                    to: documentContent,
                    using: templateId,
                    options: fusionOptions
                ) { progress in
                    Task { @MainActor in
                        self.progress = progress
                    }
                }
                
                await MainActor.run {
                    isProcessing = false
                    fusionResult = result
                    showingResult = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    showError(error.localizedDescription)
                }
            }
        }
    }
    
    /// 快速应用模板
    private func applyTemplateQuickly() {
        guard let templateId = selectedTemplateId else {
            showError("请选择模板")
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                let result = try await TemplateFusionManager.shared.quickFusion(
                    documentContent: documentContent,
                    templateId: templateId
                )
                
                await MainActor.run {
                    isProcessing = false
                    onComplete?(result)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    showError(error.localizedDescription)
                }
            }
        }
    }
    
    /// 显示错误信息
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

/// 融合结果视图
struct TemplateFusionResultView: View {
    /// 融合结果
    let result: TemplateFusionManager.FusionResult
    /// 完成回调
    var onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("融合完成")
                .font(.title)
                .padding(.top)
            
            // 结果概览
            VStack(alignment: .leading, spacing: 8) {
                Text("概览")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("应用模板: \(result.templateName)")
                        Text("生成幻灯片数: \(result.slideCount)")
                        Text("处理时间: \(result.fusionTimeMs) 毫秒")
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // 警告信息
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("警告")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    ForEach(result.warnings, id: \.self) { warning in
                        Text("• \(warning)")
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // 预览图
            if let previewImages = result.previewImages, !previewImages.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("预览")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<previewImages.count, id: \.self) { index in
                                VStack {
                                    Image(uiImage: previewImages[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 160)
                                        .cornerRadius(8)
                                    
                                    Text("幻灯片 \(index + 1)")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            Button("完成") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}