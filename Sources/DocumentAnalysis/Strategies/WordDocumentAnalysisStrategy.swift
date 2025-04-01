import Foundation
import UniformTypeIdentifiers
import ZIPFoundation
import XMLCoder

/// Word文档分析策略 - 处理.docx和.doc文件
public class WordDocumentAnalysisStrategy: DocumentAnalysisStrategy {
    
    // MARK: - 属性
    
    /// 策略描述
    public var description: String {
        return "Word文档分析策略"
    }
    
    // XML命名空间常量
    private enum XMLNamespace {
        static let wordprocessingML = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
        static let relationships = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    }
    
    // MARK: - 初始化
    
    public init() {}
    
    // MARK: - DocumentAnalysisStrategy 协议实现
    
    public func supportedTypes() -> [UTType] {
        var types: [UTType] = []
        
        // 添加.docx类型
        if let docx = UTType(filenameExtension: "docx") {
            types.append(docx)
        }
        
        // 添加.doc类型
        if let doc = UTType(filenameExtension: "doc") {
            types.append(doc)
        }
        
        return types
    }
    
    public func analyze(content: Data, filename: String?) async throws -> DocumentAnalysisResult {
        // 提取文件名（不含扩展名）作为文档标题
        var documentTitle = "未命名文档"
        if let filename = filename {
            let url = URL(fileURLWithPath: filename)
            documentTitle = url.deletingPathExtension().lastPathComponent
        }
        
        // 判断文件类型并解析
        if filename?.lowercased().hasSuffix(".docx") == true {
            return try await parseDocx(data: content, filename: documentTitle)
        } else if filename?.lowercased().hasSuffix(".doc") == true {
            return try await parseDoc(data: content, filename: documentTitle)
        }
        
        // 如果无法确定类型，默认尝试作为docx解析
        return try await parseDocx(data: content, filename: documentTitle)
    }
    
    // MARK: - 私有解析方法
    
    /// 将.docx文件解析为DocumentAnalysisResult
    /// - Parameters:
    ///   - data: 文件数据
    ///   - filename: 文件名（不含扩展名）
    /// - Returns: 分析结果
    private func parseDocx(data: Data, filename: String) async throws -> DocumentAnalysisResult {
        // 创建临时目录用于解压缩docx文件
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        // 确保目录存在
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // 用于清理临时文件的延迟执行
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        
        // 临时zip文件路径
        let zipPath = tempDirectory.appendingPathComponent("document.zip")
        
        // 将数据写入临时文件
        try data.write(to: zipPath)
        
        // 解压文件
        let unzipDestination = tempDirectory.appendingPathComponent("unpacked", isDirectory: true)
        try FileManager.default.createDirectory(at: unzipDestination, withIntermediateDirectories: true)
        
        // 使用ZIPFoundation解压
        try FileManager.default.unzipItem(at: zipPath, to: unzipDestination)
        
        // 解析文档内容
        let documentXmlPath = unzipDestination.appendingPathComponent("word/document.xml")
        guard FileManager.default.fileExists(atPath: documentXmlPath.path) else {
            throw DocumentAnalysisError.invalidDocumentFormat
        }
        
        // 读取document.xml内容
        let documentData = try Data(contentsOf: documentXmlPath)
        
        // 解析文档结构
        return try await parseDocumentXml(data: documentData, filename: filename)
    }
    
    /// 解析document.xml文件
    private func parseDocumentXml(data: Data, filename: String) async throws -> DocumentAnalysisResult {
        // 初始化结果
        var result = DocumentAnalysisResult(
            title: filename,
            sections: [],
            metadata: [:],
            sourceType: .word
        )
        
        // 创建一个默认部分
        var currentSection = DocumentSection(title: "正文", level: 1)
        var currentParagraph = ""
        
        // 简单解析XML以提取文本内容（实际应该使用XMLParser或XMLCoder）
        if let xmlString = String(data: data, encoding: .utf8) {
            let paragraphs = extractParagraphs(from: xmlString)
            
            for paragraphText in paragraphs {
                if paragraphText.isEmpty {
                    continue
                }
                
                // 简单检测标题（这只是一个基础实现，后续会增强）
                if let (title, level) = detectHeading(paragraphText) {
                    // 如果当前段落不为空，添加到当前部分
                    if !currentParagraph.isEmpty {
                        let paragraphItem = ContentItem(type: .paragraph, text: currentParagraph)
                        currentSection.contentItems.append(paragraphItem)
                        currentParagraph = ""
                    }
                    
                    // 如果当前部分有内容，将其添加到结果中
                    if !currentSection.contentItems.isEmpty {
                        result.sections.append(currentSection)
                    }
                    
                    // 创建新部分
                    currentSection = DocumentSection(title: title, level: level)
                } else if let listItemText = detectListItem(paragraphText) {
                    // 如果当前段落不为空，添加到当前部分
                    if !currentParagraph.isEmpty {
                        let paragraphItem = ContentItem(type: .paragraph, text: currentParagraph)
                        currentSection.contentItems.append(paragraphItem)
                        currentParagraph = ""
                    }
                    
                    // 添加列表项
                    let listItem = ContentItem(type: .listItem, text: listItemText)
                    currentSection.contentItems.append(listItem)
                } else {
                    // 普通段落
                    if currentParagraph.isEmpty {
                        currentParagraph = paragraphText
                    } else {
                        currentParagraph += " " + paragraphText
                    }
                }
            }
        }
        
        // 处理可能剩余的段落
        if !currentParagraph.isEmpty {
            let paragraphItem = ContentItem(type: .paragraph, text: currentParagraph)
            currentSection.contentItems.append(paragraphItem)
        }
        
        // 添加最后一个部分
        if !currentSection.contentItems.isEmpty {
            result.sections.append(currentSection)
        }
        
        // 如果没有解析出任何部分，添加一个默认部分
        if result.sections.isEmpty {
            let defaultSection = DocumentSection(title: "正文", level: 1)
            result.sections.append(defaultSection)
        }
        
        return result
    }
    
    /// 从XML字符串中提取段落文本
    private func extractParagraphs(from xmlString: String) -> [String] {
        var paragraphs: [String] = []
        
        // 使用简单的正则表达式提取<w:p>...</w:p>之间的内容
        // 注意：实际的实现应该使用XML解析器
        do {
            // 定义正则表达式匹配<w:p>...</w:p>内容
            let paragraphPattern = try NSRegularExpression(pattern: "<w:p[^>]*>(.*?)</w:p>", options: [.dotMatchesLineSeparators])
            
            // 在XML字符串中搜索匹配项
            let range = NSRange(xmlString.startIndex..<xmlString.endIndex, in: xmlString)
            let matches = paragraphPattern.matches(in: xmlString, options: [], range: range)
            
            // 对于每个匹配的段落，提取所有<w:t>...</w:t>中的文本
            for match in matches {
                if let paragraphRange = Range(match.range(at: 1), in: xmlString) {
                    let paragraphXml = String(xmlString[paragraphRange])
                    
                    // 提取所有<w:t>...</w:t>文本
                    let textPattern = try NSRegularExpression(pattern: "<w:t[^>]*>(.*?)</w:t>", options: [.dotMatchesLineSeparators])
                    let textRange = NSRange(paragraphXml.startIndex..<paragraphXml.endIndex, in: paragraphXml)
                    let textMatches = textPattern.matches(in: paragraphXml, options: [], range: textRange)
                    
                    var paragraphText = ""
                    for textMatch in textMatches {
                        if let textRange = Range(textMatch.range(at: 1), in: paragraphXml) {
                            paragraphText += paragraphXml[textRange]
                        }
                    }
                    
                    // 清理文本并添加到结果
                    paragraphText = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !paragraphText.isEmpty {
                        paragraphs.append(paragraphText)
                    }
                }
            }
        } catch {
            print("正则表达式错误: \(error)")
        }
        
        return paragraphs
    }
    
    /// 检测标题
    private func detectHeading(_ text: String) -> (String, Int)? {
        // 简单的标题检测（后续会增强）
        if text.count < 100 { // 标题通常不会很长
            // 数字标题 (1. 标题内容)
            if let match = text.range(of: #"^\s*(\d+[\.\)]\s+)(.+)$"#, options: .regularExpression) {
                let title = String(text[match]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (title, 1)
            }
            
            // 章节标题 (第一章 标题内容)
            if let match = text.range(of: #"^\s*(第[一二三四五六七八九十百千万零]+[章节篇部])\s*(.+)$"#, options: .regularExpression) {
                let title = String(text[match]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (title, 1)
            }
        }
        
        return nil
    }
    
    /// 检测列表项
    private func detectListItem(_ text: String) -> String? {
        // 简单的列表项检测（后续会增强）
        
        // 项目符号列表
        if let match = text.range(of: #"^\s*[•·\-\*]\s+(.+)$"#, options: .regularExpression) {
            return String(text[match]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 数字列表
        if let match = text.range(of: #"^\s*\d+[\.\)]\s+(.+)$"#, options: .regularExpression) {
            return String(text[match]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    /// 将.doc文件解析为DocumentAnalysisResult
    /// - Parameters:
    ///   - data: 文件数据
    ///   - filename: 文件名
    /// - Returns: 分析结果
    private func parseDoc(data: Data, filename: String) async throws -> DocumentAnalysisResult {
        // 目前仅支持.docx格式
        throw DocumentAnalysisError.analysisFailure("暂不支持.doc格式，请将文档转换为.docx格式")
    }
    
    // MARK: - 技术说明
    
    // Word文档解析技术方案：
    
    // 1. .docx文件是Office Open XML (OOXML)格式，本质是ZIP压缩的XML文件集合
    //    解析步骤：
    //    - 使用ZIPFoundation解压文件
    //    - 解析document.xml（包含主要内容）
    //    - 解析styles.xml（包含样式信息）
    //    - 从numbering.xml提取列表信息
    //    - 必要时从media文件夹提取图片
    
    // 2. .doc文件是旧版二进制格式，更复杂
    //    可能的方案：
    //    - 使用libwps等开源库转换并解析
    //    - 或者仅支持.docx格式，推荐用户转换格式
}

// MARK: - 文件格式说明

/*
 DOCX文件结构：
 
 [Content_Types].xml - 内容类型清单
 _rels/ - 关系定义
 docProps/ - 文档属性
 word/ - 主要内容
   document.xml - 文档内容
   styles.xml - 样式定义
   numbering.xml - 编号和列表
   media/ - 图片和媒体文件
 
 关键内容标签：
 - w:p - 段落
 - w:r - 格式一致的文本块
 - w:t - 文本内容
 - w:pStyle - 段落样式，包括标题级别
 - w:numPr - 列表信息
 */