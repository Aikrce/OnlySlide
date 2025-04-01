import Foundation
import SwiftUI
import ZIPFoundation
import XMLCoder

/// PowerPoint导出选项
public struct PowerPointExportOptions {
    /// 幻灯片尺寸
    public enum SlideSize {
        case standard    // 4:3
        case widescreen  // 16:9
        
        /// 获取尺寸大小（像素）
        public var dimensions: CGSize {
            switch self {
            case .standard:
                return CGSize(width: 720, height: 540)
            case .widescreen:
                return CGSize(width: 960, height: 540)
            }
        }
    }
    
    /// 主题
    public enum Theme: String, CaseIterable, Identifiable {
        case office     = "Office"
        case modern     = "Modern"
        case minimal    = "Minimal"
        case colorful   = "Colorful"
        case corporate  = "Corporate"
        case elegant    = "Elegant"
        
        public var id: String { rawValue }
    }
    
    /// 过渡效果
    public enum TransitionEffect: String, CaseIterable, Identifiable {
        case none     = "无"
        case fade     = "淡入淡出"
        case push     = "推送"
        case wipe     = "擦除"
        case split    = "分割"
        case reveal   = "显示"
        
        public var id: String { rawValue }
    }
    
    /// 幻灯片大小
    public var slideSize: SlideSize = .widescreen
    
    /// 主题
    public var theme: Theme = .office
    
    /// 每张幻灯片最大内容项数量
    public var maxItemsPerSlide: Int = 6
    
    /// 是否包含封面页
    public var includeCoverSlide: Bool = true
    
    /// 是否包含目录页
    public var includeTableOfContents: Bool = true
    
    /// 是否在页脚显示页码
    public var includePageNumbers: Bool = true
    
    /// 页脚文本
    public var footerText: String = ""
    
    /// 幻灯片过渡效果
    public var transitionEffect: TransitionEffect = .none
    
    /// 是否自动生成笔记
    public var generateNotes: Bool = false
    
    public init() {}
}

/// PowerPoint导出功能错误类型
public enum PowerPointExportError: Error {
    case templateCreationFailed
    case structureCreationFailed
    case slideGenerationFailed
    case compressionFailed
    case resourceProcessingFailed
}

/// PowerPoint导出工具
public class PowerPointExporter {
    /// 分析结果
    private let result: DocumentAnalysisResult
    
    /// 导出选项
    private var options: PowerPointExportOptions
    
    /// 临时工作目录
    private var workingDirectory: URL?
    
    /// XML编码器设置
    private let xmlEncoder: XMLEncoder = {
        let encoder = XMLEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return encoder
    }()
    
    /// 初始化
    /// - Parameters:
    ///   - result: 文档分析结果
    ///   - options: 导出选项
    public init(result: DocumentAnalysisResult, options: PowerPointExportOptions = PowerPointExportOptions()) {
        self.result = result
        self.options = options
    }
    
    /// 导出为PowerPoint文件
    /// - Parameter url: 目标URL
    /// - Returns: 是否成功
    public func exportToPowerPoint(url: URL) -> Bool {
        do {
            // 1. 创建临时工作目录
            let tempDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            self.workingDirectory = tempDirectory
            
            // 2. 创建PPTX文件结构
            try createPPTXStructure()
            
            // 3. 生成内容
            try generateContent()
            
            // 4. 压缩为PPTX文件
            try compressDirectory(tempDirectory, to: url)
            
            // 5. 清理临时文件
            try FileManager.default.removeItem(at: tempDirectory)
            
            return true
        } catch {
            print("PowerPoint导出错误: \(error)")
            
            // 清理临时文件
            if let dir = workingDirectory {
                try? FileManager.default.removeItem(at: dir)
            }
            
            return false
        }
    }
    
    // MARK: - 私有方法
    
    /// 创建PPTX文件结构
    private func createPPTXStructure() throws {
        guard let baseDir = workingDirectory else {
            throw PowerPointExportError.structureCreationFailed
        }
        
        // 创建基本目录结构
        let directories = [
            "ppt/slides",
            "ppt/slideLayouts",
            "ppt/slideMasters",
            "ppt/theme",
            "ppt/media",
            "ppt/_rels",
            "docProps",
            "_rels"
        ]
        
        for dir in directories {
            let dirURL = baseDir.appendingPathComponent(dir)
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }
        
        // 创建基本文件
        try createContentTypesXML()
        try createRelsFiles()
        try createPresentationXML()
        try createThemeFiles()
        try createDocPropsFiles()
    }
    
    /// 创建[Content_Types].xml文件
    private func createContentTypesXML() throws {
        guard let baseDir = workingDirectory else {
            throw PowerPointExportError.structureCreationFailed
        }
        
        let contentTypesXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Default Extension="png" ContentType="image/png"/>
            <Default Extension="jpeg" ContentType="image/jpeg"/>
            <Default Extension="jpg" ContentType="image/jpeg"/>
            <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
            <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
            <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
            <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
            <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
            <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
            <Override PartName="/ppt/slideLayouts/slideLayout2.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
        </Types>
        """
        
        let contentTypesURL = baseDir.appendingPathComponent("[Content_Types].xml")
        try contentTypesXML.write(to: contentTypesURL, atomically: true, encoding: .utf8)
    }
    
    /// 创建关系文件
    private func createRelsFiles() throws {
        guard let baseDir = workingDirectory else {
            throw PowerPointExportError.structureCreationFailed
        }
        
        // 根关系文件
        let rootRelsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
            <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
            <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """
        
        let rootRelsURL = baseDir.appendingPathComponent("_rels/.rels")
        try rootRelsXML.write(to: rootRelsURL, atomically: true, encoding: .utf8)
        
        // 演示文稿关系文件
        let presentationRelsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
            <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
        </Relationships>
        """
        
        let presentationRelsURL = baseDir.appendingPathComponent("ppt/_rels/presentation.xml.rels")
        try presentationRelsXML.write(to: presentationRelsURL, atomically: true, encoding: .utf8)
    }
    
    /// 创建演示文稿XML
    private func createPresentationXML() throws {
        guard let baseDir = workingDirectory else {
            throw PowerPointExportError.structureCreationFailed
        }
        
        // 根据幻灯片尺寸设置
        let cx = Int(options.slideSize.dimensions.width * 9525) // 英寸到EMU转换
        let cy = Int(options.slideSize.dimensions.height * 9525)
        
        let presentationXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:sldMasterIdLst>
            <p:sldMasterId id="2147483648" r:id="rId1"/>
          </p:sldMasterIdLst>
          <p:sldIdLst>
          </p:sldIdLst>
          <p:sldSz cx="\(cx)" cy="\(cy)"/>
          <p:notesSz cx="6858000" cy="9144000"/>
          <p:defaultTextStyle>
          </p:defaultTextStyle>
        </p:presentation>
        """
        
        let presentationURL = baseDir.appendingPathComponent("ppt/presentation.xml")
        try presentationXML.write(to: presentationURL, atomically: true, encoding: .utf8)
    }
    
    /// 创建主题文件
    private func createThemeFiles() throws {
        guard let baseDir = workingDirectory else {
            throw PowerPointExportError.structureCreationFailed
        }
        
        // 简化的主题文件
        let themeXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
          <a:themeElements>
            <a:clrScheme name="Office">
              <a:dk1>
                <a:sysClr val="windowText" lastClr="000000"/>
              </a:dk1>
              <a:lt1>
                <a:sysClr val="window" lastClr="FFFFFF"/>
              </a:lt1>
              <a:dk2>
                <a:srgbClr val="1F497D"/>
              </a:dk2>
              <a:lt2>
                <a:srgbClr val="EEECE1"/>
              </a:lt2>
              <a:accent1>
                <a:srgbClr val="4F81BD"/>
              </a:accent1>
              <a:accent2>
                <a:srgbClr val="C0504D"/>
              </a:accent2>
              <a:accent3>
                <a:srgbClr val="9BBB59"/>
              </a:accent3>
              <a:accent4>
                <a:srgbClr val="8064A2"/>
              </a:accent4>
              <a:accent5>
                <a:srgbClr val="4BACC6"/>
              </a:accent5>
              <a:accent6>
                <a:srgbClr val="F79646"/>
              </a:accent6>
              <a:hlink>
                <a:srgbClr val="0000FF"/>
              </a:hlink>
              <a:folHlink>
                <a:srgbClr val="800080"/>
              </a:folHlink>
            </a:clrScheme>
            <a:fontScheme name="Office">
              <a:majorFont>
                <a:latin typeface="Calibri Light"/>
                <a:ea typeface=""/>
                <a:cs typeface=""/>
              </a:majorFont>
              <a:minorFont>
                <a:latin typeface="Calibri"/>
                <a:ea typeface=""/>
                <a:cs typeface=""/>
              </a:minorFont>
            </a:fontScheme>
            <a:fmtScheme name="Office">
              <a:fillStyleLst>
                <a:solidFill>
                  <a:schemeClr val="phClr"/>
                </a:solidFill>
                <a:gradFill rotWithShape="1">
                  <a:gsLst>
                    <a:gs pos="0">
                      <a:schemeClr val="phClr">
                        <a:tint val="50000"/>
                        <a:satMod val="300000"/>
                      </a:schemeClr>
                    </a:gs>
                    <a:gs pos="35000">
                      <a:schemeClr val="phClr">
                        <a:tint val="37000"/>
                        <a:satMod val="300000"/>
                      </a:schemeClr>
                    </a:gs>
                    <a:gs pos="100000">
                      <a:schemeClr val="phClr">
                        <a:tint val="15000"/>
                        <a:satMod val="350000"/>
                      </a:schemeClr>
                    </a:gs>
                  </a:gsLst>
                  <a:lin ang="16200000" scaled="1"/>
                </a:gradFill>
              </a:fillStyleLst>
              <a:lnStyleLst>
                <a:ln w="9525" cap="flat" cmpd="sng" algn="ctr">
                  <a:solidFill>
                    <a:schemeClr val="phClr">
                      <a:shade val="95000"/>
                      <a:satMod val="105000"/>
                    </a:schemeClr>
                  </a:solidFill>
                  <a:prstDash val="solid"/>
                </a:ln>
              </a:lnStyleLst>
              <a:effectStyleLst>
                <a:effectStyle>
                  <a:effectLst>
                    <a:outerShdw blurRad="40000" dist="20000" dir="5400000" rotWithShape="0">
                      <a:srgbClr val="000000">
                        <a:alpha val="38000"/>
                      </a:srgbClr>
                    </a:outerShdw>
                  </a:effectLst>
                </a:effectStyle>
              </a:effectStyleLst>
              <a:bgFillStyleLst>
                <a:solidFill>
                  <a:schemeClr val="phClr"/>
                </a:solidFill>
              </a:bgFillStyleLst>
            </a:fmtScheme>
          </a:themeElements>
          <a:objectDefaults/>
          <a:extraClrSchemeLst/>
        </a:theme>
        """
        
        let themeURL = baseDir.appendingPathComponent("ppt/theme/theme1.xml")
        try themeXML.write(to: themeURL, atomically: true, encoding: .utf8)
    }
    
    /// 创建文档属性文件
    private func createDocPropsFiles() throws {
        guard let baseDir = workingDirectory else {
            throw PowerPointExportError.structureCreationFailed
        }
        
        // app.xml
        let appXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
          <Application>OnlySlide PowerPoint Exporter</Application>
          <AppVersion>1.0.0</AppVersion>
          <Slides>0</Slides>
          <Words>0</Words>
          <Paragraphs>0</Paragraphs>
        </Properties>
        """
        
        let appURL = baseDir.appendingPathComponent("docProps/app.xml")
        try appXML.write(to: appURL, atomically: true, encoding: .utf8)
        
        // core.xml
        let createdDate = ISO8601DateFormatter().string(from: Date())
        
        let coreXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <dc:title>\(result.title)</dc:title>
          <dc:creator>OnlySlide PowerPoint Exporter</dc:creator>
          <dcterms:created xsi:type="dcterms:W3CDTF">\(createdDate)</dcterms:created>
          <cp:lastModifiedBy>OnlySlide PowerPoint Exporter</cp:lastModifiedBy>
          <dcterms:modified xsi:type="dcterms:W3CDTF">\(createdDate)</dcterms:modified>
        </cp:coreProperties>
        """
        
        let coreURL = baseDir.appendingPathComponent("docProps/core.xml")
        try coreXML.write(to: coreURL, atomically: true, encoding: .utf8)
    }
    
    /// 生成内容
    private func generateContent() throws {
        // 生成幻灯片总数估计
        let totalSlides = estimateTotalSlides()
        
        // 更新presentationXML中的幻灯片列表
        try updatePresentationWithSlides(count: totalSlides)
        
        // 生成幻灯片
        if options.includeCoverSlide {
            try generateCoverSlide()
        }
        
        if options.includeTableOfContents {
            try generateTableOfContentsSlide()
        }
        
        // 生成内容幻灯片
        try generateContentSlides()
    }
    
    /// 估计总幻灯片数
    private func estimateTotalSlides() -> Int {
        var totalSlides = 0
        
        // 封面
        if options.includeCoverSlide {
            totalSlides += 1
        }
        
        // 目录
        if options.includeTableOfContents {
            totalSlides += 1
        }
        
        // 内容幻灯片（简单估算：每个章节至少一页，加上内容项数/每页最大项数）
        for section in result.sections {
            totalSlides += 1 // 标题幻灯片
            
            let contentItemsCount = section.contentItems.count
            totalSlides += (contentItemsCount / options.maxItemsPerSlide)
            if contentItemsCount % options.maxItemsPerSlide > 0 {
                totalSlides += 1
            }
        }
        
        return totalSlides
    }
    
    /// 更新presentation.xml中的幻灯片列表
    private func updatePresentationWithSlides(count: Int) throws {
        guard let baseDir = workingDirectory else {
            throw PowerPointExportError.structureCreationFailed
        }
        
        var slidesList = "<p:sldIdLst>\n"
        for i in 1...count {
            slidesList += "  <p:sldId id=\"\(256 + i)\" r:id=\"rId\(i + 2)\"/>\n"
        }
        slidesList += "</p:sldIdLst>"
        
        // 更新presentation.xml
        let presentationURL = baseDir.appendingPathComponent("ppt/presentation.xml")
        var presentationXML = try String(contentsOf: presentationURL)
        
        // 替换幻灯片列表
        let pattern = "<p:sldIdLst>.*?</p:sldIdLst>"
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(presentationXML.startIndex..<presentationXML.endIndex, in: presentationXML)
        presentationXML = regex.stringByReplacingMatches(in: presentationXML, options: [], range: range, withTemplate: slidesList)
        
        try presentationXML.write(to: presentationURL, atomically: true, encoding: .utf8)
        
        // 更新presentation.xml.rels
        let relsURL = baseDir.appendingPathComponent("ppt/_rels/presentation.xml.rels")
        var relsXML = try String(contentsOf: relsURL)
        
        // 添加幻灯片关系
        var slideRels = ""
        for i in 1...count {
            slideRels += "<Relationship Id=\"rId\(i + 2)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide\(i).xml\"/>\n"
        }
        
        // 替换或添加到关系文件
        if relsXML.contains("</Relationships>") {
            relsXML = relsXML.replacingOccurrences(of: "</Relationships>", with: slideRels + "</Relationships>")
        } else {
            relsXML += slideRels
        }
        
        try relsXML.write(to: relsURL, atomically: true, encoding: .utf8)
    }
    
    /// 生成封面幻灯片
    private func generateCoverSlide() throws {
        guard let baseDir = workingDirectory else {
            throw PowerPointExportError.slideGenerationFailed
        }
        
        // 封面幻灯片XML
        let slideXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld>
            <p:spTree>
              <p:nvGrpSpPr>
                <p:cNvPr id="1" name=""/>
                <p:cNvGrpSpPr/>
                <p:nvPr/>
              </p:nvGrpSpPr>
              <p:grpSpPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="0" cy="0"/>
                  <a:chOff x="0" y="0"/>
                  <a:chExt cx="0" cy="0"/>
                </a:xfrm>
              </p:grpSpPr>
              <p:sp>
                <p:nvSpPr>
                  <p:cNvPr id="2" name="Title"/>
                  <p:cNvSpPr>
                    <a:spLocks noGrp="1"/>
                  </p:cNvSpPr>
                  <p:nvPr>
                    <p:ph type="ctrTitle"/>
                  </p:nvPr>
                </p:nvSpPr>
                <p:spPr>
                  <a:xfrm>
                    <a:off x="685800" y="2130425"/>
                    <a:ext cx="7772400" cy="1470025"/>
                  </a:xfrm>
                </p:spPr>
                <p:txBody>
                  <a:bodyPr/>
                  <a:lstStyle/>
                  <a:p>
                    <a:r>
                      <a:rPr lang="en-US" dirty="0" smtClean="0"/>
                      <a:t>\(result.title)</a:t>
                    </a:r>
                    <a:endParaRPr lang="en-US" dirty="0"/>
                  </a:p>
                </p:txBody>
              </p:sp>
              <p:sp>
                <p:nvSpPr>
                  <p:cNvPr id="3" name="Subtitle"/>
                  <p:cNvSpPr>
                    <a:spLocks noGrp="1"/>
                  </p:cNvSpPr>
                  <p:nvPr>
                    <p:ph type="subTitle" idx="1"/>
                  </p:nvPr>
                </p:nvSpPr>
                <p:spPr>
                  <a:xfrm>
                    <a:off x="1371600" y="3886200"/>
                    <a:ext cx="6400800" cy="1752600"/>
                  </a:xfrm>
                </p:spPr>
                <p:txBody>
                  <a:bodyPr/>
                  <a:lstStyle/>
                  <a:p>
                    <a:r>
                      <a:rPr lang="en-US" dirty="0" smtClean="0"/>
                      <a:t>由 OnlySlide 分析引擎生成</a:t>
                    </a:r>
                    <a:endParaRPr lang="en-US" dirty="0"/>
                  </a:p>
                  <a:p>
                    <a:r>
                      <a:rPr lang="en-US" dirty="0" smtClean="0"/>
                      <a:t>文档类型: \(result.sourceType.displayName)</a:t>
                    </a:r>
                    <a:endParaRPr lang="en-US" dirty="0"/>
                  </a:p>
                </p:txBody>
              </p:sp>
            </p:spTree>
          </p:cSld>
          <p:clrMapOvr>
            <a:masterClrMapping/>
          </p:clrMapOvr>
        </p:sld>
        """
        
        // 保存幻灯片文件
        let slideURL = baseDir.appendingPathComponent("ppt/slides/slide1.xml")
        try slideXML.write(to: slideURL, atomically: true, encoding: .utf8)
        
        // 创建slide1.xml.rels
        let slideRelsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
        </Relationships>
        """
        
        let slideRelsURL = baseDir.appendingPathComponent("ppt/slides/_rels/slide1.xml.rels")
        try FileManager.default.createDirectory(at: slideRelsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try slideRelsXML.write(to: slideRelsURL, atomically: true, encoding: .utf8)
    }
    
    /// 生成目录幻灯片
    private func generateTableOfContentsSlide() throws {
        guard let baseDir = workingDirectory else {
            throw PowerPointExportError.slideGenerationFailed
        }
        
        let slideIndex = options.includeCoverSlide ? 2 : 1
        
        // 构建目录内容
        var tocContent = ""
        for (index, section) in result.sections.enumerated() {
            let indent = String(repeating: "  ", count: max(0, section.level - 1))
            tocContent += """
              <a:p>
                <a:pPr lvl="\(max(0, section.level - 1))"/>
                <a:r>
                  <a:rPr lang="en-US" dirty="0" smtClean="0"/>
                  <a:t>\(indent)\(section.title)</a:t>
                </a:r>
                <a:endParaRPr lang="en-US" dirty="0"/>
              </a:p>
            """
        }
        
        // 目录幻灯片XML
        let slideXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld>
            <p:spTree>
              <p:nvGrpSpPr>
                <p:cNvPr id="1" name=""/>
                <p:cNvGrpSpPr/>
                <p:nvPr/>
              </p:nvGrpSpPr>
              <p:grpSpPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="0" cy="0"/>
                  <a:chOff x="0" y="0"/>
                  <a:chExt cx="0" cy="0"/>
                </a:xfrm>
              </p:grpSpPr>
              <p:sp>
                <p:nvSpPr>
                  <p:cNvPr id="2" name="Title"/>
                  <p:cNvSpPr>
                    <a:spLocks noGrp="1"/>
                  </p:cNvSpPr>
                  <p:nvPr>
                    <p:ph type="title"/>
                  </p:nvPr>
                </p:nvSpPr>
                <p:spPr>
                  <a:xfrm>
                    <a:off x="685800" y="457200"/>
                    <a:ext cx="7772400" cy="1470025"/>
                  </a:xfrm>
                </p:spPr>
                <p:txBody>
                  <a:bodyPr/>
                  <a:lstStyle/>
                  <a:p>
                    <a:r>
                      <a:rPr lang="en-US" dirty="0" smtClean="0"/>
                      <a:t>目录</a:t>
                    </a:r>
                    <a:endParaRPr lang="en-US" dirty="0"/>
                  </a:p>
                </p:txBody>
              </p:sp>
              <p:sp>
                <p:nvSpPr>
                  <p:cNvPr id="3" name="Content"/>
                  <p:cNvSpPr>
                    <a:spLocks noGrp="1"/>
                  </p:cNvSpPr>
                  <p:nvPr>
                    <p:ph type="body" idx="1"/>
                  </p:nvPr>
                </p:nvSpPr>
                <p:spPr>
                  <a:xfrm>
                    <a:off x="1371600" y="1600200"/>
                    <a:ext cx="6400800" cy="4600800"/>
                  </a:xfrm>
                </p:spPr>
                <p:txBody>
                  <a:bodyPr/>
                  <a:lstStyle/>
                  \(tocContent)
                </p:txBody>
              </p:sp>
            </p:spTree>
          </p:cSld>
          <p:clrMapOvr>
            <a:masterClrMapping/>
          </p:clrMapOvr>
        </p:sld>
        """
        
        // 保存幻灯片文件
        let slideURL = baseDir.appendingPathComponent("ppt/slides/slide\(slideIndex).xml")
        try slideXML.write(to: slideURL, atomically: true, encoding: .utf8)
        
        // 创建slideX.xml.rels
        let slideRelsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout2.xml"/>
        </Relationships>
        """
        
        let slideRelsURL = baseDir.appendingPathComponent("ppt/slides/_rels/slide\(slideIndex).xml.rels")
        try FileManager.default.createDirectory(at: slideRelsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try slideRelsXML.write(to: slideRelsURL, atomically: true, encoding: .utf8)
    }
    
    /// 生成内容幻灯片
    private func generateContentSlides() throws {
        // 这里应实现详细的内容幻灯片生成逻辑
        // 暂时留空作为示例框架
    }
    
    /// 压缩目录为PPTX文件
    private func compressDirectory(_ directory: URL, to destinationURL: URL) throws {
        // 如果目标文件已存在，先删除
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // 使用ZIPFoundation创建ZIP文件
        let fileManager = FileManager()
        try fileManager.zipItem(at: directory, to: destinationURL)
    }
}

// MARK: - DocumentAnalysisResult扩展

extension DocumentAnalysisResult {
    /// 导出为PowerPoint文件
    /// - Parameters:
    ///   - url: 文件URL
    ///   - options: 导出选项
    /// - Returns: 是否成功
    public func exportToPowerPoint(url: URL, options: PowerPointExportOptions = PowerPointExportOptions()) -> Bool {
        let exporter = PowerPointExporter(result: self, options: options)
        return exporter.exportToPowerPoint(url: url)
    }
} 