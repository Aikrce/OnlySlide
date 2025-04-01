import Foundation
import SwiftUI
import PDFKit

/// 文档导出格式
public enum DocumentExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case powerPoint
    case images
    case text
    
    public var id: String { rawValue }
    
    /// 格式显示名称
    public var displayName: String {
        switch self {
        case .pdf:
            return "PDF文档"
        case .powerPoint:
            return "PowerPoint演示文稿"
        case .images:
            return "图片集"
        case .text:
            return "文本文档"
        }
    }
    
    /// 格式图标
    public var iconName: String {
        switch self {
        case .pdf:
            return "doc.text.viewfinder"
        case .powerPoint:
            return "rectangle.stack"
        case .images:
            return "photo.on.rectangle"
        case .text:
            return "doc.text"
        }
    }
    
    /// 文件扩展名
    public var fileExtension: String {
        switch self {
        case .pdf:
            return "pdf"
        case .powerPoint:
            return "pptx"
        case .images:
            return "zip"
        case .text:
            return "txt"
        }
    }
    
    /// 统一类型标识符
    public var contentType: UTType {
        switch self {
        case .pdf:
            return .pdf
        case .powerPoint:
            return .data // 使用通用数据类型
        case .images:
            return .archive // 使用归档类型
        case .text:
            return .plainText
        }
    }
}

/// 导出结果
public enum ExportResult {
    case success(URL)
    case failure(Error)
    case cancelled
}

/// 导出进度
public struct ExportProgress {
    public var progress: Double
    public var message: String
    
    public init(progress: Double, message: String) {
        self.progress = progress
        self.message = message
    }
}

/// 文档导出管理器
public class DocumentExportManager: ObservableObject {
    /// 单例实例
    public static let shared = DocumentExportManager()
    
    /// 发布当前导出进度
    @Published public var currentProgress: ExportProgress?
    
    /// 是否正在导出
    @Published public var isExporting = false
    
    /// 私有初始化方法
    private init() {}
    
    /// 导出文档
    /// - Parameters:
    ///   - result: 文档分析结果
    ///   - format: 导出格式
    ///   - url: 目标URL（如果为nil，则会显示保存对话框）
    /// - Returns: 导出结果
    public func exportDocument(_ result: DocumentAnalysisResult, format: DocumentExportFormat, to url: URL? = nil) async -> ExportResult {
        isExporting = true
        currentProgress = ExportProgress(progress: 0.0, message: "准备导出...")
        
        defer {
            Task { @MainActor in
                self.isExporting = false
                self.currentProgress = nil
            }
        }
        
        // 根据格式选择不同的导出方法
        switch format {
        case .pdf:
            return await exportToPDF(result, to: url)
        case .powerPoint:
            return await exportToPowerPoint(result, to: url)
        case .images:
            return await exportToImages(result, to: url)
        case .text:
            return await exportToText(result, to: url)
        }
    }
    
    /// 导出为PDF
    private func exportToPDF(_ result: DocumentAnalysisResult, to url: URL? = nil) async -> ExportResult {
        await updateProgress(0.2, "创建PDF文档...")
        
        // 创建默认选项
        let options = PDFExportOptions()
        
        // 如果未提供URL，需要使用系统对话框（通常在SwiftUI中处理）
        guard let targetURL = url else {
            // 在UI层处理
            return .cancelled
        }
        
        await updateProgress(0.5, "生成PDF内容...")
        
        // 创建导出器并导出
        let exporter = PDFExporter(result: result, options: options)
        let success = exporter.exportToPDF(url: targetURL)
        
        await updateProgress(1.0, "完成导出")
        
        if success {
            return .success(targetURL)
        } else {
            return .failure(NSError(domain: "PDFExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "导出PDF失败"]))
        }
    }
    
    /// 导出为PowerPoint
    private func exportToPowerPoint(_ result: DocumentAnalysisResult, to url: URL? = nil) async -> ExportResult {
        await updateProgress(0.2, "创建PowerPoint文档...")
        
        // 创建默认选项
        let options = PowerPointExportOptions()
        
        // 如果未提供URL，需要使用系统对话框（通常在SwiftUI中处理）
        guard let targetURL = url else {
            // 在UI层处理
            return .cancelled
        }
        
        await updateProgress(0.5, "生成幻灯片内容...")
        
        // 创建导出器并导出
        let exporter = PowerPointExporter(result: result, options: options)
        let success = exporter.exportToPowerPoint(url: targetURL)
        
        await updateProgress(1.0, "完成导出")
        
        if success {
            return .success(targetURL)
        } else {
            return .failure(NSError(domain: "PowerPointExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "导出PowerPoint失败"]))
        }
    }
    
    /// 导出为图片集
    private func exportToImages(_ result: DocumentAnalysisResult, to url: URL? = nil) async -> ExportResult {
        await updateProgress(0.2, "创建图片导出...")
        
        // 创建默认选项
        let options = ImagesExportOptions()
        
        // 如果未提供URL，需要使用系统对话框（通常在SwiftUI中处理）
        guard let targetURL = url else {
            // 在UI层处理
            return .cancelled
        }
        
        await updateProgress(0.5, "生成图片内容...")
        
        // 创建导出器并导出
        let success = result.exportToImages(url: targetURL, options: options)
        
        await updateProgress(1.0, "完成导出")
        
        if success {
            return .success(targetURL)
        } else {
            return .failure(NSError(domain: "ImagesExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "导出图片失败"]))
        }
    }
    
    /// 导出为文本
    private func exportToText(_ result: DocumentAnalysisResult, to url: URL? = nil) async -> ExportResult {
        await updateProgress(0.2, "创建文本导出...")
        
        // 创建默认选项
        let options = TextExportOptions()
        
        // 如果未提供URL，需要使用系统对话框（通常在SwiftUI中处理）
        guard let targetURL = url else {
            // 在UI层处理
            return .cancelled
        }
        
        await updateProgress(0.5, "生成文本内容...")
        
        // 创建导出器并导出
        let success = result.exportToText(url: targetURL, options: options)
        
        await updateProgress(1.0, "完成导出")
        
        if success {
            return .success(targetURL)
        } else {
            return .failure(NSError(domain: "TextExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "导出文本失败"]))
        }
    }
    
    /// 更新进度信息
    private func updateProgress(_ progress: Double, _ message: String) async {
        await MainActor.run {
            currentProgress = ExportProgress(progress: progress, message: message)
        }
    }
}

/// 导出辅助方法
extension DocumentAnalysisResult {
    /// 快速导出为PDF
    public func quickExportToPDF() async -> ExportResult {
        return await DocumentExportManager.shared.exportDocument(self, format: .pdf)
    }
    
    /// 快速导出为PowerPoint
    public func quickExportToPowerPoint() async -> ExportResult {
        return await DocumentExportManager.shared.exportDocument(self, format: .powerPoint)
    }
    
    /// 快速导出为图片集
    public func quickExportToImages() async -> ExportResult {
        return await DocumentExportManager.shared.exportDocument(self, format: .images)
    }
    
    /// 快速导出为文本
    public func quickExportToText() async -> ExportResult {
        return await DocumentExportManager.shared.exportDocument(self, format: .text)
    }
} 