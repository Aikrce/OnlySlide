import Foundation
import AppKit

/// 内容融合引擎
/// 整合分析结果并生成最终的一致性演示文稿
class ContentFusionEngine {
    // 依赖组件
    private let themeManager: VisualThemeManager
    private let relationAnalyzer: ContentRelationAnalyzer
    private let templateEngine: ContentTemplateEngine
    
    // 初始化
    init(themeManager: VisualThemeManager,
         relationAnalyzer: ContentRelationAnalyzer,
         templateEngine: ContentTemplateEngine) {
        self.themeManager = themeManager
        self.relationAnalyzer = relationAnalyzer
        self.templateEngine = templateEngine
    }
    
    /// 融合内容并生成演示文稿
    func fuseContentIntoPresentation(_ analyzedContent: AnalyzedContent,
                                    selectedTheme: VisualTheme) -> PresentationDocument {
        // 1. 进行关系分析和增强
        let enhancedContent = relationAnalyzer.analyzeAndEnhanceContent(analyzedContent)
        
        // 2. 映射内容到模板
        let templateMappings = templateEngine.mapContentToTemplates(enhancedContent, theme: selectedTheme)
        
        // 3. 应用建议的章节顺序 (如果合理)
        let orderedSections = reorderSections(enhancedContent)
        
        // 4. 构建演示文稿
        let presentation = buildPresentation(
            orderedSections: orderedSections,
            mappings: templateMappings,
            enhancedContent: enhancedContent,
            theme: selectedTheme
        )
        
        // 5. 应用和谐化处理
        let harmonizedPresentation = harmonizePresentation(presentation)
        
        return harmonizedPresentation
    }
    
    /// 重新排序章节
    private func reorderSections(_ enhancedContent: EnhancedContent) -> [ContentSection] {
        // 获取原内容和建议顺序
        let originalSections = enhancedContent.originalContent.sections
        let suggestedOrder = enhancedContent.suggestedSectionOrder
        
        // 按建议顺序重排章节
        var orderedSections: [ContentSection] = []
        
        for index in suggestedOrder {
            if index < originalSections.count {
                orderedSections.append(originalSections[index])
            }
        }
        
        // 确保所有章节都被包含
        for (index, section) in originalSections.enumerated() {
            if !suggestedOrder.contains(index) {
                orderedSections.append(section)
            }
        }
        
        return orderedSections
    }
    
    /// 构建演示文稿
    private func buildPresentation(
        orderedSections: [ContentSection],
        mappings: [TemplateMappingResult],
        enhancedContent: EnhancedContent,
        theme: VisualTheme
    ) -> PresentationDocument {
        var presentation = PresentationDocument(
            title: enhancedContent.originalContent.title,
            slides: []
        )
        
        // 添加封面幻灯片
        let coverSlide = createCoverSlide(enhancedContent.originalContent, theme)
        presentation.slides.append(coverSlide)
        
        // 添加目录幻灯片
        let tocSlide = createTableOfContentsSlide(orderedSections, theme)
        presentation.slides.append(tocSlide)
        
        // 为每个章节创建幻灯片
        for (index, section) in orderedSections.enumerated() {
            // 查找该章节的模板映射
            let sectionMappings = mappings.filter { $0.sectionIndex == findOriginalIndex(section, in: enhancedContent.originalContent.sections) }
            
            // 章节标题幻灯片
            let sectionTitleSlide = createSectionTitleSlide(section, theme)
            presentation.slides.append(sectionTitleSlide)
            
            // 章节内容幻灯片
            let contentSlides = createContentSlides(
                section,
                mappings: sectionMappings,
                enhancedContent: enhancedContent,
                theme: theme,
                isLastSection: index == orderedSections.count - 1
            )
            
            presentation.slides.append(contentsOf: contentSlides)
            
            // 过渡幻灯片（除了最后一个章节）
            if index < orderedSections.count - 1 {
                if let transitionSlide = createTransitionSlide(
                    fromSection: section,
                    toSection: orderedSections[index + 1],
                    enhancedContent: enhancedContent,
                    theme: theme
                ) {
                    presentation.slides.append(transitionSlide)
                }
            }
        }
        
        // 添加总结幻灯片
        let summarySlide = createSummarySlide(enhancedContent, theme)
        presentation.slides.append(summarySlide)
        
        // 添加结束/谢谢幻灯片
        let thankYouSlide = createThankYouSlide(theme)
        presentation.slides.append(thankYouSlide)
        
        return presentation
    }
    
    /// 查找章节在原始内容中的索引
    private func findOriginalIndex(_ section: ContentSection, in originalSections: [ContentSection]) -> Int {
        if let index = originalSections.firstIndex(where: { $0.id == section.id }) {
            return index
        }
        return 0
    }
    
    /// 创建封面幻灯片
    private func createCoverSlide(_ content: AnalyzedContent, _ theme: VisualTheme) -> PresentationSlide {
        let layout = SlideLayout(
            type: .cover,
            background: theme.coverSlideBackground,
            textStyle: theme.titleTextStyle
        )
        
        let titleElement = SlideElement(
            type: .title,
            content: content.title,
            position: CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.2),
            style: theme.titleTextStyle
        )
        
        let subtitleElement = SlideElement(
            type: .subtitle,
            content: content.subtitle ?? "演示文稿",
            position: CGRect(x: 0.2, y: 0.6, width: 0.6, height: 0.1),
            style: theme.subtitleTextStyle
        )
        
        var elements = [titleElement, subtitleElement]
        
        // 如果有作者信息
        if let author = content.author {
            let authorElement = SlideElement(
                type: .text,
                content: author,
                position: CGRect(x: 0.3, y: 0.75, width: 0.4, height: 0.05),
                style: theme.bodyTextStyle
            )
            elements.append(authorElement)
        }
        
        // 如果有日期信息
        if let date = content.date {
            let dateElement = SlideElement(
                type: .text,
                content: date,
                position: CGRect(x: 0.3, y: 0.82, width: 0.4, height: 0.05),
                style: theme.captionTextStyle
            )
            elements.append(dateElement)
        }
        
        return PresentationSlide(
            id: UUID().uuidString,
            title: "封面",
            elements: elements,
            layout: layout,
            notes: "开场白：\(content.title) 演示文稿"
        )
    }
    
    /// 创建目录幻灯片
    private func createTableOfContentsSlide(_ sections: [ContentSection], _ theme: VisualTheme) -> PresentationSlide {
        let layout = SlideLayout(
            type: .tableOfContents,
            background: theme.contentSlideBackground,
            textStyle: theme.bodyTextStyle
        )
        
        let titleElement = SlideElement(
            type: .title,
            content: "目录",
            position: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.1),
            style: theme.sectionTitleStyle
        )
        
        var elements = [titleElement]
        
        // 为每个章节创建目录项
        for (index, section) in sections.enumerated() {
            let yPosition = 0.25 + Double(index) * 0.07
            
            let tocItemElement = SlideElement(
                type: .text,
                content: "\(index + 1). \(section.title)",
                position: CGRect(x: 0.15, y: yPosition, width: 0.7, height: 0.06),
                style: theme.tocItemStyle
            )
            
            elements.append(tocItemElement)
        }
        
        return PresentationSlide(
            id: UUID().uuidString,
            title: "目录",
            elements: elements,
            layout: layout,
            notes: "今天我们将会讨论以下几个主题..."
        )
    }
    
    /// 创建章节标题幻灯片
    private func createSectionTitleSlide(_ section: ContentSection, _ theme: VisualTheme) -> PresentationSlide {
        let layout = SlideLayout(
            type: .sectionHeader,
            background: theme.sectionHeaderBackground,
            textStyle: theme.sectionTitleStyle
        )
        
        let titleElement = SlideElement(
            type: .title,
            content: section.title,
            position: CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.2),
            style: theme.sectionTitleStyle
        )
        
        var elements = [titleElement]
        
        // 添加可选的装饰元素
        if let decorativeImage = theme.decorativeElements["sectionHeader"] {
            let imageElement = SlideElement(
                type: .image,
                content: decorativeImage,
                position: CGRect(x: 0.8, y: 0.8, width: 0.15, height: 0.15),
                style: nil
            )
            elements.append(imageElement)
        }
        
        return PresentationSlide(
            id: UUID().uuidString,
            title: section.title,
            elements: elements,
            layout: layout,
            notes: "在这一部分，我们将讨论\(section.title)..."
        )
    }
    
    /// 创建内容幻灯片
    private func createContentSlides(
        _ section: ContentSection,
        mappings: [TemplateMappingResult],
        enhancedContent: EnhancedContent,
        theme: VisualTheme,
        isLastSection: Bool
    ) -> [PresentationSlide] {
        var slides: [PresentationSlide] = []
        
        // 如果没有映射结果，使用默认模板
        if mappings.isEmpty {
            let contentItems = section.items
            
            // 每张幻灯片最多显示3个内容项
            for i in stride(from: 0, to: contentItems.count, by: 3) {
                let layout = SlideLayout(
                    type: .content,
                    background: theme.contentSlideBackground,
                    textStyle: theme.bodyTextStyle
                )
                
                let titleElement = SlideElement(
                    type: .title,
                    content: section.title,
                    position: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.1),
                    style: theme.slideTitleStyle
                )
                
                var elements = [titleElement]
                
                // 添加当前幻灯片的内容项
                let endIndex = min(i + 3, contentItems.count)
                for j in i..<endIndex {
                    let item = contentItems[j]
                    let yPosition = 0.25 + Double(j - i) * 0.2
                    
                    let contentElement = createElementFromContentItem(
                        item,
                        position: CGRect(x: 0.1, y: yPosition, width: 0.8, height: 0.15),
                        theme: theme
                    )
                    
                    elements.append(contentElement)
                }
                
                // 如果是最后一节的最后一张幻灯片，添加总结提示
                if isLastSection && endIndex == contentItems.count {
                    let summaryHintElement = SlideElement(
                        type: .text,
                        content: "接下来是总结...",
                        position: CGRect(x: 0.7, y: 0.9, width: 0.25, height: 0.05),
                        style: theme.captionTextStyle
                    )
                    elements.append(summaryHintElement)
                }
                
                let slide = PresentationSlide(
                    id: UUID().uuidString,
                    title: "\(section.title) - \(i/3 + 1)",
                    elements: elements,
                    layout: layout,
                    notes: "讲解\(section.title)的关键点..."
                )
                
                slides.append(slide)
            }
        } else {
            // 使用映射结果创建幻灯片
            for mapping in mappings {
                let templateSlide = mapping.template.createSlide(
                    withContent: mapping.contentMappings,
                    theme: theme
                )
                slides.append(templateSlide)
            }
        }
        
        return slides
    }
    
    /// 从内容项创建幻灯片元素
    private func createElementFromContentItem(_ item: ContentItem, position: CGRect, theme: VisualTheme) -> SlideElement {
        switch item.type {
        case .text:
            guard let text = item.content as? String else {
                return SlideElement(
                    type: .text,
                    content: "文本内容",
                    position: position,
                    style: theme.bodyTextStyle
                )
            }
            
            return SlideElement(
                type: .text,
                content: text,
                position: position,
                style: theme.bodyTextStyle
            )
            
        case .list:
            guard let listItems = item.content as? [String] else {
                return SlideElement(
                    type: .bulletList,
                    content: ["列表项"],
                    position: position,
                    style: theme.listStyle
                )
            }
            
            return SlideElement(
                type: .bulletList,
                content: listItems,
                position: position,
                style: theme.listStyle
            )
            
        case .image:
            guard let imageUrl = item.content as? String else {
                return SlideElement(
                    type: .image,
                    content: "image_placeholder",
                    position: position,
                    style: nil
                )
            }
            
            return SlideElement(
                type: .image,
                content: imageUrl,
                position: position,
                style: nil
            )
            
        case .chart:
            guard let chartData = item.content else {
                return SlideElement(
                    type: .chart,
                    content: ["数据1": 10, "数据2": 20],
                    position: position,
                    style: theme.chartStyle
                )
            }
            
            return SlideElement(
                type: .chart,
                content: chartData,
                position: position,
                style: theme.chartStyle
            )
            
        case .table:
            guard let tableData = item.content else {
                return SlideElement(
                    type: .table,
                    content: [["标题1", "标题2"], ["数据1", "数据2"]],
                    position: position,
                    style: theme.tableStyle
                )
            }
            
            return SlideElement(
                type: .table,
                content: tableData,
                position: position,
                style: theme.tableStyle
            )
            
        case .code:
            guard let codeText = item.content as? String else {
                return SlideElement(
                    type: .code,
                    content: "// 示例代码",
                    position: position,
                    style: theme.codeStyle
                )
            }
            
            return SlideElement(
                type: .code,
                content: codeText,
                position: position,
                style: theme.codeStyle
            )
        }
    }
    
    /// 创建过渡幻灯片
    private func createTransitionSlide(
        fromSection: ContentSection,
        toSection: ContentSection,
        enhancedContent: EnhancedContent,
        theme: VisualTheme
    ) -> PresentationSlide? {
        // 查找从当前章节到下一章节的过渡建议
        let fromIndex = findOriginalIndex(fromSection, in: enhancedContent.originalContent.sections)
        let toIndex = findOriginalIndex(toSection, in: enhancedContent.originalContent.sections)
        
        // 查找适当的过渡建议
        let transitionSuggestion = enhancedContent.transitionSuggestions.first { 
            $0.sourceSection == fromIndex && $0.targetSection == toIndex
        }
        
        guard let suggestion = transitionSuggestion else {
            // 如果没有特定的过渡建议，不创建过渡幻灯片
            return nil
        }
        
        let layout = SlideLayout(
            type: .transition,
            background: theme.transitionSlideBackground,
            textStyle: theme.bodyTextStyle
        )
        
        let transitionElement = SlideElement(
            type: .text,
            content: suggestion.suggestedText,
            position: CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.2),
            style: theme.subtitleTextStyle
        )
        
        let nextSectionHint = SlideElement(
            type: .text,
            content: "下一部分: \(toSection.title)",
            position: CGRect(x: 0.1, y: 0.65, width: 0.8, height: 0.1),
            style: theme.captionTextStyle
        )
        
        let slide = PresentationSlide(
            id: UUID().uuidString,
            title: "过渡",
            elements: [transitionElement, nextSectionHint],
            layout: layout,
            notes: "过渡到下一部分：\(suggestion.suggestedText)"
        )
        
        return slide
    }
    
    /// 创建总结幻灯片
    private func createSummarySlide(_ enhancedContent: EnhancedContent, _ theme: VisualTheme) -> PresentationSlide {
        let layout = SlideLayout(
            type: .summary,
            background: theme.summarySlideBackground,
            textStyle: theme.bodyTextStyle
        )
        
        let titleElement = SlideElement(
            type: .title,
            content: "总结",
            position: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.1),
            style: theme.sectionTitleStyle
        )
        
        var elements = [titleElement]
        
        // 添加主题总结
        if !enhancedContent.themes.isEmpty {
            for (index, theme) in enhancedContent.themes.prefix(3).enumerated() {
                let yPosition = 0.25 + Double(index) * 0.15
                
                let themeElement = SlideElement(
                    type: .text,
                    content: "• \(theme.name)",
                    position: CGRect(x: 0.15, y: yPosition, width: 0.7, height: 0.1),
                    style: theme.listStyle
                )
                
                elements.append(themeElement)
            }
        } else {
            // 使用关键摘要
            for (index, summary) in enhancedContent.keySummaries.prefix(3).enumerated() {
                let yPosition = 0.25 + Double(index) * 0.15
                
                let keyPoint = summary.keyPoints.first ?? "重要点"
                let summaryElement = SlideElement(
                    type: .text,
                    content: "• \(keyPoint)",
                    position: CGRect(x: 0.15, y: yPosition, width: 0.7, height: 0.1),
                    style: theme.listStyle
                )
                
                elements.append(summaryElement)
            }
        }
        
        return PresentationSlide(
            id: UUID().uuidString,
            title: "总结",
            elements: elements,
            layout: layout,
            notes: "总结今天讨论的主要内容..."
        )
    }
    
    /// 创建感谢幻灯片
    private func createThankYouSlide(_ theme: VisualTheme) -> PresentationSlide {
        let layout = SlideLayout(
            type: .thankYou,
            background: theme.endSlideBackground,
            textStyle: theme.bodyTextStyle
        )
        
        let thankYouElement = SlideElement(
            type: .title,
            content: "谢谢!",
            position: CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.2),
            style: theme.titleTextStyle
        )
        
        let questionsElement = SlideElement(
            type: .subtitle,
            content: "有问题吗?",
            position: CGRect(x: 0.2, y: 0.6, width: 0.6, height: 0.1),
            style: theme.subtitleTextStyle
        )
        
        var elements = [thankYouElement, questionsElement]
        
        // 添加可选的装饰元素
        if let decorativeImage = theme.decorativeElements["thankYou"] {
            let imageElement = SlideElement(
                type: .image,
                content: decorativeImage,
                position: CGRect(x: 0.8, y: 0.8, width: 0.15, height: 0.15),
                style: nil
            )
            elements.append(imageElement)
        }
        
        return PresentationSlide(
            id: UUID().uuidString,
            title: "谢谢",
            elements: elements,
            layout: layout,
            notes: "感谢大家的聆听，现在开始回答问题环节。"
        )
    }
    
    /// 和谐化演示文稿（应用一致性）
    private func harmonizePresentation(_ presentation: PresentationDocument) -> PresentationDocument {
        var harmonizedPresentation = presentation
        
        // 确保所有幻灯片使用一致的样式
        for i in 0..<harmonizedPresentation.slides.count {
            // 应用标准元素位置和大小
            harmonizedPresentation.slides[i] = standardizeElementPlacement(harmonizedPresentation.slides[i])
            
            // 检查及修复乱码或特殊字符
            harmonizedPresentation.slides[i] = sanitizeSlideContent(harmonizedPresentation.slides[i])
            
            // 确保幻灯片编号正确
            if i > 1 { // 跳过封面和目录
                let slideNumberElement = SlideElement(
                    type: .text,
                    content: "\(i-1)/\(presentation.slides.count-3)",
                    position: CGRect(x: 0.9, y: 0.95, width: 0.1, height: 0.05),
                    style: TextStyle(fontName: "HelveticaNeue", fontSize: 12, color: NSColor.gray, alignment: .right)
                )
                
                harmonizedPresentation.slides[i].elements.append(slideNumberElement)
            }
        }
        
        return harmonizedPresentation
    }
    
    /// 标准化元素位置和大小
    private func standardizeElementPlacement(_ slide: PresentationSlide) -> PresentationSlide {
        var standardizedSlide = slide
        var updatedElements: [SlideElement] = []
        
        for element in standardizedSlide.elements {
            var updatedElement = element
            
            // 修正任何超出边界的元素
            var position = element.position
            if position.origin.x < 0 {
                position.origin.x = 0.05
            }
            if position.origin.y < 0 {
                position.origin.y = 0.05
            }
            if position.origin.x + position.size.width > 1 {
                position.size.width = 1 - position.origin.x - 0.05
            }
            if position.origin.y + position.size.height > 1 {
                position.size.height = 1 - position.origin.y - 0.05
            }
            
            updatedElement.position = position
            updatedElements.append(updatedElement)
        }
        
        standardizedSlide.elements = updatedElements
        return standardizedSlide
    }
    
    /// 清理幻灯片内容
    private func sanitizeSlideContent(_ slide: PresentationSlide) -> PresentationSlide {
        var sanitizedSlide = slide
        var sanitizedElements: [SlideElement] = []
        
        for element in sanitizedSlide.elements {
            var sanitizedElement = element
            
            switch element.type {
            case .title, .subtitle, .text:
                if let content = element.content as? String {
                    let sanitizedContent = sanitizeText(content)
                    sanitizedElement.content = sanitizedContent
                }
                
            case .bulletList:
                if let listItems = element.content as? [String] {
                    let sanitizedItems = listItems.map { sanitizeText($0) }
                    sanitizedElement.content = sanitizedItems
                }
                
            default:
                // 其他类型保持不变
                break
            }
            
            sanitizedElements.append(sanitizedElement)
        }
        
        sanitizedSlide.elements = sanitizedElements
        return sanitizedSlide
    }
    
    /// 清理文本内容
    private func sanitizeText(_ text: String) -> String {
        // 移除或替换可能导致显示问题的特殊字符
        var sanitized = text
        
        // 替换不可见字符或控制字符
        let controlChars = CharacterSet.controlCharacters
        sanitized = sanitized.components(separatedBy: controlChars).joined(separator: "")
        
        // 替换多余的空格
        sanitized = sanitized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // 移除超长的行（每行最多200个字符）
        let lines = sanitized.split(separator: "\n")
        let truncatedLines = lines.map { line -> String in
            let str = String(line)
            if str.count > 200 {
                return str.prefix(197) + "..."
            }
            return str
        }
        
        return truncatedLines.joined(separator: "\n")
    }
}

// MARK: - 支持类型

// 引用已定义的类型 