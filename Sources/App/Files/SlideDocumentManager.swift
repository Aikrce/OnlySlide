// SlideDocumentManager.swift
// 幻灯片文档管理器，处理文件操作

import Foundation
import SwiftUI
import Combine

// MARK: - 幻灯片文档数据
public struct SlideDocument: Codable {
    public var title: String
    public var slides: [SlideData]
    public var lastModified: Date
    public var version: String
    
    public struct SlideData: Codable, Identifiable {
        public var id: UUID
        public var title: String
        public var content: String
        public var styleType: StyleType
        
        public enum StyleType: String, Codable {
            case standard
            case modern
            case light
            
            public var style: SlideStyle {
                switch self {
                case .standard: return .standard
                case .modern: return .modern
                case .light: return .light
                }
            }
        }
        
        public init(from slide: SlideContent) {
            self.id = slide.id
            self.title = slide.title
            self.content = slide.content
            
            if slide.style.backgroundColor == SlideStyle.modern.backgroundColor {
                self.styleType = .modern
            } else if slide.style.backgroundColor == SlideStyle.light.backgroundColor {
                self.styleType = .light
            } else {
                self.styleType = .standard
            }
        }
        
        public func toSlideContent() -> SlideContent {
            SlideContent(
                title: title,
                content: content,
                style: styleType.style
            )
        }
    }
    
    public init(
        title: String = "未命名演示文稿",
        slides: [SlideContent] = [],
        lastModified: Date = Date(),
        version: String = "1.0"
    ) {
        self.title = title
        self.slides = slides.map { SlideData(from: $0) }
        self.lastModified = lastModified
        self.version = version
    }
    
    public init(from viewModel: SlideEditorViewModel) {
        self.title = viewModel.documentTitle
        self.slides = viewModel.slides.map { SlideData(from: $0) }
        self.lastModified = Date()
        self.version = "1.0"
    }
    
    public func toViewModel() -> SlideEditorViewModel {
        let slideContents = slides.map { $0.toSlideContent() }
        return SlideEditorViewModel(
            slides: slideContents,
            documentTitle: title
        )
    }
}

// MARK: - 文档管理器
public class SlideDocumentManager: ObservableObject {
    @Published public var currentDocument: SlideDocument
    @Published public var documentURL: URL?
    @Published public var isDocumentSaved: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(document: SlideDocument = SlideDocument()) {
        self.currentDocument = document
    }
    
    // 从视图模型更新文档
    public func updateFromViewModel(_ viewModel: SlideEditorViewModel) {
        currentDocument = SlideDocument(from: viewModel)
        isDocumentSaved = false
    }
    
    // 创建新文档
    public func createNewDocument() {
        currentDocument = SlideDocument()
        documentURL = nil
        isDocumentSaved = true
    }
    
    // 打开文档
    public func openDocument() async -> Bool {
        let config = FileManagerAdapter.FilePickerConfig(
            fileTypes: [.presentation]
        )
        
        guard let urls = await FileManagerAdapter.openFile(config: config),
              let url = urls.first else {
            return false
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let document = try decoder.decode(SlideDocument.self, from: data)
            
            await MainActor.run {
                self.currentDocument = document
                self.documentURL = url
                self.isDocumentSaved = true
            }
            return true
        } catch {
            print("打开文档失败: \(error)")
            return false
        }
    }
    
    // 保存文档
    public func saveDocument() async -> Bool {
        if let url = documentURL {
            return await saveDocumentToURL(url)
        } else {
            return await saveDocumentAs()
        }
    }
    
    // 另存为
    public func saveDocumentAs() async -> Bool {
        let config = FileManagerAdapter.FileSaveConfig(
            defaultName: currentDocument.title,
            fileType: .presentation
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(currentDocument)
            
            if let url = await FileManagerAdapter.saveFile(data: data, config: config) {
                await MainActor.run {
                    self.documentURL = url
                    self.isDocumentSaved = true
                }
                return true
            }
            return false
        } catch {
            print("保存文档失败: \(error)")
            return false
        }
    }
    
    // 保存到指定URL
    public func saveDocumentToURL(_ url: URL) async -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(currentDocument)
            try data.write(to: url)
            
            await MainActor.run {
                self.isDocumentSaved = true
            }
            return true
        } catch {
            print("保存文档失败: \(error)")
            return false
        }
    }
    
    // 导出为PDF
    public func exportAsPDF() async -> Bool {
        // PDF导出功能将在后续实现
        return false
    }
    
    // 导入模板
    public func importTemplate() async -> Bool {
        let config = FileManagerAdapter.FilePickerConfig(
            fileTypes: [.presentation]
        )
        
        guard let urls = await FileManagerAdapter.openFile(config: config),
              let url = urls.first else {
            return false
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let document = try decoder.decode(SlideDocument.self, from: data)
            
            // 只导入模板样式，不导入内容
            let templateSlides = document.slides.map { slideData -> SlideData in
                var newSlide = slideData
                newSlide.title = "新幻灯片"
                newSlide.content = "在此处添加内容"
                return newSlide
            }
            
            await MainActor.run {
                self.currentDocument.slides = templateSlides
                self.isDocumentSaved = false
            }
            return true
        } catch {
            print("导入模板失败: \(error)")
            return false
        }
    }
}

// MARK: - 文档状态助手视图
public struct DocumentStatusView: View {
    @ObservedObject var documentManager: SlideDocumentManager
    
    public var body: some View {
        HStack(spacing: 4) {
            if documentManager.isDocumentSaved {
                Image(systemName: "doc")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "doc.badge.ellipsis")
                    .foregroundColor(.orange)
            }
            
            Text(documentManager.currentDocument.title)
                .lineLimit(1)
            
            if !documentManager.isDocumentSaved {
                Text("(未保存)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 文档操作工具栏
public struct DocumentToolbarView: View {
    @ObservedObject var documentManager: SlideDocumentManager
    @Environment(\.openWindow) private var openWindow
    
    public var body: some View {
        #if os(macOS)
        HStack {
            Button(action: {
                Task {
                    _ = await documentManager.createNewDocument()
                }
            }) {
                Label("新建", systemImage: "doc.badge.plus")
            }
            
            Button(action: {
                Task {
                    _ = await documentManager.openDocument()
                }
            }) {
                Label("打开", systemImage: "folder")
            }
            
            Button(action: {
                Task {
                    _ = await documentManager.saveDocument()
                }
            }) {
                Label("保存", systemImage: "square.and.arrow.down")
            }
            .disabled(documentManager.isDocumentSaved)
        }
        #else
        HStack {
            Button(action: {
                Task {
                    _ = await documentManager.createNewDocument()
                }
            }) {
                Image(systemName: "doc.badge.plus")
            }
            
            Button(action: {
                Task {
                    _ = await documentManager.openDocument()
                }
            }) {
                Image(systemName: "folder")
            }
            
            Button(action: {
                Task {
                    _ = await documentManager.saveDocument()
                }
            }) {
                Image(systemName: "square.and.arrow.down")
            }
            .disabled(documentManager.isDocumentSaved)
        }
        #endif
    }
} 