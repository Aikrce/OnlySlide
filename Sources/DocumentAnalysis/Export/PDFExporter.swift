import Foundation
import SwiftUI
import PDFKit
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// PDF导出选项
public struct PDFExportOptions {
    /// 页面大小
    public var pageSize: CGSize = CGSize(width: 595, height: 842) // A4
    
    /// 页面边距
    public var pageMargins: UIEdgeInsets = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
    
    /// 是否包含目录
    public var includeTableOfContents: Bool = true
    
    /// 是否包含页码
    public var includePageNumbers: Bool = true
    
    /// 是否包含页眉页脚
    public var includeHeaderFooter: Bool = true
    
    /// 页眉文本
    public var headerText: String = ""
    
    /// 页脚文本
    public var footerText: String = ""
    
    /// 导出标题样式
    public var titleStyle: PDFTextStyle = PDFTextStyle(font: .systemFont(ofSize: 24, weight: .bold), color: .black)
    
    /// 导出小标题样式
    public var headingStyle: PDFTextStyle = PDFTextStyle(font: .systemFont(ofSize: 18, weight: .bold), color: .black)
    
    /// 正文样式
    public var bodyStyle: PDFTextStyle = PDFTextStyle(font: .systemFont(ofSize: 12), color: .black)
    
    /// 列表样式
    public var listStyle: PDFTextStyle = PDFTextStyle(font: .systemFont(ofSize: 12), color: .black)
    
    /// 自定义样式表
    public var customStyles: [String: PDFTextStyle] = [:]
    
    public init() {}
}

/// PDF文本样式
public struct PDFTextStyle {
    public var font: UIFont
    public var color: UIColor
    
    public init(font: UIFont, color: UIColor) {
        self.font = font
        self.color = color
    }
}

/// PDF导出工具
public class PDFExporter {
    /// 分析结果
    private let result: DocumentAnalysisResult
    
    /// 导出选项
    private var options: PDFExportOptions
    
    /// 初始化
    /// - Parameters:
    ///   - result: 文档分析结果
    ///   - options: 导出选项
    public init(result: DocumentAnalysisResult, options: PDFExportOptions = PDFExportOptions()) {
        self.result = result
        self.options = options
        
        // 设置默认页眉页脚
        if options.headerText.isEmpty {
            self.options.headerText = result.title
        }
        
        if options.footerText.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            self.options.footerText = "导出日期: \(dateFormatter.string(from: Date()))"
        }
    }
    
    /// 导出为PDF数据
    /// - Returns: PDF数据
    public func exportToPDFData() -> Data? {
        let pdfData = createPDFData()
        return pdfData
    }
    
    /// 导出PDF到文件
    /// - Parameter url: 目标URL
    /// - Returns: 是否成功
    public func exportToPDF(url: URL) -> Bool {
        guard let pdfData = exportToPDFData() else {
            return false
        }
        
        do {
            try pdfData.write(to: url)
            return true
        } catch {
            print("PDF导出错误: \(error)")
            return false
        }
    }
    
    // MARK: - 私有方法
    
    /// 创建PDF数据
    private func createPDFData() -> Data? {
        let pdfMetadata = [
            kCGPDFContextCreator: "OnlySlide PDF Exporter" as CFString,
            kCGPDFContextTitle: result.title as CFString,
            kCGPDFContextAuthor: (result.metadata["author"] ?? "OnlySlide") as CFString
        ]
        
        let data = NSMutableData()
        
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            return nil
        }
        
        // 设置页面大小
        let mediaBox = CGRect(x: 0, y: 0, width: options.pageSize.width, height: options.pageSize.height)
        
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &CGRect(mediaBox), pdfMetadata) else {
            return nil
        }
        
        // 创建PDF文档
        let pdfDocument = renderDocument(in: pdfContext)
        
        return data as Data
    }
    
    /// 在上下文中渲染PDF文档
    private func renderDocument(in context: CGContext) -> CGPDFDocument? {
        // 目录页面
        if options.includeTableOfContents {
            renderTableOfContents(in: context)
        }
        
        // 内容页面
        for (index, section) in result.sections.enumerated() {
            let isNewPage = index > 0 || options.includeTableOfContents
            renderSection(section, in: context, newPage: isNewPage)
        }
        
        return nil
    }
    
    /// 渲染目录
    private func renderTableOfContents(in context: CGContext) {
        context.beginPage(mediaBox: nil)
        
        // 标题
        renderText("目录", at: CGPoint(x: options.pageMargins.left, y: options.pageSize.height - options.pageMargins.top - 30), style: options.titleStyle, in: context)
        
        // 目录项
        var y = options.pageSize.height - options.pageMargins.top - 70
        
        for (index, section) in result.sections.enumerated() {
            let indentation = CGFloat(max(0, section.level - 1) * 20)
            let tocText = "\(section.title) ................... \(index + 1)"
            
            renderText(tocText, at: CGPoint(x: options.pageMargins.left + indentation, y: y), style: options.bodyStyle, in: context)
            
            y -= 20
            
            // 如果页面空间不足，创建新页面
            if y < options.pageMargins.bottom + 30 {
                context.endPage()
                context.beginPage(mediaBox: nil)
                y = options.pageSize.height - options.pageMargins.top - 30
            }
        }
        
        renderPageFooter(0, in: context)
        context.endPage()
    }
    
    /// 渲染章节
    private func renderSection(_ section: DocumentSection, in context: CGContext, newPage: Bool) {
        if newPage {
            context.beginPage(mediaBox: nil)
        }
        
        // 页面号
        let pageNumber = context.numberOfPages
        
        // 标题
        let titleStyle = section.level == 1 ? options.titleStyle : options.headingStyle
        let titleY = options.pageSize.height - options.pageMargins.top - (newPage ? 30 : 60)
        renderText(section.title, at: CGPoint(x: options.pageMargins.left, y: titleY), style: titleStyle, in: context)
        
        // 内容
        var y = titleY - 40
        
        for item in section.contentItems {
            let (itemHeight, hasMore) = renderContentItem(item, at: CGPoint(x: options.pageMargins.left, y: y), in: context)
            
            y -= itemHeight + 10
            
            // 如果内容太多，需要创建新页面
            if hasMore || y < options.pageMargins.bottom + 30 {
                renderPageFooter(pageNumber, in: context)
                context.endPage()
                context.beginPage(mediaBox: nil)
                y = options.pageSize.height - options.pageMargins.top - 30
            }
        }
        
        if options.includeHeaderFooter {
            renderPageHeader(in: context)
            renderPageFooter(pageNumber, in: context)
        }
        
        if !newPage {
            context.endPage()
        }
    }
    
    /// 渲染内容项
    private func renderContentItem(_ item: ContentItem, at position: CGPoint, in context: CGContext) -> (height: CGFloat, hasMore: Bool) {
        var y = position.y
        var hasMore = false
        
        switch item.type {
        case .paragraph:
            let paragraphHeight = renderParagraph(item.text, at: CGPoint(x: position.x, y: y), in: context)
            y -= paragraphHeight
            
        case .listItem:
            let listText = "• \(item.text)"
            let listHeight = renderParagraph(listText, at: CGPoint(x: position.x + 10, y: y), in: context)
            y -= listHeight
            
        case .table, .image, .code, .quote:
            // 这些类型需要更复杂的渲染，这里简化处理
            let placeholderText = "[\(item.type.rawValue.capitalized)] \(item.text)"
            let placeholderHeight = renderParagraph(placeholderText, at: CGPoint(x: position.x, y: y), in: context)
            y -= placeholderHeight
        }
        
        // 如果有子项，递归渲染
        for child in item.children {
            let childPosition = CGPoint(x: position.x + 20, y: y)
            let (childHeight, childHasMore) = renderContentItem(child, at: childPosition, in: context)
            
            y -= childHeight + 5
            hasMore = hasMore || childHasMore
            
            // 如果页面空间不足，标记需要创建新页面
            if y < options.pageMargins.bottom + 30 {
                hasMore = true
                break
            }
        }
        
        return (position.y - y, hasMore)
    }
    
    /// 渲染段落文本
    private func renderParagraph(_ text: String, at position: CGPoint, in context: CGContext) -> CGFloat {
        // 在实际实现中，这里应该进行文本换行和分页处理
        // 简化版本：返回一个大致的高度
        renderText(text, at: position, style: options.bodyStyle, in: context)
        
        return 20 // 简化处理，返回固定高度
    }
    
    /// 渲染文本
    private func renderText(_ text: String, at position: CGPoint, style: PDFTextStyle, in context: CGContext) {
        context.saveGState()
        
        context.setFillColor(style.color.cgColor)
        
        #if canImport(AppKit)
        let attributedString = NSAttributedString(
            string: text,
            attributes: [.font: style.font, .foregroundColor: style.color]
        )
        
        let textRect = CGRect(
            x: position.x,
            y: position.y,
            width: options.pageSize.width - options.pageMargins.left - options.pageMargins.right,
            height: 100 // 假设最大高度
        )
        
        attributedString.draw(in: textRect)
        #else
        // 使用基本的CG绘图，不支持丰富的文本样式
        context.setFont(style.font as CTFont)
        context.setTextPosition(position.x, position.y)
        
        // 将NSString转换为CFString
        let cfString = text as CFString
        
        // 使用Core Text绘制文本
        let line = CTLineCreateWithAttributedString(NSAttributedString(
            string: text,
            attributes: [.font: style.font, .foregroundColor: style.color]
        ) as CFAttributedString)
        
        context.textPosition = position
        CTLineDraw(line, context)
        #endif
        
        context.restoreGState()
    }
    
    /// 渲染页眉
    private func renderPageHeader(in context: CGContext) {
        if options.headerText.isEmpty {
            return
        }
        
        let headerY = options.pageSize.height - options.pageMargins.top / 2
        
        renderText(options.headerText, at: CGPoint(x: options.pageMargins.left, y: headerY), style: PDFTextStyle(font: .systemFont(ofSize: 10), color: .gray), in: context)
        
        // 绘制分隔线
        context.saveGState()
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.move(to: CGPoint(x: options.pageMargins.left, y: headerY - 10))
        context.addLine(to: CGPoint(x: options.pageSize.width - options.pageMargins.right, y: headerY - 10))
        context.strokePath()
        context.restoreGState()
    }
    
    /// 渲染页脚
    private func renderPageFooter(_ pageNumber: Int, in context: CGContext) {
        let footerY = options.pageMargins.bottom / 2
        
        if options.includePageNumbers {
            let pageText = "第 \(pageNumber) 页"
            renderText(pageText, at: CGPoint(x: options.pageSize.width / 2 - 20, y: footerY), style: PDFTextStyle(font: .systemFont(ofSize: 10), color: .gray), in: context)
        }
        
        if !options.footerText.isEmpty {
            renderText(options.footerText, at: CGPoint(x: options.pageMargins.left, y: footerY - 15), style: PDFTextStyle(font: .systemFont(ofSize: 8), color: .gray), in: context)
        }
    }
}

// MARK: - PDF导出扩展

extension DocumentAnalysisResult {
    /// 导出为PDF数据
    /// - Parameter options: 导出选项
    /// - Returns: PDF数据
    public func exportToPDFData(options: PDFExportOptions = PDFExportOptions()) -> Data? {
        let exporter = PDFExporter(result: self, options: options)
        return exporter.exportToPDFData()
    }
    
    /// 导出PDF到文件
    /// - Parameters:
    ///   - url: 文件URL
    ///   - options: 导出选项
    /// - Returns: 是否成功
    public func exportToPDF(url: URL, options: PDFExportOptions = PDFExportOptions()) -> Bool {
        let exporter = PDFExporter(result: self, options: options)
        return exporter.exportToPDF(url: url)
    }
}

// MARK: - 兼容性类型定义

#if canImport(UIKit) && !canImport(AppKit)
public typealias UIFont = UIFont
public typealias UIColor = UIColor
public typealias UIEdgeInsets = UIEdgeInsets
#elseif canImport(AppKit)
public typealias UIFont = NSFont
public typealias UIColor = NSColor
public typealias UIEdgeInsets = NSEdgeInsets
#endif 