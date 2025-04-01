import SwiftUI

/// PowerPoint导出视图（适配基础架构）
public struct PowerPointExportViewBase: View, ExportViewProtocol {
    /// 文档分析结果
    public let documentResult: DocumentAnalysisResult
    
    /// 导出选项
    @State public var options: PowerPointExportOptions
    
    /// 视图状态
    @StateObject public var viewState = ExportViewState()
    
    /// 初始化
    /// - Parameter documentResult: 文档分析结果
    public init(documentResult: DocumentAnalysisResult) {
        self.documentResult = documentResult
        self._options = State(initialValue: PowerPointExportOptions())
    }
    
    /// 创建导出文档
    public func createExportDocument() -> any FileDocument {
        return PowerPointExportDocument(result: documentResult, options: options)
    }
    
    /// 获取默认文件名
    public func getDefaultFilename() -> String {
        return "\(documentResult.title).pptx"
    }
    
    public var body: some View {
        NavigationView {
            Form {
                // 幻灯片设置
                Section(header: Text("幻灯片设置")) {
                    Picker("幻灯片大小", selection: $options.slideSize) {
                        Text("标准 (4:3)").tag(PowerPointExportOptions.SlideSize.standard)
                        Text("宽屏 (16:9)").tag(PowerPointExportOptions.SlideSize.widescreen)
                    }
                    
                    Picker("主题", selection: $options.theme) {
                        ForEach(PowerPointExportOptions.Theme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    
                    Picker("过渡效果", selection: $options.transitionEffect) {
                        ForEach(PowerPointExportOptions.TransitionEffect.allCases) { effect in
                            Text(effect.rawValue).tag(effect)
                        }
                    }
                    
                    Stepper("每页最大内容项: \(options.maxItemsPerSlide)", value: $options.maxItemsPerSlide, in: 1...10)
                }
                
                // 内容选项
                Section(header: Text("内容选项")) {
                    Toggle("包含封面页", isOn: $options.includeCoverSlide)
                    Toggle("包含目录页", isOn: $options.includeTableOfContents)
                    Toggle("显示页码", isOn: $options.includePageNumbers)
                    
                    if options.includePageNumbers {
                        TextField("页脚文本", text: $options.footerText)
                    }
                    
                    Toggle("生成演讲者备注", isOn: $options.generateNotes)
                }
                
                // 文档信息
                DocumentInfoSection(documentResult: documentResult)
                
                // 预估幻灯片数量
                Section {
                    LabeledContent("预估幻灯片数量") {
                        Text("\(estimatedSlideCount)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // 导出按钮
                Section {
                    ExportButton(
                        action: startExport,
                        isExporting: viewState.isExporting,
                        title: "导出PowerPoint文档"
                    )
                }
            }
            .navigationTitle("PowerPoint导出")
            .fileExporter(
                isPresented: $viewState.showingExportDialog,
                document: createExportDocument(),
                contentType: UTType(filenameExtension: "pptx") ?? .data,
                defaultFilename: getDefaultFilename(),
                onCompletion: { result in
                    switch result {
                    case .success(let url):
                        viewState.handleExportResult(.success(url))
                    case .failure(let error):
                        viewState.handleExportResult(.failure(error))
                    }
                }
            )
            .exportAlerts(
                showExportSuccess: $viewState.showExportSuccess,
                showExportError: $viewState.showExportError,
                errorMessage: $viewState.errorMessage,
                exportURL: $viewState.exportURL,
                onDismiss: {}
            )
        }
    }
    
    /// 预估幻灯片数量
    private var estimatedSlideCount: Int {
        var count = 0
        
        // 封面页
        if options.includeCoverSlide {
            count += 1
        }
        
        // 目录页
        if options.includeTableOfContents {
            count += 1
        }
        
        // 内容页
        let contentItemCount = documentResult.totalContentItemCount
        let contentSlideCount = (contentItemCount + options.maxItemsPerSlide - 1) / options.maxItemsPerSlide
        
        count += contentSlideCount
        
        return count
    }
    
    /// 开始导出
    private func startExport() {
        viewState.startExport()
    }
}

/// 预览
struct PowerPointExportViewBase_Previews: PreviewProvider {
    static var previews: some View {
        PowerPointExportViewBase(documentResult: DocumentAnalysisExample.createSampleResult())
    }
} 