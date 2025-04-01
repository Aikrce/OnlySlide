import Foundation
import SwiftUI
import UniformTypeIdentifiers

// 扩展PowerPointExportOptions以符合ExportOptionsProtocol
extension PowerPointExportOptions: ExportOptionsProtocol {
    /// 返回默认选项
    public static func defaultOptions() -> PowerPointExportOptions {
        return PowerPointExportOptions()
    }
    
    /// 返回内容类型
    public var contentType: UTType {
        // PPTX文件暂无标准UTType，使用通用数据类型
        return .data
    }
    
    /// 返回文件扩展名
    public var fileExtension: String {
        return "pptx"
    }
}

/// PowerPoint导出文档
public class PowerPointExportDocument: GenericExportDocument<PowerPointExporterImpl> {
    /// 返回内容类型（覆盖基类方法以使用正确的内容类型）
    public static var readableContentTypes: [UTType] { [UTType(filenameExtension: "pptx") ?? .data] }
} 