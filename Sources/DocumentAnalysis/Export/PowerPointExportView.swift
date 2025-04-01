import SwiftUI

/// PowerPoint导出设置视图
public struct PowerPointExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    let documentResult: DocumentAnalysisResult
    @State private var options: PowerPointExportOptions = PowerPointExportOptions()
    @State private var isExporting = false
    @State private var showingExportDialog = false
    @State private var exportURL: URL?
    @State private var showExportSuccess = false
    @State private var showExportError = false
    @State private var errorMessage = ""
    
    public init(documentResult: DocumentAnalysisResult) {
        self.documentResult = documentResult
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("幻灯片设置")) {
                    Picker("幻灯片比例", selection: $options.slideSize) {
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
                    
                    Stepper("每页最大内容项: \(options.maxItemsPerSlide)", value: $options.maxItemsPerSlide, in: 3...10)
                }
                
                Section(header: Text("内容选项")) {
                    Toggle("包含封面", isOn: $options.includeCoverSlide)
                    Toggle("包含目录", isOn: $options.includeTableOfContents)
                    Toggle("包含页码", isOn: $options.includePageNumbers)
                    Toggle("自动生成演讲备注", isOn: $options.generateNotes)
                }
                
                if options.includePageNumbers {
                    Section(header: Text("页脚设置")) {
                        TextField("页脚文本", text: $options.footerText)
                    }
                }
                
                Section(header: Text("文档信息")) {
                    LabeledContent("标题") {
                        Text(documentResult.title)
                            .foregroundColor(.secondary)
                    }
                    
                    LabeledContent("内容项") {
                        Text("\(documentResult.totalContentItemCount) 项")
                            .foregroundColor(.secondary)
                    }
                    
                    LabeledContent("预计幻灯片数") {
                        Text("\(estimatedSlideCount) 张")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(action: startExport) {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .padding(.trailing, 5)
                            }
                            Text(isExporting ? "导出中..." : "导出为PowerPoint")
                            Spacer()
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .navigationTitle("PowerPoint导出选项")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isExporting)
                }
            }
        }
        .fileExporter(
            isPresented: $showingExportDialog,
            document: PowerPointExportDocument(result: documentResult, options: options),
            contentType: .data,
            defaultFilename: "\(documentResult.title).pptx"
        ) { result in
            switch result {
            case .success(let url):
                self.exportURL = url
                self.showExportSuccess = true
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.showExportError = true
            }
            self.isExporting = false
        }
        .alert("导出成功", isPresented: $showExportSuccess) {
            Button("确定", role: .cancel) {
                dismiss()
            }
        } message: {
            if let url = exportURL {
                Text("已成功导出PowerPoint到：\n\(url.path)")
            }
        }
        .alert("导出失败", isPresented: $showExportError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    /// 估计幻灯片数
    private var estimatedSlideCount: Int {
        var slideCount = 0
        
        // 封面
        if options.includeCoverSlide {
            slideCount += 1
        }
        
        // 目录
        if options.includeTableOfContents {
            slideCount += 1
        }
        
        // 标题幻灯片 + 内容幻灯片
        for section in documentResult.sections {
            slideCount += 1 // 标题幻灯片
            
            let contentItemCount = section.contentItems.count
            slideCount += contentItemCount / options.maxItemsPerSlide
            if contentItemCount % options.maxItemsPerSlide > 0 {
                slideCount += 1
            }
        }
        
        return max(slideCount, 1)
    }
    
    /// 开始导出
    private func startExport() {
        isExporting = true
        showingExportDialog = true
    }
}

/// PowerPoint导出文件包装类
struct PowerPointExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    
    let result: DocumentAnalysisResult
    let options: PowerPointExportOptions
    
    init(result: DocumentAnalysisResult, options: PowerPointExportOptions) {
        self.result = result
        self.options = options
    }
    
    init(configuration: ReadConfiguration) throws {
        // 目前只支持导出，不支持读取
        throw CocoaError(.fileReadUnsupportedScheme)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // 创建临时URL用于导出
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pptx")
        
        // 导出到临时URL
        guard result.exportToPowerPoint(url: tempURL, options: options) else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        // 读取文件数据
        guard let data = try? Data(contentsOf: tempURL) else {
            throw CocoaError(.fileReadUnknown)
        }
        
        // 删除临时文件
        try? FileManager.default.removeItem(at: tempURL)
        
        return FileWrapper(regularFileWithContents: data)
    }
}

/// 预览
struct PowerPointExportView_Previews: PreviewProvider {
    static var previews: some View {
        PowerPointExportView(documentResult: DocumentAnalysisExample.createSampleResult())
    }
} 