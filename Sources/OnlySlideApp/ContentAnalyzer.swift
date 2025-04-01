import Foundation
import NaturalLanguage
import CoreML

/// 文档内容分析器
/// 负责分析和组织文档内容，提取关键信息，评估内容重要性和结构
class ContentAnalyzer {
    private let sentimentAnalyzer: NLModel?
    private let keywordExtractor: KeywordExtractor
    private let sectionDetector: SectionDetector
    
    init() {
        // 加载情感分析模型（如果可用）
        if let modelURL = Bundle.main.url(forResource: "SentimentAnalysis", withExtension: "mlmodelc") {
            self.sentimentAnalyzer = try? NLModel(contentsOf: modelURL)
        } else {
            self.sentimentAnalyzer = nil
        }
        
        self.keywordExtractor = KeywordExtractor()
        self.sectionDetector = SectionDetector()
    }
    
    /// 分析文档内容
    func analyze(_ content: DocumentContent) async throws -> AnalyzedContent {
        // 创建分析结果
        var analyzedContent = AnalyzedContent(
            title: content.title,
            summary: content.summary ?? "",
            keywords: [],
            sections: []
        )
        
        // 提取关键词
        analyzedContent.keywords = await extractKeywords(from: content)
        
        // 检测章节
        let sections = await detectSections(in: content)
        
        // 分析每个章节
        analyzedContent.sections = await withTaskGroup(of: ContentSection.self) { group in
            for section in sections {
                group.addTask {
                    return await self.analyzeSection(section)
                }
            }
            
            var analyzedSections: [ContentSection] = []
            for await section in group {
                analyzedSections.append(section)
            }
            
            // 按原始顺序排序
            return analyzedSections.sorted { sections.firstIndex(of: $0)! < sections.firstIndex(of: $1)! }
        }
        
        return analyzedContent
    }
    
    /// 提取关键词
    private func extractKeywords(from content: DocumentContent) async -> [String] {
        // 组合所有内容文本
        var fullText = content.title + " " + (content.summary ?? "")
        
        for section in content.sections {
            fullText += " " + section.title
            
            for item in section.items {
                if let textContent = item.content as? String {
                    fullText += " " + textContent
                } else if let listContent = item.content as? [String] {
                    fullText += " " + listContent.joined(separator: " ")
                }
            }
        }
        
        // 使用关键词提取器
        return keywordExtractor.extract(from: fullText, maxCount: 15)
    }
    
    /// 检测文档章节
    private func detectSections(in content: DocumentContent) async -> [ContentSection] {
        // 如果文档已经有预定义的章节，使用它们
        if !content.sections.isEmpty {
            return content.sections
        }
        
        // 否则尝试从内容中检测章节
        return await sectionDetector.detectSections(in: content)
    }
    
    /// 分析单个章节
    private func analyzeSection(_ section: ContentSection) async -> ContentSection {
        var analyzedSection = section
        
        // 分析每个内容项的重要性和类型
        for i in 0..<analyzedSection.items.count {
            analyzedSection.items[i] = await analyzeContentItem(analyzedSection.items[i])
        }
        
        // 根据章节标题和内容评估章节重要性
        analyzedSection.importance = evaluateSectionImportance(analyzedSection)
        
        // 分析章节内容项之间的语义关系
        analyzedSection.items = await analyzeSemanticRelationships(analyzedSection.items)
        
        return analyzedSection
    }
    
    /// 分析内容项
    private func analyzeContentItem(_ item: ContentItem) async -> ContentItem {
        var analyzedItem = item
        
        // 根据内容类型分别处理
        switch item.type {
        case .text:
            analyzedItem = await analyzeTextItem(item)
        case .list:
            analyzedItem = await analyzeListItem(item)
        case .table:
            analyzedItem = await analyzeTableItem(item)
        case .image:
            analyzedItem = await analyzeImageItem(item)
        case .chart, .code:
            // 图表和代码默认重要性较高
            analyzedItem.importance = 8
        }
        
        return analyzedItem
    }
    
    /// 分析文本项
    private func analyzeTextItem(_ item: ContentItem) async -> ContentItem {
        guard let text = item.content as? String else { return item }
        
        var analyzedItem = item
        
        // 评估文本重要性
        let importance = await evaluateTextImportance(text)
        analyzedItem.importance = importance
        
        // 检测是否为标题
        analyzedItem.isTitle = detectIfTitle(text)
        
        return analyzedItem
    }
    
    /// 分析列表项
    private func analyzeListItem(_ item: ContentItem) async -> ContentItem {
        guard let listItems = item.content as? [String] else { return item }
        
        var analyzedItem = item
        
        // 列表重要性基于长度和内容
        let averageItemLength = listItems.reduce(0) { $0 + $1.count } / max(1, listItems.count)
        let baseImportance = min(7, 3 + listItems.count / 2)
        
        if averageItemLength > 50 {
            // 长列表项通常更重要
            analyzedItem.importance = baseImportance + 2
        } else {
            analyzedItem.importance = baseImportance
        }
        
        return analyzedItem
    }
    
    /// 分析表格项
    private func analyzeTableItem(_ item: ContentItem) async -> ContentItem {
        guard let tableData = item.content as? [[String]] else { return item }
        
        var analyzedItem = item
        
        // 表格的重要性基于大小和内容
        let rows = tableData.count
        let cols = tableData.first?.count ?? 0
        
        // 表格通常很重要，特别是大表格
        analyzedItem.importance = min(10, 6 + (rows * cols) / 10)
        
        return analyzedItem
    }
    
    /// 分析图片项
    private func analyzeImageItem(_ item: ContentItem) async -> ContentItem {
        // 图片通常很重要
        var analyzedItem = item
        analyzedItem.importance = 7
        
        // 如果有标题则更重要
        if !item.title.isEmpty {
            analyzedItem.importance = 8
        }
        
        return analyzedItem
    }
    
    /// 评估文本重要性 (1-10)
    private func evaluateTextImportance(_ text: String) async -> Int {
        // 基本启发式评估
        var importance = 5
        
        // 长度因素
        if text.count < 30 {
            importance -= 1
        } else if text.count > 200 {
            importance += 1
        }
        
        // 关键词因素
        let containsImportantTerms = ["重要", "关键", "核心", "必要", "significant", "important", "key", "essential", "critical"].contains { text.contains($0) }
        if containsImportantTerms {
            importance += 2
        }
        
        // 大写/强调因素
        let uppercaseRatio = Double(text.filter { $0.isUppercase }.count) / Double(text.count)
        if uppercaseRatio > 0.3 {
            importance += 1
        }
        
        // 如果有情感分析模型，使用它
        if let sentimentModel = sentimentAnalyzer {
            let sentiment = sentimentModel.predictedLabel(for: text) ?? ""
            if sentiment == "positive" {
                importance += 1
            } else if sentiment == "negative" {
                importance -= 1
            }
        }
        
        // 确保范围在1-10之间
        return min(10, max(1, importance))
    }
    
    /// 评估章节重要性 (1-10)
    private func evaluateSectionImportance(_ section: ContentSection) -> Int {
        // 基于标题和内容项的平均重要性计算
        let titleImportance = detectIfTitle(section.title) ? 8 : 5
        
        if section.items.isEmpty {
            return titleImportance
        }
        
        let contentImportance = section.items.reduce(0) { $0 + $1.importance } / section.items.count
        
        // 章节重要性是标题重要性和内容重要性的加权平均
        return (titleImportance * 2 + contentImportance) / 3
    }
    
    /// 检测文本是否为标题
    private func detectIfTitle(_ text: String) -> Bool {
        // 简单启发式检测
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 长度通常较短
        if trimmed.count > 100 {
            return false
        }
        
        // 没有句号通常是标题
        if !trimmed.contains(".") && !trimmed.contains("。") {
            return true
        }
        
        // 大写开头更可能是标题
        if let firstChar = trimmed.first, firstChar.isUppercase {
            return true
        }
        
        // 其他特征检查
        let endsWithPunctuation = [".", "!", "?", "。", "！", "？"].contains { trimmed.hasSuffix($0) }
        if !endsWithPunctuation && trimmed.count < 50 {
            return true
        }
        
        return false
    }
    
    /// 分析内容项之间的语义关系
    private func analyzeSemanticRelationships(_ items: [ContentItem]) async -> [ContentItem] {
        var relatedItems = items
        
        // 跳过过少的项目
        if items.count <= 1 {
            return items
        }
        
        // 创建项目之间的关系图
        var relationshipGraph: [Int: [Int: Double]] = [:] // [源项索引: [目标项索引: 相关性分数]]
        
        // 分析每对项目的相关性
        for i in 0..<items.count {
            relationshipGraph[i] = [:]
            
            for j in 0..<items.count {
                if i != j {
                    let relationScore = await calculateRelationScore(items[i], items[j])
                    relationshipGraph[i]?[j] = relationScore
                    
                    // 为有强关系的项目添加相关性标记
                    if relationScore > 0.7 {
                        // 在更新的项目上添加关联元数据
                        if var metaData = relatedItems[i].metadata as? [String: Any] {
                            var relatedIds = metaData["relatedItems"] as? [Int] ?? []
                            relatedIds.append(j)
                            metaData["relatedItems"] = relatedIds
                            relatedItems[i].metadata = metaData
                        } else {
                            relatedItems[i].metadata = ["relatedItems": [j]]
                        }
                    }
                }
            }
        }
        
        // 可以在这里添加更复杂的分析，如聚类或重排序
        
        return relatedItems
    }
    
    /// 计算两个内容项之间的相关性分数 (0.0-1.0)
    private func calculateRelationScore(_ item1: ContentItem, _ item2: ContentItem) async -> Double {
        // 提取两个项目的文本内容
        let text1 = extractText(from: item1)
        let text2 = extractText(from: item2)
        
        if text1.isEmpty || text2.isEmpty {
            return 0.1 // 如果任一项没有文本，则相关性低
        }
        
        // 1. 关键词重叠度分析
        let keywords1 = await extractImportantTerms(from: text1)
        let keywords2 = await extractImportantTerms(from: text2)
        
        let commonKeywords = Set(keywords1).intersection(Set(keywords2))
        let keywordOverlapScore = Double(commonKeywords.count) / Double(max(1, min(keywords1.count, keywords2.count)))
        
        // 2. 如果是图像和文本，检查文本是否提到图像
        if (item1.type == .image && item2.type == .text) || (item2.type == .image && item1.type == .text) {
            let imageItem = item1.type == .image ? item1 : item2
            let textItem = item1.type == .text ? item1 : item2
            
            if let textContent = textItem.content as? String {
                // 检查文本是否包含图像相关术语或图像的标题
                let imageKeywords = ["图", "图片", "照片", "图像", "显示", "展示", "image", "picture", "photo", "shown", "displayed"]
                let containsImageReference = imageKeywords.contains { textContent.contains($0) }
                
                if !imageItem.title.isEmpty && textContent.contains(imageItem.title) {
                    return 0.9 // 文本直接引用了图像标题，强相关
                }
                
                if containsImageReference {
                    return 0.7 // 文本提到了图像类术语，可能相关
                }
            }
        }
        
        // 3. 表格/图表和文本的关系
        if ((item1.type == .table || item1.type == .chart) && item2.type == .text) || 
           ((item2.type == .table || item2.type == .chart) && item1.type == .text) {
            let dataItem = (item1.type == .table || item1.type == .chart) ? item1 : item2
            let textItem = item1.type == .text ? item1 : item2
            
            if let textContent = textItem.content as? String {
                // 检查文本是否包含数据相关术语
                let dataKeywords = ["表", "表格", "数据", "图表", "统计", "显示", "table", "data", "chart", "statistics", "shows"]
                let containsDataReference = dataKeywords.contains { textContent.contains($0) }
                
                if !dataItem.title.isEmpty && textContent.contains(dataItem.title) {
                    return 0.85 // 文本直接引用了数据表/图表标题，强相关
                }
                
                if containsDataReference {
                    return 0.65 // 文本提到了数据类术语，可能相关
                }
            }
        }
        
        // 4. 代码块和文本的关系
        if (item1.type == .code && item2.type == .text) || (item2.type == .code && item1.type == .text) {
            let codeItem = item1.type == .code ? item1 : item2
            let textItem = item1.type == .text ? item1 : item2
            
            if let textContent = textItem.content as? String,
               let codeContent = codeItem.content as? String {
                // 检查文本是否包含代码中的关键标识符
                let codeIdentifiers = extractCodeIdentifiers(from: codeContent)
                let mentionsCode = codeIdentifiers.contains { textContent.contains($0) }
                
                if mentionsCode {
                    return 0.8 // 文本提到了代码中的标识符，很可能相关
                }
                
                // 检查文本是否包含代码相关术语
                let codeKeywords = ["代码", "函数", "变量", "方法", "类", "接口", "code", "function", "variable", "method", "class", "interface"]
                let containsCodeReference = codeKeywords.contains { textContent.contains($0) }
                
                if containsCodeReference {
                    return 0.6 // 文本提到了代码类术语，可能相关
                }
            }
        }
        
        // 5. 内容重要性相似度
        let importanceScore = 1.0 - Double(abs(item1.importance - item2.importance)) / 10.0
        
        // 综合评分 (加权平均)
        return keywordOverlapScore * 0.6 + importanceScore * 0.4
    }
    
    /// 从内容项中提取文本
    private func extractText(from item: ContentItem) -> String {
        switch item.type {
        case .text:
            return item.content as? String ?? ""
        case .list:
            if let listItems = item.content as? [String] {
                return listItems.joined(separator: " ")
            }
            return ""
        case .table:
            if let tableData = item.content as? [[String]] {
                return tableData.flatMap { $0 }.joined(separator: " ")
            }
            return ""
        case .image, .chart:
            return item.title
        case .code:
            return item.content as? String ?? ""
        }
    }
    
    /// 提取文本中的重要术语
    private func extractImportantTerms(from text: String) async -> [String] {
        // 使用NLP标记文本并提取重要的词语
        let tagger = NLTagger(tagSchemes: [.lemma, .nameType, .lexicalClass])
        tagger.string = text
        
        var terms: [String] = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        
        // 对名词、动词和专有名词特别关注
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            guard let tag = tag else { return true }
            
            let term = String(text[tokenRange])
            if term.count < 2 || isStopword(term) {
                return true
            }
            
            if tag == .noun || tag == .verb || tag == .adjective {
                terms.append(term.lowercased())
            }
            
            return true
        }
        
        // 添加专有名词
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            guard let tag = tag else { return true }
            
            if tag == .personalName || tag == .placeName || tag == .organizationName {
                let term = String(text[tokenRange])
                terms.append(term.lowercased())
            }
            
            return true
        }
        
        return terms
    }
    
    /// 从代码中提取关键标识符
    private func extractCodeIdentifiers(from code: String) -> [String] {
        // 简单的启发式方法，提取可能的标识符
        // 这里仅做简单处理，实际应用中可能需要更复杂的解析
        
        // 分割代码为单词，并过滤常见代码关键字和符号
        let codeWords = code.split { !$0.isLetter && !$0.isNumber && $0 != "_" }
            .map { String($0) }
            .filter { $0.count > 2 } // 只保留长度大于2的标识符
        
        // 过滤常见的编程语言关键字
        let commonKeywords = ["func", "function", "var", "let", "const", "class", "struct", "enum", "interface",
                             "if", "else", "for", "while", "switch", "case", "break", "return", "true", "false",
                             "public", "private", "protected", "static", "void", "int", "string", "bool", "float"]
        
        return codeWords.filter { !commonKeywords.contains($0.lowercased()) }
    }
    
    /// 检查是否为停用词
    private func isStopword(_ word: String) -> Bool {
        let commonStopwords = ["的", "地", "得", "和", "与", "或", "是", "在", "有", "这", "那", "一个", "了", "我", "你", "他", "她", "它", "们",
                              "the", "a", "an", "and", "or", "is", "are", "was", "were", "in", "on", "at", "to", "for", "with", "by",
                              "of", "this", "that", "these", "those", "it", "i", "you", "he", "she", "they", "we"]
        return commonStopwords.contains(word.lowercased())
    }
}

// MARK: - 关键词提取器

class KeywordExtractor {
    /// 提取文本中的关键词
    func extract(from text: String, maxCount: Int) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType, .lemma])
        tagger.string = text
        
        var keywords: [String: Int] = [:]
        
        // 设置标记选项
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
        
        // 标记文本以查找实体和关键词
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            guard let tag = tag else { return true }
            
            let token = String(text[tokenRange])
            // 排除常见的停用词和很短的词
            if !isStopword(token) && token.count > 2 {
                if tag == .personalName || tag == .organizationName || tag == .placeName {
                    // 实体名词更重要
                    keywords[token, default: 0] += 3
                } else {
                    keywords[token, default: 0] += 1
                }
            }
            
            return true
        }
        
        // 再次标记以查找词性
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            guard let tag = tag else { return true }
            
            let token = String(text[tokenRange])
            if !isStopword(token) && token.count > 2 {
                if tag == .noun || tag == .verb {
                    // 名词和动词更可能是关键词
                    keywords[token, default: 0] += 1
                }
            }
            
            return true
        }
        
        // 排序并限制数量
        let sortedKeywords = keywords.sorted { $0.value > $1.value }.prefix(maxCount).map { $0.key }
        
        return Array(sortedKeywords)
    }
    
    /// 检查是否为停用词
    private func isStopword(_ word: String) -> Bool {
        let commonStopwords = ["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "with", "by", "of", "是", "的", "了", "和", "与", "在", "对", "这", "那", "这个", "那个"]
        return commonStopwords.contains(word.lowercased())
    }
}

// MARK: - 章节检测器

class SectionDetector {
    /// 从内容中检测章节
    func detectSections(in content: DocumentContent) async -> [ContentSection] {
        // 如果内容已经有预定义的章节
        if !content.sections.isEmpty {
            return content.sections
        }
        
        // 分析内容项，尝试识别标题和章节
        var sections: [ContentSection] = []
        var currentSection: ContentSection?
        var currentItems: [ContentItem] = []
        
        // 扁平化所有内容项
        var allItems: [ContentItem] = []
        for section in content.sections {
            allItems.append(contentsOf: section.items)
        }
        
        if allItems.isEmpty {
            // 如果没有预处理章节，创建一个主章节
            return [ContentSection(
                title: content.title,
                items: [],
                importance: 5
            )]
        }
        
        // 扫描所有项目，识别章节
        for item in allItems {
            if isLikelyTitle(item) && !currentItems.isEmpty {
                // 完成当前章节
                if let section = currentSection {
                    var completedSection = section
                    completedSection.items = currentItems
                    sections.append(completedSection)
                } else {
                    // 创建一个带有默认标题的章节
                    sections.append(ContentSection(
                        title: "引言",
                        items: currentItems,
                        importance: 5
                    ))
                }
                
                // 开始新章节
                currentSection = ContentSection(
                    title: item.content as? String ?? "未命名章节",
                    items: [],
                    importance: 5
                )
                currentItems = []
            } else {
                // 添加到当前项目
                currentItems.append(item)
            }
        }
        
        // 添加最后一个章节
        if !currentItems.isEmpty {
            if let section = currentSection {
                var completedSection = section
                completedSection.items = currentItems
                sections.append(completedSection)
            } else {
                // 如果没有标题，创建一个默认章节
                sections.append(ContentSection(
                    title: content.title,
                    items: currentItems,
                    importance: 5
                ))
            }
        }
        
        // 如果没有检测到章节，创建单个章节
        if sections.isEmpty {
            sections = [ContentSection(
                title: content.title,
                items: allItems,
                importance: 5
            )]
        }
        
        return sections
    }
    
    /// 检查内容项是否像一个标题
    private func isLikelyTitle(_ item: ContentItem) -> Bool {
        // 如果已标记为标题
        if item.isTitle {
            return true
        }
        
        // 检查文本类型
        if item.type == .text, let text = item.content as? String {
            // 启发式检测
            // 短文本
            if text.count < 80 && text.count > 0 {
                // 不包含句号
                if !text.contains(".") && !text.contains("。") {
                    // 文本开头是大写或特定字符
                    if let firstChar = text.first, firstChar.isUppercase || firstChar == "#" || firstChar == "第" {
                        return true
                    }
                    
                    // 数字开头可能是章节标题
                    let startsWithNumber = text.first?.isNumber ?? false
                    if startsWithNumber && text.count < 40 {
                        return true
                    }
                    
                    // 特定前缀模式
                    let titlePrefixes = ["Chapter", "Section", "Part", "第", "章", "节", "部分"]
                    for prefix in titlePrefixes {
                        if text.hasPrefix(prefix) {
                            return true
                        }
                    }
                }
            }
        }
        
        return false
    }
}

// MARK: - 数据模型

/// 分析后的内容
struct AnalyzedContent {
    var title: String
    var summary: String
    var keywords: [String]
    var sections: [ContentSection]
}

/// 内容章节
struct ContentSection: Equatable {
    var title: String
    var items: [ContentItem]
    var importance: Int = 5
    
    static func ==(lhs: ContentSection, rhs: ContentSection) -> Bool {
        return lhs.title == rhs.title
    }
}

/// 内容项
struct ContentItem {
    var id: String
    var title: String
    var content: Any
    var type: ContentItemType
    var isTitle: Bool = false
    var importance: Int = 5
    var metadata: [String: Any]? = nil
    
    init(title: String, content: Any, type: ContentItemType) {
        self.id = UUID().uuidString
        self.title = title
        self.content = content
        self.type = type
    }
}

/// 内容项类型
enum ContentItemType {
    case text
    case list
    case table
    case image
    case chart
    case code
}

/// 文档内容
struct DocumentContent {
    var title: String
    var summary: String?
    var sections: [ContentSection]
} 