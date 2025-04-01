import SwiftUI

/// 文档导出主视图，整合所有导出格式选项
struct ExportView: View {
    /// 文档分析结果
    let documentResult: DocumentAnalysisResult
    
    /// 导出格式
    @State private var selectedFormat: ExportFormat = .powerpoint
    
    /// 是否显示快速导出确认
    @State private var showingQuickExportConfirmation = false
    
    /// 导出完成警告
    @State private var showingExportDoneAlert = false
    
    /// 导出错误警告
    @State private var showingExportErrorAlert = false
    
    /// 错误消息
    @State private var errorMessage = ""
    
    /// 导出格式枚举
    enum ExportFormat: String, CaseIterable, Identifiable {
        case powerpoint = "PowerPoint"
        case pdf = "PDF"
        case images = "图片"
        case text = "文本"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .powerpoint: return "doc.richtext"
            case .pdf: return "doc.text"
            case .images: return "photo.on.rectangle"
            case .text: return "doc.plaintext"
            }
        }
        
        var description: String {
            switch self {
            case .powerpoint:
                return "导出为标准PowerPoint演示文件，保留布局、样式和动画效果。"
            case .pdf:
                return "创建PDF格式的静态演示文件，适合跨平台分享和打印。"
            case .images:
                return "将每张幻灯片导出为高质量图片，支持PNG、JPEG格式，可选压缩包导出。"
            case .text:
                return "提取文档内容为纯文本或Markdown格式，便于编辑和内容重用。"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("导出")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    showingQuickExportConfirmation = true
                }) {
                    Text("快速导出")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .alert("快速导出", isPresented: $showingQuickExportConfirmation) {
                    Button("取消", role: .cancel) {}
                    Button("导出") {
                        performQuickExport()
                    }
                } message: {
                    Text("是否使用默认设置快速导出为\(selectedFormat.rawValue)格式？")
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // 分隔线
            Divider()
            
            // 主内容区域
            HStack(spacing: 0) {
                // 左侧格式选择列表
                VStack(spacing: 0) {
                    List(ExportFormat.allCases, selection: $selectedFormat) { format in
                        HStack {
                            Image(systemName: format.icon)
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            Text(format.rawValue)
                                .font(.headline)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Divider()
                    
                    // 格式描述
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedFormat.rawValue)
                            .font(.headline)
                        
                        Text(selectedFormat.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                }
                .frame(width: 250)
                .background(Color(.systemBackground))
                
                // 分隔线
                Divider()
                
                // 右侧格式特定视图
                formatSpecificView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("导出成功", isPresented: $showingExportDoneAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("文档已成功导出为\(selectedFormat.rawValue)格式。")
        }
        .alert("导出失败", isPresented: $showingExportErrorAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    /// 根据选择的格式显示对应的视图
    private var formatSpecificView: some View {
        Group {
            switch selectedFormat {
            case .powerpoint:
                PowerPointExportView(documentResult: documentResult)
            case .pdf:
                PDFExportView(documentResult: documentResult)
            case .images:
                ImagesExportView(documentResult: documentResult)
            case .text:
                TextExportView(documentResult: documentResult)
            }
        }
    }
    
    /// 执行快速导出
    private func performQuickExport() {
        Task {
            do {
                // 基于所选格式执行快速导出
                switch selectedFormat {
                case .powerpoint:
                    try await documentResult.quickExportToPowerPoint()
                case .pdf:
                    try await documentResult.quickExportToPDF()
                case .images:
                    try await documentResult.quickExportToImages()
                case .text:
                    try await documentResult.quickExportToText()
                }
                
                // 显示成功消息
                await MainActor.run {
                    showingExportDoneAlert = true
                }
            } catch {
                // 显示错误消息
                await MainActor.run {
                    errorMessage = "导出失败: \(error.localizedDescription)"
                    showingExportErrorAlert = true
                }
            }
        }
    }
}

/// 占位的PowerPoint导出视图
struct PowerPointExportView: View {
    let documentResult: DocumentAnalysisResult
    
    var body: some View {
        VStack {
            Text("PowerPoint导出选项")
                .font(.title)
            
            Text("此处将显示PowerPoint导出的详细选项")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 占位的PDF导出视图
struct PDFExportView: View {
    let documentResult: DocumentAnalysisResult
    
    var body: some View {
        VStack {
            Text("PDF导出选项")
                .font(.title)
            
            Text("此处将显示PDF导出的详细选项")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
} 