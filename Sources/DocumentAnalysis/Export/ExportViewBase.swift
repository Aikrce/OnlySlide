import SwiftUI

/// 通用导出视图状态
public class ExportViewState: ObservableObject {
    /// 是否正在导出
    @Published public var isExporting = false
    
    /// 是否显示导出对话框
    @Published public var showingExportDialog = false
    
    /// 导出的URL
    @Published public var exportURL: URL?
    
    /// 是否显示导出成功提示
    @Published public var showExportSuccess = false
    
    /// 是否显示导出错误提示
    @Published public var showExportError = false
    
    /// 错误消息
    @Published public var errorMessage = ""
    
    /// 初始化
    public init() {}
    
    /// 开始导出
    public func startExport() {
        isExporting = true
        showingExportDialog = true
    }
    
    /// 处理导出结果
    public func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            exportURL = url
            showExportSuccess = true
        case .failure(let error):
            errorMessage = error.localizedDescription
            showExportError = true
        }
        isExporting = false
    }
}

/// 导出视图基础协议
public protocol ExportViewProtocol {
    associatedtype ExportOptions
    
    /// 文档分析结果
    var documentResult: DocumentAnalysisResult { get }
    
    /// 导出选项
    var options: ExportOptions { get set }
    
    /// 视图状态
    var viewState: ExportViewState { get }
    
    /// 获取导出文件的默认文件名
    func getDefaultFilename() -> String
    
    /// 创建导出文档
    func createExportDocument() -> any FileDocument
}

/// 默认导出按钮
public struct ExportButton: View {
    let action: () -> Void
    let isExporting: Bool
    let title: String
    
    public init(
        action: @escaping () -> Void,
        isExporting: Bool,
        title: String
    ) {
        self.action = action
        self.isExporting = isExporting
        self.title = title
    }
    
    public var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                if isExporting {
                    ProgressView()
                        .padding(.trailing, 5)
                }
                Text(isExporting ? "导出中..." : title)
                Spacer()
            }
        }
        .disabled(isExporting)
    }
}

/// 文档信息部分
public struct DocumentInfoSection: View {
    let documentResult: DocumentAnalysisResult
    
    public init(documentResult: DocumentAnalysisResult) {
        self.documentResult = documentResult
    }
    
    public var body: some View {
        Section(header: Text("文档信息")) {
            LabeledContent("标题") {
                Text(documentResult.title)
                    .foregroundColor(.secondary)
            }
            
            LabeledContent("内容项") {
                Text("\(documentResult.totalContentItemCount) 项")
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// 导出成功/失败提示
public struct ExportAlerts: ViewModifier {
    @Binding var showExportSuccess: Bool
    @Binding var showExportError: Bool
    @Binding var errorMessage: String
    @Binding var exportURL: URL?
    let onDismiss: () -> Void
    
    public init(
        showExportSuccess: Binding<Bool>,
        showExportError: Binding<Bool>,
        errorMessage: Binding<String>,
        exportURL: Binding<URL?>,
        onDismiss: @escaping () -> Void
    ) {
        self._showExportSuccess = showExportSuccess
        self._showExportError = showExportError
        self._errorMessage = errorMessage
        self._exportURL = exportURL
        self.onDismiss = onDismiss
    }
    
    public func body(content: Content) -> some View {
        content
            .alert("导出成功", isPresented: $showExportSuccess) {
                Button("确定", role: .cancel) {
                    onDismiss()
                }
            } message: {
                if let url = exportURL {
                    Text("已成功导出到：\n\(url.path)")
                }
            }
            .alert("导出失败", isPresented: $showExportError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
    }
}

extension View {
    public func exportAlerts(
        showExportSuccess: Binding<Bool>,
        showExportError: Binding<Bool>,
        errorMessage: Binding<String>,
        exportURL: Binding<URL?>,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(ExportAlerts(
            showExportSuccess: showExportSuccess,
            showExportError: showExportError,
            errorMessage: errorMessage,
            exportURL: exportURL,
            onDismiss: onDismiss
        ))
    }
} 