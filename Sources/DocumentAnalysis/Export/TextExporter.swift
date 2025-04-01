import Foundation

/// 文本导出选项
public struct TextExportOptions {
    /// 文本格式
    public enum TextFormat: String, CaseIterable, Identifiable {
        case plainText = "纯文本"
        case markdown = "Markdown"
        
        public var id: String { rawValue }
        
        /// 文件扩展名
        public var fileExtension: String {
            switch self {
            case .plainText:
                return "txt"
            case .markdown:
                return "md"
            }
        }
        
        /// MIME类型
        public var mimeType: String {
            switch self {
            case .plainText:
                return "text/plain"
            case .markdown:
                return "text/markdown"
            }
        }
    }
    
    /// 文本格式
    public var format: TextFormat = .plainText
    
    /// 是否包含标题
    public var includeTitle: Bool = true
    
    /// 是否包含目录
    public var includeTableOfContents: Bool = true
    
    /// 是否包含元数据
    public var includeMetadata: Bool = true
    
    /// 是否缩进内容
    public var indentContent: Bool = true
    
    /// 是否添加编号
    public var addNumbering: Bool = false
    
    /// 行尾类型
    public enum LineEnding: String, CaseIterable, Identifiable {
        case lf = "LF (Unix/macOS)"
        case crlf = "CRLF (Windows)"
        case cr = "CR (旧版 macOS)"
        
        public var id: String { rawValue }
        
        /// 换行符
        public var value: String {
            switch self {
            case .lf:
                return "\n"
            case .crlf:
                return "\r\n"
            case .cr:
                return "\r"
            }
        }
    }
    
    /// 行尾类型
    public var lineEnding: LineEnding = .lf
    
    /// 字符编码
    public enum Encoding: String, CaseIterable, Identifiable {
        case utf8 = "UTF-8"
        case utf16 = "UTF-16"
        case ascii = "ASCII"
        
        public var id: String { rawValue }
        
        /// 对应的String.Encoding
        public var stringEncoding: String.Encoding {
            switch self {
            case .utf8:
                return .utf8
            case .utf16:
                return .utf16
            case .ascii:
                return .ascii
            }
        }
    }
    
    /// 字符编码
    public var encoding: Encoding = .utf8
    
    public init() {}
}

/// 文本导出错误类型
public enum TextExportError: Error {
    case textGenerationFailed
    case encodingFailed
    case fileWriteFailed
}

/// 文本导出工具
public class TextExporter {
    /// 分析结果
    private let result: DocumentAnalysisResult
    
    /// 导出选项
    private var options: TextExportOptions
    
    /// 初始化
    /// - Parameters:
    ///   - result: 文档分析结果
    ///   - options: 导出选项
    public init(result: DocumentAnalysisResult, options: TextExportOptions = TextExportOptions()) {
        self.result = result
        self.options = options
    }
    
    /// 导出为文本文件
    /// - Parameter url: 目标URL
    /// - Returns: 是否成功
    public func exportToText(url: URL) -> Bool {
        do {
            // 生成文本内容
            let textContent = generateTextContent()
            
            // 使用指定的编码写入文件
            try textContent.write(to: url, atomically: true, encoding: options.encoding.stringEncoding)
            
            return true
        } catch {
            print("文本导出错误: \(error)")
            return false
        }
    }
    
    // MARK: - 私有方法
    
    /// 生成文本内容
    private func generateTextContent() -> String {
        var content = ""
        let newLine = options.lineEnding.value
        
        // 添加标题
        if options.includeTitle {
            switch options.format {
            case .plainText:
                content += result.title + newLine
                content += String(repeating: "=", count: result.title.count) + newLine + newLine
            case .markdown:
                content += "# " + result.title + newLine + newLine
            }
        }
        
        // 添加元数据
        if options.includeMetadata {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            
            switch options.format {
            case .plainText:
                content += "文档类型: " + result.sourceType.displayName + newLine
                content += "导出时间: " + dateFormatter.string(from: Date()) + newLine
                content += "章节数量: " + String(result.sections.count) + newLine
                content += "内容项数量: " + String(result.totalContentItemCount) + newLine + newLine
            case .markdown:
                content += "> **文档信息**" + newLine
                content += "> - 文档类型: " + result.sourceType.displayName + newLine
                content += "> - 导出时间: " + dateFormatter.string(from: Date()) + newLine
                content += "> - 章节数量: " + String(result.sections.count) + newLine
                content += "> - 内容项数量: " + String(result.totalContentItemCount) + newLine + newLine
            }
        }
        
        // 添加目录
        if options.includeTableOfContents {
            switch options.format {
            case .plainText:
                content += "目录" + newLine
                content += String(repeating: "-", count: 4) + newLine + newLine
                
                for section in result.sections {
                    let indent = String(repeating: "  ", count: max(0, section.level - 1))
                    content += indent + section.title + newLine
                }
                
                content += newLine
            case .markdown:
                content += "## 目录" + newLine + newLine
                
                for section in result.sections {
                    let indent = String(repeating: "  ", count: max(0, section.level - 1))
                    content += indent + "- [" + section.title + "](#" + section.title.lowercased().replacingOccurrences(of: " ", with: "-") + ")" + newLine
                }
                
                content += newLine
            }
        }
        
        // 添加章节内容
        for (sectionIndex, section) in result.sections.enumerated() {
            // 章节标题
            switch options.format {
            case .plainText:
                let sectionNumber = options.addNumbering ? "\(sectionIndex + 1). " : ""
                let titlePrefix = String(repeating: "#", count: section.level)
                content += titlePrefix + " " + sectionNumber + section.title + newLine
                content += String(repeating: "-", count: section.title.count + 4) + newLine + newLine
            case .markdown:
                let sectionNumber = options.addNumbering ? "\(sectionIndex + 1). " : ""
                let titlePrefix = String(repeating: "#", count: section.level + 1) // 增加一级，因为文档标题已经使用了一级标题
                content += titlePrefix + " " + sectionNumber + section.title + newLine + newLine
            }
            
            // 章节内容
            for (itemIndex, item) in section.contentItems.enumerated() {
                content += formatContentItem(item, index: itemIndex + 1, level: 0) + newLine
            }
            
            content += newLine
        }
        
        // 添加结尾
        switch options.format {
        case .plainText:
            content += "--- 文档结束 ---" + newLine
        case .markdown:
            content += "---" + newLine
            content += "*由 OnlySlide 导出工具生成*" + newLine
        }
        
        return content
    }
    
    /// 格式化内容项
    private func formatContentItem(_ item: ContentItem, index: Int, level: Int) -> String {
        let newLine = options.lineEnding.value
        let baseIndent = options.indentContent ? String(repeating: "  ", count: level) : ""
        var content = ""
        
        switch options.format {
        case .plainText:
            switch item.type {
            case .paragraph:
                content += baseIndent + item.text
            case .listItem:
                let prefix = options.addNumbering ? "\(index). " : "- "
                content += baseIndent + prefix + item.text
            case .code:
                content += baseIndent + "[代码] " + item.text
            case .table:
                content += baseIndent + "[表格] " + item.text
            case .image:
                content += baseIndent + "[图片] " + item.text
            case .quote:
                content += baseIndent + "\"" + item.text + "\""
            }
        case .markdown:
            switch item.type {
            case .paragraph:
                content += baseIndent + item.text
            case .listItem:
                let prefix = options.addNumbering ? "\(index). " : "- "
                content += baseIndent + prefix + item.text
            case .code:
                content += baseIndent + "```" + newLine
                content += baseIndent + item.text + newLine
                content += baseIndent + "```"
            case .table:
                // 简化表格处理
                content += baseIndent + "| " + item.text + " |"
            case .image:
                content += baseIndent + "![" + item.text + "](" + item.text + ")"
            case .quote:
                content += baseIndent + "> " + item.text
            }
        }
        
        // 处理子项
        if !item.children.isEmpty {
            content += newLine
            for (childIndex, child) in item.children.enumerated() {
                content += newLine + formatContentItem(child, index: childIndex + 1, level: level + 1)
            }
        }
        
        return content
    }
}

// MARK: - DocumentAnalysisResult扩展

extension DocumentAnalysisResult {
    /// 导出为文本文件
    /// - Parameters:
    ///   - url: 文件URL
    ///   - options: 导出选项
    /// - Returns: 是否成功
    public func exportToText(url: URL, options: TextExportOptions = TextExportOptions()) -> Bool {
        let exporter = TextExporter(result: self, options: options)
        return exporter.exportToText(url: url)
    }
} 