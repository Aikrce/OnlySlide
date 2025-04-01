import SwiftUI

/// 文档导出视图
public struct DocumentExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    /// 文档分析结果
    let documentResult: DocumentAnalysisResult
    
    /// 选择的导出格式
    @State private var selectedFormat: DocumentExportFormat = .pdf
    
    /// 是否显示格式特定的选项视图
    @State private var showFormatOptions = false
    
    public init(documentResult: DocumentAnalysisResult) {
        self.documentResult = documentResult
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 标题和说明
                VStack(alignment: .leading, spacing: 8) {
                    Text("导出文档")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("选择导出格式并自定义导出选项")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // 文档信息卡片
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: documentResult.sourceType.iconName)
                            .font(.title)
                        
                        VStack(alignment: .leading) {
                            Text(documentResult.title)
                                .font(.headline)
                            
                            Text("\(documentResult.sourceType.displayName) · \(documentResult.sections.count) 章节 · \(documentResult.totalContentItemCount) 内容项")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .padding(.horizontal)
                
                // 格式选择
                VStack(alignment: .leading, spacing: 8) {
                    Text("导出格式")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(DocumentExportFormat.allCases) { format in
                        FormatSelectionButton(
                            format: format,
                            isSelected: selectedFormat == format,
                            action: {
                                selectedFormat = format
                            }
                        )
                    }
                }
                
                Spacer()
                
                // 按钮区域
                VStack(spacing: 12) {
                    Button(action: {
                        showFormatOptions = true
                    }) {
                        HStack {
                            Text("设置导出选项")
                            Spacer()
                            Image(systemName: "gear")
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: performQuickExport) {
                        Text("快速导出")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.accentColor)
                            )
                            .foregroundColor(.white)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showFormatOptions) {
                formatSpecificView
            }
        }
    }
    
    /// 根据所选格式返回对应的设置视图
    @ViewBuilder
    private var formatSpecificView: some View {
        switch selectedFormat {
        case .pdf:
            PDFExportView(documentResult: documentResult)
        case .powerPoint:
            PowerPointExportView(documentResult: documentResult)
        case .images:
            ImagesExportView(documentResult: documentResult)
        case .text:
            TextExportView(documentResult: documentResult)
        }
    }
    
    /// 执行快速导出
    private func performQuickExport() {
        switch selectedFormat {
        case .pdf:
            Task {
                _ = await documentResult.quickExportToPDF()
            }
        case .powerPoint:
            Task {
                _ = await documentResult.quickExportToPowerPoint()
            }
        case .images:
            Task {
                _ = await documentResult.quickExportToImages()
            }
        case .text:
            Task {
                _ = await documentResult.quickExportToText()
            }
        }
        
        // 关闭视图
        dismiss()
    }
}

/// 格式选择按钮
struct FormatSelectionButton: View {
    let format: DocumentExportFormat
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: format.iconName)
                    .font(.title3)
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading) {
                    Text(format.displayName)
                        .font(.body)
                    
                    Text(formatDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
    
    /// 格式描述
    private var formatDescription: String {
        switch format {
        case .pdf:
            return "便携式文档格式，广泛兼容"
        case .powerPoint:
            return "Microsoft PowerPoint演示文稿"
        case .images:
            return "将内容导出为图片集合"
        case .text:
            return "纯文本格式，无格式排版"
        }
    }
}

/// 预览
struct DocumentExportView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentExportView(documentResult: DocumentAnalysisExample.createSampleResult())
    }
} 