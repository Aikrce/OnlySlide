import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 文档分析功能的主视图
public struct DocumentAnalysisView: View, DocumentFilePickerDelegate {
    @State private var isFilePickerPresented = false
    @State private var selectedDocument: DocumentAnalysisResult?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var engine = DocumentAnalysisEngine()
    @State private var showingSavedResults = false
    @State private var selectedFileTypes: [UTType] = DocumentFilePicker.textDocumentTypes
    
    public init() {
        // 初始化引擎
        _engine = State(initialValue: DocumentAnalysisUtil.createEngine())
    }
    
    public var body: some View {
        VStack {
            if isAnalyzing {
                ProgressView("分析文档中...")
                    .padding()
            } else if let document = selectedDocument {
                DocumentAnalysisResultView(result: document)
            } else {
                contentView
            }
        }
        .navigationTitle("文档分析")
        .toolbar {
            if selectedDocument != nil {
                Button("清除") {
                    selectedDocument = nil
                    errorMessage = nil
                }
            } else {
                Button(action: { showingSavedResults = true }) {
                    Label("已保存", systemImage: "folder")
                }
            }
        }
        .documentFilePicker(
            isPresented: $isFilePickerPresented,
            supportedTypes: selectedFileTypes,
            delegate: self
        )
        .sheet(isPresented: $showingSavedResults) {
            NavigationView {
                SavedResultsListView()
                    .navigationBarItems(trailing: Button("关闭") {
                        showingSavedResults = false
                    })
            }
        }
        .alert(
            "分析错误",
            isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            actions: { Button("确定", role: .cancel) {} },
            message: { 
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        )
    }
    
    private var contentView: some View {
        VStack(spacing: 30) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("文档分析")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("分析文档内容，提取结构化信息")
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                Button(action: {
                    selectedFileTypes = DocumentFilePicker.textDocumentTypes
                    isFilePickerPresented = true
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("选择文本文件")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: {
                    selectedFileTypes = DocumentFilePicker.richTextDocumentTypes
                    isFilePickerPresented = true
                }) {
                    HStack {
                        Image(systemName: "doc.richtext")
                        Text("选择Word文档")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: {
                    selectedFileTypes = [UTType.pdf]
                    isFilePickerPresented = true
                }) {
                    HStack {
                        Image(systemName: "doc.text.viewfinder")
                        Text("选择PDF文档")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: analyzeExampleDocument) {
                    HStack {
                        Image(systemName: "text.book.closed")
                        Text("分析示例文档")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: { showingSavedResults = true }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("查看已保存的分析")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
            
            Text("支持纯文本、Word和PDF文档")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - DocumentFilePickerDelegate
    
    public func didPickDocuments(urls: [URL]) {
        guard let url = urls.first else { return }
        analyzeDocument(at: url)
    }
    
    public func didFailPickingDocuments(error: Error) {
        errorMessage = "选择文件失败: \(error.localizedDescription)"
    }
    
    // MARK: - 文档分析方法
    
    private func analyzeDocument(at url: URL) {
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                let data = try Data(contentsOf: url)
                let result = try await engine.analyze(content: data, filename: url.lastPathComponent)
                
                await MainActor.run {
                    selectedDocument = result
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "分析失败: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
    
    private func analyzeExampleDocument() {
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                if let result = await DocumentAnalysisUtil.analyzeExampleText() {
                    await MainActor.run {
                        selectedDocument = result
                        isAnalyzing = false
                    }
                } else {
                    throw NSError(domain: "DocumentAnalysis", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法分析示例文档"])
                }
            } catch {
                await MainActor.run {
                    errorMessage = "分析失败: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
}

// MARK: - 预览
struct DocumentAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // iOS 预览
            NavigationView {
                DocumentAnalysisView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .previewDevice(PreviewDevice(rawValue: "iPhone 13"))
            .previewDisplayName("iOS - iPhone 13")
            
            // macOS 预览
            NavigationView {
                DocumentAnalysisView()
            }
            .frame(width: 1000, height: 700)
            .previewDevice(PreviewDevice(rawValue: "Mac"))
            .previewDisplayName("macOS")
            
            // iPad 预览
            NavigationView {
                DocumentAnalysisView()
            }
            .navigationViewStyle(DoubleColumnNavigationViewStyle())
            .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (5th generation)"))
            .previewDisplayName("iPadOS")
        }
    }
} 