import Foundation
import AppKit
import PDFKit

/// 演示文稿导出格式
enum PresentationExportFormat {
    case pdf
    case images
    case html
    
    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .images: return "zip"
        case .html: return "html"
        }
    }
    
    var contentType: String {
        switch self {
        case .pdf: return "application/pdf"
        case .images: return "application/zip"
        case .html: return "text/html"
        }
    }
}

/// 演示文稿导出器
class PresentationExporter {
    
    /// 导出演示文稿到指定格式
    /// - Parameters:
    ///   - presentation: 要导出的演示文稿
    ///   - format: 导出格式
    ///   - outputFileName: 输出文件名（不含扩展名）
    /// - Returns: 导出文件的URL
    func export(_ presentation: PresentationDocument, format: PresentationExportFormat, outputFileName: String) throws -> URL {
        switch format {
        case .pdf:
            return try exportToPDF(presentation, outputFileName: outputFileName)
        case .images:
            return try exportToImages(presentation, outputFileName: outputFileName)
        case .html:
            return try exportToHTML(presentation, outputFileName: outputFileName)
        }
    }
    
    // MARK: - 私有方法
    
    /// 导出为PDF格式
    private func exportToPDF(_ presentation: PresentationDocument, outputFileName: String) throws -> URL {
        // 创建PDF文档
        let pdfDocument = PDFDocument()
        
        // 为每个幻灯片创建PDF页面
        for (index, slide) in presentation.slides.enumerated() {
            // 创建幻灯片视图
            let slideView = createSlideView(for: slide, at: index, in: presentation)
            
            // 将视图转换为PDF页面
            if let pdfPage = createPDFPage(from: slideView) {
                pdfDocument.insert(pdfPage, at: index)
            }
        }
        
        // 保存PDF文件
        let outputURL = getOutputFileURL(fileName: outputFileName, extension: "pdf")
        pdfDocument.write(to: outputURL)
        
        return outputURL
    }
    
    /// 导出为图片集（ZIP格式）
    private func exportToImages(_ presentation: PresentationDocument, outputFileName: String) throws -> URL {
        // 创建临时目录
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // 为每个幻灯片创建图片
        for (index, slide) in presentation.slides.enumerated() {
            // 创建幻灯片视图
            let slideView = createSlideView(for: slide, at: index, in: presentation)
            
            // 将视图转换为图片
            if let image = createImage(from: slideView) {
                // 保存图片
                let imageURL = tempDir.appendingPathComponent("slide_\(index+1).png")
                if let imageData = image.pngData() {
                    try imageData.write(to: imageURL)
                }
            }
        }
        
        // 创建ZIP文件
        let zipURL = getOutputFileURL(fileName: outputFileName, extension: "zip")
        try createZipFile(from: tempDir, to: zipURL)
        
        // 清理临时目录
        try FileManager.default.removeItem(at: tempDir)
        
        return zipURL
    }
    
    /// 导出为HTML格式
    private func exportToHTML(_ presentation: PresentationDocument, outputFileName: String) throws -> URL {
        // 创建临时目录
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // 创建images目录
        let imagesDir = tempDir.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        
        // 生成幻灯片图片
        var slidePaths: [String] = []
        for (index, slide) in presentation.slides.enumerated() {
            // 创建幻灯片视图
            let slideView = createSlideView(for: slide, at: index, in: presentation)
            
            // 将视图转换为图片
            if let image = createImage(from: slideView) {
                // 保存图片
                let imageName = "slide_\(index+1).png"
                let imageURL = imagesDir.appendingPathComponent(imageName)
                if let imageData = image.pngData() {
                    try imageData.write(to: imageURL)
                    slidePaths.append("images/\(imageName)")
                }
            }
        }
        
        // 生成HTML内容
        let htmlContent = generateHTML(presentation: presentation, slidePaths: slidePaths)
        
        // 保存HTML文件
        let htmlFileURL = tempDir.appendingPathComponent("index.html")
        try htmlContent.write(to: htmlFileURL, atomically: true, encoding: .utf8)
        
        // 生成CSS文件
        let cssContent = generateCSS()
        let cssFileURL = tempDir.appendingPathComponent("style.css")
        try cssContent.write(to: cssFileURL, atomically: true, encoding: .utf8)
        
        // 生成JavaScript文件
        let jsContent = generateJavaScript()
        let jsFileURL = tempDir.appendingPathComponent("script.js")
        try jsContent.write(to: jsFileURL, atomically: true, encoding: .utf8)
        
        // 创建ZIP文件
        let zipURL = getOutputFileURL(fileName: outputFileName, extension: "html.zip")
        try createZipFile(from: tempDir, to: zipURL)
        
        // 清理临时目录
        try FileManager.default.removeItem(at: tempDir)
        
        return zipURL
    }
    
    /// 创建幻灯片视图
    private func createSlideView(for slide: PresentationSlide, at index: Int, in presentation: PresentationDocument) -> NSView {
        // 创建幻灯片容器视图
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 1024, height: 768))
        
        // 设置背景
        let backgroundView = NSView(frame: containerView.bounds)
        backgroundView.wantsLayer = true
        
        if let backgroundColor = slide.layout.background {
            backgroundView.layer?.backgroundColor = backgroundColor.cgColor
        } else {
            backgroundView.layer?.backgroundColor = NSColor.white.cgColor
        }
        
        containerView.addSubview(backgroundView)
        
        // 添加幻灯片元素
        for element in slide.elements {
            let elementView = createElementView(element, containerSize: containerView.bounds.size)
            containerView.addSubview(elementView)
        }
        
        // 添加幻灯片编号（除了封面）
        if index > 0 {
            let slideNumberView = NSTextField(labelWithString: "\(index)/\(presentation.slides.count - 1)")
            slideNumberView.frame = NSRect(x: containerView.bounds.width - 80, 
                                          y: containerView.bounds.height - 30, 
                                          width: 70, height: 20)
            slideNumberView.alignment = .right
            slideNumberView.textColor = NSColor.darkGray
            slideNumberView.font = NSFont.systemFont(ofSize: 12)
            containerView.addSubview(slideNumberView)
        }
        
        return containerView
    }
    
    /// 创建元素视图
    private func createElementView(_ element: SlideElement, containerSize: NSSize) -> NSView {
        // 计算元素的实际位置和大小
        let x = element.position.origin.x * containerSize.width
        let y = element.position.origin.y * containerSize.height
        let width = element.position.size.width * containerSize.width
        let height = element.position.size.height * containerSize.height
        
        let frame = NSRect(x: x, y: y, width: width, height: height)
        
        switch element.type {
        case .title, .subtitle, .text:
            if let content = element.content as? String {
                let textField = NSTextField(wrappingLabelWithString: content)
                textField.frame = frame
                
                if let style = element.style as? TextStyle {
                    textField.font = NSFont(name: style.fontName, size: style.fontSize) ?? NSFont.systemFont(ofSize: style.fontSize)
                    textField.textColor = style.color
                    
                    // 设置对齐方式
                    switch style.alignment {
                    case .left:
                        textField.alignment = .left
                    case .center:
                        textField.alignment = .center
                    case .right:
                        textField.alignment = .right
                    case .justified:
                        textField.alignment = .justified
                    }
                    
                    // 对于标题和副标题，设置粗体
                    if element.type == .title || element.type == .subtitle {
                        textField.font = NSFont.boldSystemFont(ofSize: style.fontSize)
                    }
                }
                
                return textField
            }
            
        case .bulletList:
            if let items = element.content as? [String] {
                let listView = NSScrollView(frame: frame)
                listView.hasVerticalScroller = false
                listView.hasHorizontalScroller = false
                listView.autohidesScrollers = true
                
                let contentView = NSTextView(frame: NSRect(origin: .zero, size: frame.size))
                contentView.isEditable = false
                contentView.isSelectable = false
                contentView.autoresizingMask = [.width, .height]
                
                // 构建带项目符号的文本
                let bulletedText = NSMutableAttributedString()
                
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.headIndent = 15.0
                paragraphStyle.firstLineHeadIndent = 0.0
                paragraphStyle.tailIndent = 0.0
                paragraphStyle.lineSpacing = 5.0
                
                for (index, item) in items.enumerated() {
                    let bulletPoint = "• "
                    let bulletString = NSAttributedString(string: bulletPoint)
                    bulletedText.append(bulletString)
                    
                    let itemString = NSAttributedString(
                        string: "\(item)\(index < items.count - 1 ? "\n" : "")",
                        attributes: [.paragraphStyle: paragraphStyle]
                    )
                    bulletedText.append(itemString)
                }
                
                if let style = element.style as? TextStyle {
                    let range = NSRange(location: 0, length: bulletedText.length)
                    bulletedText.addAttribute(.font, value: NSFont(name: style.fontName, size: style.fontSize) ?? NSFont.systemFont(ofSize: style.fontSize), range: range)
                    bulletedText.addAttribute(.foregroundColor, value: style.color, range: range)
                }
                
                contentView.textStorage?.setAttributedString(bulletedText)
                
                listView.documentView = contentView
                return listView
            }
            
        case .image:
            if let imageName = element.content as? String {
                let imageView = NSImageView(frame: frame)
                
                // 尝试加载图片（可能是名称或URL）
                if let url = URL(string: imageName), let image = NSImage(contentsOf: url) {
                    imageView.image = image
                } else if let image = NSImage(named: imageName) {
                    imageView.image = image
                } else {
                    // 使用占位图像
                    imageView.image = NSImage(named: "image_placeholder")
                }
                
                imageView.imageScaling = .scaleProportionallyUpOrDown
                return imageView
            }
            
        case .chart:
            // 简单的图表视图（仅作演示）
            let chartView = NSView(frame: frame)
            chartView.wantsLayer = true
            chartView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
            chartView.layer?.borderWidth = 1
            chartView.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
            chartView.layer?.cornerRadius = 4
            
            let chartLabel = NSTextField(labelWithString: "图表：数据可视化")
            chartLabel.frame = NSRect(x: 10, y: frame.height / 2 - 10, width: frame.width - 20, height: 20)
            chartLabel.alignment = .center
            chartLabel.textColor = NSColor.systemBlue
            
            chartView.addSubview(chartLabel)
            return chartView
            
        case .table:
            // 简单的表格视图（仅作演示）
            let tableView = NSView(frame: frame)
            tableView.wantsLayer = true
            tableView.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.1).cgColor
            tableView.layer?.borderWidth = 1
            tableView.layer?.borderColor = NSColor.systemGray.withAlphaComponent(0.3).cgColor
            
            if let tableData = element.content as? [[String]], !tableData.isEmpty {
                let rowCount = tableData.count
                let columnCount = tableData[0].count
                
                let cellHeight = frame.height / CGFloat(rowCount)
                let cellWidth = frame.width / CGFloat(columnCount)
                
                for (rowIndex, row) in tableData.enumerated() {
                    for (colIndex, cellText) in row.enumerated() {
                        let cellFrame = NSRect(
                            x: CGFloat(colIndex) * cellWidth,
                            y: frame.height - CGFloat(rowIndex + 1) * cellHeight,
                            width: cellWidth,
                            height: cellHeight
                        )
                        
                        let cellView = NSView(frame: cellFrame)
                        cellView.wantsLayer = true
                        cellView.layer?.borderWidth = 0.5
                        cellView.layer?.borderColor = NSColor.gray.cgColor
                        
                        // 表头样式
                        if rowIndex == 0 {
                            cellView.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.2).cgColor
                        }
                        
                        let textField = NSTextField(labelWithString: cellText)
                        textField.frame = NSRect(x: 5, y: 0, width: cellFrame.width - 10, height: cellFrame.height)
                        textField.centerY()
                        textField.alignment = .center
                        
                        if rowIndex == 0 {
                            textField.font = NSFont.boldSystemFont(ofSize: 12)
                        } else {
                            textField.font = NSFont.systemFont(ofSize: 12)
                        }
                        
                        cellView.addSubview(textField)
                        tableView.addSubview(cellView)
                    }
                }
            } else {
                let textField = NSTextField(labelWithString: "表格数据")
                textField.frame = NSRect(x: 0, y: 0, width: frame.width, height: frame.height)
                textField.alignment = .center
                tableView.addSubview(textField)
            }
            
            return tableView
            
        case .code:
            if let codeText = element.content as? String {
                // 创建代码视图
                let scrollView = NSScrollView(frame: frame)
                scrollView.hasVerticalScroller = true
                scrollView.hasHorizontalScroller = true
                scrollView.autohidesScrollers = true
                
                let textView = NSTextView(frame: NSRect(origin: .zero, size: frame.size))
                textView.string = codeText
                textView.isEditable = false
                textView.isSelectable = true
                textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                textView.textColor = NSColor.darkGray
                textView.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1)
                
                // 设置代码风格
                if let style = element.style as? TextStyle {
                    textView.font = NSFont(name: style.fontName, size: style.fontSize) ?? NSFont.monospacedSystemFont(ofSize: style.fontSize, weight: .regular)
                    textView.textColor = style.color
                }
                
                scrollView.documentView = textView
                return scrollView
            }
        }
        
        // 默认返回空视图
        return NSView(frame: frame)
    }
    
    /// 创建PDF页面
    private func createPDFPage(from view: NSView) -> PDFPage? {
        // 设置页面大小
        let pageRect = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        
        // 创建位图上下文
        let context = CGContext(data: nil, 
                               width: Int(pageRect.width), 
                               height: Int(pageRect.height), 
                               bitsPerComponent: 8, 
                               bytesPerRow: 0,
                               space: CGColorSpaceCreateDeviceRGB(), 
                               bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        if let context = context {
            let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
            
            // 渲染视图到上下文
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphicsContext
            view.layer?.render(in: context)
            NSGraphicsContext.restoreGraphicsState()
            
            // 创建PDF数据
            let pdfData = NSMutableData()
            let consumer = CGDataConsumer(data: pdfData as CFMutableData)!
            
            if let pdfContext = CGContext(consumer: consumer, mediaBox: &pageRect, nil) {
                pdfContext.beginPage(mediaBox: &pageRect)
                
                // 绘制图像到PDF
                if let image = context.makeImage() {
                    pdfContext.draw(image, in: pageRect)
                }
                
                pdfContext.endPage()
                pdfContext.closePDF()
                
                // 创建PDF页面
                let provider = CGDataProvider(data: pdfData as CFData)!
                if let pdfDocument = CGPDFDocument(provider) {
                    return PDFPage(pageRef: pdfDocument.page(at: 1)!)
                }
            }
        }
        
        return nil
    }
    
    /// 创建图像
    private func createImage(from view: NSView) -> NSImage? {
        let imageRep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: imageRep)
        
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(imageRep)
        
        return image
    }
    
    /// 创建ZIP文件
    private func createZipFile(from directory: URL, to zipURL: URL) throws {
        // 获取目录中的所有项目
        let fileURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        
        // 创建ZIP命令
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipURL.path] + fileURLs.map { $0.lastPathComponent }
        process.currentDirectoryURL = directory
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "PresentationExporter", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to create ZIP file"])
        }
    }
    
    /// 获取输出文件URL
    private func getOutputFileURL(fileName: String, extension ext: String) -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputDir = documentsDir.appendingPathComponent("OnlySlide", isDirectory: true)
        
        // 确保输出目录存在
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        let outputURL = outputDir.appendingPathComponent("\(fileName).\(ext)")
        
        // 如果文件已存在，添加数字后缀
        var fileURL = outputURL
        var counter = 1
        
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileURL = outputDir.appendingPathComponent("\(fileName)_\(counter).\(ext)")
            counter += 1
        }
        
        return fileURL
    }
    
    /// 生成HTML内容
    private func generateHTML(presentation: PresentationDocument, slidePaths: [String]) -> String {
        let slideHtml = slidePaths.enumerated().map { index, path in
            let slide = presentation.slides[index]
            let notes = slide.notes?.replacingOccurrences(of: "\"", with: "&quot;") ?? ""
            
            return """
                <div class="slide" data-notes="\(notes)">
                    <img src="\(path)" alt="Slide \(index + 1)">
                </div>
            """
        }.joined(separator: "\n")
        
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(presentation.title)</title>
            <link rel="stylesheet" href="style.css">
        </head>
        <body>
            <div class="presentation">
                <div class="title-bar">
                    <h1>\(presentation.title)</h1>
                    <div class="controls">
                        <button id="prevButton">上一页</button>
                        <span id="slideCounter">1/\(slidePaths.count)</span>
                        <button id="nextButton">下一页</button>
                        <button id="fullscreenButton">全屏</button>
                    </div>
                </div>
                
                <div class="slide-container">
                    \(slideHtml)
                </div>
                
                <div class="notes-panel">
                    <h3>演讲备注</h3>
                    <div id="currentNotes"></div>
                </div>
            </div>
            
            <script src="script.js"></script>
        </body>
        </html>
        """
    }
    
    /// 生成CSS样式
    private func generateCSS() -> String {
        return """
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f5f5f5;
        }
        
        .presentation {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        }
        
        .title-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 1rem 2rem;
            background: #f0f0f0;
            border-bottom: 1px solid #ddd;
        }
        
        .title-bar h1 {
            font-size: 1.2rem;
            font-weight: 500;
        }
        
        .controls {
            display: flex;
            align-items: center;
            gap: 1rem;
        }
        
        .controls button {
            padding: 0.5rem 1rem;
            background: #0071e3;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.9rem;
        }
        
        .controls button:hover {
            background: #0062c4;
        }
        
        .slide-container {
            width: 100%;
            position: relative;
            background: #fafafa;
        }
        
        .slide {
            width: 100%;
            display: none;
            text-align: center;
        }
        
        .slide.active {
            display: block;
        }
        
        .slide img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 0 auto;
        }
        
        .notes-panel {
            padding: 1rem 2rem;
            background: #f9f9f9;
            border-top: 1px solid #eee;
        }
        
        .notes-panel h3 {
            font-size: 1rem;
            margin-bottom: 0.5rem;
            color: #666;
        }
        
        #currentNotes {
            padding: 1rem;
            background: white;
            border-radius: 4px;
            border: 1px solid #eee;
            min-height: 100px;
        }
        
        /* 全屏模式 */
        .fullscreen .presentation {
            max-width: none;
            height: 100vh;
            display: flex;
            flex-direction: column;
        }
        
        .fullscreen .slide-container {
            flex: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #000;
        }
        
        .fullscreen .slide {
            display: none;
            height: 100%;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .fullscreen .slide.active {
            display: flex;
        }
        
        .fullscreen .slide img {
            max-height: 100%;
            width: auto;
            height: auto;
            max-width: 100%;
            object-fit: contain;
        }
        
        .fullscreen .notes-panel {
            display: none;
        }
        """
    }
    
    /// 生成JavaScript代码
    private func generateJavaScript() -> String {
        return """
        document.addEventListener('DOMContentLoaded', function() {
            const slides = document.querySelectorAll('.slide');
            const prevButton = document.getElementById('prevButton');
            const nextButton = document.getElementById('nextButton');
            const fullscreenButton = document.getElementById('fullscreenButton');
            const slideCounter = document.getElementById('slideCounter');
            const notesPanel = document.getElementById('currentNotes');
            
            let currentSlide = 0;
            
            // 初始化显示
            showSlide(currentSlide);
            
            // 事件监听
            prevButton.addEventListener('click', prevSlide);
            nextButton.addEventListener('click', nextSlide);
            fullscreenButton.addEventListener('click', toggleFullscreen);
            
            // 键盘快捷键
            document.addEventListener('keydown', function(e) {
                if (e.key === 'ArrowRight' || e.key === ' ' || e.key === 'PageDown') {
                    nextSlide();
                } else if (e.key === 'ArrowLeft' || e.key === 'PageUp') {
                    prevSlide();
                } else if (e.key === 'f' || e.key === 'F') {
                    toggleFullscreen();
                }
            });
            
            // 显示指定幻灯片
            function showSlide(index) {
                // 隐藏所有幻灯片
                slides.forEach(slide => slide.classList.remove('active'));
                
                // 显示当前幻灯片
                slides[index].classList.add('active');
                
                // 更新计数器
                slideCounter.textContent = `${index + 1}/${slides.length}`;
                
                // 更新备注
                const notes = slides[index].getAttribute('data-notes') || '';
                notesPanel.textContent = notes;
                
                // 更新导航按钮状态
                prevButton.disabled = index === 0;
                nextButton.disabled = index === slides.length - 1;
            }
            
            // 下一张幻灯片
            function nextSlide() {
                if (currentSlide < slides.length - 1) {
                    currentSlide++;
                    showSlide(currentSlide);
                }
            }
            
            // 上一张幻灯片
            function prevSlide() {
                if (currentSlide > 0) {
                    currentSlide--;
                    showSlide(currentSlide);
                }
            }
            
            // 切换全屏模式
            function toggleFullscreen() {
                document.body.classList.toggle('fullscreen');
                
                if (document.body.classList.contains('fullscreen')) {
                    if (document.documentElement.requestFullscreen) {
                        document.documentElement.requestFullscreen();
                    } else if (document.documentElement.webkitRequestFullscreen) {
                        document.documentElement.webkitRequestFullscreen();
                    }
                    fullscreenButton.textContent = '退出全屏';
                } else {
                    if (document.exitFullscreen) {
                        document.exitFullscreen();
                    } else if (document.webkitExitFullscreen) {
                        document.webkitExitFullscreen();
                    }
                    fullscreenButton.textContent = '全屏';
                }
            }
            
            // 监听全屏变化
            document.addEventListener('fullscreenchange', updateFullscreenButton);
            document.addEventListener('webkitfullscreenchange', updateFullscreenButton);
            
            function updateFullscreenButton() {
                if (document.fullscreenElement || document.webkitFullscreenElement) {
                    document.body.classList.add('fullscreen');
                    fullscreenButton.textContent = '退出全屏';
                } else {
                    document.body.classList.remove('fullscreen');
                    fullscreenButton.textContent = '全屏';
                }
            }
        });
        """
    }
}

// MARK: - 扩展

extension NSTextField {
    func centerY() {
        let height = self.frame.size.height
        let textHeight = self.cell?.cellSize.height ?? height
        self.frame.origin.y = (height - textHeight) / 2
    }
} 