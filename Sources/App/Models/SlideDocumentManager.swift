import Foundation
import SwiftUI

/// 幻灯片文档结构
struct SlideDocument: Codable {
    var slides: [SlideContent]
    var metadata: DocumentMetadata
    var lastModified: Date = Date()
    var version: String = "1.0.0"
    
    init(slides: [SlideContent] = [], 
         metadata: DocumentMetadata = DocumentMetadata()) {
        self.slides = slides
        self.metadata = metadata
    }
}

/// 文档元数据
struct DocumentMetadata: Codable {
    var title: String = "未命名演示文稿"
    var author: String = ""
    var theme: String = "standard"
    var createdAt: Date = Date()
    var tags: [String] = []
    var description: String = ""
    
    // 从系统获取当前用户名
    static func getCurrentUserName() -> String {
        #if os(macOS)
        return NSFullUserName()
        #else
        return UIDevice.current.name
        #endif
    }
    
    init() {
        self.author = DocumentMetadata.getCurrentUserName()
    }
}

/// 文档操作结果
enum DocumentResult {
    case success
    case failure(Error)
}

/// 文档管理错误类型
enum DocumentError: Error {
    case saveFailed
    case loadFailed
    case fileNotFound
    case invalidData
    case userCancelled
    
    var localizedDescription: String {
        switch self {
        case .saveFailed: return "保存文档失败"
        case .loadFailed: return "加载文档失败"
        case .fileNotFound: return "找不到文件"
        case .invalidData: return "无效的文档数据"
        case .userCancelled: return "用户取消操作"
        }
    }
}

/// 幻灯片文档管理器 - 管理文档的保存、加载和状态
class SlideDocumentManager: ObservableObject {
    // 当前文档
    @Published var currentDocument: SlideDocument = SlideDocument()
    
    // 文档URL
    @Published var documentURL: URL?
    
    // 文档状态
    @Published var isDocumentSaved: Bool = true
    @Published var isNewDocument: Bool = true
    
    // 最近文件列表
    @Published var recentDocuments: [URL] = []
    
    // 通过URL加载文档
    func loadDocument(from url: URL) async -> DocumentResult {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let document = try decoder.decode(SlideDocument.self, from: data)
            
            // 在主线程更新UI
            await MainActor.run {
                self.currentDocument = document
                self.documentURL = url
                self.isDocumentSaved = true
                self.isNewDocument = false
                
                // 更新最近文件列表
                self.addToRecentDocuments(url)
            }
            
            return .success
        } catch {
            print("加载文档失败: \(error.localizedDescription)")
            return .failure(DocumentError.loadFailed)
        }
    }
    
    // 保存文档
    func saveDocument() async -> DocumentResult {
        // 更新最后修改时间
        currentDocument.lastModified = Date()
        
        // 文档没有URL，需要执行"另存为"
        if documentURL == nil {
            return await saveDocumentAs()
        }
        
        // 保存到当前URL
        return await saveDocument(to: documentURL!)
    }
    
    // 另存为
    func saveDocumentAs() async -> DocumentResult {
        // 使用平台特定的文件选择器
        #if os(macOS)
        return await withCheckedContinuation { continuation in
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.init(filenameExtension: "onlyslide")!]
            savePanel.canCreateDirectories = true
            savePanel.isExtensionHidden = false
            savePanel.title = "保存演示文稿"
            savePanel.message = "选择保存位置"
            savePanel.nameFieldLabel = "文件名:"
            savePanel.nameFieldStringValue = currentDocument.metadata.title
            
            DispatchQueue.main.async {
                let response = savePanel.runModal()
                
                if response == .OK, let url = savePanel.url {
                    Task {
                        let result = await self.saveDocument(to: url)
                        continuation.resume(returning: result)
                    }
                } else {
                    continuation.resume(returning: .failure(DocumentError.userCancelled))
                }
            }
        }
        #else
        // iOS实现
        // 由于iOS上的文件选择需要UI交互，这里返回错误
        return .failure(DocumentError.saveFailed)
        #endif
    }
    
    // 保存到指定URL
    private func saveDocument(to url: URL) async -> DocumentResult {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(currentDocument)
            try data.write(to: url)
            
            // 在主线程更新UI
            await MainActor.run {
                self.documentURL = url
                self.isDocumentSaved = true
                self.isNewDocument = false
                
                // 更新最近文件列表
                self.addToRecentDocuments(url)
            }
            
            return .success
        } catch {
            print("保存文档失败: \(error.localizedDescription)")
            return .failure(DocumentError.saveFailed)
        }
    }
    
    // 创建新文档
    func newDocument() {
        currentDocument = SlideDocument(
            slides: [SlideContent(title: "欢迎使用OnlySlide", content: "创建专业演示文稿的最佳工具")]
        )
        documentURL = nil
        isDocumentSaved = false
        isNewDocument = true
    }
    
    // 标记文档已修改
    func markDocumentAsModified() {
        isDocumentSaved = false
    }
    
    // 从视图模型更新文档
    func updateFromViewModel(_ viewModel: SlideEditorViewModel) {
        currentDocument.slides = viewModel.slides
        currentDocument.metadata.title = viewModel.documentTitle
        currentDocument.lastModified = Date()
        markDocumentAsModified()
    }
    
    // 将视图模型更新为当前文档
    func updateViewModel(_ viewModel: SlideEditorViewModel) {
        viewModel.slides = currentDocument.slides
        viewModel.documentTitle = currentDocument.metadata.title
    }
    
    // 添加到最近文件列表
    private func addToRecentDocuments(_ url: URL) {
        // 移除已存在的相同URL
        recentDocuments.removeAll { $0 == url }
        
        // 添加到列表开头
        recentDocuments.insert(url, at: 0)
        
        // 限制列表大小
        if recentDocuments.count > 10 {
            recentDocuments = Array(recentDocuments.prefix(10))
        }
        
        // 保存到UserDefaults
        saveRecentDocuments()
    }
    
    // 保存最近文件列表
    private func saveRecentDocuments() {
        let urlStrings = recentDocuments.map { $0.absoluteString }
        UserDefaults.standard.set(urlStrings, forKey: "recentDocuments")
    }
    
    // 加载最近文件列表
    func loadRecentDocuments() {
        if let urlStrings = UserDefaults.standard.stringArray(forKey: "recentDocuments") {
            recentDocuments = urlStrings.compactMap { URL(string: $0) }
        }
    }
    
    // 导出PDF
    func exportPDF() async -> DocumentResult {
        #if os(macOS)
        return await withCheckedContinuation { continuation in
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.pdf]
            savePanel.canCreateDirectories = true
            savePanel.isExtensionHidden = false
            savePanel.title = "导出PDF"
            savePanel.message = "选择保存位置"
            savePanel.nameFieldLabel = "文件名:"
            savePanel.nameFieldStringValue = "\(currentDocument.metadata.title).pdf"
            
            DispatchQueue.main.async {
                let response = savePanel.runModal()
                
                if response == .OK, let url = savePanel.url {
                    // 这里需要实现PDF导出
                    // TODO: 实现PDF渲染
                    continuation.resume(returning: .failure(DocumentError.saveFailed))
                } else {
                    continuation.resume(returning: .failure(DocumentError.userCancelled))
                }
            }
        }
        #else
        return .failure(DocumentError.saveFailed)
        #endif
    }
    
    // 初始化
    init() {
        loadRecentDocuments()
    }
} 