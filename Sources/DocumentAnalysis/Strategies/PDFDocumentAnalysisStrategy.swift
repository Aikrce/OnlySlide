import Foundation
import UniformTypeIdentifiers
import PDFKit

/// PDF文档分析策略 - 处理PDF文件
public class PDFDocumentAnalysisStrategy: DocumentAnalysisStrategy {
    
    // MARK: - 属性
    
    /// 策略描述
    public var description: String {
        return "PDF文档分析策略"
    }
    
    // MARK: - 初始化
    
    public init() {}
    
    // MARK: - DocumentAnalysisStrategy 协议实现
    
    public func supportedTypes() -> [UTType] {
        var types: [UTType] = []
        
        // 添加PDF类型
        if let pdf = UTType(filenameExtension: "pdf") {
            types.append(pdf)
        }
        
        // 也可以直接使用预定义的UTType
        #if canImport(UniformTypeIdentifiers)
        if #available(iOS 14.0, macOS 11.0, *) {
            types.append(UTType.pdf)
        }
        #endif
        
        return types
    }
    
    public func analyze(content: Data, filename: String?) async throws -> DocumentAnalysisResult {
        // 提取文件名（不含扩展名）作为文档标题
        var documentTitle = "未命名文档"
        if let filename = filename {
            let url = URL(fileURLWithPath: filename)
            documentTitle = url.deletingPathExtension().lastPathComponent
        }
        
        // 基本的PDF解析
        guard let pdfDocument = PDFDocument(data: content) else {
            throw DocumentAnalysisError.invalidDocumentFormat
        }
        
        return try await analyzePDFDocument(pdfDocument, title: documentTitle)
    }
    
    // MARK: - 私有解析方法
    
    /// 分析PDF文档
    private func analyzePDFDocument(_ document: PDFDocument, title: String) async throws -> DocumentAnalysisResult {
        // 初始化结果
        var result = DocumentAnalysisResult(
            title: title,
            sections: [],
            metadata: extractMetadata(from: document),
            sourceType: .pdf
        )
        
        // 检查PDF页数
        guard document.pageCount > 0 else {
            throw DocumentAnalysisError.invalidDocumentFormat
        }
        
        // 提取大纲（目录）
        if let outline = document.outlineRoot {
            // 如果PDF有大纲，使用大纲创建部分
            let sections = await extractSectionsFromOutline(outline, document: document)
            if !sections.isEmpty {
                result.sections = sections
                return result
            }
        }
        
        // 如果没有大纲或大纲为空，通过页面分析创建部分
        let sections = await extractSectionsFromPages(document)
        result.sections = sections
        
        return result
    }
    
    /// 从PDF大纲提取部分
    private func extractSectionsFromOutline(_ outline: PDFOutline, document: PDFDocument, level: Int = 1) async -> [DocumentSection] {
        var sections: [DocumentSection] = []
        
        // 大纲标题
        let title = outline.label ?? "未命名部分"
        
        // 大纲目标页面
        var pageIndex: Int? = nil
        if let destination = outline.destination, let page = destination.page {
            pageIndex = document.index(for: page)
        }
        
        // 创建当前部分
        var section = DocumentSection(title: title, level: level)
        
        // 如果有页面索引，从该页面提取内容
        if let pageIndex = pageIndex, pageIndex < document.pageCount {
            let content = extractTextContent(from: document, startPage: pageIndex)
            
            // 将内容分割为段落
            let paragraphs = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            // 将段落添加为内容项
            for paragraph in paragraphs {
                if paragraph.contains("•") || paragraph.contains("-") || paragraph.contains("*") {
                    // 简单列表项检测
                    let listItem = ContentItem(type: .listItem, text: paragraph)
                    section.contentItems.append(listItem)
                } else {
                    // 普通段落
                    let paragraphItem = ContentItem(type: .paragraph, text: paragraph)
                    section.contentItems.append(paragraphItem)
                }
            }
        }
        
        // 添加当前部分
        if !section.contentItems.isEmpty || outline.numberOfChildren == 0 {
            sections.append(section)
        }
        
        // 递归处理子大纲
        for i in 0..<outline.numberOfChildren {
            if let childOutline = outline.child(at: i) {
                let childSections = await extractSectionsFromOutline(childOutline, document: document, level: level + 1)
                sections.append(contentsOf: childSections)
            }
        }
        
        return sections
    }
    
    /// 从PDF页面提取部分
    private func extractSectionsFromPages(_ document: PDFDocument) async -> [DocumentSection] {
        var sections: [DocumentSection] = []
        
        // 创建默认部分
        var currentSection = DocumentSection(title: "页面内容", level: 1)
        
        // 提取所有页面的文本
        let content = extractTextContent(from: document, startPage: 0)
        
        // 将内容分割为段落
        let paragraphs = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // 分析段落
        var currentParagraph = ""
        
        for paragraph in paragraphs {
            // 简单的标题检测
            if paragraph.count < 100 && (paragraph.hasSuffix(":") || paragraph.hasSuffix("：")) {
                // 如果当前段落不为空，添加到当前部分
                if !currentParagraph.isEmpty {
                    let paragraphItem = ContentItem(type: .paragraph, text: currentParagraph)
                    currentSection.contentItems.append(paragraphItem)
                    currentParagraph = ""
                }
                
                // 如果当前部分有内容，添加到结果
                if !currentSection.contentItems.isEmpty {
                    sections.append(currentSection)
                }
                
                // 创建新部分
                currentSection = DocumentSection(title: paragraph, level: 1)
                continue
            }
            
            // 列表项检测
            if paragraph.contains("•") || paragraph.contains("-") || paragraph.contains("*") || paragraph.matches(pattern: "^\\d+\\.") {
                // 如果当前段落不为空，添加到当前部分
                if !currentParagraph.isEmpty {
                    let paragraphItem = ContentItem(type: .paragraph, text: currentParagraph)
                    currentSection.contentItems.append(paragraphItem)
                    currentParagraph = ""
                }
                
                // 添加列表项
                let listItem = ContentItem(type: .listItem, text: paragraph)
                currentSection.contentItems.append(listItem)
                continue
            }
            
            // 普通段落
            if currentParagraph.isEmpty {
                currentParagraph = paragraph
            } else {
                currentParagraph += " " + paragraph
            }
        }
        
        // 处理最后可能剩余的段落
        if !currentParagraph.isEmpty {
            let paragraphItem = ContentItem(type: .paragraph, text: currentParagraph)
            currentSection.contentItems.append(paragraphItem)
        }
        
        // 添加最后一个部分
        if !currentSection.contentItems.isEmpty {
            sections.append(currentSection)
        }
        
        // 如果没有解析出任何部分，添加一个默认部分
        if sections.isEmpty {
            let defaultSection = DocumentSection(title: "文档内容", level: 1)
            sections.append(defaultSection)
        }
        
        return sections
    }
    
    /// 提取PDF元数据
    private func extractMetadata(from document: PDFDocument) -> [String: String] {
        var metadata: [String: String] = [:]
        
        // 尝试提取常见的PDF元数据
        if let info = document.documentAttributes {
            // 标题
            if let title = info[PDFDocumentAttribute.titleAttribute] as? String {
                metadata["title"] = title
            }
            
            // 作者
            if let author = info[PDFDocumentAttribute.authorAttribute] as? String {
                metadata["author"] = author
            }
            
            // 主题
            if let subject = info[PDFDocumentAttribute.subjectAttribute] as? String {
                metadata["subject"] = subject
            }
            
            // 创建者
            if let creator = info[PDFDocumentAttribute.creatorAttribute] as? String {
                metadata["creator"] = creator
            }
            
            // 创建日期
            if let creationDate = info[PDFDocumentAttribute.creationDateAttribute] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                metadata["creationDate"] = formatter.string(from: creationDate)
            }
            
            // 页数
            metadata["pageCount"] = "\(document.pageCount)"
        }
        
        return metadata
    }
    
    /// 从PDF文档中提取文本内容
    private func extractTextContent(from document: PDFDocument, startPage: Int, endPage: Int? = nil) -> String {
        var content = ""
        let endPageIndex = endPage ?? document.pageCount - 1
        
        for i in startPage...min(endPageIndex, document.pageCount - 1) {
            if let page = document.page(at: i) {
                if let pageContent = page.string {
                    content += pageContent + "\n\n"
                }
            }
        }
        
        return content
    }
}

// MARK: - 实用扩展

extension String {
    /// 检查字符串是否匹配正则表达式模式
    func matches(pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(self.startIndex..<self.endIndex, in: self)
            return regex.firstMatch(in: self, range: range) != nil
        } catch {
            return false
        }
    }
} 