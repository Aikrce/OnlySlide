import Foundation
import SwiftUI

/// 模板适配器
/// 负责提取和适应演示模板
class TemplateAdapter {
    
    /// 从PPT文档中提取模板
    func extractTemplate(from pptDocument: PPTDocument) -> PresentationTemplate {
        // 提取布局
        let layouts = extractLayouts(from: pptDocument)
        
        // 提取主题
        let theme = extractTheme(from: pptDocument)
        
        // 提取元数据
        let metadata = extractMetadata(from: pptDocument)
        
        return PresentationTemplate(
            id: UUID().uuidString,
            name: metadata.title,
            description: "从PPT提取的模板",
            masterLayouts: layouts,
            theme: theme,
            metadata: metadata
        )
    }
    
    /// 从内置模板集合中获取模板
    func getDefaultTemplate(style: TemplateStyle = .modern) -> PresentationTemplate {
        switch style {
        case .modern:
            return createModernTemplate()
        case .classic:
            return createClassicTemplate()
        case .minimal:
            return createMinimalTemplate()
        case .creative:
            return createCreativeTemplate()
        case .professional:
            return createProfessionalTemplate()
        }
    }
    
    /// 适应模板以匹配内容特征
    func adaptTemplateToContent(_ template: PresentationTemplate, content: DocumentContent) -> PresentationTemplate {
        var adaptedTemplate = template
        
        // 基于内容分析色调和情感
        let contentTone = analyzeContentTone(content)
        let contentComplexity = analyzeContentComplexity(content)
        
        // 1. 适应主题颜色
        adaptedTemplate.theme = adaptThemeColors(template.theme, for: content, tone: contentTone)
        
        // 2. 适应字体以匹配内容风格
        adaptedTemplate.theme.fonts = adaptFonts(template.theme.fonts, for: content, complexity: contentComplexity)
        
        // 3. 适应布局
        adaptedTemplate.masterLayouts = adaptLayouts(template.masterLayouts, for: content, complexity: contentComplexity)
        
        // 4. 更新模板元数据
        adaptedTemplate.metadata.modified = Date()
        adaptedTemplate.metadata.description += " (Adapted for content)"
        
        return adaptedTemplate
    }
    
    // MARK: - 提取方法
    
    /// 从PPT文档中提取布局
    private func extractLayouts(from pptDocument: PPTDocument) -> [SlideLayout] {
        var layouts: [SlideLayout] = []
        
        // 提取主布局
        if let masterLayout = pptDocument.theme.masterLayouts.first {
            layouts.append(convertPPTLayoutToSlideLayout(masterLayout, type: "title"))
        }
        
        // 提取其他布局
        for layout in pptDocument.theme.masterLayouts {
            let slideLayout = convertPPTLayoutToSlideLayout(layout, type: determineLayoutType(layout))
            layouts.append(slideLayout)
        }
        
        // 确保包含基本布局类型
        let requiredTypes = ["cover", "title", "content", "section", "table", "chart", "image"]
        let existingTypes = layouts.map { $0.type }
        
        for type in requiredTypes {
            if !existingTypes.contains(type) {
                // 添加缺失的布局类型
                layouts.append(createDefaultLayout(for: type))
            }
        }
        
        return layouts
    }
    
    /// 根据PPT布局特征确定其类型
    private func determineLayoutType(_ layout: SlideLayout) -> String {
        // 分析占位符模式来推断布局类型
        let placeholderTypes = layout.placeholders.map { $0.type.rawValue }
        
        if placeholderTypes.contains("title") && placeholderTypes.contains("subtitle") && placeholderTypes.count == 2 {
            return "cover"
        }
        
        if placeholderTypes.contains("title") && placeholderTypes.contains("body") {
            if placeholderTypes.contains("table") {
                return "table"
            }
            if placeholderTypes.contains("chart") {
                return "chart"
            }
            if placeholderTypes.contains("image") {
                return "image"
            }
            return "content"
        }
        
        if placeholderTypes.contains("title") && placeholderTypes.count == 1 {
            return "section"
        }
        
        // 默认为内容布局
        return "content"
    }
    
    /// 将PPT布局转换为幻灯片布局
    private func convertPPTLayoutToSlideLayout(_ layout: SlideLayout, type: String) -> SlideLayout {
        // 转换占位符
        var slidePlaceholders: [Placeholder] = []
        
        for pptPlaceholder in layout.placeholders {
            let placeholderType = convertPlaceholderType(pptPlaceholder.type)
            slidePlaceholders.append(Placeholder(
                type: placeholderType,
                frame: pptPlaceholder.frame
            ))
        }
        
        return SlideLayout(
            type: type,
            placeholders: slidePlaceholders
        )
    }
    
    /// 转换占位符类型
    private func convertPlaceholderType(_ pptType: Placeholder.PlaceholderType) -> PlaceholderType {
        switch pptType {
        case .title:
            return .title
        case .subtitle:
            return .subtitle
        case .body:
            return .body
        case .table:
            return .table
        case .chart:
            return .chart
        case .image:
            return .image
        case .footer:
            return .footer
        case .date:
            return .date
        case .slideNumber:
            return .slideNumber
        }
    }
    
    /// 从PPT文档提取主题
    private func extractTheme(from pptDocument: PPTDocument) -> PresentationTheme {
        let pptTheme = pptDocument.theme
        
        // 转换颜色方案
        let colors = pptTheme.colorScheme
        
        // 转换字体
        let fonts = FontSet(
            title: pptTheme.fonts.title,
            body: pptTheme.fonts.body,
            accent: pptTheme.fonts.accent
        )
        
        // 创建背景样式
        let backgroundStyle = BackgroundStyle(
            primaryColor: colors.first ?? .white,
            secondaryColor: colors.count > 1 ? colors[1] : nil,
            pattern: .solid
        )
        
        return PresentationTheme(
            name: "Extracted Theme",
            colors: colors,
            fonts: fonts,
            backgroundStyle: backgroundStyle
        )
    }
    
    /// 从PPT文档提取元数据
    private func extractMetadata(from pptDocument: PPTDocument) -> TemplateMetadata {
        let meta = pptDocument.metadata
        
        return TemplateMetadata(
            title: meta.title,
            author: meta.author,
            description: "从PPT导入的模板",
            created: meta.created,
            modified: meta.modified
        )
    }
    
    // MARK: - 内容分析方法
    
    /// 分析内容的语调和情感
    private func analyzeContentTone(_ content: DocumentContent) -> ContentTone {
        // 分析标题和摘要中的关键词
        let titleAndSummary = content.title + " " + (content.summary ?? "")
        
        // 检查关键词和表达方式
        let formalKeywords = ["分析", "评估", "研究", "报告", "战略", "方法论", 
                              "analysis", "evaluation", "research", "report", "strategy"]
        
        let technicalKeywords = ["技术", "系统", "算法", "数据", "代码", "平台", "架构", 
                                "technical", "system", "algorithm", "data", "code", "platform"]
        
        let creativeKeywords = ["创意", "创新", "灵感", "设计", "艺术", "想象", 
                                "creative", "innovative", "inspiration", "design", "artistic"]
        
        let casualKeywords = ["聊天", "分享", "故事", "点子", "简单", "快速", 
                             "chat", "share", "story", "idea", "simple", "quick"]
        
        // 统计各类型关键词出现频率
        let formalCount = formalKeywords.filter { titleAndSummary.contains($0) }.count
        let technicalCount = technicalKeywords.filter { titleAndSummary.contains($0) }.count
        let creativeCount = creativeKeywords.filter { titleAndSummary.contains($0) }.count
        let casualCount = casualKeywords.filter { titleAndSummary.contains($0) }.count
        
        // 检查内容项类型
        let contentItems = content.sections.flatMap { $0.items }
        let hasCharts = contentItems.contains { $0.type == .chart }
        let hasCode = contentItems.contains { $0.type == .code }
        let hasManyImages = contentItems.filter { $0.type == .image }.count > contentItems.count / 3
        
        // 综合判断内容语调
        if technicalCount > 2 || hasCode || hasCharts {
            return .technical
        } else if formalCount > 2 || content.title.contains("报告") || content.title.contains("Report") {
            return .formal
        } else if creativeCount > 2 || hasManyImages {
            return .creative
        } else {
            return .casual
        }
    }
    
    /// 分析内容的复杂度
    private func analyzeContentComplexity(_ content: DocumentContent) -> ContentComplexity {
        // 分析内容项的数量和类型
        let contentItems = content.sections.flatMap { $0.items }
        
        // 计算各类型内容的数量
        let tableCount = contentItems.filter { $0.type == .table }.count
        let chartCount = contentItems.filter { $0.type == .chart }.count
        let codeCount = contentItems.filter { $0.type == .code }.count
        let imageCount = contentItems.filter { $0.type == .image }.count
        
        // 评估文本复杂度
        let textComplexity = assessTextComplexity(content)
        
        // 综合计算复杂度分数 (0-10)
        let complexityScore = 
            min(3, tableCount) * 1.5 + 
            min(3, chartCount) * 1.5 + 
            min(2, codeCount) * 1.0 +
            min(5, content.sections.count / 2) * 0.5 +
            textComplexity * 0.8
        
        // 根据图像数量进行调整（更多图像通常意味着更简单的呈现）
        let adjustedScore = complexityScore - min(3, imageCount / 2) * 0.5
        
        // 确定复杂度级别
        if adjustedScore >= 7 {
            return .high
        } else if adjustedScore >= 4 {
            return .medium
        } else {
            return .low
        }
    }
    
    /// 评估文本内容的复杂度
    private func assessTextComplexity(_ content: DocumentContent) -> Double {
        // 收集所有文本内容
        var allText = content.title + " " + (content.summary ?? "")
        
        for section in content.sections {
            allText += " " + section.title
            
            for item in section.items {
                if item.type == .text, let text = item.content as? String {
                    allText += " " + text
                } else if item.type == .list, let listItems = item.content as? [String] {
                    allText += " " + listItems.joined(separator: " ")
                }
            }
        }
        
        // 计算句子长度
        let sentences = allText.components(separatedBy: [".", "!", "?", "。", "！", "？"])
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        if sentences.isEmpty {
            return 3.0 // 默认中等复杂度
        }
        
        // 计算平均句子长度
        let avgSentenceLength = Double(allText.count) / Double(sentences.count)
        
        // 计算专业术语和长词的比例
        let words = allText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        let longWordCount = words.filter { $0.count > 8 }.count
        let longWordRatio = Double(longWordCount) / Double(max(1, words.count))
        
        // 综合评分 (0-10)
        let lengthScore = min(5.0, avgSentenceLength / 10.0)
        let vocabScore = min(5.0, longWordRatio * 20.0)
        
        return lengthScore + vocabScore
    }
    
    // MARK: - 适应方法
    
    /// 适应主题颜色以匹配内容语调
    private func adaptThemeColors(_ theme: PresentationTheme, for content: DocumentContent, tone: ContentTone) -> PresentationTheme {
        var adaptedTheme = theme
        
        // 根据内容语调调整颜色方案
        switch tone {
        case .formal:
            // 正式场合使用更保守、专业的颜色
            if !theme.colors.isEmpty {
                // 调整主色调为更深沉的蓝色或灰色
                var colors = theme.colors
                
                // 替换主色调为更正式的颜色
                if colors.count > 0 {
                    colors[0] = Color(red: 0.1, green: 0.3, blue: 0.5) // 深蓝色
                }
                if colors.count > 1 {
                    colors[1] = Color(red: 0.2, green: 0.2, blue: 0.3) // 深灰蓝色
                }
                
                adaptedTheme.colors = colors
                
                // 更新背景样式
                adaptedTheme.backgroundStyle = BackgroundStyle(
                    primaryColor: .white,
                    secondaryColor: colors[0].opacity(0.05),
                    pattern: .solid
                )
            }
            
        case .technical:
            // 技术内容使用更鲜明的对比和功能性颜色
            if !theme.colors.isEmpty {
                var colors = theme.colors
                
                // 替换主色调为技术感颜色
                if colors.count > 0 {
                    colors[0] = Color(red: 0.0, green: 0.5, blue: 0.7) // 科技蓝
                }
                if colors.count > 1 {
                    colors[1] = Color(red: 0.1, green: 0.1, blue: 0.2) // 深蓝黑
                }
                if colors.count > 2 {
                    colors[2] = Color(red: 0.7, green: 0.2, blue: 0.0) // 强调红
                }
                
                adaptedTheme.colors = colors
                
                // 更新背景样式为网格图案
                adaptedTheme.backgroundStyle = BackgroundStyle(
                    primaryColor: Color(red: 0.98, green: 0.98, blue: 1.0),
                    secondaryColor: colors[0].opacity(0.1),
                    pattern: .grid
                )
            }
            
        case .creative:
            // 创意内容使用更丰富多彩的颜色
            if !theme.colors.isEmpty {
                var colors = theme.colors
                
                // 替换为更有创意的颜色组合
                if colors.count > 0 {
                    colors[0] = Color(red: 0.8, green: 0.3, blue: 0.6) // 桃红色
                }
                if colors.count > 1 {
                    colors[1] = Color(red: 0.3, green: 0.8, blue: 0.8) // 青绿色
                }
                if colors.count > 2 {
                    colors[2] = Color(red: 0.9, green: 0.8, blue: 0.2) // 亮黄色
                }
                
                adaptedTheme.colors = colors
                
                // 更新背景样式为渐变
                adaptedTheme.backgroundStyle = BackgroundStyle(
                    primaryColor: .white,
                    secondaryColor: colors[0].opacity(0.15),
                    pattern: .gradient
                )
            }
            
        case .casual:
            // 休闲内容使用更友好、柔和的颜色
            if !theme.colors.isEmpty {
                var colors = theme.colors
                
                // 替换为更友好的颜色
                if colors.count > 0 {
                    colors[0] = Color(red: 0.4, green: 0.6, blue: 0.8) // 柔和蓝
                }
                if colors.count > 1 {
                    colors[1] = Color(red: 0.5, green: 0.7, blue: 0.5) // 柔和绿
                }
                
                adaptedTheme.colors = colors
                
                // 更新背景样式为简单纯色
                adaptedTheme.backgroundStyle = BackgroundStyle(
                    primaryColor: .white,
                    secondaryColor: nil,
                    pattern: .solid
                )
            }
        }
        
        return adaptedTheme
    }
    
    /// 适应字体以匹配内容风格和复杂度
    private func adaptFonts(_ fonts: FontSet, for content: DocumentContent, complexity: ContentComplexity) -> FontSet {
        var adaptedFonts = fonts
        
        // 根据内容复杂度调整字体
        switch complexity {
        case .high:
            // 复杂内容需要更清晰、专业的字体
            adaptedFonts.title = "SF Pro Display"
            adaptedFonts.body = "SF Pro Text"
            adaptedFonts.accent = "SF Pro"
            
        case .medium:
            // 中等复杂度保持平衡
            // 保持原字体不变
            break
            
        case .low:
            // 简单内容可以使用更有个性的字体
            if fonts.title == "SF Pro Display" || fonts.title == "Helvetica Neue" {
                adaptedFonts.title = "Avenir Next"
                adaptedFonts.body = "Avenir"
                adaptedFonts.accent = "Avenir Next"
            }
        }
        
        return adaptedFonts
    }
    
    /// 适应布局以匹配内容
    private func adaptLayouts(_ layouts: [SlideLayout], for content: DocumentContent, complexity: ContentComplexity) -> [SlideLayout] {
        var adaptedLayouts = layouts
        
        // 分析内容需求
        let contentItems = content.sections.flatMap { $0.items }
        let needsTableLayout = contentItems.contains { item in item.type == .table }
        let needsChartLayout = contentItems.contains { item in item.type == .chart }
        let needsCodeLayout = contentItems.contains { item in item.type == .code }
        let needsImageLayout = contentItems.contains { item in item.type == .image }
        let hasLongLists = contentItems.contains { item in
            if item.type == .list, let listItems = item.content as? [String] {
                return listItems.count > 6
            }
            return false
        }
        
        // 确保有需要的特殊布局
        if needsTableLayout && !layouts.contains(where: { $0.type == "table" }) {
            adaptedLayouts.append(createDefaultLayout(for: "table"))
        }
        
        if needsChartLayout && !layouts.contains(where: { $0.type == "chart" }) {
            adaptedLayouts.append(createDefaultLayout(for: "chart"))
        }
        
        if needsCodeLayout && !layouts.contains(where: { $0.type == "code" }) {
            adaptedLayouts.append(createDefaultLayout(for: "code"))
        }
        
        if needsImageLayout {
            // 检查现有的图像布局
            if !layouts.contains(where: { $0.type == "image" }) {
                adaptedLayouts.append(createDefaultLayout(for: "image"))
            }
            
            // 添加图片画廊布局
            if !layouts.contains(where: { $0.type == "gallery" }) {
                adaptedLayouts.append(createGalleryLayout())
            }
            
            // 添加带说明的图片布局
            if !layouts.contains(where: { $0.type == "imageWithCaption" }) {
                adaptedLayouts.append(createImageWithCaptionLayout())
            }
        }
        
        if hasLongLists && !layouts.contains(where: { $0.type == "longList" }) {
            adaptedLayouts.append(createLongListLayout())
        }
        
        // 根据内容复杂度调整布局尺寸
        if complexity == .high {
            // 对于复杂内容，增加内容区域，减少边距
            for i in 0..<adaptedLayouts.count {
                adaptedLayouts[i] = expandContentArea(adaptedLayouts[i])
            }
        }
        
        return adaptedLayouts
    }
    
    /// 扩展布局的内容区域
    private func expandContentArea(_ layout: SlideLayout) -> SlideLayout {
        var updatedLayout = layout
        
        // 调整内容类型的占位符
        for i in 0..<updatedLayout.placeholders.count {
            if updatedLayout.placeholders[i].type == .body ||
               updatedLayout.placeholders[i].type == .table ||
               updatedLayout.placeholders[i].type == .chart {
                
                var frame = updatedLayout.placeholders[i].frame
                // 扩大内容区域，减少边距
                frame.origin.x = max(20, frame.origin.x - 10)
                frame.origin.y = max(10, frame.origin.y - 5)
                frame.size.width += 20
                frame.size.height += 10
                
                updatedLayout.placeholders[i].frame = frame
            }
        }
        
        return updatedLayout
    }
    
    /// 创建图片画廊布局
    private func createGalleryLayout() -> SlideLayout {
        let titlePlaceholder = Placeholder(
            type: .title,
            frame: CGRect(x: 40, y: 40, width: 720, height: 60)
        )
        
        // 为图片画廊创建4个图像占位符
        let image1 = Placeholder(
            type: .image,
            frame: CGRect(x: 40, y: 120, width: 350, height: 200)
        )
        
        let image2 = Placeholder(
            type: .image,
            frame: CGRect(x: 410, y: 120, width: 350, height: 200)
        )
        
        let image3 = Placeholder(
            type: .image,
            frame: CGRect(x: 40, y: 340, width: 350, height: 200)
        )
        
        let image4 = Placeholder(
            type: .image,
            frame: CGRect(x: 410, y: 340, width: 350, height: 200)
        )
        
        return SlideLayout(
            type: "gallery",
            placeholders: [titlePlaceholder, image1, image2, image3, image4]
        )
    }
    
    /// 创建带说明的图片布局
    private func createImageWithCaptionLayout() -> SlideLayout {
        let titlePlaceholder = Placeholder(
            type: .title,
            frame: CGRect(x: 40, y: 40, width: 720, height: 60)
        )
        
        let imagePlaceholder = Placeholder(
            type: .image,
            frame: CGRect(x: 140, y: 120, width: 520, height: 320)
        )
        
        let captionPlaceholder = Placeholder(
            type: .caption,
            frame: CGRect(x: 140, y: 450, width: 520, height: 60)
        )
        
        return SlideLayout(
            type: "imageWithCaption",
            placeholders: [titlePlaceholder, imagePlaceholder, captionPlaceholder]
        )
    }
    
    /// 创建长列表布局
    private func createLongListLayout() -> SlideLayout {
        let titlePlaceholder = Placeholder(
            type: .title,
            frame: CGRect(x: 40, y: 40, width: 720, height: 60)
        )
        
        let column1 = Placeholder(
            type: .body,
            frame: CGRect(x: 40, y: 120, width: 350, height: 420)
        )
        
        let column2 = Placeholder(
            type: .body,
            frame: CGRect(x: 410, y: 120, width: 350, height: 420)
        )
        
        return SlideLayout(
            type: "longList",
            placeholders: [titlePlaceholder, column1, column2]
        )
    }
    
    // MARK: - 创建默认模板
    
    /// 创建现代风格模板
    private func createModernTemplate() -> PresentationTemplate {
        // 现代配色方案
        let colors: [Color] = [
            Color(red: 0.2, green: 0.4, blue: 0.8),
            Color(red: 0.1, green: 0.1, blue: 0.3),
            Color(red: 0.8, green: 0.3, blue: 0.3),
            Color(red: 0.3, green: 0.6, blue: 0.3),
            Color.white
        ]
        
        // 现代字体
        let fonts = FontSet(
            title: "SF Pro Display",
            body: "SF Pro Text",
            accent: "SF Pro"
        )
        
        // 背景样式
        let backgroundStyle = BackgroundStyle(
            primaryColor: Color.white,
            secondaryColor: colors[0].opacity(0.1),
            pattern: .gradient
        )
        
        // 创建主题
        let theme = PresentationTheme(
            name: "Modern",
            colors: colors,
            fonts: fonts,
            backgroundStyle: backgroundStyle
        )
        
        // 创建布局
        let layouts = createDefaultLayouts()
        
        // 创建元数据
        let metadata = TemplateMetadata(
            title: "Modern Template",
            author: "OnlySlide",
            description: "A modern, clean template with vibrant colors",
            created: Date(),
            modified: Date()
        )
        
        return PresentationTemplate(
            id: UUID().uuidString,
            name: "Modern",
            description: "A modern, clean template with vibrant colors",
            masterLayouts: layouts,
            theme: theme,
            metadata: metadata
        )
    }
    
    /// 创建经典风格模板
    private func createClassicTemplate() -> PresentationTemplate {
        // 经典配色方案
        let colors: [Color] = [
            Color(red: 0.0, green: 0.2, blue: 0.4),
            Color(red: 0.2, green: 0.2, blue: 0.2),
            Color(red: 0.6, green: 0.2, blue: 0.2),
            Color(red: 0.7, green: 0.7, blue: 0.7),
            Color.white
        ]
        
        // 经典字体
        let fonts = FontSet(
            title: "Times New Roman",
            body: "Times New Roman",
            accent: "Arial"
        )
        
        // 背景样式
        let backgroundStyle = BackgroundStyle(
            primaryColor: Color.white,
            secondaryColor: nil,
            pattern: .solid
        )
        
        // 创建主题
        let theme = PresentationTheme(
            name: "Classic",
            colors: colors,
            fonts: fonts,
            backgroundStyle: backgroundStyle
        )
        
        // 创建布局
        let layouts = createDefaultLayouts()
        
        // 创建元数据
        let metadata = TemplateMetadata(
            title: "Classic Template",
            author: "OnlySlide",
            description: "A classic, professional template with traditional styling",
            created: Date(),
            modified: Date()
        )
        
        return PresentationTemplate(
            id: UUID().uuidString,
            name: "Classic",
            description: "A classic, professional template with traditional styling",
            masterLayouts: layouts,
            theme: theme,
            metadata: metadata
        )
    }
    
    /// 创建极简风格模板
    private func createMinimalTemplate() -> PresentationTemplate {
        // 极简配色方案
        let colors: [Color] = [
            Color(red: 0.1, green: 0.1, blue: 0.1),
            Color(red: 0.3, green: 0.3, blue: 0.3),
            Color(red: 0.7, green: 0.3, blue: 0.3),
            Color(red: 0.8, green: 0.8, blue: 0.8),
            Color.white
        ]
        
        // 极简字体
        let fonts = FontSet(
            title: "Helvetica Neue",
            body: "Helvetica Neue",
            accent: "Helvetica Neue"
        )
        
        // 背景样式
        let backgroundStyle = BackgroundStyle(
            primaryColor: Color.white,
            secondaryColor: nil,
            pattern: .solid
        )
        
        // 创建主题
        let theme = PresentationTheme(
            name: "Minimal",
            colors: colors,
            fonts: fonts,
            backgroundStyle: backgroundStyle
        )
        
        // 创建布局
        let layouts = createDefaultLayouts()
        
        // 创建元数据
        let metadata = TemplateMetadata(
            title: "Minimal Template",
            author: "OnlySlide",
            description: "A minimalist template with focus on content",
            created: Date(),
            modified: Date()
        )
        
        return PresentationTemplate(
            id: UUID().uuidString,
            name: "Minimal",
            description: "A minimalist template with focus on content",
            masterLayouts: layouts,
            theme: theme,
            metadata: metadata
        )
    }
    
    /// 创建创意风格模板
    private func createCreativeTemplate() -> PresentationTemplate {
        // 创意配色方案
        let colors: [Color] = [
            Color(red: 0.9, green: 0.3, blue: 0.5),
            Color(red: 0.2, green: 0.2, blue: 0.3),
            Color(red: 0.3, green: 0.8, blue: 0.6),
            Color(red: 0.9, green: 0.7, blue: 0.3),
            Color.white
        ]
        
        // 创意字体
        let fonts = FontSet(
            title: "Avenir Next",
            body: "Avenir",
            accent: "Futura"
        )
        
        // 背景样式
        let backgroundStyle = BackgroundStyle(
            primaryColor: Color(red: 0.98, green: 0.97, blue: 1.0),
            secondaryColor: colors[0].opacity(0.1),
            pattern: .gradient
        )
        
        // 创建主题
        let theme = PresentationTheme(
            name: "Creative",
            colors: colors,
            fonts: fonts,
            backgroundStyle: backgroundStyle
        )
        
        // 创建布局
        let layouts = createDefaultLayouts()
        
        // 创建元数据
        let metadata = TemplateMetadata(
            title: "Creative Template",
            author: "OnlySlide",
            description: "A creative template with vibrant colors and dynamic layouts",
            created: Date(),
            modified: Date()
        )
        
        return PresentationTemplate(
            id: UUID().uuidString,
            name: "Creative",
            description: "A creative template with vibrant colors and dynamic layouts",
            masterLayouts: layouts,
            theme: theme,
            metadata: metadata
        )
    }
    
    /// 创建专业风格模板
    private func createProfessionalTemplate() -> PresentationTemplate {
        // 专业配色方案
        let colors: [Color] = [
            Color(red: 0.0, green: 0.3, blue: 0.6),
            Color(red: 0.1, green: 0.1, blue: 0.1),
            Color(red: 0.5, green: 0.1, blue: 0.1),
            Color(red: 0.6, green: 0.6, blue: 0.6),
            Color.white
        ]
        
        // 专业字体
        let fonts = FontSet(
            title: "Georgia",
            body: "Palatino",
            accent: "Helvetica"
        )
        
        // 背景样式
        let backgroundStyle = BackgroundStyle(
            primaryColor: Color.white,
            secondaryColor: Color(red: 0.95, green: 0.95, blue: 0.97),
            pattern: .gradient
        )
        
        // 创建主题
        let theme = PresentationTheme(
            name: "Professional",
            colors: colors,
            fonts: fonts,
            backgroundStyle: backgroundStyle
        )
        
        // 创建布局
        let layouts = createDefaultLayouts()
        
        // 创建元数据
        let metadata = TemplateMetadata(
            title: "Professional Template",
            author: "OnlySlide",
            description: "A professional template suitable for business presentations",
            created: Date(),
            modified: Date()
        )
        
        return PresentationTemplate(
            id: UUID().uuidString,
            name: "Professional",
            description: "A professional template suitable for business presentations",
            masterLayouts: layouts,
            theme: theme,
            metadata: metadata
        )
    }
    
    // MARK: - 辅助方法
    
    /// 创建默认布局集
    private func createDefaultLayouts() -> [SlideLayout] {
        return [
            createDefaultLayout(for: "cover"),
            createDefaultLayout(for: "title"),
            createDefaultLayout(for: "content"),
            createDefaultLayout(for: "section"),
            createDefaultLayout(for: "table"),
            createDefaultLayout(for: "image"),
            createDefaultLayout(for: "chart"),
            createDefaultLayout(for: "twoColumn"),
            createDefaultLayout(for: "imageWithContent")
        ]
    }
    
    /// 创建指定类型的默认布局
    private func createDefaultLayout(for type: String) -> SlideLayout {
        var placeholders: [Placeholder] = []
        
        switch type {
        case "cover":
            placeholders = [
                Placeholder(type: .title, frame: CGRect(x: 50, y: 200, width: 700, height: 120)),
                Placeholder(type: .subtitle, frame: CGRect(x: 50, y: 340, width: 700, height: 80))
            ]
            
        case "title", "section":
            placeholders = [
                Placeholder(type: .title, frame: CGRect(x: 50, y: 250, width: 700, height: 100))
            ]
            
        case "content":
            placeholders = [
                Placeholder(type: .title, frame: CGRect(x: 50, y: 50, width: 700, height: 80)),
                Placeholder(type: .body, frame: CGRect(x: 50, y: 150, width: 700, height: 450))
            ]
            
        case "table":
            placeholders = [
                Placeholder(type: .title, frame: CGRect(x: 50, y: 50, width: 700, height: 80)),
                Placeholder(type: .table, frame: CGRect(x: 50, y: 150, width: 700, height: 400))
            ]
            
        case "image":
            placeholders = [
                Placeholder(type: .title, frame: CGRect(x: 50, y: 50, width: 700, height: 80)),
                Placeholder(type: .image, frame: CGRect(x: 150, y: 150, width: 500, height: 400))
            ]
            
        case "chart":
            placeholders = [
                Placeholder(type: .title, frame: CGRect(x: 50, y: 50, width: 700, height: 80)),
                Placeholder(type: .chart, frame: CGRect(x: 100, y: 150, width: 600, height: 400))
            ]
            
        case "twoColumn":
            placeholders = [
                Placeholder(type: .title, frame: CGRect(x: 50, y: 50, width: 700, height: 80)),
                Placeholder(type: .body, frame: CGRect(x: 50, y: 150, width: 340, height: 450)),
                Placeholder(type: .body, frame: CGRect(x: 410, y: 150, width: 340, height: 450))
            ]
            
        case "imageWithContent":
            placeholders = [
                Placeholder(type: .title, frame: CGRect(x: 50, y: 50, width: 700, height: 80)),
                Placeholder(type: .image, frame: CGRect(x: 50, y: 150, width: 340, height: 300)),
                Placeholder(type: .body, frame: CGRect(x: 410, y: 150, width: 340, height: 450))
            ]
            
        default:
            placeholders = [
                Placeholder(type: .title, frame: CGRect(x: 50, y: 50, width: 700, height: 80)),
                Placeholder(type: .body, frame: CGRect(x: 50, y: 150, width: 700, height: 450))
            ]
        }
        
        return SlideLayout(type: type, placeholders: placeholders)
    }
}

// MARK: - 支持类型

/// 模板样式
enum TemplateStyle {
    case modern
    case classic
    case minimal
    case creative
    case professional
}

/// 演示文稿模板
struct PresentationTemplate {
    var id: String
    var name: String
    var description: String
    var masterLayouts: [SlideLayout]
    var theme: PresentationTheme
    var metadata: TemplateMetadata
}

/// 演示文稿主题
struct PresentationTheme {
    var name: String
    var colors: [Color]
    var fonts: FontSet
    var backgroundStyle: BackgroundStyle
}

/// 字体集
struct FontSet {
    var title: String
    var body: String
    var accent: String?
}

/// 背景样式
struct BackgroundStyle {
    var primaryColor: Color
    var secondaryColor: Color?
    var pattern: PatternType
    
    enum PatternType {
        case solid
        case gradient
        case texture
    }
}

/// 幻灯片布局
struct SlideLayout {
    var type: String
    var placeholders: [Placeholder]
}

/// 占位符
struct Placeholder {
    var type: PlaceholderType
    var frame: CGRect
}

/// 占位符类型
enum PlaceholderType {
    case title
    case subtitle
    case heading
    case body
    case table
    case chart
    case image
    case footer
    case date
    case slideNumber
    case caption
}

/// 模板元数据
struct TemplateMetadata {
    var title: String
    var author: String
    var description: String
    var created: Date
    var modified: Date
}

/// 演示文稿
struct Presentation {
    var title: String
    var slides: [Slide]
    var theme: PresentationTheme
}

/// 幻灯片
struct Slide {
    var id: String
    var elements: [SlideElement]
    var layout: SlideLayout
    var background: BackgroundStyle
}

/// 幻灯片元素
enum SlideElement {
    case text(TextElement)
    case image(ImageElement)
    case table(TableElement)
    case chart(ChartElement)
    case shape(ShapeElement)
}

// MARK: - 内容特征枚举

enum ContentTone {
    case formal    // 正式、商务
    case technical // 技术、专业
    case creative  // 创意、艺术
    case casual    // 休闲、非正式
}

enum ContentComplexity {
    case low    // 简单内容
    case medium // 中等复杂度
    case high   // 高复杂度内容
} 