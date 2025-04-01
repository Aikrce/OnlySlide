import SwiftUI

/// OnlySlide主界面视图，整合文档分析、模板管理和内容融合功能
public struct MainView: View {
    /// 当前活动视图
    @State private var activeView: ActiveView = .home
    /// 当前打开的文档
    @State private var currentDocument: DocumentAnalysisResult?
    /// 文档分析中
    @State private var isAnalyzing: Bool = false
    /// 分析进度
    @State private var analysisProgress: Float = 0
    /// 显示文件导入选择器
    @State private var showingFileImporter: Bool = false
    /// 显示导入错误警告
    @State private var showingImportError: Bool = false
    /// 错误消息
    @State private var errorMessage: String = ""
    /// 是否显示模板库
    @State private var showingTemplateLibrary: Bool = false
    /// 是否显示设置
    @State private var showingSettings: Bool = false
    
    // 增强模板库功能
    /// 模板搜索关键词
    @State private var templateSearchQuery: String = ""
    /// 选中的模板分类
    @State private var selectedTemplateCategory: TemplateCategory = .all
    /// 模板排序方式
    @State private var templateSortOrder: TemplateSortOrder = .newest
    
    /// 当前正在分析的URL
    @State private var currentAnalyzingURL: URL? = nil
    
    /// 活动视图枚举
    enum ActiveView {
        case welcome
        case home
        case analyzing
        case document
        case export
    }
    
    /// 模板分类枚举
    enum TemplateCategory: String, CaseIterable, Identifiable {
        case all = "全部"
        case business = "商务"
        case education = "教育"
        case creative = "创意"
        case simple = "简约"
        case colorful = "多彩"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .business: return "briefcase"
            case .education: return "book"
            case .creative: return "paintbrush"
            case .simple: return "circle.grid.2x2"
            case .colorful: return "paintpalette"
            }
        }
    }
    
    /// 模板排序方式
    enum TemplateSortOrder: String, CaseIterable, Identifiable {
        case newest = "最新"
        case popular = "最受欢迎"
        case nameAsc = "名称 A-Z"
        case nameDesc = "名称 Z-A"
        
        var id: String { self.rawValue }
    }
    
    public init() {
        // 配置初始化代码
        setupNotificationObservers()
    }
    
    public var body: some View {
        ZStack {
            // 主背景
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // 主内容区域
            VStack(spacing: 0) {
                // 标题栏
                titleBar
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // 内容区域
                mainContentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // 模板库悬浮视图
            if showingTemplateLibrary {
                templateLibraryView
                    .transition(.move(edge: .trailing))
            }
            
            // 设置悬浮视图
            if showingSettings {
                settingsView
                    .transition(.move(edge: .bottom))
            }
        }
        .sheet(isPresented: $showingFileImporter) {
            // 文件导入选择器
            DocumentPicker(onDocumentPicked: handleDocumentSelection)
        }
        .alert("导入错误", isPresented: $showingImportError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // 首次启动时显示欢迎界面
            if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
                activeView = .welcome
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            }
        }
    }
    
    /// 标题栏视图
    private var titleBar: some View {
        HStack {
            // 应用标志和标题
            HStack(spacing: 8) {
                Image(systemName: "doc.text.image")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("OnlySlide")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // 工具栏按钮
            HStack(spacing: 16) {
                Button(action: importDocument) {
                    Image(systemName: "doc.badge.plus")
                        .font(.title3)
                }
                .help("导入文档")
                
                Button(action: toggleTemplateLibrary) {
                    Image(systemName: "rectangle.grid.2x2")
                        .font(.title3)
                }
                .help("模板库")
                
                if activeView == .document, let _ = currentDocument {
                    Button(action: exportDocument) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                    }
                    .help("导出")
                }
                
                Button(action: toggleSettings) {
                    Image(systemName: "gear")
                        .font(.title3)
                }
                .help("设置")
            }
            .foregroundColor(.primary)
        }
    }
    
    /// 主内容视图
    private var mainContentView: some View {
        Group {
            switch activeView {
            case .welcome:
                WelcomeView(
                    importAction: importDocument,
                    browseTemplatesAction: toggleTemplateLibrary
                )
                .transition(.opacity)
            
            case .home:
                homeContentView
                    .transition(.opacity)
            
            case .analyzing:
                AnalysisProgressView(
                    progress: analysisProgress,
                    fileType: determineFileType(url: currentAnalyzingURL),
                    showCancelButton: true,
                    onCancel: cancelAnalysis
                )
                .transition(.opacity)
            
            case .document:
                documentContentView
                    .transition(.opacity)
            
            case .export:
                exportContentView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: activeView)
    }
    
    /// 主页内容视图
    private var homeContentView: some View {
        HomeView()
            .overlay(
                Button(action: importDocument) {
                    VStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 40))
                        
                        Text("导入文档")
                            .font(.headline)
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .shadow(radius: 3)
                .buttonStyle(.plain),
                alignment: .bottom
            )
    }
    
    /// 文档内容视图
    private var documentContentView: some View {
        Group {
            if let document = currentDocument {
                DocumentView(document: document)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("导出") {
                                exportDocument()
                            }
                        }
                    }
            } else {
                VStack {
                    Text("文档加载失败")
                        .font(.title)
                    
                    Button("返回主页") {
                        activeView = .home
                    }
                    .padding()
                }
            }
        }
    }
    
    /// 导出内容视图
    private var exportContentView: some View {
        Group {
            if let document = currentDocument {
                ExportView(documentResult: document)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("返回") {
                                activeView = .document
                            }
                        }
                    }
            } else {
                VStack {
                    Text("没有可导出的文档")
                        .font(.title)
                    
                    Button("返回主页") {
                        activeView = .home
                    }
                    .padding()
                }
            }
        }
    }
    
    /// 增强的模板库视图
    private var templateLibraryView: some View {
        Rectangle()
            .fill(Color(.systemBackground))
            .frame(width: 350)
            .shadow(radius: 5)
            .overlay(
                VStack(spacing: 0) {
                    // 标题和搜索栏
                    VStack(spacing: 12) {
                        HStack {
                            Text("模板库")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button(action: toggleTemplateLibrary) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                            }
                        }
                        
                        // 搜索栏
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("搜索模板", text: $templateSearchQuery)
                                .textFieldStyle(PlainTextFieldStyle())
                            
                            if !templateSearchQuery.isEmpty {
                                Button(action: {
                                    templateSearchQuery = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding()
                    
                    Divider()
                    
                    // 分类选择和排序控件
                    VStack(spacing: 12) {
                        // 分类选择器
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(TemplateCategory.allCases) { category in
                                    categoryButton(category)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 排序选择器
                        HStack {
                            Text("排序:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("排序方式", selection: $templateSortOrder) {
                                ForEach(TemplateSortOrder.allCases) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // 模板网格视图
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                            ForEach(getFilteredTemplates()) { template in
                                templateGridItem(template)
                            }
                        }
                        .padding()
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .animation(.easeInOut, value: showingTemplateLibrary)
            .animation(.easeInOut, value: selectedTemplateCategory)
            .animation(.easeInOut, value: templateSortOrder)
            .animation(.easeInOut, value: templateSearchQuery)
            .zIndex(1)
            .transition(.move(edge: .trailing))
    }
    
    /// 分类按钮
    private func categoryButton(_ category: TemplateCategory) -> some View {
        Button(action: {
            selectedTemplateCategory = category
        }) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 20))
                    .frame(width: 36, height: 36)
                    .background(selectedTemplateCategory == category ? Color.blue : Color.clear)
                    .foregroundColor(selectedTemplateCategory == category ? .white : .primary)
                    .cornerRadius(8)
                
                Text(category.rawValue)
                    .font(.caption)
                    .foregroundColor(selectedTemplateCategory == category ? .blue : .primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    /// 模板网格项
    private func templateGridItem(_ template: TemplateItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 模板预览图
            ZStack(alignment: .bottomTrailing) {
                Rectangle()
                    .aspectRatio(16/9, contentMode: .fit)
                    .foregroundColor(template.color)
                    .cornerRadius(8)
                
                // 收藏按钮
                Button(action: {
                    // 切换收藏状态
                    toggleFavorite(template)
                }) {
                    Image(systemName: template.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(template.isFavorite ? .red : .white)
                        .padding(6)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .padding(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // 模板标题
                Text(template.name)
                    .font(.headline)
                    .lineLimit(1)
                
                // 模板分类
                Text(template.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 应用按钮
                Button(action: {
                    applyTemplate(template)
                }) {
                    Text("应用")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 4)
            }
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
    
    /// 模板项目视图（旧版，已替换为网格视图）
    private func templateItem(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("应用") {
                // 应用模板
                showingTemplateLibrary = false
            }
            .font(.caption)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    /// 设置视图
    private var settingsView: some View {
        Rectangle()
            .fill(Color(.systemBackground))
            .frame(height: 300)
            .shadow(radius: 5)
            .overlay(
                VStack {
                    HStack {
                        Text("设置")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: toggleSettings) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.title3)
                        }
                    }
                    .padding()
                    
                    Divider()
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // 设置项
                            settingItem(
                                title: "保存位置",
                                description: "设置文档保存位置",
                                icon: "folder"
                            )
                            
                            settingItem(
                                title: "默认导出格式",
                                description: "选择默认的导出文件格式",
                                icon: "doc.richtext"
                            )
                            
                            settingItem(
                                title: "语言设置",
                                description: "选择应用语言和语音识别语言",
                                icon: "globe"
                            )
                            
                            settingItem(
                                title: "高级设置",
                                description: "性能和分析引擎设置",
                                icon: "gear"
                            )
                        }
                        .padding()
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(.easeInOut, value: showingSettings)
            .zIndex(1)
            .transition(.move(edge: .bottom))
    }
    
    /// 设置项视图
    private func settingItem(title: String, description: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - 功能方法
    
    /// 获取筛选后的模板列表
    private func getFilteredTemplates() -> [TemplateItem] {
        var templates = getSampleTemplates()
        
        // 按分类筛选
        if selectedTemplateCategory != .all {
            templates = templates.filter { $0.category == selectedTemplateCategory }
        }
        
        // 按关键词搜索
        if !templateSearchQuery.isEmpty {
            templates = templates.filter {
                $0.name.localizedCaseInsensitiveContains(templateSearchQuery) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(templateSearchQuery)
            }
        }
        
        // 按选择的排序方式排序
        switch templateSortOrder {
        case .newest:
            templates.sort { $0.creationDate > $1.creationDate }
        case .popular:
            templates.sort { $0.popularity > $1.popularity }
        case .nameAsc:
            templates.sort { $0.name < $1.name }
        case .nameDesc:
            templates.sort { $0.name > $1.name }
        }
        
        return templates
    }
    
    /// 切换模板收藏状态
    private func toggleFavorite(_ template: TemplateItem) {
        // 在实际应用中，这里会更新数据库中的模板收藏状态
        // 现在只是打印一条消息
        print("切换模板 '\(template.name)' 的收藏状态")
    }
    
    /// 应用模板
    private func applyTemplate(_ template: TemplateItem) {
        if let document = currentDocument {
            // 在实际应用中，这里会将模板应用到当前文档
            print("将模板 '\(template.name)' 应用到文档 '\(document.title)'")
            
            // 关闭模板库面板
            withAnimation {
                showingTemplateLibrary = false
            }
            
            // 切换到文档视图
            activeView = .document
        } else {
            // 如果没有打开的文档，显示错误提示
            errorMessage = "请先导入或创建文档"
            showingImportError = true
        }
    }
    
    /// 获取示例模板数据
    private func getSampleTemplates() -> [TemplateItem] {
        [
            TemplateItem(id: UUID(), name: "商务简约", category: .business, color: .blue, isFavorite: true, popularity: 4.8),
            TemplateItem(id: UUID(), name: "创意视觉", category: .creative, color: .purple, isFavorite: false, popularity: 4.5),
            TemplateItem(id: UUID(), name: "教育主题", category: .education, color: .green, isFavorite: true, popularity: 4.7),
            TemplateItem(id: UUID(), name: "极简黑白", category: .simple, color: .gray, isFavorite: false, popularity: 4.2),
            TemplateItem(id: UUID(), name: "多彩图表", category: .colorful, color: .orange, isFavorite: false, popularity: 4.3),
            TemplateItem(id: UUID(), name: "企业报告", category: .business, color: .blue.opacity(0.7), isFavorite: true, popularity: 4.9),
            TemplateItem(id: UUID(), name: "学术研究", category: .education, color: .green.opacity(0.7), isFavorite: false, popularity: 4.6),
            TemplateItem(id: UUID(), name: "创意广告", category: .creative, color: .pink, isFavorite: false, popularity: 4.4),
            TemplateItem(id: UUID(), name: "简约线条", category: .simple, color: .black, isFavorite: true, popularity: 4.1),
            TemplateItem(id: UUID(), name: "彩虹渐变", category: .colorful, color: .red, isFavorite: false, popularity: 4.0),
            TemplateItem(id: UUID(), name: "产品展示", category: .business, color: .indigo, isFavorite: false, popularity: 4.6),
            TemplateItem(id: UUID(), name: "课程计划", category: .education, color: .teal, isFavorite: true, popularity: 4.5)
        ]
    }
    
    /// 设置通知观察者
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ImportDocument"),
            object: nil,
            queue: .main
        ) { _ in
            importDocument()
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ExportPowerPoint"),
            object: nil,
            queue: .main
        ) { _ in
            if currentDocument != nil {
                activeView = .export
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("OpenTemplateLibrary"),
            object: nil,
            queue: .main
        ) { _ in
            toggleTemplateLibrary()
        }
    }
    
    /// 导入文档
    private func importDocument() {
        showingFileImporter = true
    }
    
    /// 处理文档选择
    private func handleDocumentSelection(url: URL) {
        // 记录当前分析URL
        currentAnalyzingURL = url
        
        // 开始分析流程
        activeView = .analyzing
        isAnalyzing = true
        analysisProgress = 0
        
        // 根据文件类型选择不同的处理流程
        let fileType = determineFileType(url: url)
        
        // 添加到最近文档
        addToRecentDocuments(title: url.lastPathComponent, url: url)
        
        // 创建实际的分析任务
        Task {
            do {
                // 开始分析文件
                switch fileType {
                case .pdf:
                    try await analyzePDFDocument(url: url)
                case .word:
                    try await analyzeWordDocument(url: url)
                case .audio:
                    try await analyzeAudioFile(url: url)
                case .video:
                    try await analyzeVideoFile(url: url)
                default:
                    // 使用通用分析流程
                    simulateDocumentAnalysis(url: url, fileType: fileType)
                }
            } catch {
                // 处理分析错误
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    self.errorMessage = "分析文件时出错: \(error.localizedDescription)"
                    self.showingImportError = true
                    self.activeView = .home
                }
            }
        }
    }
    
    /// 分析PDF文档实现
    private func analyzePDFDocument(url: URL) async throws {
        // 在实际应用中，这里会集成PDF解析库来提取内容
        // 目前使用模拟进度来演示功能
        
        // 更新分析进度信息
        DispatchQueue.main.async {
            self.analysisProgress = 0.1
        }
        
        // 模拟PDF文本提取过程
        await Task.sleep(1_000_000_000) // 1秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.3
        }
        
        // 模拟PDF结构分析
        await Task.sleep(1_000_000_000) // 1秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.5
        }
        
        // 模拟图像提取
        await Task.sleep(1_000_000_000) // 1秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.7
        }
        
        // 模拟内容结构化
        await Task.sleep(1_000_000_000) // 1秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.9
        }
        
        // 创建结构化文档内容
        let sections = createPDFDocumentSections()
        let content = DocumentContent(sections: sections)
        
        // 完成分析
        DispatchQueue.main.async {
            self.analysisProgress = 1.0
            self.isAnalyzing = false
            
            // 创建分析结果
            self.currentDocument = DocumentAnalysisResult(
                id: UUID(),
                title: url.lastPathComponent,
                fileType: .pdf,
                content: content,
                creationDate: Date()
            )
            
            // 切换到文档视图
            self.activeView = .document
        }
    }
    
    /// 分析Word文档实现
    private func analyzeWordDocument(url: URL) async throws {
        // 在实际应用中，这里会集成Word文档解析库
        // 目前使用模拟进度来演示功能
        
        // 更新分析进度和状态信息
        DispatchQueue.main.async {
            self.analysisProgress = 0.1
        }
        
        // 模拟Word文本提取过程
        await Task.sleep(800_000_000) // 0.8秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.3
        }
        
        // 模拟Word格式分析
        await Task.sleep(800_000_000) // 0.8秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.5
        }
        
        // 模拟表格和图像提取
        await Task.sleep(800_000_000) // 0.8秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.7
        }
        
        // 模拟内容结构化
        await Task.sleep(800_000_000) // 0.8秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.9
        }
        
        // 创建结构化文档内容
        let sections = createWordDocumentSections()
        let content = DocumentContent(sections: sections)
        
        // 完成分析
        DispatchQueue.main.async {
            self.analysisProgress = 1.0
            self.isAnalyzing = false
            
            // 创建分析结果
            self.currentDocument = DocumentAnalysisResult(
                id: UUID(),
                title: url.lastPathComponent,
                fileType: .word,
                content: content,
                creationDate: Date()
            )
            
            // 切换到文档视图
            self.activeView = .document
        }
    }
    
    /// 分析音频文件实现
    private func analyzeAudioFile(url: URL) async throws {
        // 在实际应用中，这里会集成语音识别和音频分析库
        // 目前使用模拟进度来演示功能
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.2
        }
        
        // 模拟音频转录过程
        await Task.sleep(1_500_000_000) // 1.5秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.5
        }
        
        // 模拟内容结构化
        await Task.sleep(1_500_000_000) // 1.5秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.8
        }
        
        // 创建结构化音频分析内容
        let sections = createAudioAnalysisSections(filename: url.lastPathComponent)
        let content = DocumentContent(sections: sections)
        
        // 完成分析
        DispatchQueue.main.async {
            self.analysisProgress = 1.0
            self.isAnalyzing = false
            
            // 创建分析结果
            self.currentDocument = DocumentAnalysisResult(
                id: UUID(),
                title: url.lastPathComponent,
                fileType: .audio,
                content: content,
                creationDate: Date()
            )
            
            // 切换到文档视图
            self.activeView = .document
        }
    }
    
    /// 分析视频文件实现
    private func analyzeVideoFile(url: URL) async throws {
        // 在实际应用中，这里会集成视频处理和分析库
        // 目前使用模拟进度来演示功能
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.1
        }
        
        // 模拟视频帧提取
        await Task.sleep(1_000_000_000) // 1秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.3
        }
        
        // 模拟音频转录
        await Task.sleep(1_000_000_000) // 1秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.5
        }
        
        // 模拟关键帧分析
        await Task.sleep(1_000_000_000) // 1秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.7
        }
        
        // 模拟内容结构化
        await Task.sleep(1_000_000_000) // 1秒
        
        DispatchQueue.main.async {
            self.analysisProgress = 0.9
        }
        
        // 创建结构化视频分析内容
        let sections = createVideoAnalysisSections(filename: url.lastPathComponent)
        let content = DocumentContent(sections: sections)
        
        // 完成分析
        DispatchQueue.main.async {
            self.analysisProgress = 1.0
            self.isAnalyzing = false
            
            // 创建分析结果
            self.currentDocument = DocumentAnalysisResult(
                id: UUID(),
                title: url.lastPathComponent,
                fileType: .video,
                content: content,
                creationDate: Date()
            )
            
            // 切换到文档视图
            self.activeView = .document
        }
    }
    
    /// 模拟文档分析进度（用于非特定文件类型）
    private func simulateDocumentAnalysis(url: URL, fileType: DocumentFileType) {
        // 模拟文档分析进度
        let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
        
        var progressSubscription: Cancellable?
        progressSubscription = timer.sink { _ in
            if self.analysisProgress < 1.0 {
                self.analysisProgress += 0.1
                
                if self.analysisProgress >= 1.0 {
                    self.isAnalyzing = false
                    progressSubscription?.cancel()
                    
                    // 分析完成，创建通用文档结果
                    let sections = self.createGenericSections()
                    let content = DocumentContent(sections: sections)
                    
                    self.currentDocument = DocumentAnalysisResult(
                        id: UUID(),
                        title: url.lastPathComponent,
                        fileType: fileType,
                        content: content,
                        creationDate: Date()
                    )
                    
                    // 切换到文档视图
                    self.activeView = .document
                }
            }
        }
    }
    
    /// 创建PDF文档章节（针对PDF文件优化）
    private func createPDFDocumentSections() -> [DocumentContent.Section] {
        return [
            DocumentContent.Section(
                title: "文档概览",
                items: [
                    .text("通过PDF分析引擎提取的内容"),
                    .text("文档包含多个章节和图表")
                ]
            ),
            DocumentContent.Section(
                title: "第一章：介绍",
                items: [
                    .text("这是PDF文档的第一章内容。"),
                    .text("主要包括背景介绍和项目概述。"),
                    .list(["项目背景", "研究目标", "预期成果"])
                ]
            ),
            DocumentContent.Section(
                title: "第二章：方法论",
                items: [
                    .text("详细介绍了研究和分析方法。"),
                    .table([
                        ["方法", "适用场景", "优势"],
                        ["定量分析", "数据处理", "精确性高"],
                        ["定性分析", "概念研究", "深度理解"],
                        ["混合方法", "复杂问题", "全面视角"]
                    ])
                ]
            ),
            DocumentContent.Section(
                title: "第三章：数据分析",
                items: [
                    .text("基于收集的数据进行的分析结果。"),
                    .text("数据显示了明显的趋势和模式。"),
                    .quote("数据是21世纪的新石油，但必须经过提炼才能发挥价值。", author: "数据科学家")
                ]
            ),
            DocumentContent.Section(
                title: "第四章：结论",
                items: [
                    .text("总结研究发现和主要贡献。"),
                    .list([
                        "发现1：用户行为模式与预期相符",
                        "发现2：市场需求呈现增长趋势",
                        "发现3：产品改进空间明确"
                    ]),
                    .text("这些结论为未来工作提供了明确方向。")
                ]
            )
        ]
    }
    
    /// 创建Word文档章节（针对Word文件优化）
    private func createWordDocumentSections() -> [DocumentContent.Section] {
        return [
            DocumentContent.Section(
                title: "执行摘要",
                items: [
                    .text("本报告通过Word文档分析提取，包含项目关键信息和发现。"),
                    .text("主要内容涵盖市场分析、竞争态势和战略建议。")
                ]
            ),
            DocumentContent.Section(
                title: "1. 市场概况",
                items: [
                    .text("当前市场状况分析和主要趋势。"),
                    .list([
                        "市场规模持续增长，年增长率约15%",
                        "用户需求向个性化和便捷性方向发展",
                        "移动端使用比例已超过65%"
                    ]),
                    .table([
                        ["区域", "市场份额", "增长率"],
                        ["北美", "35%", "12%"],
                        ["欧洲", "28%", "10%"],
                        ["亚太", "30%", "18%"],
                        ["其他", "7%", "8%"]
                    ])
                ]
            ),
            DocumentContent.Section(
                title: "2. 竞争分析",
                items: [
                    .text("主要竞争对手及其市场表现。"),
                    .text("竞争格局显示三家主要企业占据主导地位。"),
                    .table([
                        ["公司", "优势", "劣势"],
                        ["竞争对手A", "品牌认知度高", "产品更新缓慢"],
                        ["竞争对手B", "技术领先", "价格偏高"],
                        ["竞争对手C", "渠道丰富", "用户体验一般"]
                    ])
                ]
            ),
            DocumentContent.Section(
                title: "3. 产品策略",
                items: [
                    .text("基于市场和竞争分析的产品策略建议。"),
                    .list([
                        "强化核心功能，提升用户体验",
                        "开发创新特性，增加产品差异化",
                        "优化定价策略，提高性价比",
                        "扩展合作伙伴生态系统"
                    ]),
                    .quote("创新不仅是创造新产品，还包括创造新的价值和体验。", author: "产品总监")
                ]
            ),
            DocumentContent.Section(
                title: "4. 实施路线图",
                items: [
                    .text("战略实施的具体步骤和时间表。"),
                    .table([
                        ["阶段", "目标", "时间线"],
                        ["第一阶段", "市场调研和产品定位", "Q1"],
                        ["第二阶段", "核心功能开发", "Q2-Q3"],
                        ["第三阶段", "市场测试和优化", "Q3"],
                        ["第四阶段", "全面上市和推广", "Q4"]
                    ])
                ]
            ),
            DocumentContent.Section(
                title: "5. 结论与建议",
                items: [
                    .text("战略实施的预期成果和关键建议。"),
                    .list([
                        "持续监控市场变化，及时调整策略",
                        "重视用户反馈，快速迭代产品",
                        "加强团队协作，确保执行力",
                        "建立明确的成功指标和评估机制"
                    ])
                ]
            )
        ]
    }
    
    /// 导出文档
    private func exportDocument() {
        if currentDocument != nil {
            activeView = .export
        } else {
            errorMessage = "没有可导出的文档"
            showingImportError = true
        }
    }
    
    /// 切换模板库显示
    private func toggleTemplateLibrary() {
        withAnimation {
            showingTemplateLibrary.toggle()
            if showingTemplateLibrary {
                showingSettings = false
            }
        }
    }
    
    /// 切换设置显示
    private func toggleSettings() {
        withAnimation {
            showingSettings.toggle()
            if showingSettings {
                showingTemplateLibrary = false
            }
        }
    }
    
    /// 取消分析
    private func cancelAnalysis() {
        // 取消分析过程
        isAnalyzing = false
        currentAnalyzingURL = nil
        
        // 返回主页
        activeView = .home
    }
    
    /// 确定文件类型
    private func determineFileType(url: URL?) -> DocumentFileType {
        guard let url = url else {
            return .other
        }
        
        let extension = url.pathExtension.lowercased()
        
        switch extension {
        case "pdf":
            return .pdf
        case "doc", "docx":
            return .word
        case "txt", "md":
            return .text
        case "mp3", "wav", "m4a":
            return .audio
        case "mp4", "mov", "m4v":
            return .video
        default:
            return .other
        }
    }
}

// MARK: - 辅助类型

/// 模板项目
struct TemplateItem: Identifiable {
    var id: UUID
    var name: String
    var category: MainView.TemplateCategory
    var color: Color
    var isFavorite: Bool
    var popularity: Double
    var creationDate: Date = Date()
}

/// 文档内容
struct DocumentContent {
    var sections: [Section]
    
    struct Section {
        var title: String
        var items: [ContentItem]
    }
    
    enum ContentItem {
        case text(String)
        case list([String])
        case table([[String]])
        case code(String, language: String)
        case quote(String, author: String?)
        case image(UIImage)
    }
}

/// 文档分析结果
struct DocumentAnalysisResult: Identifiable {
    var id: UUID
    var title: String
    var fileType: DocumentFileType
    var content: DocumentContent
    var creationDate: Date
    
    /// 快速导出为PowerPoint
    func quickExportToPowerPoint() async throws {
        // 在实际应用中实现导出逻辑
        try await Task.sleep(nanoseconds: 2_000_000_000)
    }
    
    /// 快速导出为PDF
    func quickExportToPDF() async throws {
        // 在实际应用中实现导出逻辑
        try await Task.sleep(nanoseconds: 1_500_000_000)
    }
    
    /// 快速导出为图片
    func quickExportToImages() async throws {
        // 在实际应用中实现导出逻辑
        try await Task.sleep(nanoseconds: 1_800_000_000)
    }
    
    /// 快速导出为文本
    func quickExportToText() async throws {
        // 在实际应用中实现导出逻辑
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

/// 文档选择器
struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf,
            .plainText,
            .audio,
            .movie
        ])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // 不需要更新
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onDocumentPicked(url)
        }
    }
}

/// 主页视图（占位符）
struct HomeView: View {
    var body: some View {
        VStack {
            Text("OnlySlide")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            Text("轻松将文档转换为精美演示文稿")
                .font(.title3)
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
            
            Text("最近活动将显示在这里")
                .foregroundColor(.secondary)
                .padding()
        }
    }
}

/// 文档视图（占位符）
struct DocumentView: View {
    let document: DocumentAnalysisResult
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(document.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom)
                
                ForEach(0..<document.content.sections.count, id: \.self) { sectionIndex in
                    let section = document.content.sections[sectionIndex]
                    
                    Text(section.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    ForEach(0..<section.items.count, id: \.self) { itemIndex in
                        contentItemView(section.items[itemIndex])
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    func contentItemView(_ item: DocumentContent.ContentItem) -> some View {
        switch item {
        case .text(let text):
            Text(text)
                .padding(.vertical, 4)
        
        case .list(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { index in
                    HStack(alignment: .top) {
                        Text("•")
                            .padding(.trailing, 4)
                        Text(items[index])
                    }
                }
            }
            .padding(.vertical, 4)
            
        case .table(let rows):
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 0) {
                        ForEach(rows[rowIndex].indices, id: \.self) { colIndex in
                            Text(rows[rowIndex][colIndex])
                                .padding(8)
                                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                                .background(rowIndex == 0 ? Color.secondary.opacity(0.2) : (rowIndex % 2 == 1 ? Color.secondary.opacity(0.1) : Color.clear))
                                .border(Color.secondary.opacity(0.3), width: 0.5)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            
        case .code(let code, let language):
            VStack(alignment: .leading, spacing: 4) {
                Text(language)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                }
            }
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding(.vertical, 4)
            
        case .quote(let text, let author):
            VStack(alignment: .leading, spacing: 8) {
                Text("\"\(text)\"")
                    .italic()
                    .padding(.horizontal)
                
                if let author = author {
                    Text("— \(author)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding(.vertical, 4)
            
        case .image:
            // 简化实现，实际项目中应显示图片
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 200)
                .overlay(
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                )
                .cornerRadius(8)
                .padding(.vertical, 4)
        }
    }
}

// MARK: - 预览

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
} 
 