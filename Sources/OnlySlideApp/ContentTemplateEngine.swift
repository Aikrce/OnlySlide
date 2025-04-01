import Foundation
import SwiftUI
import CoreML

// MARK: - 内容-模板融合引擎

/// 内容-模板智能融合引擎
/// 负责将文档分析结果与模板进行融合，生成最终演示文稿
class ContentTemplateEngine {
    // 依赖组件
    private let contentAnalyzer: ContentAnalyzer
    private let templateAdapter: TemplateAdapter
    private let layoutOptimizer: LayoutOptimizer
    private let styleManager: StyleManager
    
    init(
        contentAnalyzer: ContentAnalyzer = ContentAnalyzer(),
        templateAdapter: TemplateAdapter = TemplateAdapter(),
        layoutOptimizer: LayoutOptimizer = LayoutOptimizer(),
        styleManager: StyleManager = StyleManager()
    ) {
        self.contentAnalyzer = contentAnalyzer
        self.templateAdapter = templateAdapter
        self.layoutOptimizer = layoutOptimizer
        self.styleManager = styleManager
    }
    
    /// 将文档内容应用到演示模板
    func applyContent(_ content: DocumentContent, to template: PresentationTemplate) async throws -> Presentation {
        // 1. 分析内容结构和重要性
        let analyzedContent = try await contentAnalyzer.analyze(content)
        
        // 2. 创建内容分布计划
        let distributionPlan = try createDistributionPlan(analyzedContent, template)
        
        // 3. 进行样式匹配
        let styleMappings = styleManager.matchStyles(content: analyzedContent, template: template)
        
        // 4. 应用分布计划和样式，创建演示文稿
        var presentation = try await applyDistribution(distributionPlan, styleMappings, template)
        
        // 5. 优化最终布局
        presentation = layoutOptimizer.optimizePresentation(presentation)
        
        return presentation
    }
    
    /// 创建内容分布计划
    private func createDistributionPlan(_ content: AnalyzedContent, _ template: PresentationTemplate) throws -> DistributionPlan {
        // 根据内容结构和模板特性创建分布计划
        
        let sections = content.sections
        var slidePlans: [SlidePlan] = []
        
        // 创建封面幻灯片
        if let coverLayout = template.masterLayouts.first(where: { $0.type == "cover" }) {
            let coverPlan = SlidePlan(
                layoutType: "cover",
                contentItems: [
                    .text(TextItem(
                        content: content.title,
                        role: .title,
                        placement: .center
                    ))
                ],
                importance: .high
            )
            slidePlans.append(coverPlan)
        }
        
        // 为每个章节创建幻灯片
        for section in sections {
            // 为章节标题创建幻灯片
            let titleSlide = createSectionTitleSlide(for: section, in: template)
            slidePlans.append(titleSlide)
            
            // 根据章节内容创建内容幻灯片
            let contentSlides = createContentSlides(for: section, in: template)
            slidePlans.append(contentsOf: contentSlides)
        }
        
        return DistributionPlan(slidePlans: slidePlans)
    }
    
    /// 为章节创建标题幻灯片
    private func createSectionTitleSlide(for section: ContentSection, in template: PresentationTemplate) -> SlidePlan {
        // 使用章节分隔布局
        let sectionLayout = template.masterLayouts.first { $0.type == "section" } ?? 
                            template.masterLayouts.first { $0.type == "title" } ?? 
                            template.masterLayouts[0]
        
        return SlidePlan(
            layoutType: sectionLayout.type,
            contentItems: [
                .text(TextItem(
                    content: section.title,
                    role: .title,
                    placement: .center
                ))
            ],
            importance: .high
        )
    }
    
    /// 为章节内容创建幻灯片
    private func createContentSlides(for section: ContentSection, in template: PresentationTemplate) -> [SlidePlan] {
        var plans: [SlidePlan] = []
        
        // 根据内容类型和重要性智能分组
        let contentGroups = organizeContentIntoGroups(section.items)
        
        // 为每组内容创建幻灯片
        for group in contentGroups {
            let slidePlan = createSlideForContentGroup(group, in: template, sectionTitle: section.title)
            plans.append(slidePlan)
        }
        
        return plans
    }
    
    /// 将内容项智能分组为幻灯片
    private func organizeContentIntoGroups(_ items: [ContentItem]) -> [[ContentItem]] {
        // 首先分离标题项和普通内容项
        var titleItems: [ContentItem] = []
        var contentItems: [ContentItem] = []
        
        for item in items {
            if item.isTitle || (item.type == .text && item.importance >= 8) {
                titleItems.append(item)
            } else {
                contentItems.append(item)
            }
        }
        
        // 如果没有内容，直接返回
        if contentItems.isEmpty {
            return titleItems.map { [$0] }
        }
        
        // 内容智能分组
        var groups: [[ContentItem]] = []
        
        // 1. 按类型分组
        var imageItems: [ContentItem] = []
        var textItems: [ContentItem] = []
        var listItems: [ContentItem] = []
        var tableItems: [ContentItem] = []
        var chartItems: [ContentItem] = []
        var codeItems: [ContentItem] = []
        
        for item in contentItems {
            switch item.type {
            case .image: imageItems.append(item)
            case .text: textItems.append(item)
            case .list: listItems.append(item)
            case .table: tableItems.append(item)
            case .chart: chartItems.append(item)
            case .code: codeItems.append(item)
            }
        }
        
        // 2. 智能组合图像和相关文本
        let imageTextGroups = createImageTextGroups(imageItems, textItems)
        groups.append(contentsOf: imageTextGroups)
        
        // 从已分组的列表中移除已使用的项目
        let usedImageIds = imageTextGroups.flatMap { $0 }.filter { $0.type == .image }.map { $0.id }
        let usedTextIds = imageTextGroups.flatMap { $0 }.filter { $0.type == .text }.map { $0.id }
        
        imageItems = imageItems.filter { !usedImageIds.contains($0.id) }
        textItems = textItems.filter { !usedTextIds.contains($0.id) }
        
        // 3. 图表及其相关文本组合
        let chartGroups = createChartGroups(chartItems, textItems)
        groups.append(contentsOf: chartGroups)
        
        // 移除已使用的项目
        let usedChartIds = chartGroups.flatMap { $0 }.filter { $0.type == .chart }.map { $0.id }
        let usedChartTextIds = chartGroups.flatMap { $0 }.filter { $0.type == .text }.map { $0.id }
        
        chartItems = chartItems.filter { !usedChartIds.contains($0.id) }
        textItems = textItems.filter { !usedChartTextIds.contains($0.id) }
        
        // 4. 表格及其相关文本组合
        for table in tableItems {
            let relevantText = findMostRelevantText(for: table, from: textItems)
            if let text = relevantText {
                groups.append([table, text])
                textItems = textItems.filter { $0.id != text.id }
            } else {
                groups.append([table])
            }
        }
        
        // 5. 相同类型的内容分组（考虑复杂度）
        if !textItems.isEmpty {
            groups.append(contentsOf: createGroupsOfSameType(textItems, .text))
        }
        
        if !listItems.isEmpty {
            groups.append(contentsOf: createGroupsOfSameType(listItems, .list))
        }
        
        if !codeItems.isEmpty {
            // 代码项通常是独立的
            for codeItem in codeItems {
                groups.append([codeItem])
            }
        }
        
        // 6. 处理剩余的图片和图表
        for item in imageItems + chartItems {
            groups.append([item])
        }
        
        // 7. 确保每个标题有一个关联的内容组
        for titleItem in titleItems {
            // 查找内容组是否已包含此标题
            let titleInGroups = groups.contains { group in
                group.contains { $0.id == titleItem.id }
            }
            
            if !titleInGroups {
                // 查找最相关的内容组
                if let bestGroupIndex = findBestGroupForTitle(titleItem, groups) {
                    groups[bestGroupIndex].insert(titleItem, at: 0)
                } else {
                    // 如果没有找到合适的组，为标题创建单独的组
                    groups.insert([titleItem], at: 0)
                }
            }
        }
        
        return groups
    }
    
    /// 创建图像和文本的组合组
    private func createImageTextGroups(_ images: [ContentItem], _ texts: [ContentItem]) -> [[ContentItem]] {
        var groups: [[ContentItem]] = []
        var remainingTexts = texts
        
        for image in images {
            if let relatedText = findMostRelevantText(for: image, from: remainingTexts) {
                groups.append([image, relatedText])
                remainingTexts = remainingTexts.filter { $0.id != relatedText.id }
            } else if images.count <= 3 {
                // 如果图片不多，可以单独成组
                groups.append([image])
            }
        }
        
        // 如果还有剩余的图片，且数量较多，创建图片画廊
        let remainingImages = images.filter { image in
            !groups.contains { group in
                group.contains { item in item.id == image.id }
            }
        }
        
        if remainingImages.count >= 3 {
            // 每组最多放4张图片
            let maxImagesPerGroup = 4
            for i in stride(from: 0, to: remainingImages.count, by: maxImagesPerGroup) {
                let endIndex = min(i + maxImagesPerGroup, remainingImages.count)
                let galleryGroup = Array(remainingImages[i..<endIndex])
                if !galleryGroup.isEmpty {
                    groups.append(galleryGroup)
                }
            }
        } else {
            // 剩余少量图片单独成组
            for image in remainingImages {
                groups.append([image])
            }
        }
        
        return groups
    }
    
    /// 找到与内容项最相关的文本
    private func findMostRelevantText(for item: ContentItem, from texts: [ContentItem]) -> ContentItem? {
        // 如果文本为空，返回nil
        if texts.isEmpty {
            return nil
        }
        
        // 1. 首先查找标题匹配
        if !item.title.isEmpty {
            for text in texts {
                if let textContent = text.content as? String, 
                   textContent.lowercased().contains(item.title.lowercased()) {
                    return text
                }
            }
        }
        
        // 2. 查找内容关键词匹配
        var bestMatch: ContentItem? = nil
        var highestScore = 0
        
        for text in texts {
            guard let textContent = text.content as? String else { continue }
            
            var score = 0
            
            // 根据内容类型计算相关性分数
            switch item.type {
            case .image:
                // 图片相关关键词
                let imageKeywords = ["图", "图片", "照片", "截图", "图像", "image", "picture", "photo", "screenshot"]
                for keyword in imageKeywords {
                    if textContent.contains(keyword) {
                        score += 2
                    }
                }
                
            case .chart:
                // 图表相关关键词
                let chartKeywords = ["图表", "统计", "数据", "趋势", "chart", "graph", "data", "statistics", "trend"]
                for keyword in chartKeywords {
                    if textContent.contains(keyword) {
                        score += 2
                    }
                }
                
            case .table:
                // 表格相关关键词
                let tableKeywords = ["表", "表格", "数据", "列表", "table", "data", "list"]
                for keyword in tableKeywords {
                    if textContent.contains(keyword) {
                        score += 2
                    }
                }
                
            default:
                break
            }
            
            // 考虑文本重要性
            score += text.importance
            
            // 文本长度适中加分
            let textLength = textContent.count
            if textLength > 30 && textLength < 200 {
                score += 1
            }
            
            // 更新最佳匹配
            if score > highestScore {
                highestScore = score
                bestMatch = text
            }
        }
        
        // 只有当分数足够高时才返回匹配
        if highestScore >= 3 {
            return bestMatch
        }
        
        // 3. 如果没有找到明确的匹配，返回第一个文本（如果有）
        if !texts.isEmpty && item.importance >= 7 {
            return texts.first
        }
        
        return nil
    }
    
    /// 创建图表和相关文本的组合
    private func createChartGroups(_ charts: [ContentItem], _ texts: [ContentItem]) -> [[ContentItem]] {
        var groups: [[ContentItem]] = []
        
        for chart in charts {
            if let relatedText = findMostRelevantText(for: chart, from: texts) {
                groups.append([chart, relatedText])
            } else {
                groups.append([chart])
            }
        }
        
        return groups
    }
    
    /// 创建同类型内容的组
    private func createGroupsOfSameType(_ items: [ContentItem], _ type: ContentItemType) -> [[ContentItem]] {
        var groups: [[ContentItem]] = []
        var currentGroup: [ContentItem] = []
        var currentComplexity: Int = 0
        let maxComplexity = 120 // 增大复杂度阈值，使更多内容可以在一张幻灯片上
        
        // 按重要性排序
        let sortedItems = items.sorted { $0.importance > $1.importance }
        
        for item in sortedItems {
            let itemComplexity = calculateItemComplexity(item)
            
            // 如果项目太复杂，单独成组
            if itemComplexity > maxComplexity * 0.8 {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                    currentGroup = []
                    currentComplexity = 0
                }
                groups.append([item])
                continue
            }
            
            // 如果添加此项会使组太复杂，创建新组
            if currentComplexity + itemComplexity > maxComplexity {
                groups.append(currentGroup)
                currentGroup = [item]
                currentComplexity = itemComplexity
            } else {
                // 否则添加到当前组
                currentGroup.append(item)
                currentComplexity += itemComplexity
            }
        }
        
        // 添加最后一组
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    /// 为标题找到最匹配的内容组
    private func findBestGroupForTitle(_ title: ContentItem, _ groups: [[ContentItem]]) -> Int? {
        guard let titleText = title.content as? String else { return nil }
        
        var bestScore = -1
        var bestIndex: Int? = nil
        
        for (index, group) in groups.enumerated() {
            // 跳过只有标题的组
            if group.count == 1 && group[0].isTitle {
                continue
            }
            
            var score = 0
            
            // 基于内容匹配计算得分
            for item in group {
                switch item.type {
                case .text:
                    if let text = item.content as? String {
                        // 检查文本内容是否与标题相关
                        if text.lowercased().contains(titleText.lowercased()) {
                            score += 5
                        }
                        
                        // 检查相同关键词
                        let titleWords = titleText.lowercased().split(separator: " ")
                        let contentWords = text.lowercased().split(separator: " ")
                        
                        for titleWord in titleWords {
                            if contentWords.contains(titleWord) {
                                score += 1
                            }
                        }
                    }
                default:
                    break
                }
            }
            
            // 组中的项目越少，分数越高
            score += 10 - min(10, group.count * 2)
            
            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }
        
        // 只有达到最低分数才返回
        return bestScore >= 2 ? bestIndex : nil
    }
    
    /// 为内容组创建幻灯片计划
    private func createSlideForContentGroup(_ group: [ContentItem], in template: PresentationTemplate, sectionTitle: String) -> SlidePlan {
        // 确定最适合此内容组的布局类型
        let layoutType = determineOptimalLayout(for: group, in: template)
        
        // 转换内容项为幻灯片内容项
        var slideItems: [SlideContentItem] = []
        
        // 添加标题（如果组中没有明确的标题）
        var hasTitle = false
        for item in group {
            if item.type == .text && item.isTitle {
                hasTitle = true
                break
            }
        }
        
        if !hasTitle && group.count > 0 {
            // 使用第一个项目的标题或章节标题
            let title = group[0].title.isEmpty ? sectionTitle : group[0].title
            slideItems.append(.text(TextItem(
                content: title,
                role: .subtitle,
                placement: .top
            )))
        }
        
        // 转换内容
        for item in group {
            let contentItem = convertToSlideContentItem(item)
            slideItems.append(contentItem)
        }
        
        // 确定重要性
        let importance = determineImportance(for: group)
        
        return SlidePlan(
            layoutType: layoutType,
            contentItems: slideItems,
            importance: importance
        )
    }
    
    /// 确定最佳布局类型
    private func determineOptimalLayout(for items: [ContentItem], in template: PresentationTemplate) -> String {
        // 分析内容特征以确定最佳布局类型
        
        // 统计内容类型
        var contentTypes: [ContentItemType: Int] = [:]
        var totalImportance: Int = 0
        var totalItems: Int = 0
        
        // 计数每种内容类型，并计算平均重要性
        for item in items {
            contentTypes[item.type, default: 0] += 1
            totalImportance += item.importance
            totalItems += 1
        }
        
        let averageImportance = totalItems > 0 ? totalImportance / totalItems : 5
        
        // 检查是否包含标题
        let containsTitle = items.contains { $0.isTitle || (($0.type == .text) && $0.importance >= 8) }
        
        // 检查主要内容类型 - 占比超过40%的类型
        var primaryType: ContentItemType?
        for (type, count) in contentTypes {
            if Double(count) / Double(totalItems) >= 0.4 {
                primaryType = type
                break
            }
        }
        
        // 1. 特殊图片布局
        if contentTypes[.image, default: 0] >= 3 {
            return "gallery"
        }
        
        // 2. 特殊图表布局
        if contentTypes[.chart, default: 0] > 0 {
            if contentTypes[.chart, default: 0] > 1 {
                return "multiChart"
            }
            if contentTypes[.text, default: 0] > 0 || contentTypes[.list, default: 0] > 0 {
                return "chartWithExplanation"
            }
            return "chart"
        }
        
        // 3. 代码块布局
        if contentTypes[.code, default: 0] > 0 {
            return "code"
        }
        
        // 4. 表格布局
        if contentTypes[.table, default: 0] > 0 {
            return "table"
        }
        
        // 5. 图片+文本组合布局
        if contentTypes[.image, default: 0] > 0 {
            // 检查图片与文本的组合方式
            if contentTypes[.image, default: 0] == 1 && 
               (contentTypes[.text, default: 0] > 0 || contentTypes[.list, default: 0] > 0) {
                // 检查文本和图片的相对重要性，决定布局方式
                let imageItems = items.filter { $0.type == .image }
                let textItems = items.filter { $0.type == .text || $0.type == .list }
                
                let imageImportance = imageItems.reduce(0) { $0 + $1.importance }
                let textImportance = textItems.reduce(0) { $0 + $1.importance }
                
                if imageImportance > textImportance {
                    return "imageWithCaption" // 图片为主
                } else if containsTitle && textItems.count == 1 {
                    return "titleImageContent" // 标题+图片+文本
                } else {
                    return "contentWithImage" // 文本为主，图片辅助
                }
            } else {
                return "image"
            }
        }
        
        // 6. 列表布局
        if contentTypes[.list, default: 0] > 0 {
            if contentTypes[.list, default: 0] >= 2 {
                return "compareLists" // 比较多个列表
            }
            
            let listItems = items.filter { $0.type == .list }
            let firstList = listItems.first
            
            if let list = firstList, let items = list.content as? [String], items.count > 6 {
                return "longList" // 长列表
            }
            
            return "bulletList"
        }
        
        // 7. 纯文本内容布局
        if primaryType == .text {
            let textItems = items.filter { $0.type == .text }
            
            // 计算文本长度
            var totalTextLength = 0
            for item in textItems {
                if let text = item.content as? String {
                    totalTextLength += text.count
                }
            }
            
            // 高重要性内容使用强调布局
            if averageImportance >= 8 {
                return "emphasis"
            }
            
            // 长文本使用段落布局
            if totalTextLength > 500 && textItems.count <= 2 {
                return "paragraph"
            }
            
            // 多个短文本使用多列布局
            if textItems.count >= 3 {
                return "twoColumnText"
            }
            
            // 包含问题或引言的特殊布局
            for item in textItems {
                if let text = item.content as? String {
                    if text.contains("?") || text.contains("？") || 
                       text.contains("\"") || text.contains(""") {
                        return "quote"
                    }
                }
            }
        }
        
        // 8. 标题+内容组合
        if containsTitle && contentTypes[.text, default: 0] > 1 {
            return "titleAndContent"
        }
        
        // 9. 默认内容布局
        return "content"
    }
    
    /// 确定内容组的重要性
    private func determineImportance(for items: [ContentItem]) -> SlideImportance {
        // 计算平均重要性
        let totalImportance = items.reduce(0) { $0 + $1.importance }
        let averageImportance = totalImportance / items.count
        
        if averageImportance > 7 {
            return .high
        } else if averageImportance > 4 {
            return .medium
        } else {
            return .low
        }
    }
    
    /// 将内容项转换为幻灯片内容项
    private func convertToSlideContentItem(_ item: ContentItem) -> SlideContentItem {
        switch item.type {
        case .text:
            return .text(TextItem(
                content: item.content as? String ?? "",
                role: item.isTitle ? .title : .body,
                placement: .automatic
            ))
            
        case .list:
            return .list(ListItem(
                items: item.content as? [String] ?? [],
                style: .bullet,
                placement: .automatic
            ))
            
        case .table:
            return .table(TableItem(
                data: item.content as? [[String]] ?? [[]],
                hasHeader: true,
                placement: .automatic
            ))
            
        case .image:
            return .image(ImageItem(
                data: item.content as? Data ?? Data(),
                caption: item.title,
                placement: .automatic
            ))
            
        case .chart:
            if let chartData = item.content as? [ChartPoint] {
                return .chart(ChartItem(
                    type: "bar",
                    data: chartData,
                    placement: .automatic
                ))
            } else {
                return .chart(ChartItem(
                    type: "bar",
                    data: [],
                    placement: .automatic
                ))
            }
            
        case .code:
            // 代码块作为特殊格式文本处理
            return .text(TextItem(
                content: item.content as? String ?? "",
                role: .code,
                placement: .automatic
            ))
        }
    }
    
    /// 应用分布计划生成演示文稿
    private func applyDistribution(_ plan: DistributionPlan, _ styleMappings: StyleMappings, _ template: PresentationTemplate) async throws -> Presentation {
        var slides: [Slide] = []
        
        for slidePlan in plan.slidePlans {
            // 查找对应的布局模板
            let layoutType = slidePlan.layoutType
            let layout = findLayoutForType(layoutType, in: template)
            
            // 创建幻灯片
            let slide = try await createSlide(from: slidePlan, with: layout, using: styleMappings, in: template)
            slides.append(slide)
        }
        
        return Presentation(
            title: template.metadata.title,
            slides: slides,
            theme: template.theme
        )
    }
    
    /// 为布局类型查找布局
    private func findLayoutForType(_ type: String, in template: PresentationTemplate) -> SlideLayout {
        if let layout = template.masterLayouts.first(where: { $0.type == type }) {
            return layout
        }
        
        // 找不到精确匹配时的备选规则
        switch type {
        case "cover":
            return template.masterLayouts.first { $0.type == "title" } ?? template.masterLayouts[0]
        case "section":
            return template.masterLayouts.first { $0.type == "title" } ?? template.masterLayouts[0]
        case "bulletList":
            return template.masterLayouts.first { $0.type == "content" } ?? template.masterLayouts[0]
        case "image", "imageWithContent":
            return template.masterLayouts.first { $0.type == "content" } ?? template.masterLayouts[0]
        case "chart", "table":
            return template.masterLayouts.first { $0.type == "content" } ?? template.masterLayouts[0]
        default:
            return template.masterLayouts[0]
        }
    }
    
    /// 从计划创建幻灯片
    private func createSlide(from plan: SlidePlan, with layout: SlideLayout, using styles: StyleMappings, in template: PresentationTemplate) async throws -> Slide {
        var elements: [SlideElement] = []
        
        // 创建元素
        for contentItem in plan.contentItems {
            let element = try await createElementFromContentItem(contentItem, layout, styles)
            elements.append(element)
        }
        
        // 应用布局优化
        elements = optimizeElementLayout(elements, in: layout)
        
        return Slide(
            id: UUID().uuidString,
            elements: elements,
            layout: layout,
            background: template.theme.backgroundStyle
        )
    }
    
    /// 从内容项创建幻灯片元素
    private func createElementFromContentItem(_ item: SlideContentItem, _ layout: SlideLayout, _ styles: StyleMappings) async throws -> SlideElement {
        switch item {
        case .text(let textItem):
            return try createTextElement(textItem, layout, styles)
        case .list(let listItem):
            return try createListElement(listItem, layout, styles)
        case .table(let tableItem):
            return try createTableElement(tableItem, layout, styles)
        case .image(let imageItem):
            return try createImageElement(imageItem, layout, styles)
        case .chart(let chartItem):
            return try createChartElement(chartItem, layout, styles)
        }
    }
    
    /// 优化元素布局
    private func optimizeElementLayout(_ elements: [SlideElement], in layout: SlideLayout) -> [SlideElement] {
        // 如果元素数量很少，使用默认布局
        if elements.count <= 2 {
            return elements
        }
        
        // 创建可变元素副本
        var optimizedElements = elements
        
        // 检测重叠并调整
        for i in 0..<optimizedElements.count {
            for j in (i+1)..<optimizedElements.count {
                if let frame1 = getElementFrame(optimizedElements[i]),
                   let frame2 = getElementFrame(optimizedElements[j]) {
                    if frame1.intersects(frame2) {
                        // 调整位置以避免重叠
                        optimizedElements[j] = adjustElementPosition(optimizedElements[j], to: CGPoint(x: frame2.origin.x, y: frame2.origin.y + frame1.height + 10))
                    }
                }
            }
        }
        
        return optimizedElements
    }
    
    /// 获取元素框架
    private func getElementFrame(_ element: SlideElement) -> CGRect? {
        switch element {
        case .text(let textElement):
            return textElement.frame
        case .image(let imageElement):
            return imageElement.frame
        case .table(let tableElement):
            return tableElement.frame
        case .chart(let chartElement):
            return chartElement.frame
        case .shape(let shapeElement):
            return shapeElement.frame
        }
    }
    
    /// 调整元素位置
    private func adjustElementPosition(_ element: SlideElement, to newPosition: CGPoint) -> SlideElement {
        switch element {
        case .text(var textElement):
            textElement.frame.origin = newPosition
            return .text(textElement)
        case .image(var imageElement):
            imageElement.frame.origin = newPosition
            return .image(imageElement)
        case .table(var tableElement):
            tableElement.frame.origin = newPosition
            return .table(tableElement)
        case .chart(var chartElement):
            chartElement.frame.origin = newPosition
            return .chart(chartElement)
        case .shape(var shapeElement):
            shapeElement.frame.origin = newPosition
            return .shape(shapeElement)
        }
    }
    
    // MARK: - 元素创建方法
    
    private func createTextElement(_ item: TextItem, _ layout: SlideLayout, _ styles: StyleMappings) throws -> SlideElement {
        // 根据角色获取样式
        let style = styles.textStyles[item.role] ?? styles.textStyles[.body]!
        
        // 查找合适的占位符
        let placeholderType: PlaceholderType = {
            switch item.role {
            case .title: return .title
            case .subtitle: return .subtitle
            case .heading: return .heading
            case .body: return .body
            case .caption: return .caption
            case .code: return .body
            }
        }()
        
        // 找到占位符或使用默认位置
        let placeholder = layout.placeholders.first { $0.type == placeholderType }
        let frame = placeholder?.frame ?? defaultFrameForRole(item.role)
        
        return .text(TextElement(
            id: UUID().uuidString,
            text: AttributedString(item.content),
            frame: frame,
            style: style
        ))
    }
    
    private func createListElement(_ item: ListItem, _ layout: SlideLayout, _ styles: StyleMappings) throws -> SlideElement {
        // 找到合适的占位符
        let placeholder = layout.placeholders.first { $0.type == .body }
        let frame = placeholder?.frame ?? CGRect(x: 50, y: 150, width: 600, height: 400)
        
        // 构建列表文本
        var listText = AttributedString()
        
        for (index, listItem) in item.items.enumerated() {
            let bulletSymbol: String
            switch item.style {
            case .bullet:
                bulletSymbol = "•  "
            case .numbered:
                bulletSymbol = "\(index + 1). "
            case .checkbox:
                bulletSymbol = "☐  "
            }
            
            let itemText = AttributedString(bulletSymbol + listItem)
            
            if index > 0 {
                listText.append(AttributedString("\n"))
            }
            
            listText.append(itemText)
        }
        
        return .text(TextElement(
            id: UUID().uuidString,
            text: listText,
            frame: frame,
            style: styles.textStyles[.body]!
        ))
    }
    
    private func createTableElement(_ item: TableItem, _ layout: SlideLayout, _ styles: StyleMappings) throws -> SlideElement {
        // 查找占位符
        let placeholder = layout.placeholders.first { $0.type == .table } ?? 
                          layout.placeholders.first { $0.type == .body }
        
        let frame = placeholder?.frame ?? CGRect(x: 50, y: 150, width: 600, height: 400)
        
        // 构建表格单元格
        var cells: [[TableCell]] = []
        
        for rowIndex in 0..<item.data.count {
            var row: [TableCell] = []
            
            for colIndex in 0..<item.data[rowIndex].count {
                let text = item.data[rowIndex][colIndex]
                
                // 标题行使用不同样式
                let isHeader = item.hasHeader && rowIndex == 0
                
                row.append(TableCell(
                    content: AttributedString(text),
                    backgroundColor: isHeader ? styles.colorStyles[.accent] : (rowIndex % 2 == 1 ? styles.colorStyles[.alternateRow] : nil),
                    borders: createDefaultCellBorders(styles)
                ))
            }
            
            cells.append(row)
        }
        
        return .table(TableElement(
            id: UUID().uuidString,
            rows: item.data.count,
            columns: item.data.first?.count ?? 0,
            cells: cells,
            frame: frame,
            style: TableStyle(
                headerStyle: styles.textStyles[.heading]!,
                cellStyle: styles.textStyles[.body]!,
                alternatingRowColors: true,
                gridStyle: createDefaultBorderStyle(styles)
            )
        ))
    }
    
    private func createImageElement(_ item: ImageItem, _ layout: SlideLayout, _ styles: StyleMappings) throws -> SlideElement {
        // 查找占位符
        let placeholder = layout.placeholders.first { $0.type == .image } ?? 
                          layout.placeholders.first { $0.type == .body }
        
        let frame = placeholder?.frame ?? CGRect(x: 150, y: 150, width: 400, height: 300)
        
        // 创建图片元素
        let imageElement = ImageElement(
            id: UUID().uuidString,
            imageData: item.data,
            frame: frame,
            contentMode: .fit
        )
        
        // 如果有标题，创建标题元素
        if !item.caption.isEmpty {
            let captionFrame = CGRect(
                x: frame.minX,
                y: frame.maxY + 10,
                width: frame.width,
                height: 30
            )
            
            let captionElement = TextElement(
                id: UUID().uuidString + "_caption",
                text: AttributedString(item.caption),
                frame: captionFrame,
                style: styles.textStyles[.caption]!
            )
            
            // 在实际应用中，可能需要返回两个元素
            // 简化处理：这里仅返回图片元素
            return .image(imageElement)
        }
        
        return .image(imageElement)
    }
    
    private func createChartElement(_ item: ChartItem, _ layout: SlideLayout, _ styles: StyleMappings) throws -> SlideElement {
        // 查找占位符
        let placeholder = layout.placeholders.first { $0.type == .chart } ?? 
                          layout.placeholders.first { $0.type == .body }
        
        let frame = placeholder?.frame ?? CGRect(x: 100, y: 150, width: 500, height: 300)
        
        // 确定图表类型
        let chartType: ChartType
        switch item.type.lowercased() {
        case "bar":
            chartType = .bar
        case "line":
            chartType = .line
        case "pie":
            chartType = .pie
        case "scatter":
            chartType = .scatter
        default:
            chartType = .bar
        }
        
        // 转换数据点
        let dataPoints = item.data.map { point in
            ChartDataPoint(
                category: point.label,
                value: point.value,
                series: point.series
            )
        }
        
        return .chart(ChartElement(
            id: UUID().uuidString,
            type: chartType,
            data: dataPoints,
            frame: frame,
            style: ChartStyle(
                colors: [
                    styles.colorStyles[.primary]!,
                    styles.colorStyles[.secondary]!,
                    styles.colorStyles[.accent]!
                ],
                legendPosition: .bottom,
                showValues: true
            )
        ))
    }
    
    // MARK: - 辅助方法
    
    /// 为角色创建默认框架
    private func defaultFrameForRole(_ role: TextRole) -> CGRect {
        switch role {
        case .title:
            return CGRect(x: 50, y: 50, width: 700, height: 100)
        case .subtitle:
            return CGRect(x: 50, y: 120, width: 700, height: 60)
        case .heading:
            return CGRect(x: 50, y: 100, width: 700, height: 60)
        case .body:
            return CGRect(x: 50, y: 180, width: 600, height: 350)
        case .caption:
            return CGRect(x: 50, y: 530, width: 600, height: 40)
        case .code:
            return CGRect(x: 50, y: 180, width: 600, height: 350)
        }
    }
    
    /// 创建默认单元格边框
    private func createDefaultCellBorders(_ styles: StyleMappings) -> CellBorders {
        let borderStyle = createDefaultBorderStyle(styles)
        
        return CellBorders(
            top: borderStyle,
            left: borderStyle,
            bottom: borderStyle,
            right: borderStyle
        )
    }
    
    /// 创建默认边框样式
    private func createDefaultBorderStyle(_ styles: StyleMappings) -> BorderStyle {
        return BorderStyle(
            width: 1,
            color: styles.colorStyles[.border] ?? .gray,
            style: .solid
        )
    }
    
    /// 计算内容项的复杂度
    private func calculateItemComplexity(_ item: ContentItem) -> Int {
        switch item.type {
        case .text:
            if let text = item.content as? String {
                return max(15, text.count / 40) // 约40个字符的复杂度为1，最小复杂度为15
            }
            return 15
            
        case .list:
            if let listItems = item.content as? [String] {
                // 考虑列表项数量和每项长度
                let itemCount = listItems.count
                let totalLength = listItems.reduce(0) { $0 + $1.count }
                return max(20, itemCount * 12 + totalLength / 100) // 每个列表项基础复杂度为12，再根据总长度调整
            }
            return 30
            
        case .table:
            if let tableData = item.content as? [[String]] {
                let rows = tableData.count
                let cols = tableData.first?.count ?? 0
                // 表格复杂度基于行列数量和单元格内容长度
                let cellComplexity = tableData.flatMap { $0 }.reduce(0) { $0 + $1.count / 20 }
                return max(40, rows * cols * 8 + cellComplexity) // 每个单元格基础复杂度为8，再根据内容调整
            }
            return 50
            
        case .image:
            // 图片复杂度固定，但有标题的更复杂
            return item.title.isEmpty ? 40 : 50
            
        case .chart:
            // 图表很复杂，占用空间大
            return 70
            
        case .code:
            if let code = item.content as? String {
                // 代码比普通文本复杂度更高
                return max(30, code.count / 25)
            }
            return 40
        }
    }
}

// MARK: - 支持类型

/// 内容分布计划
struct DistributionPlan {
    var slidePlans: [SlidePlan]
}

/// 幻灯片计划
struct SlidePlan {
    var layoutType: String
    var contentItems: [SlideContentItem]
    var importance: SlideImportance
}

/// 幻灯片重要性
enum SlideImportance {
    case high
    case medium
    case low
}

/// 幻灯片内容项
enum SlideContentItem {
    case text(TextItem)
    case list(ListItem)
    case table(TableItem)
    case image(ImageItem)
    case chart(ChartItem)
}

/// 文本项
struct TextItem {
    var content: String
    var role: TextRole
    var placement: ElementPlacement
}

/// 列表项
struct ListItem {
    var items: [String]
    var style: ListStyle
    var placement: ElementPlacement
    
    enum ListStyle {
        case bullet
        case numbered
        case checkbox
    }
}

/// 表格项
struct TableItem {
    var data: [[String]]
    var hasHeader: Bool
    var placement: ElementPlacement
}

/// 图片项
struct ImageItem {
    var data: Data
    var caption: String
    var placement: ElementPlacement
}

/// 图表项
struct ChartItem {
    var type: String
    var data: [ChartPoint]
    var placement: ElementPlacement
}

/// 图表数据点
struct ChartPoint {
    var label: String
    var value: Double
    var series: String?
}

/// 元素放置
enum ElementPlacement {
    case automatic
    case top
    case center
    case bottom
    case left
    case right
    case custom(CGPoint)
}

/// 文本角色
enum TextRole {
    case title
    case subtitle
    case heading
    case body
    case caption
    case code
}

/// 颜色角色
enum ColorRole {
    case primary
    case secondary
    case accent
    case background
    case text
    case border
    case alternateRow
}

/// 样式映射
struct StyleMappings {
    var textStyles: [TextRole: TextStyle]
    var colorStyles: [ColorRole: Color]
}

/// 占位符类型
enum PlaceholderType: String {
    case title
    case subtitle
    case heading
    case body
    case table
    case chart
    case image
    case caption
    case date
    case footer
    case slideNumber
} 
 