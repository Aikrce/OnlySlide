import Foundation
import SwiftUI

/// 自适应主题引擎
/// 负责根据内容分析结果和行业特征选择最佳演示主题
class ThemeEngine {
    // 依赖组件
    private let templateAdapter: TemplateAdapter
    
    // 行业模板映射
    private var industryTemplates: [Industry: TemplateStyle] = [
        .technology: .modern,
        .business: .professional,
        .education: .classic,
        .creative: .creative,
        .healthcare: .minimal,
        .marketing: .creative
    ]
    
    init(templateAdapter: TemplateAdapter = TemplateAdapter()) {
        self.templateAdapter = templateAdapter
    }
    
    /// 根据内容和目标行业选择最佳模板
    func selectBestTemplate(for content: AnalyzedContent, industry: Industry? = nil) -> PresentationTemplate {
        // 1. 根据内容特征进行评分
        let templateScores = scoreTemplatesForContent(content)
        
        // 2. 如果指定了行业，优先考虑行业推荐模板
        var finalScores = templateScores
        if let industry = industry, let recommendedStyle = industryTemplates[industry] {
            finalScores[recommendedStyle] = (finalScores[recommendedStyle] ?? 0) + 5
        }
        
        // 3. 选择最高分模板
        let bestStyle = finalScores.sorted { $0.value > $1.value }.first?.key ?? .modern
        
        // 4. 获取模板
        var template = templateAdapter.getDefaultTemplate(style: bestStyle)
        
        // 5. 自定义模板以更好地匹配内容
        if let industry = industry {
            template = customizeTemplateForIndustry(template, industry: industry)
        }
        
        return template
    }
    
    /// 对内容的每种模板风格进行评分
    private func scoreTemplatesForContent(_ content: AnalyzedContent) -> [TemplateStyle: Int] {
        var scores: [TemplateStyle: Int] = [
            .modern: 0,
            .classic: 0,
            .minimal: 0,
            .creative: 0,
            .professional: 0
        ]
        
        // 分析关键词以确定适合的风格
        for keyword in content.keywords {
            // 现代风格关键词
            if ["创新", "科技", "数字", "先进", "modern", "tech", "digital", "innovative"].contains(where: { keyword.lowercased().contains($0) }) {
                scores[.modern] = (scores[.modern] ?? 0) + 2
            }
            
            // 经典风格关键词
            if ["传统", "历史", "学术", "研究", "classic", "traditional", "academic", "research"].contains(where: { keyword.lowercased().contains($0) }) {
                scores[.classic] = (scores[.classic] ?? 0) + 2
            }
            
            // 极简风格关键词
            if ["简约", "清晰", "重点", "精简", "minimal", "clean", "simple", "focus"].contains(where: { keyword.lowercased().contains($0) }) {
                scores[.minimal] = (scores[.minimal] ?? 0) + 2
            }
            
            // 创意风格关键词
            if ["创意", "艺术", "设计", "灵感", "creative", "artistic", "design", "inspiration"].contains(where: { keyword.lowercased().contains($0) }) {
                scores[.creative] = (scores[.creative] ?? 0) + 2
            }
            
            // 专业风格关键词
            if ["专业", "商务", "企业", "方案", "professional", "business", "corporate", "solution"].contains(where: { keyword.lowercased().contains($0) }) {
                scores[.professional] = (scores[.professional] ?? 0) + 2
            }
        }
        
        // 分析内容类型
        let contentItems = content.sections.flatMap { $0.items }
        
        // 更多图表倾向于专业/现代风格
        let chartCount = contentItems.filter { $0.type == .chart }.count
        if chartCount > 0 {
            scores[.professional] = (scores[.professional] ?? 0) + chartCount
            scores[.modern] = (scores[.modern] ?? 0) + chartCount
        }
        
        // 更多图片倾向于创意风格
        let imageCount = contentItems.filter { $0.type == .image }.count
        if imageCount > 2 {
            scores[.creative] = (scores[.creative] ?? 0) + min(5, imageCount)
        }
        
        // 更多代码倾向于现代/极简风格
        let codeCount = contentItems.filter { $0.type == .code }.count
        if codeCount > 0 {
            scores[.modern] = (scores[.modern] ?? 0) + codeCount * 2
            scores[.minimal] = (scores[.minimal] ?? 0) + codeCount
        }
        
        // 更多表格倾向于专业/经典风格
        let tableCount = contentItems.filter { $0.type == .table }.count
        if tableCount > 0 {
            scores[.professional] = (scores[.professional] ?? 0) + tableCount
            scores[.classic] = (scores[.classic] ?? 0) + tableCount
        }
        
        // 内容量影响
        if contentItems.count > 30 {
            // 大量内容更适合极简风格保持清晰
            scores[.minimal] = (scores[.minimal] ?? 0) + 3
        }
        
        return scores
    }
    
    /// 根据行业特征定制模板
    private func customizeTemplateForIndustry(_ template: PresentationTemplate, industry: Industry) -> PresentationTemplate {
        var customizedTemplate = template
        
        switch industry {
        case .technology:
            // 技术行业使用更现代的颜色方案
            if !template.theme.colors.isEmpty {
                var colors = template.theme.colors
                colors[0] = Color(red: 0.0, green: 0.6, blue: 0.9) // 科技蓝
                customizedTemplate.theme.colors = colors
            }
            
        case .healthcare:
            // 医疗行业使用平和的色调
            if !template.theme.colors.isEmpty {
                var colors = template.theme.colors
                colors[0] = Color(red: 0.0, green: 0.5, blue: 0.5) // 青蓝色
                colors[1] = Color(red: 0.5, green: 0.7, blue: 0.9) // 淡蓝色
                customizedTemplate.theme.colors = colors
            }
            
        case .business:
            // 商业行业使用专业稳重的颜色
            if !template.theme.colors.isEmpty {
                var colors = template.theme.colors
                colors[0] = Color(red: 0.2, green: 0.3, blue: 0.5) // 深蓝色
                customizedTemplate.theme.colors = colors
            }
            
        case .education:
            // 教育行业使用明亮友好的颜色
            if !template.theme.colors.isEmpty {
                var colors = template.theme.colors
                colors[0] = Color(red: 0.0, green: 0.5, blue: 0.3) // 绿色
                customizedTemplate.theme.colors = colors
            }
            
        case .creative:
            // 创意行业使用活力四射的颜色
            if !template.theme.colors.isEmpty {
                var colors = template.theme.colors
                colors[0] = Color(red: 0.9, green: 0.4, blue: 0.3) // 亮橙红色
                customizedTemplate.theme.colors = colors
            }
            
        case .marketing:
            // 营销行业使用引人注目的颜色
            if !template.theme.colors.isEmpty {
                var colors = template.theme.colors
                colors[0] = Color(red: 0.8, green: 0.2, blue: 0.3) // 红色
                customizedTemplate.theme.colors = colors
            }
        }
        
        // 根据行业更新元数据
        customizedTemplate.metadata.description += " (Optimized for \(industry.rawValue) industry)"
        
        return customizedTemplate
    }
    
    /// 识别内容可能的行业分类
    func detectIndustry(from content: AnalyzedContent) -> Industry? {
        // 行业关键词映射
        let industryKeywords: [Industry: [String]] = [
            .technology: ["技术", "软件", "编程", "应用", "开发", "系统", "算法", "数据", "网络", "tech", "software", "app", "development", "system", "data", "algorithm", "network"],
            
            .business: ["商业", "经济", "市场", "销售", "投资", "利润", "战略", "管理", "business", "market", "sales", "profit", "investment", "strategy", "management"],
            
            .education: ["教育", "学习", "学生", "教师", "课程", "学校", "培训", "知识", "education", "learning", "student", "teacher", "course", "school", "training"],
            
            .healthcare: ["医疗", "健康", "患者", "医生", "治疗", "药物", "诊断", "医院", "healthcare", "health", "patient", "doctor", "treatment", "medicine", "diagnosis"],
            
            .creative: ["创意", "设计", "艺术", "创作", "灵感", "美学", "创新", "创造", "creative", "design", "art", "creation", "inspiration", "aesthetic", "innovation"],
            
            .marketing: ["营销", "广告", "品牌", "推广", "受众", "营销策略", "媒体", "宣传", "marketing", "advertising", "brand", "promotion", "audience", "campaign", "media"]
        ]
        
        // 计算每个行业的匹配分数
        var industryScores: [Industry: Int] = [:]
        
        // 基于关键词匹配
        for keyword in content.keywords {
            let lowercaseKeyword = keyword.lowercased()
            
            for (industry, keywords) in industryKeywords {
                if keywords.contains(where: { lowercaseKeyword.contains($0) }) {
                    industryScores[industry, default: 0] += 2
                }
            }
        }
        
        // 扫描内容文本寻找更多线索
        let allText = content.title + " " + content.summary + " " + content.sections.map { $0.title }.joined(separator: " ")
        
        for (industry, keywords) in industryKeywords {
            for keyword in keywords {
                if allText.lowercased().contains(keyword) {
                    industryScores[industry, default: 0] += 1
                }
            }
        }
        
        // 如果有明确的行业痕迹，返回分数最高的
        if let topIndustry = industryScores.sorted(by: { $0.value > $1.value }).first, topIndustry.value >= 3 {
            return topIndustry.key
        }
        
        return nil
    }
}

/// 行业分类
enum Industry: String, CaseIterable {
    case technology = "Technology"
    case business = "Business"
    case education = "Education"
    case healthcare = "Healthcare"
    case creative = "Creative"
    case marketing = "Marketing"
} 