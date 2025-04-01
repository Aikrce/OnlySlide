import SwiftUI

/// 文本导出设置视图
public struct TextExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    let documentResult: DocumentAnalysisResult
    @State private var options: TextExportOptions = TextExportOptions()
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
                Section(header: Text("文本格式")) {
                    Picker("输出格式", selection: $options.format) {
                        ForEach(TextExportOptions.TextFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    
                    Picker("换行符", selection: $options.lineEnding) {
                        ForEach(TextExportOptions.LineEnding.allCases) { ending in
                            Text(ending.rawValue).tag(ending)
                        }
                    }
                    
                    Picker("字符编码", selection: $options.encoding) {
                        ForEach(TextExportOptions.Encoding.allCases) { encoding in
                            Text(encoding.rawValue).tag(encoding)
                        }
                    }
                }
                
                Section(header: Text("内容选项")) {
                    Toggle("包含标题", isOn: $options.includeTitle)
                    Toggle("包含目录", isOn: $options.includeTableOfContents)
                    Toggle("包含元数据", isOn: $options.includeMetadata)
                    Toggle("缩进内容", isOn: $options.indentContent)
                    Toggle("添加项目编号", isOn: $options.addNumbering)
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
                    
                    LabeledContent("预计输出格式") {
                        Text(".\(options.format.fileExtension) (\(options.encoding.rawValue))")
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
                            Text(isExporting ? "导出中..." : "导出为文本")
                            Spacer()
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .navigationTitle("文本导出选项")
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
            document: TextExportDocument(result: documentResult, options: options),
            contentType: .plainText,
            defaultFilename: "\(documentResult.title).\(options.format.fileExtension)"
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
                Text("已成功导出文本到：\n\(url.path)")
            }
        }
        .alert("导出失败", isPresented: $showExportError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    /// 开始导出
    private func startExport() {
        isExporting = true
        showingExportDialog = true
    }
}

/// 文本导出文件包装类
struct TextExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    
    let result: DocumentAnalysisResult
    let options: TextExportOptions
    
    init(result: DocumentAnalysisResult, options: TextExportOptions) {
        self.result = result
        self.options = options
    }
    
    init(configuration: ReadConfiguration) throws {
        // 目前只支持导出，不支持读取
        throw CocoaError(.fileReadUnsupportedScheme)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // 创建临时URL用于导出
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(options.format.fileExtension)
        
        // 导出到临时URL
        guard result.exportToText(url: tempURL, options: options) else {
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
struct TextExportView_Previews: PreviewProvider {
    static var previews: some View {
        TextExportView(documentResult: DocumentAnalysisExample.createSampleResult())
    }
} 