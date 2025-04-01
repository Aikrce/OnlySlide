import Foundation
import UniformTypeIdentifiers

/// 纯文本分析策略 - 处理纯文本文件
public class TextAnalysisStrategy: DocumentAnalysisStrategy {
    
    // MARK: - 属性
    
    /// 策略描述
    public var description: String {
        return "纯文本文档分析策略"
    }
    
    // 标题检测正则表达式
    private let titleRegexPatterns = [
        // 数字标题 (1. 标题内容)
        #"^\s*(\d+[\.\)]\s+)(.+)$"#,
        // 章节标题 (第一章 标题内容)
        #"^\s*(第[一二三四五六七八九十百千万零]+[章节篇部])\s*(.+)$"#,
        // 井号标题 (# 标题内容) - Markdown风格
        #"^\s*(#{1,6})\s+(.+)$"#
    ]
    
    // 列表项检测正则表达式
    private let listItemRegexPatterns = [
        // 普通项目符号列表
        #"^\s*[-•·*]\s+(.+)$"#,
        // 数字列表
        #"^\s*(\d+[\.。\)）])\s+(.+)$"#,
        // 字母列表
        #"^\s*([a-zA-Z][\.。\)）])\s+(.+)$"#,
        // 中文序号列表
        #"^\s*([一二三四五六七八九十]+[\.。、])\s+(.+)$"#
    ]
    
    // MARK: - 初始化
    
    public init() {}
    
    // MARK: - DocumentAnalysisStrategy 协议实现
    
    public func supportedTypes() -> [UTType] {
        return [.plainText, .text]
    }
    
    public func analyze(content: Data, filename: String?) async throws -> DocumentAnalysisResult {
        // 尝试转换为文本，使用UTF8编码
        guard let text = String(data: content, encoding: .utf8) else {
            throw DocumentAnalysisError.invalidDocumentFormat
        }
        
        // 从文件名提取标题
        var documentTitle = "未命名文档"
        if let filename = filename {
            let url = URL(fileURLWithPath: filename)
            documentTitle = url.deletingPathExtension().lastPathComponent
        }
        
        // 解析文本内容
        return try await parseTextContent(text, documentTitle: documentTitle)
    }
    
    // MARK: - 私有解析方法
    
    /// 解析文本内容
    private func parseTextContent(_ text: String, documentTitle: String) async throws -> DocumentAnalysisResult {
        // 分割为行
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // 识别结构
        var currentTitle = documentTitle
        var currentLevel = 1
        var sections: [DocumentSection] = []
        var currentSection: DocumentSection?
        var currentParagraph = ""
        
        // 遍历每一行
        for line in lines {
            // 跳过空行，如果正在构建段落则结束段落
            if line.isEmpty {
                if !currentParagraph.isEmpty {
                    // 将当前段落添加到当前部分
                    let paragraphItem = ContentItem(type: .paragraph, text: currentParagraph)
                    currentSection?.contentItems.append(paragraphItem)
                    currentParagraph = ""
                }
                continue
            }
            
            // 检查是否为标题
            if let (detectedTitle, level) = detectTitle(line) {
                // 如果有当前段落，先保存
                if !currentParagraph.isEmpty {
                    let paragraphItem = ContentItem(type: .paragraph, text: currentParagraph)
                    currentSection?.contentItems.append(paragraphItem)
                    currentParagraph = ""
                }
                
                // 如果有当前部分，保存到结果中
                if let section = currentSection {
                    sections.append(section)
                }
                
                // 创建新部分
                currentSection = DocumentSection(title: detectedTitle, level: level)
                currentTitle = detectedTitle
                currentLevel = level
                continue
            }
            
            // 检查是否为列表项
            if let listItemText = detectListItem(line) {
                // 如果有当前段落，先保存
                if !currentParagraph.isEmpty {
                    let paragraphItem = ContentItem(type: .paragraph, text: currentParagraph)
                    currentSection?.contentItems.append(paragraphItem)
                    currentParagraph = ""
                }
                
                // 创建列表项
                let listItem = ContentItem(type: .listItem, text: listItemText)
                
                // 如果还没有当前部分，创建一个默认部分
                if currentSection == nil {
                    currentSection = DocumentSection(title: currentTitle, level: currentLevel)
                }
                
                currentSection?.contentItems.append(listItem)
                continue
            }
            
            // 如果以上都不是，则认为是普通段落的一部分
            if currentParagraph.isEmpty {
                currentParagraph = line
            } else {
                currentParagraph += " " + line
            }
        }
        
        // 处理最后可能遗留的段落
        if !currentParagraph.isEmpty {
            let paragraphItem = ContentItem(type: .paragraph, text: currentParagraph)
            
            // 如果还没有当前部分，创建一个默认部分
            if currentSection == nil {
                currentSection = DocumentSection(title: currentTitle, level: currentLevel)
            }
            
            currentSection?.contentItems.append(paragraphItem)
        }
        
        // 添加最后一个部分
        if let section = currentSection {
            sections.append(section)
        }
        
        // 如果没有识别出任何部分，创建一个默认部分
        if sections.isEmpty {
            let defaultSection = DocumentSection(title: currentTitle, level: 1)
            sections.append(defaultSection)
        }
        
        // 创建分析结果
        return DocumentAnalysisResult(
            title: documentTitle,
            sections: sections,
            metadata: [:],
            sourceType: .text
        )
    }
    
    /// 检测标题
    private func detectTitle(_ line: String) -> (String, Int)? {
        // 遍历标题正则表达式模式
        for pattern in titleRegexPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                
                if let match = regex.firstMatch(in: line, range: range) {
                    // 提取标题和级别
                    if match.numberOfRanges >= 3,
                       let levelRange = Range(match.range(at: 1), in: line),
                       let titleRange = Range(match.range(at: 2), in: line) {
                        let levelText = String(line[levelRange])
                        let title = String(line[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // 确定标题级别
                        var level = 1
                        
                        // 如果是Markdown风格的标题
                        if levelText.contains("#") {
                            level = levelText.count
                        }
                        // 如果是数字标题
                        else if let number = Int(levelText.trimmingCharacters(in: CharacterSet(charactersIn: ".)"))) {
                            level = min(number, 6)  // 限制级别最大为6
                        }
                        
                        return (title, level)
                    }
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
    
    /// 检测列表项
    private func detectListItem(_ line: String) -> String? {
        // 遍历列表项正则表达式模式
        for pattern in listItemRegexPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                
                if let match = regex.firstMatch(in: line, range: range) {
                    // 根据不同的模式提取内容
                    if pattern.contains("[-•·*]") {
                        // 常规项目符号
                        if let contentRange = Range(match.range(at: 1), in: line) {
                            return String(line[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } else {
                        // 编号列表
                        if match.numberOfRanges >= 3,
                           let contentRange = Range(match.range(at: 2), in: line) {
                            return String(line[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
} 