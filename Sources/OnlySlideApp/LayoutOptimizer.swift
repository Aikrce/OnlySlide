import Foundation
import SwiftUI

/// 智能布局优化器
/// 负责优化幻灯片元素的布局，提高可读性和视觉平衡
class LayoutOptimizer {
    
    /// 优化演示文稿的布局
    func optimizePresentation(_ presentation: Presentation) -> Presentation {
        var optimizedPresentation = presentation
        
        // 优化每张幻灯片
        for i in 0..<optimizedPresentation.slides.count {
            optimizedPresentation.slides[i] = optimizeSlide(optimizedPresentation.slides[i])
        }
        
        // 确保整体连贯性
        optimizedPresentation = ensureCohesiveness(optimizedPresentation)
        
        return optimizedPresentation
    }
    
    /// 优化单张幻灯片的布局
    func optimizeSlide(_ slide: Slide) -> Slide {
        var optimizedSlide = slide
        var elements = slide.elements
        
        // 1. 检测并修复重叠
        elements = resolveOverlaps(elements)
        
        // 2. 平衡视觉权重
        elements = balanceVisualWeight(elements)
        
        // 3. 优化空间使用
        elements = optimizeSpaceUsage(elements, slide.layout)
        
        // 4. 优化文本可读性
        elements = optimizeTextReadability(elements)
        
        // 5. 增强视觉层次结构
        elements = enhanceVisualHierarchy(elements)
        
        optimizedSlide.elements = elements
        return optimizedSlide
    }
    
    /// 解决元素重叠问题
    private func resolveOverlaps(_ elements: [SlideElement]) -> [SlideElement] {
        var optimizedElements = elements
        
        // 检测每对元素是否有重叠
        for i in 0..<optimizedElements.count {
            for j in (i+1)..<optimizedElements.count {
                let frame1 = getElementFrame(optimizedElements[i])
                let frame2 = getElementFrame(optimizedElements[j])
                
                if frame1.intersects(frame2) {
                    // 处理重叠
                    optimizedElements = resolveOverlap(optimizedElements, at: i, and: j)
                }
            }
        }
        
        return optimizedElements
    }
    
    /// 解决两个特定元素之间的重叠
    private func resolveOverlap(_ elements: [SlideElement], at index1: Int, and index2: Int) -> [SlideElement] {
        var updatedElements = elements
        
        let frame1 = getElementFrame(elements[index1])
        let frame2 = getElementFrame(elements[index2])
        
        // 判断重叠程度
        let intersection = frame1.intersection(frame2)
        let overlapRatio = intersection.width * intersection.height / (frame1.width * frame1.height)
        
        if overlapRatio > 0.5 {
            // 重叠严重，需要垂直重新布局
            var newFrame = frame2
            newFrame.origin.y = frame1.maxY + 10
            updatedElements[index2] = adjustElementPosition(elements[index2], to: newFrame.origin)
        } else {
            // 轻微重叠，可以水平错开
            var newFrame = frame2
            
            // 根据元素在画布上的位置决定向左还是向右移动
            if frame2.midX < 400 { // 画布宽度假设为800
                newFrame.origin.x = frame1.maxX + 10
            } else {
                newFrame.origin.x = frame1.minX - frame2.width - 10
            }
            
            updatedElements[index2] = adjustElementPosition(elements[index2], to: newFrame.origin)
        }
        
        return updatedElements
    }
    
    /// 平衡幻灯片上元素的视觉权重
    private func balanceVisualWeight(_ elements: [SlideElement]) -> [SlideElement] {
        var optimizedElements = elements
        
        // 如果元素很少，不需要平衡
        if elements.count <= 2 {
            return elements
        }
        
        // 计算当前重心
        var weightedX: CGFloat = 0
        var weightedY: CGFloat = 0
        var totalWeight: CGFloat = 0
        
        for element in elements {
            let frame = getElementFrame(element)
            let weight = calculateVisualWeight(element)
            
            weightedX += frame.midX * weight
            weightedY += frame.midY * weight
            totalWeight += weight
        }
        
        let centerOfWeight = CGPoint(
            x: weightedX / totalWeight,
            y: weightedY / totalWeight
        )
        
        // 检查是否需要平衡
        let slideCenterX: CGFloat = 400 // 假设幻灯片宽度为800
        let slideCenterY: CGFloat = 300 // 假设幻灯片高度为600
        
        let xOffset = slideCenterX - centerOfWeight.x
        let yOffset = slideCenterY - centerOfWeight.y
        
        // 如果重心偏离中心太远，调整元素位置
        if abs(xOffset) > 100 || abs(yOffset) > 80 {
            for i in 0..<optimizedElements.count {
                var frame = getElementFrame(optimizedElements[i])
                frame.origin.x += xOffset * 0.5
                frame.origin.y += yOffset * 0.5
                
                // 确保不会移出边界
                frame.origin.x = max(20, min(780 - frame.width, frame.origin.x))
                frame.origin.y = max(20, min(580 - frame.height, frame.origin.y))
                
                optimizedElements[i] = adjustElementPosition(optimizedElements[i], to: frame.origin)
            }
        }
        
        return optimizedElements
    }
    
    /// 优化空间使用
    private func optimizeSpaceUsage(_ elements: [SlideElement], _ layout: SlideLayout) -> [SlideElement] {
        var optimizedElements = elements
        
        // 获取布局区域
        let contentArea = layout.placeholders.first { $0.type == .body }?.frame ?? 
                          CGRect(x: 50, y: 100, width: 700, height: 450)
        
        // 计算所有元素当前占用的区域
        var elementsFrame = CGRect.zero
        for element in elements {
            let frame = getElementFrame(element)
            if elementsFrame.isNull {
                elementsFrame = frame
            } else {
                elementsFrame = elementsFrame.union(frame)
            }
        }
        
        // 如果元素占用区域太小，放大元素
        let usageRatio = (elementsFrame.width * elementsFrame.height) / (contentArea.width * contentArea.height)
        
        if usageRatio < 0.5 && elements.count > 0 {
            let scaleRatio = min(1.3, sqrt(0.7 / usageRatio))
            
            // 计算中心点
            let centerX = elementsFrame.midX
            let centerY = elementsFrame.midY
            
            for i in 0..<optimizedElements.count {
                var frame = getElementFrame(optimizedElements[i])
                
                // 计算相对于中心点的新位置和大小
                let relativeX = frame.origin.x - centerX
                let relativeY = frame.origin.y - centerY
                
                let newX = centerX + relativeX * scaleRatio
                let newY = centerY + relativeY * scaleRatio
                let newWidth = frame.width * scaleRatio
                let newHeight = frame.height * scaleRatio
                
                // 应用新位置和大小
                frame = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
                
                // 确保不超出边界
                if frame.maxX > contentArea.maxX {
                    frame.origin.x = contentArea.maxX - frame.width
                }
                if frame.maxY > contentArea.maxY {
                    frame.origin.y = contentArea.maxY - frame.height
                }
                if frame.minX < contentArea.minX {
                    frame.origin.x = contentArea.minX
                }
                if frame.minY < contentArea.minY {
                    frame.origin.y = contentArea.minY
                }
                
                optimizedElements[i] = adjustElementSize(optimizedElements[i], to: frame.size)
                optimizedElements[i] = adjustElementPosition(optimizedElements[i], to: frame.origin)
            }
        }
        
        return optimizedElements
    }
    
    /// 优化文本可读性
    private func optimizeTextReadability(_ elements: [SlideElement]) -> [SlideElement] {
        var optimizedElements = elements
        
        for i in 0..<optimizedElements.count {
            if case let .text(textElement) = optimizedElements[i] {
                var updatedElement = textElement
                
                // 检查文本长度
                let textLength = textElement.text.characters.count
                
                // 针对不同角色的文本调整字体大小
                switch textElement.style.role {
                case .title:
                    // 标题太长时减小字体
                    if textLength > 50 {
                        updatedElement.style.fontSize = max(24, updatedElement.style.fontSize - 4)
                    }
                    
                case .body:
                    // 正文太长时调整字体或容器
                    if textLength > 200 {
                        updatedElement.style.fontSize = max(14, updatedElement.style.fontSize - 2)
                        
                        // 如果文字太多，可能需要扩大容器
                        if textLength > 400 {
                            var frame = updatedElement.frame
                            frame.size.height = min(400, frame.height + 50)
                            updatedElement.frame = frame
                        }
                    }
                    
                default:
                    break
                }
                
                // 更新元素
                optimizedElements[i] = .text(updatedElement)
            }
        }
        
        return optimizedElements
    }
    
    /// 增强视觉层次结构
    private func enhanceVisualHierarchy(_ elements: [SlideElement]) -> [SlideElement] {
        var optimizedElements = elements
        
        // 分离标题和内容
        var titleElements: [SlideElement] = []
        var contentElements: [SlideElement] = []
        
        for element in elements {
            if case let .text(textElement) = element, textElement.style.role == .title || textElement.style.role == .subtitle {
                titleElements.append(element)
            } else {
                contentElements.append(element)
            }
        }
        
        // 确保标题在顶部
        for i in 0..<titleElements.count {
            var frame = getElementFrame(titleElements[i])
            
            // 将标题移至顶部
            if frame.origin.y > 100 {
                frame.origin.y = max(40, frame.origin.y - 20)
                titleElements[i] = adjustElementPosition(titleElements[i], to: frame.origin)
            }
        }
        
        // 重新组合元素，标题在前
        optimizedElements = titleElements + contentElements
        
        return optimizedElements
    }
    
    /// 确保整个演示文稿的连贯性
    private func ensureCohesiveness(_ presentation: Presentation) -> Presentation {
        var optimizedPresentation = presentation
        
        // 确保标题位置一致
        var titlePositions: [CGPoint] = []
        
        for slide in presentation.slides {
            for element in slide.elements {
                if case let .text(textElement) = element, textElement.style.role == .title {
                    titlePositions.append(textElement.frame.origin)
                    break
                }
            }
        }
        
        // 如果有足够的幻灯片，计算标题位置的平均值
        if titlePositions.count > 1 {
            let avgX = titlePositions.reduce(0) { $0 + $1.x } / CGFloat(titlePositions.count)
            let avgY = titlePositions.reduce(0) { $0 + $1.y } / CGFloat(titlePositions.count)
            
            // 标准化所有幻灯片上的标题位置
            for i in 0..<optimizedPresentation.slides.count {
                var updatedElements = optimizedPresentation.slides[i].elements
                
                for j in 0..<updatedElements.count {
                    if case let .text(textElement) = updatedElements[j], textElement.style.role == .title {
                        var updatedTextElement = textElement
                        
                        // 如果位置偏离太多，调整为平均位置
                        let currentPos = textElement.frame.origin
                        if abs(currentPos.x - avgX) > 30 || abs(currentPos.y - avgY) > 20 {
                            updatedTextElement.frame.origin = CGPoint(x: avgX, y: avgY)
                            updatedElements[j] = .text(updatedTextElement)
                        }
                        
                        break
                    }
                }
                
                optimizedPresentation.slides[i].elements = updatedElements
            }
        }
        
        return optimizedPresentation
    }
    
    // MARK: - 辅助方法
    
    /// 获取元素框架
    private func getElementFrame(_ element: SlideElement) -> CGRect {
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
    
    /// 调整元素大小
    private func adjustElementSize(_ element: SlideElement, to newSize: CGSize) -> SlideElement {
        switch element {
        case .text(var textElement):
            textElement.frame.size = newSize
            return .text(textElement)
        case .image(var imageElement):
            imageElement.frame.size = newSize
            return .image(imageElement)
        case .table(var tableElement):
            tableElement.frame.size = newSize
            return .table(tableElement)
        case .chart(var chartElement):
            chartElement.frame.size = newSize
            return .chart(chartElement)
        case .shape(var shapeElement):
            shapeElement.frame.size = newSize
            return .shape(shapeElement)
        }
    }
    
    /// 计算元素的视觉权重
    private func calculateVisualWeight(_ element: SlideElement) -> CGFloat {
        switch element {
        case .text(let textElement):
            // 基于角色和大小计算权重
            let baseWeight: CGFloat
            switch textElement.style.role {
            case .title: baseWeight = 5.0
            case .subtitle: baseWeight = 3.0
            case .heading: baseWeight = 2.5
            default: baseWeight = 1.0
            }
            
            // 文字长度影响
            let textLength = min(1.0, CGFloat(textElement.text.characters.count) / 100.0)
            
            // 面积影响
            let area = textElement.frame.width * textElement.frame.height / 10000.0
            
            return baseWeight * (1.0 + textLength) * (1.0 + area)
            
        case .image(let imageElement):
            // 图片权重基于尺寸
            return imageElement.frame.width * imageElement.frame.height / 10000.0 * 3.0
            
        case .table(let tableElement):
            // 表格权重基于尺寸和复杂度
            let cellCount = tableElement.rows * tableElement.columns
            return tableElement.frame.width * tableElement.frame.height / 10000.0 * min(5.0, CGFloat(cellCount) / 4.0)
            
        case .chart(let chartElement):
            // 图表通常吸引更多注意力
            return chartElement.frame.width * chartElement.frame.height / 10000.0 * 4.0
            
        case .shape(let shapeElement):
            // 形状权重相对较低
            return shapeElement.frame.width * shapeElement.frame.height / 10000.0 * 1.5
        }
    }
}

// MARK: - Support types

/// 图表类型
enum ChartType {
    case bar
    case line
    case pie
    case scatter
}

/// 图表数据点
struct ChartDataPoint {
    var category: String
    var value: Double
    var series: String?
}

/// 文本元素
struct TextElement {
    var id: String
    var text: AttributedString
    var frame: CGRect
    var style: TextStyle
}

/// 图像元素
struct ImageElement {
    var id: String
    var imageData: Data
    var frame: CGRect
    var contentMode: ContentMode
    
    enum ContentMode {
        case fit
        case fill
    }
}

/// 表格元素
struct TableElement {
    var id: String
    var rows: Int
    var columns: Int
    var cells: [[TableCell]]
    var frame: CGRect
    var style: TableStyle
}

/// 图表元素
struct ChartElement {
    var id: String
    var type: ChartType
    var data: [ChartDataPoint]
    var frame: CGRect
    var style: ChartStyle
}

/// 形状元素
struct ShapeElement {
    var id: String
    var type: ShapeType
    var frame: CGRect
    var style: ShapeStyle
    
    enum ShapeType {
        case rectangle
        case ellipse
        case triangle
        case arrow
        case line
    }
}

// MARK: - 样式类型

/// 文本样式
struct TextStyle {
    var font: Font
    var color: Color
    var alignment: TextAlignment
    var lineSpacing: CGFloat
}

/// 表格样式
struct TableStyle {
    var headerStyle: TextStyle
    var cellStyle: TextStyle
    var alternatingRowColors: Bool
    var gridStyle: BorderStyle
}

/// 表格单元格
struct TableCell {
    var content: AttributedString
    var backgroundColor: Color?
    var borders: CellBorders
}

/// 单元格边框
struct CellBorders {
    var top: BorderStyle?
    var left: BorderStyle?
    var bottom: BorderStyle?
    var right: BorderStyle?
}

/// 边框样式
struct BorderStyle {
    var width: CGFloat
    var color: Color
    var style: LineStyle
    
    enum LineStyle {
        case solid
        case dashed
        case dotted
    }
}

/// 图表样式
struct ChartStyle {
    var colors: [Color]
    var legendPosition: LegendPosition
    var showValues: Bool
    
    enum LegendPosition {
        case none
        case top
        case bottom
        case left
        case right
    }
}

/// 形状样式
struct ShapeStyle {
    var fillColor: Color?
    var strokeColor: Color
    var strokeWidth: CGFloat
    var opacity: Double
} 