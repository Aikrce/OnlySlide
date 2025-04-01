import SwiftUI

/// 图片导出设置视图
public struct ImagesExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    let documentResult: DocumentAnalysisResult
    @State private var options: ImagesExportOptions = ImagesExportOptions()
    @State private var isExporting = false
    @State private var showingExportDialog = false
    @State private var exportURL: URL?
    @State private var showExportSuccess = false
    @State private var showExportError = false
    @State private var errorMessage = ""
    
    public init(documentResult: DocumentAnalysisResult) {
        self.documentResult = documentResult
        
        // 设置默认水印
        _options = State(initialValue: {
            var opt = ImagesExportOptions()
            opt.watermarkText = documentResult.title
            return opt
        }())
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("图片设置")) {
                    Picker("图片格式", selection: $options.format) {
                        Text("PNG (无损)").tag(ImagesExportOptions.ImageFormat.png)
                        Text("JPEG").tag(ImagesExportOptions.ImageFormat.jpeg)
                    }
                    
                    if options.format == .jpeg {
                        VStack {
                            HStack {
                                Text("压缩质量: \(Int(options.quality * 100))%")
                                Spacer()
                            }
                            Slider(value: $options.quality, in: 0.1...1.0, step: 0.1)
                        }
                    }
                    
                    Picker("图片尺寸", selection: $options.imageSize) {
                        Text("HD (1280×720)").tag(CGSize(width: 1280, height: 720))
                        Text("Full HD (1920×1080)").tag(CGSize(width: 1920, height: 1080))
                        Text("2K (2560×1440)").tag(CGSize(width: 2560, height: 1440))
                        Text("4K (3840×2160)").tag(CGSize(width: 3840, height: 2160))
                    }
                }
                
                Section(header: Text("内容选项")) {
                    Toggle("包含封面图片", isOn: $options.includeCoverImage)
                    Toggle("包含目录图片", isOn: $options.includeTableOfContents)
                    Toggle("添加页码", isOn: $options.includePageNumbers)
                    Toggle("添加水印", isOn: $options.includeWatermark)
                }
                
                if options.includeWatermark {
                    Section(header: Text("水印设置")) {
                        TextField("水印文本", text: $options.watermarkText)
                    }
                }
                
                Section(header: Text("输出选项")) {
                    Toggle("打包为ZIP文件", isOn: $options.compressToZIP)
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
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
                    
                    LabeledContent("预计图片数") {
                        Text("\(estimatedImageCount) 张")
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
                            Text(isExporting ? "导出中..." : "导出为图片")
                            Spacer()
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .navigationTitle("图片导出选项")
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
            document: ImagesExportDocument(result: documentResult, options: options),
            contentType: options.compressToZIP ? .archive : .folder,
            defaultFilename: options.compressToZIP ? "\(documentResult.title).zip" : documentResult.title
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
                Text("已成功导出图片到：\n\(url.path)")
            }
        }
        .alert("导出失败", isPresented: $showExportError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    /// 估计图片数量
    private var estimatedImageCount: Int {
        var imageCount = 0
        
        // 封面
        if options.includeCoverImage {
            imageCount += 1
        }
        
        // 目录
        if options.includeTableOfContents {
            imageCount += 1
        }
        
        // 每个章节的标题和内容图片
        for section in documentResult.sections {
            // 章节标题图片
            imageCount += 1
            
            // 内容图片（每10个内容项约1张图片）
            let contentItemCount = section.contentItems.count
            let contentImageCount = (contentItemCount / 10) + (contentItemCount % 10 > 0 ? 1 : 0)
            imageCount += contentImageCount
        }
        
        return imageCount
    }
    
    /// 开始导出
    private func startExport() {
        isExporting = true
        showingExportDialog = true
    }
}

/// 图片导出文件包装类
struct ImagesExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.archive, .folder] }
    
    let result: DocumentAnalysisResult
    let options: ImagesExportOptions
    
    init(result: DocumentAnalysisResult, options: ImagesExportOptions) {
        self.result = result
        self.options = options
    }
    
    init(configuration: ReadConfiguration) throws {
        // 目前只支持导出，不支持读取
        throw CocoaError(.fileReadUnsupportedScheme)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        if options.compressToZIP {
            // 创建临时URL用于导出ZIP
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("zip")
            
            // 导出到临时URL
            guard result.exportToImages(url: tempURL, options: options) else {
                throw CocoaError(.fileWriteUnknown)
            }
            
            // 读取文件数据
            guard let data = try? Data(contentsOf: tempURL) else {
                throw CocoaError(.fileReadUnknown)
            }
            
            // 删除临时文件
            try? FileManager.default.removeItem(at: tempURL)
            
            return FileWrapper(regularFileWithContents: data)
        } else {
            // 创建临时目录用于导出图片
            let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            
            // 导出到临时目录
            guard result.exportToImages(url: tempDirectory, options: options) else {
                throw CocoaError(.fileWriteUnknown)
            }
            
            // 创建目录文件包装器
            var fileWrappers = [String: FileWrapper]()
            
            // 获取临时目录中的所有文件
            let fileURLs = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs {
                let fileName = fileURL.lastPathComponent
                let fileData = try Data(contentsOf: fileURL)
                let fileWrapper = FileWrapper(regularFileWithContents: fileData)
                fileWrappers[fileName] = fileWrapper
            }
            
            // 删除临时目录
            try? FileManager.default.removeItem(at: tempDirectory)
            
            return FileWrapper(directoryWithFileWrappers: fileWrappers)
        }
    }
}

/// 预览
struct ImagesExportView_Previews: PreviewProvider {
    static var previews: some View {
        ImagesExportView(documentResult: DocumentAnalysisExample.createSampleResult())
    }
} 