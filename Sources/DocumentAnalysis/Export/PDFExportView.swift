import SwiftUI

/// PDF导出设置视图
public struct PDFExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    let documentResult: DocumentAnalysisResult
    @State private var options: PDFExportOptions = PDFExportOptions()
    @State private var isExporting = false
    @State private var showingExportDialog = false
    @State private var exportURL: URL?
    @State private var showExportSuccess = false
    @State private var showExportError = false
    @State private var errorMessage = ""
    
    public init(documentResult: DocumentAnalysisResult) {
        self.documentResult = documentResult
        
        // 设置默认页眉为文档标题
        _options = State(initialValue: {
            var opt = PDFExportOptions()
            opt.headerText = documentResult.title
            return opt
        }())
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本设置")) {
                    Toggle("包含目录", isOn: $options.includeTableOfContents)
                    Toggle("包含页码", isOn: $options.includePageNumbers)
                    Toggle("包含页眉页脚", isOn: $options.includeHeaderFooter)
                }
                
                if options.includeHeaderFooter {
                    Section(header: Text("页眉页脚")) {
                        TextField("页眉文本", text: $options.headerText)
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
                    
                    LabeledContent("预计页数") {
                        Text("\(estimatedPageCount) 页")
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
                            Text(isExporting ? "导出中..." : "导出为PDF")
                            Spacer()
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .navigationTitle("PDF导出选项")
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
            document: PDFExportDocument(result: documentResult, options: options),
            contentType: .pdf,
            defaultFilename: "\(documentResult.title).pdf"
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
                Text("已成功导出PDF到：\n\(url.path)")
            }
        }
        .alert("导出失败", isPresented: $showExportError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    /// 估计PDF页数
    private var estimatedPageCount: Int {
        // 简单估算：
        // 1. 如果有目录，加1页
        // 2. 每个section加1页
        // 3. 每10个内容项加1页
        var pageCount = documentResult.sections.count
        
        if options.includeTableOfContents {
            pageCount += 1
        }
        
        // 额外页数取决于内容项的数量和复杂度
        let contentItemCount = documentResult.totalContentItemCount
        pageCount += contentItemCount / 10
        
        return max(pageCount, 1)
    }
    
    /// 开始导出
    private func startExport() {
        isExporting = true
        showingExportDialog = true
    }
}

/// PDF导出文件包装类
struct PDFExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    
    let result: DocumentAnalysisResult
    let options: PDFExportOptions
    
    init(result: DocumentAnalysisResult, options: PDFExportOptions) {
        self.result = result
        self.options = options
    }
    
    init(configuration: ReadConfiguration) throws {
        // 目前只支持导出，不支持读取
        throw CocoaError(.fileReadUnsupportedScheme)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = result.exportToPDFData(options: options) else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        return FileWrapper(regularFileWithContents: data)
    }
}

/// 预览
struct PDFExportView_Previews: PreviewProvider {
    static var previews: some View {
        PDFExportView(documentResult: DocumentAnalysisExample.createSampleResult())
    }
} 