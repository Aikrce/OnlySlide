import Foundation
import SwiftUI
import ZIPFoundation

/// 图片导出选项
public struct ImagesExportOptions {
    /// 图片格式
    public enum ImageFormat: String, CaseIterable, Identifiable {
        case png = "PNG"
        case jpeg = "JPEG"
        
        public var id: String { rawValue }
        
        /// 文件扩展名
        public var fileExtension: String {
            switch self {
            case .png:
                return "png"
            case .jpeg:
                return "jpg"
            }
        }
        
        /// MIME类型
        public var mimeType: String {
            switch self {
            case .png:
                return "image/png"
            case .jpeg:
                return "image/jpeg"
            }
        }
    }
    
    /// 图片格式
    public var format: ImageFormat = .png
    
    /// 图片质量（仅适用于JPEG格式）
    public var quality: Double = 0.8
    
    /// 图片尺寸
    public var imageSize: CGSize = CGSize(width: 1280, height: 720)
    
    /// 是否包含封面图片
    public var includeCoverImage: Bool = true
    
    /// 是否包含目录图片
    public var includeTableOfContents: Bool = true
    
    /// 是否在图片上添加文档水印
    public var includeWatermark: Bool = false
    
    /// 水印文本
    public var watermarkText: String = ""
    
    /// 是否压缩为ZIP文件
    public var compressToZIP: Bool = true
    
    /// 是否在图片上添加页码
    public var includePageNumbers: Bool = true
    
    public init() {}
}

/// 图片导出错误类型
public enum ImagesExportError: Error {
    case imageGenerationFailed
    case compressionFailed
    case imageWriteFailed
    case directoryCreationFailed
}

/// 图片导出工具
public class ImagesExporter {
    /// 分析结果
    private let result: DocumentAnalysisResult
    
    /// 导出选项
    private var options: ImagesExportOptions
    
    /// 临时工作目录
    private var workingDirectory: URL?
    
    /// 初始化
    /// - Parameters:
    ///   - result: 文档分析结果
    ///   - options: 导出选项
    public init(result: DocumentAnalysisResult, options: ImagesExportOptions = ImagesExportOptions()) {
        self.result = result
        self.options = options
    }
    
    /// 导出为图片集合
    /// - Parameter url: 目标URL (如果options.compressToZIP为true，则为ZIP文件；否则为目录)
    /// - Returns: 是否成功
    public func exportToImages(url: URL) -> Bool {
        do {
            // 1. 创建临时工作目录
            let tempDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            self.workingDirectory = tempDirectory
            
            // 2. 生成图片文件
            let imageFiles = try generateImages()
            
            // 3. 如果需要压缩，则创建ZIP文件；否则直接复制目录
            if options.compressToZIP {
                try compressDirectory(tempDirectory, to: url)
            } else {
                // 确保目标目录存在
                if !FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                }
                
                // 复制所有图片文件到目标目录
                for imageFile in imageFiles {
                    let fileName = imageFile.lastPathComponent
                    let destinationURL = url.appendingPathComponent(fileName)
                    try FileManager.default.copyItem(at: imageFile, to: destinationURL)
                }
            }
            
            // 4. 清理临时文件
            try FileManager.default.removeItem(at: tempDirectory)
            
            return true
        } catch {
            print("图片导出错误: \(error)")
            
            // 清理临时文件
            if let dir = workingDirectory {
                try? FileManager.default.removeItem(at: dir)
            }
            
            return false
        }
    }
    
    // MARK: - 私有方法
    
    /// 生成图片文件
    /// - Returns: 生成的图片文件URL数组
    private func generateImages() throws -> [URL] {
        guard let baseDir = workingDirectory else {
            throw ImagesExportError.directoryCreationFailed
        }
        
        var imageFiles: [URL] = []
        var pageIndex = 1
        
        // 创建README.txt文件
        let readmeURL = baseDir.appendingPathComponent("README.txt")
        let readmeContent = """
        文档导出图片集
        标题: \(result.title)
        文档类型: \(result.sourceType.displayName)
        生成时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))
        共 \(result.sections.count) 个章节，\(result.totalContentItemCount) 个内容项
        
        由 OnlySlide 导出工具生成
        """
        try readmeContent.write(to: readmeURL, atomically: true, encoding: .utf8)
        
        // 生成封面图片
        if options.includeCoverImage {
            let coverImage = try generateCoverImage()
            let coverURL = baseDir.appendingPathComponent(String(format: "%03d_cover.\(options.format.fileExtension)", pageIndex))
            try saveImage(coverImage, to: coverURL)
            imageFiles.append(coverURL)
            pageIndex += 1
        }
        
        // 生成目录图片
        if options.includeTableOfContents {
            let tocImage = try generateTableOfContentsImage()
            let tocURL = baseDir.appendingPathComponent(String(format: "%03d_toc.\(options.format.fileExtension)", pageIndex))
            try saveImage(tocImage, to: tocURL)
            imageFiles.append(tocURL)
            pageIndex += 1
        }
        
        // 生成章节图片
        for section in result.sections {
            // 章节标题图片
            let sectionTitleImage = try generateSectionTitleImage(section)
            let sectionTitleURL = baseDir.appendingPathComponent(String(format: "%03d_section_\(sanitizeFilename(section.title)).\(options.format.fileExtension)", pageIndex))
            try saveImage(sectionTitleImage, to: sectionTitleURL)
            imageFiles.append(sectionTitleURL)
            pageIndex += 1
            
            // 章节内容图片
            let contentImages = try generateContentImages(for: section)
            for (index, contentImage) in contentImages.enumerated() {
                let contentURL = baseDir.appendingPathComponent(String(format: "%03d_content_\(sanitizeFilename(section.title))_\(index+1).\(options.format.fileExtension)", pageIndex))
                try saveImage(contentImage, to: contentURL)
                imageFiles.append(contentURL)
                pageIndex += 1
            }
        }
        
        return imageFiles
    }
    
    /// 生成封面图片
    private func generateCoverImage() throws -> UIImage {
        // 创建图片上下文
        let renderer = UIGraphicsImageRenderer(size: options.imageSize)
        
        let image = renderer.image { ctx in
            // 绘制背景
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: options.imageSize))
            
            // 绘制标题
            let titleFont = UIFont.systemFont(ofSize: 48, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            let titleString = NSAttributedString(string: result.title, attributes: titleAttributes)
            let titleSize = titleString.size()
            let titleRect = CGRect(
                x: (options.imageSize.width - titleSize.width) / 2,
                y: options.imageSize.height * 0.4 - titleSize.height / 2,
                width: titleSize.width,
                height: titleSize.height
            )
            titleString.draw(in: titleRect)
            
            // 绘制文档类型
            let subtitleFont = UIFont.systemFont(ofSize: 24)
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.darkGray
            ]
            let subtitleString = NSAttributedString(string: "文档类型: \(result.sourceType.displayName)", attributes: subtitleAttributes)
            let subtitleSize = subtitleString.size()
            let subtitleRect = CGRect(
                x: (options.imageSize.width - subtitleSize.width) / 2,
                y: titleRect.maxY + 30,
                width: subtitleSize.width,
                height: subtitleSize.height
            )
            subtitleString.draw(in: subtitleRect)
            
            // 绘制生成信息
            let footerFont = UIFont.systemFont(ofSize: 16)
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: footerFont,
                .foregroundColor: UIColor.gray
            ]
            let footerString = NSAttributedString(string: "由 OnlySlide 导出工具生成", attributes: footerAttributes)
            let footerSize = footerString.size()
            let footerRect = CGRect(
                x: (options.imageSize.width - footerSize.width) / 2,
                y: options.imageSize.height - footerSize.height - 30,
                width: footerSize.width,
                height: footerSize.height
            )
            footerString.draw(in: footerRect)
            
            // 添加水印
            if options.includeWatermark && !options.watermarkText.isEmpty {
                drawWatermark(in: ctx.cgContext)
            }
        }
        
        return image
    }
    
    /// 生成目录图片
    private func generateTableOfContentsImage() throws -> UIImage {
        // 创建图片上下文
        let renderer = UIGraphicsImageRenderer(size: options.imageSize)
        
        let image = renderer.image { ctx in
            // 绘制背景
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: options.imageSize))
            
            // 绘制标题
            let titleFont = UIFont.systemFont(ofSize: 36, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            let titleString = NSAttributedString(string: "目录", attributes: titleAttributes)
            let titleSize = titleString.size()
            let titleRect = CGRect(
                x: 60,
                y: 60,
                width: titleSize.width,
                height: titleSize.height
            )
            titleString.draw(in: titleRect)
            
            // 绘制目录内容
            let contentFont = UIFont.systemFont(ofSize: 20)
            let contentBoldFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
            let margin: CGFloat = 60
            let lineHeight: CGFloat = 36
            
            var y = titleRect.maxY + 40
            
            for (index, section) in result.sections.enumerated() {
                let indent = CGFloat(max(0, section.level - 1) * 30)
                let font = section.level == 1 ? contentBoldFont : contentFont
                
                let contentAttributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
                
                let sectionTitle = section.title
                let contentString = NSAttributedString(string: sectionTitle, attributes: contentAttributes)
                
                let contentRect = CGRect(
                    x: margin + indent,
                    y: y,
                    width: options.imageSize.width - (margin * 2) - indent,
                    height: lineHeight
                )
                contentString.draw(in: contentRect)
                
                y += lineHeight
                
                // 如果超出页面范围，停止添加更多内容
                if y > options.imageSize.height - margin {
                    break
                }
            }
            
            // 添加页码
            if options.includePageNumbers {
                drawPageNumber(2, in: ctx.cgContext)
            }
            
            // 添加水印
            if options.includeWatermark && !options.watermarkText.isEmpty {
                drawWatermark(in: ctx.cgContext)
            }
        }
        
        return image
    }
    
    /// 生成章节标题图片
    private func generateSectionTitleImage(_ section: DocumentSection) throws -> UIImage {
        // 创建图片上下文
        let renderer = UIGraphicsImageRenderer(size: options.imageSize)
        
        let image = renderer.image { ctx in
            // 绘制背景
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: options.imageSize))
            
            // 绘制章节标题
            let titleFont = UIFont.systemFont(ofSize: 40, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            let titleString = NSAttributedString(string: section.title, attributes: titleAttributes)
            let titleSize = titleString.size()
            let titleRect = CGRect(
                x: (options.imageSize.width - titleSize.width) / 2,
                y: options.imageSize.height * 0.4 - titleSize.height / 2,
                width: titleSize.width,
                height: titleSize.height
            )
            titleString.draw(in: titleRect)
            
            // 绘制章节信息
            let infoFont = UIFont.systemFont(ofSize: 20)
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: infoFont,
                .foregroundColor: UIColor.darkGray
            ]
            let infoString = NSAttributedString(string: "\(section.contentItems.count) 个内容项", attributes: infoAttributes)
            let infoSize = infoString.size()
            let infoRect = CGRect(
                x: (options.imageSize.width - infoSize.width) / 2,
                y: titleRect.maxY + 30,
                width: infoSize.width,
                height: infoSize.height
            )
            infoString.draw(in: infoRect)
            
            // 添加页码
            if options.includePageNumbers {
                // 计算页码（假设封面+目录+之前的章节都各占一页）
                var pageNum = 3 // 封面+目录=2页
                for s in result.sections {
                    if s === section {
                        break
                    }
                    pageNum += 1 + (s.contentItems.count / 10) // 每章节标题页+内容页(每10项内容1页)
                    if s.contentItems.count % 10 > 0 {
                        pageNum += 1
                    }
                }
                drawPageNumber(pageNum, in: ctx.cgContext)
            }
            
            // 添加水印
            if options.includeWatermark && !options.watermarkText.isEmpty {
                drawWatermark(in: ctx.cgContext)
            }
        }
        
        return image
    }
    
    /// 生成内容图片
    private func generateContentImages(for section: DocumentSection) throws -> [UIImage] {
        var images: [UIImage] = []
        let itemsPerPage = 10
        let contentItems = section.contentItems
        
        // 按每页最大项数分页
        let pageCount = (contentItems.count / itemsPerPage) + (contentItems.count % itemsPerPage > 0 ? 1 : 0)
        
        for pageIndex in 0..<pageCount {
            let startIndex = pageIndex * itemsPerPage
            let endIndex = min(startIndex + itemsPerPage, contentItems.count)
            let pageItems = Array(contentItems[startIndex..<endIndex])
            
            // 为每页内容创建一个图片
            let image = try generateContentPageImage(items: pageItems, sectionTitle: section.title, pageIndex: pageIndex)
            images.append(image)
        }
        
        return images
    }
    
    /// 生成内容页图片
    private func generateContentPageImage(items: [ContentItem], sectionTitle: String, pageIndex: Int) throws -> UIImage {
        // 创建图片上下文
        let renderer = UIGraphicsImageRenderer(size: options.imageSize)
        
        let image = renderer.image { ctx in
            // 绘制背景
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: options.imageSize))
            
            // 绘制小标题
            let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            let titleString = NSAttributedString(string: sectionTitle, attributes: titleAttributes)
            let titleRect = CGRect(
                x: 60,
                y: 40,
                width: options.imageSize.width - 120,
                height: 40
            )
            titleString.draw(in: titleRect)
            
            // 绘制内容项
            let contentFont = UIFont.systemFont(ofSize: 16)
            let contentCodeFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            let margin: CGFloat = 60
            let itemSpacing: CGFloat = 16
            
            var y = titleRect.maxY + 30
            
            for (index, item) in items.enumerated() {
                let font = (item.type == .code) ? contentCodeFont : contentFont
                let indent = CGFloat(item.level * 20)
                
                // 项目前缀
                var prefix = ""
                if item.type == .listItem {
                    prefix = "• "
                } else if item.type == .code {
                    prefix = "```"
                } else if item.type == .quote {
                    prefix = "\"" // 引号
                }
                
                let contentAttributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
                
                let contentText = prefix + item.text
                let contentString = NSAttributedString(string: contentText, attributes: contentAttributes)
                let contentHeight = contentString.boundingRect(
                    with: CGSize(width: options.imageSize.width - (margin * 2) - indent, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).height
                
                let contentRect = CGRect(
                    x: margin + indent,
                    y: y,
                    width: options.imageSize.width - (margin * 2) - indent,
                    height: contentHeight
                )
                contentString.draw(in: contentRect)
                
                y += contentHeight + itemSpacing
                
                // 如果超出页面范围，停止添加更多内容
                if y > options.imageSize.height - margin {
                    break
                }
            }
            
            // 添加页码
            if options.includePageNumbers {
                // 计算大致页码（简化版，实际应用中可能需要更精确的计算）
                let pageOffset = options.includeCoverImage ? 1 : 0
                let tocOffset = options.includeTableOfContents ? 1 : 0
                let pageNum = pageOffset + tocOffset + result.sections.count + pageIndex + 1
                drawPageNumber(pageNum, in: ctx.cgContext)
            }
            
            // 添加水印
            if options.includeWatermark && !options.watermarkText.isEmpty {
                drawWatermark(in: ctx.cgContext)
            }
        }
        
        return image
    }
    
    /// 绘制页码
    private func drawPageNumber(_ number: Int, in context: CGContext) {
        let text = "\(number)"
        let font = UIFont.systemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.gray
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()
        
        let rect = CGRect(
            x: (options.imageSize.width - size.width) / 2,
            y: options.imageSize.height - size.height - 20,
            width: size.width,
            height: size.height
        )
        
        attributedString.draw(in: rect)
    }
    
    /// 绘制水印
    private func drawWatermark(in context: CGContext) {
        guard !options.watermarkText.isEmpty else { return }
        
        context.saveGState()
        
        // 设置透明度
        context.setAlpha(0.15)
        
        // 设置旋转
        context.translateBy(x: options.imageSize.width / 2, y: options.imageSize.height / 2)
        context.rotate(by: -CGFloat.pi / 4)
        
        let font = UIFont.systemFont(ofSize: 36, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.gray
        ]
        
        let attributedString = NSAttributedString(string: options.watermarkText, attributes: attributes)
        let size = attributedString.size()
        
        let rect = CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        )
        
        attributedString.draw(in: rect)
        
        context.restoreGState()
    }
    
    /// 保存图片到文件
    private func saveImage(_ image: UIImage, to url: URL) throws {
        var imageData: Data?
        
        switch options.format {
        case .png:
            imageData = image.pngData()
        case .jpeg:
            imageData = image.jpegData(compressionQuality: CGFloat(options.quality))
        }
        
        guard let data = imageData else {
            throw ImagesExportError.imageGenerationFailed
        }
        
        try data.write(to: url)
    }
    
    /// 压缩目录为ZIP文件
    private func compressDirectory(_ directory: URL, to destinationURL: URL) throws {
        // 如果目标文件已存在，先删除
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // 使用ZIPFoundation创建ZIP文件
        let fileManager = FileManager()
        try fileManager.zipItem(at: directory, to: destinationURL)
    }
    
    /// 清理文件名，移除不合法字符
    private func sanitizeFilename(_ filename: String) -> String {
        let illegalCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        var sanitized = filename
            .components(separatedBy: illegalCharacters)
            .joined(separator: "_")
        
        // 限制长度
        if sanitized.count > 50 {
            sanitized = String(sanitized.prefix(50))
        }
        
        return sanitized
    }
}

// MARK: - DocumentAnalysisResult扩展

extension DocumentAnalysisResult {
    /// 导出为图片集合
    /// - Parameters:
    ///   - url: 文件URL
    ///   - options: 导出选项
    /// - Returns: 是否成功
    public func exportToImages(url: URL, options: ImagesExportOptions = ImagesExportOptions()) -> Bool {
        let exporter = ImagesExporter(result: self, options: options)
        return exporter.exportToImages(url: url)
    }
} 