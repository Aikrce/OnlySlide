import Foundation
import SwiftUI

/// 文档导出错误类型
public enum DocumentExportError: Error, LocalizedError {
    case preparationFailed(String)
    case contentGenerationFailed(String)
    case fileOperationFailed(String)
    case exportCancelled
    case unknownError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .preparationFailed(let details):
            return "导出准备失败: \(details)"
        case .contentGenerationFailed(let details):
            return "内容生成失败: \(details)"
        case .fileOperationFailed(let details):
            return "文件操作失败: \(details)"
        case .exportCancelled:
            return "导出已取消"
        case .unknownError(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

/// 导出选项基础协议
public protocol ExportOptionsProtocol {
    /// 返回导出选项的默认实例
    static func defaultOptions() -> Self
    
    /// 返回适合导出类型的内容类型
    var contentType: UTType { get }
    
    /// 返回适合导出类型的文件扩展名
    var fileExtension: String { get }
}

/// 导出器基础协议
public protocol DocumentExporter {
    associatedtype Options: ExportOptionsProtocol
    
    /// 分析结果
    var result: DocumentAnalysisResult { get }
    
    /// 导出选项
    var options: Options { get }
    
    /// 初始化导出器
    /// - Parameters:
    ///   - result: 文档分析结果
    ///   - options: 导出选项
    init(result: DocumentAnalysisResult, options: Options)
    
    /// 执行导出操作
    /// - Parameter url: 目标URL
    /// - Returns: 是否成功
    func export(to url: URL) throws -> Bool
    
    /// 导出到数据
    /// - Returns: 导出的数据
    func exportToData() throws -> Data
}

/// 临时文件管理器
public class TemporaryFileManager {
    /// 创建临时目录
    /// - Returns: 临时目录URL
    public static func createTemporaryDirectory() throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        return tempDirectory
    }
    
    /// 删除临时目录
    /// - Parameter url: 临时目录URL
    public static func removeTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// 执行操作并自动管理临时目录
    /// - Parameter operation: 使用临时目录的操作
    /// - Returns: 操作的返回值
    public static func withTemporaryDirectory<T>(operation: (URL) throws -> T) throws -> T {
        let tempDirectory = try createTemporaryDirectory()
        defer {
            removeTemporaryDirectory(tempDirectory)
        }
        return try operation(tempDirectory)
    }
    
    /// 压缩目录为ZIP文件
    /// - Parameters:
    ///   - directory: 源目录
    ///   - destinationURL: 目标URL
    public static func compressDirectory(_ directory: URL, to destinationURL: URL) throws {
        // 如果目标文件已存在，先删除
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // 使用ZIPFoundation创建ZIP文件
        try FileManager.default.zipItem(at: directory, to: destinationURL)
    }
}

/// 进度报告协议
public protocol ProgressReporting {
    /// 报告进度
    /// - Parameters:
    ///   - progress: 进度值 (0.0-1.0)
    ///   - message: 进度消息
    func reportProgress(_ progress: Double, _ message: String)
}

/// 空进度报告实现
public class EmptyProgressReporter: ProgressReporting {
    public init() {}
    
    public func reportProgress(_ progress: Double, _ message: String) {
        // 不执行任何操作
    }
} 