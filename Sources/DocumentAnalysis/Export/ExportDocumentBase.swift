import SwiftUI
import UniformTypeIdentifiers

/// 基础导出文档
public protocol BaseExportDocument: FileDocument {
    associatedtype ExporterType: DocumentExporter
    
    /// 文档分析结果
    var result: DocumentAnalysisResult { get }
    
    /// 导出选项
    var options: ExporterType.Options { get }
    
    /// 初始化
    init(result: DocumentAnalysisResult, options: ExporterType.Options)
}

/// 通用的导出文档实现
open class GenericExportDocument<T: DocumentExporter>: BaseExportDocument {
    public typealias ExporterType = T
    
    public static var readableContentTypes: [UTType] { [options.contentType] }
    
    public let result: DocumentAnalysisResult
    public let options: T.Options
    
    private static var options: T.Options {
        T.Options.defaultOptions()
    }
    
    required public init(result: DocumentAnalysisResult, options: T.Options) {
        self.result = result
        self.options = options
    }
    
    /// 仅用于符合FileDocument协议，实际上不支持读取
    required public init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }
    
    open func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let exporter = T(result: result, options: options)
        
        do {
            // 创建临时URL用于导出
            return try TemporaryFileManager.withTemporaryDirectory { tempDirectory in
                let tempURL = tempDirectory.appendingPathComponent("export").appendingPathExtension(options.fileExtension)
                
                // 导出到临时URL
                guard try exporter.export(to: tempURL) else {
                    throw DocumentExportError.contentGenerationFailed("导出失败")
                }
                
                // 读取文件数据
                guard let data = try? Data(contentsOf: tempURL) else {
                    throw DocumentExportError.fileOperationFailed("无法读取导出文件")
                }
                
                return FileWrapper(regularFileWithContents: data)
            }
        } catch {
            if let docError = error as? DocumentExportError {
                throw docError
            } else {
                throw DocumentExportError.unknownError(error)
            }
        }
    }
}

/// ZIP文件导出文档
open class ZipExportDocument<T: DocumentExporter>: BaseExportDocument {
    public typealias ExporterType = T
    
    public static var readableContentTypes: [UTType] { [.archive] }
    
    public let result: DocumentAnalysisResult
    public let options: T.Options
    
    required public init(result: DocumentAnalysisResult, options: T.Options) {
        self.result = result
        self.options = options
    }
    
    /// 仅用于符合FileDocument协议，实际上不支持读取
    required public init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }
    
    open func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let exporter = T(result: result, options: options)
        
        do {
            // 创建临时URL用于导出
            return try TemporaryFileManager.withTemporaryDirectory { tempDirectory in
                let tempURL = tempDirectory.appendingPathComponent("export").appendingPathExtension("zip")
                
                // 导出到临时URL
                guard try exporter.export(to: tempURL) else {
                    throw DocumentExportError.contentGenerationFailed("导出失败")
                }
                
                // 读取文件数据
                guard let data = try? Data(contentsOf: tempURL) else {
                    throw DocumentExportError.fileOperationFailed("无法读取导出文件")
                }
                
                return FileWrapper(regularFileWithContents: data)
            }
        } catch {
            if let docError = error as? DocumentExportError {
                throw docError
            } else {
                throw DocumentExportError.unknownError(error)
            }
        }
    }
}

/// 目录导出文档
open class DirectoryExportDocument<T: DocumentExporter>: BaseExportDocument {
    public typealias ExporterType = T
    
    public static var readableContentTypes: [UTType] { [.folder] }
    
    public let result: DocumentAnalysisResult
    public let options: T.Options
    
    required public init(result: DocumentAnalysisResult, options: T.Options) {
        self.result = result
        self.options = options
    }
    
    /// 仅用于符合FileDocument协议，实际上不支持读取
    required public init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }
    
    open func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let exporter = T(result: result, options: options)
        
        do {
            // 创建临时目录用于导出
            return try TemporaryFileManager.withTemporaryDirectory { tempDirectory in
                let exportDir = tempDirectory.appendingPathComponent("export", isDirectory: true)
                try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
                
                // 导出到临时目录
                guard try exporter.export(to: exportDir) else {
                    throw DocumentExportError.contentGenerationFailed("导出失败")
                }
                
                // 创建目录文件包装器
                var fileWrappers = [String: FileWrapper]()
                
                // 获取临时目录中的所有文件
                let fileURLs = try FileManager.default.contentsOfDirectory(at: exportDir, includingPropertiesForKeys: nil)
                
                for fileURL in fileURLs {
                    let fileName = fileURL.lastPathComponent
                    let fileData = try Data(contentsOf: fileURL)
                    let fileWrapper = FileWrapper(regularFileWithContents: fileData)
                    fileWrappers[fileName] = fileWrapper
                }
                
                return FileWrapper(directoryWithFileWrappers: fileWrappers)
            }
        } catch {
            if let docError = error as? DocumentExportError {
                throw docError
            } else {
                throw DocumentExportError.unknownError(error)
            }
        }
    }
} 