import SwiftUI
import UniformTypeIdentifiers

/// 跨平台文件选择器协议
public protocol DocumentFilePickerDelegate {
    /// 当用户选择文件后调用
    func didPickDocuments(urls: [URL])
    
    /// 当选择过程发生错误时调用
    func didFailPickingDocuments(error: Error)
}

/// 文档文件选择器 - 支持macOS和iOS
public struct DocumentFilePicker: ViewModifier {
    /// 支持的文件类型
    private let supportedTypes: [UTType]
    
    /// 是否允许多选
    private let allowMultiple: Bool
    
    /// 代理对象
    private let delegate: DocumentFilePickerDelegate
    
    /// 控制显示状态的绑定
    @Binding private var isPresented: Bool
    
    /// 初始化文件选择器
    /// - Parameters:
    ///   - isPresented: 控制显示状态的绑定
    ///   - supportedTypes: 支持的文件类型数组
    ///   - allowMultiple: 是否允许多选
    ///   - delegate: 代理对象
    public init(
        isPresented: Binding<Bool>,
        supportedTypes: [UTType],
        allowMultiple: Bool = false,
        delegate: DocumentFilePickerDelegate
    ) {
        self._isPresented = isPresented
        self.supportedTypes = supportedTypes
        self.allowMultiple = allowMultiple
        self.delegate = delegate
    }
    
    public func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: supportedTypes,
                allowsMultipleSelection: allowMultiple
            ) { result in
                switch result {
                case .success(let urls):
                    // 确保每个URL都具有安全范围访问权限
                    var accessibleURLs: [URL] = []
                    for url in urls {
                        if url.startAccessingSecurityScopedResource() {
                            accessibleURLs.append(url)
                        }
                    }
                    
                    // 调用代理方法
                    delegate.didPickDocuments(urls: accessibleURLs)
                    
                    // 停止访问
                    for url in accessibleURLs {
                        url.stopAccessingSecurityScopedResource()
                    }
                    
                case .failure(let error):
                    delegate.didFailPickingDocuments(error: error)
                }
            }
    }
}

/// 类方法扩展
public extension DocumentFilePicker {
    /// 支持的文本文档类型
    static var textDocumentTypes: [UTType] {
        return [.plainText, .text]
    }
    
    /// 支持的富文本文档类型
    static var richTextDocumentTypes: [UTType] {
        var types: [UTType] = [.plainText, .text]
        
        // 添加可能在某些平台上不可用的类型
        if let rtf = UTType(filenameExtension: "rtf") {
            types.append(rtf)
        }
        if let docx = UTType(filenameExtension: "docx") {
            types.append(docx)
        }
        if let doc = UTType(filenameExtension: "doc") {
            types.append(doc)
        }
        
        return types
    }
    
    /// 支持的所有文档类型
    static var allDocumentTypes: [UTType] {
        var types = richTextDocumentTypes
        
        // 添加PDF类型
        if let pdf = UTType(filenameExtension: "pdf") {
            types.append(pdf)
        }
        
        return types
    }
}

// MARK: - View扩展，便于使用

public extension View {
    /// 应用文档文件选择器
    func documentFilePicker(
        isPresented: Binding<Bool>,
        supportedTypes: [UTType] = DocumentFilePicker.textDocumentTypes,
        allowMultiple: Bool = false,
        delegate: DocumentFilePickerDelegate
    ) -> some View {
        self.modifier(
            DocumentFilePicker(
                isPresented: isPresented,
                supportedTypes: supportedTypes,
                allowMultiple: allowMultiple,
                delegate: delegate
            )
        )
    }
} 