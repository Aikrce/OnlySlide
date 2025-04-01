import Foundation
import SwiftUI

/// 样式管理器
/// 负责内容与模板之间的样式匹配和适配
class StyleManager {
    /// 将内容样式与模板样式匹配
    func matchStyles(content: AnalyzedContent, template: PresentationTemplate) -> StyleMappings {
        // 创建文本样式映射
        let textStyles = createTextStyleMappings(content, template)
        
        // 创建颜色样式映射
        let colorStyles = createColorStyleMappings(content, template)
        
        return StyleMappings(
            textStyles: textStyles,
            colorStyles: colorStyles
        )
    }
    
    /// 创建文本样式映射
    private func createTextStyleMappings(_ content: AnalyzedContent, _ template: PresentationTemplate) -> [TextRole: TextStyle] {
        let theme = template.theme
        
        // 创建基本文本样式映射
        let baseStyles: [TextRole: TextStyle] = [
            .title: TextStyle(
                font: theme.fonts.title.with(size: 40),
                color: theme.colors[0],
                alignment: .leading,
                lineSpacing: 1.2
            ),
            .subtitle: TextStyle(
                font: theme.fonts.title.with(size: 28),
                color: theme.colors[1],
                alignment: .leading,
                lineSpacing: 1.2
            ),
            .heading: TextStyle(
                font: theme.fonts.title.with(size: 24),
                color: theme.colors[1],
                alignment: .leading,
                lineSpacing: 1.2
            ),
            .body: TextStyle(
                font: theme.fonts.body.with(size: 18),
                color: theme.colors[1],
                alignment: .leading,
                lineSpacing: 1.2
            ),
            .caption: TextStyle(
                font: theme.fonts.body.with(size: 14),
                color: theme.colors[2],
                alignment: .center,
                lineSpacing: 1.0
            ),
            .code: TextStyle(
                font: Font.system(.body, design: .monospaced),
                color: theme.colors[1],
                alignment: .leading,
                lineSpacing: 1.0
            )
        ]
        
        // 对样式进行内容适应性调整
        return adaptTextStylesToContent(baseStyles, content, theme)
    }
    
    /// 根据内容特性调整文本样式
    private func adaptTextStylesToContent(_ baseStyles: [TextRole: TextStyle], _ content: AnalyzedContent, _ theme: PresentationTheme) -> [TextRole: TextStyle] {
        var adaptedStyles = baseStyles
        
        // 分析内容特性以决定样式调整
        let averageTitleLength = content.sections.reduce(0) { $0 + $1.title.count } / max(1, content.sections.count)
        
        // 如果标题普遍较长，减小字体大小
        if averageTitleLength > 30 {
            adaptedStyles[.title] = TextStyle(
                font: theme.fonts.title.with(size: 36),
                color: adaptedStyles[.title]!.color,
                alignment: adaptedStyles[.title]!.alignment,
                lineSpacing: adaptedStyles[.title]!.lineSpacing
            )
        }
        
        // 检查内容密度
        let contentDensity = calculateContentDensity(content)
        
        // 对于高密度内容，减小正文字体大小以适应更多内容
        if contentDensity > 0.7 {
            adaptedStyles[.body] = TextStyle(
                font: theme.fonts.body.with(size: 16),
                color: adaptedStyles[.body]!.color,
                alignment: adaptedStyles[.body]!.alignment,
                lineSpacing: adaptedStyles[.body]!.lineSpacing
            )
        }
        
        return adaptedStyles
    }
    
    /// 计算内容密度（0-1范围）
    private func calculateContentDensity(_ content: AnalyzedContent) -> Double {
        var totalContentLength = 0
        var itemCount = 0
        
        for section in content.sections {
            for item in section.items {
                itemCount += 1
                
                switch item.type {
                case .text:
                    if let text = item.content as? String {
                        totalContentLength += text.count
                    }
                    
                case .list:
                    if let list = item.content as? [String] {
                        totalContentLength += list.joined().count
                    }
                    
                case .table:
                    if let table = item.content as? [[String]] {
                        let flatTable = table.flatMap { $0 }
                        totalContentLength += flatTable.joined().count
                    }
                    
                default:
                    // 其他内容类型按固定值计算
                    totalContentLength += 200
                }
            }
        }
        
        // 归一化为0-1范围
        let averageItemLength = Double(totalContentLength) / Double(max(1, itemCount))
        return min(1.0, max(0.0, averageItemLength / 1000.0))
    }
    
    /// 创建颜色样式映射
    private func createColorStyleMappings(_ content: AnalyzedContent, _ template: PresentationTemplate) -> [ColorRole: Color] {
        let theme = template.theme
        
        // 基本颜色映射
        var colorMappings: [ColorRole: Color] = [
            .primary: theme.colors[0],
            .secondary: theme.colors[1],
            .accent: theme.colors.count > 2 ? theme.colors[2] : theme.colors[0],
            .background: theme.backgroundStyle.primaryColor,
            .text: theme.colors[1],
            .border: theme.colors.count > 3 ? theme.colors[3] : Color.gray,
            .alternateRow: Color(white: 0.95)
        ]
        
        // 调整交替行颜色以匹配背景
        let backgroundColor = colorMappings[.background]!
        
        // 检测背景亮度
        let isDarkBackground = backgroundColor.brightness < 0.5
        
        if isDarkBackground {
            // 对于深色背景，使用稍微亮一点的交替行
            colorMappings[.alternateRow] = backgroundColor.lighten(by: 0.1)
            
            // 确保文本颜色对比度足够
            if colorMappings[.text]!.brightness < 0.6 {
                colorMappings[.text] = Color.white
            }
        } else {
            // 对于浅色背景，使用稍微暗一点的交替行
            colorMappings[.alternateRow] = backgroundColor.darken(by: 0.05)
            
            // 确保文本颜色对比度足够
            if colorMappings[.text]!.brightness > 0.4 {
                colorMappings[.text] = Color.black
            }
        }
        
        return colorMappings
    }
}

// MARK: - 颜色扩展

extension Color {
    /// 估计颜色亮度 (0-1)
    var brightness: CGFloat {
        guard let components = cgColor?.components, cgColor?.numberOfComponents ?? 0 >= 3 else {
            return 0.5 // 默认中等亮度
        }
        
        // 使用相对亮度公式 (0.2126*R + 0.7152*G + 0.0722*B)
        if components.count >= 3 {
            return 0.2126 * components[0] + 0.7152 * components[1] + 0.0722 * components[2]
        }
        
        // 灰度
        return components[0]
    }
    
    /// 使颜色更亮
    func lighten(by amount: CGFloat) -> Color {
        guard let components = cgColor?.components, cgColor?.numberOfComponents ?? 0 >= 3 else {
            return self
        }
        
        if components.count >= 3 {
            let r = min(1.0, components[0] + amount)
            let g = min(1.0, components[1] + amount)
            let b = min(1.0, components[2] + amount)
            
            return Color(red: Double(r), green: Double(g), blue: Double(b))
        }
        
        // 灰度
        let gray = min(1.0, components[0] + amount)
        return Color(white: Double(gray))
    }
    
    /// 使颜色更暗
    func darken(by amount: CGFloat) -> Color {
        guard let components = cgColor?.components, cgColor?.numberOfComponents ?? 0 >= 3 else {
            return self
        }
        
        if components.count >= 3 {
            let r = max(0.0, components[0] - amount)
            let g = max(0.0, components[1] - amount)
            let b = max(0.0, components[2] - amount)
            
            return Color(red: Double(r), green: Double(g), blue: Double(b))
        }
        
        // 灰度
        let gray = max(0.0, components[0] - amount)
        return Color(white: Double(gray))
    }
}

// MARK: - 字体扩展

extension Font {
    /// 创建指定大小的字体
    func with(size: CGFloat) -> Font {
        switch self {
        case .largeTitle, .title, .title2, .title3:
            return .system(size: size, weight: .bold)
        case .headline:
            return .system(size: size, weight: .semibold)
        case .body, .callout, .subheadline, .footnote, .caption, .caption2:
            return .system(size: size)
        default:
            return .system(size: size)
        }
    }
} 