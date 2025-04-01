import XCTest
@testable import DocumentAnalysis

final class PowerPointExporterTests: XCTestCase {
    
    // 测试文档分析结果
    var testResult: DocumentAnalysisResult!
    
    // 临时目录URL
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // 创建测试数据
        testResult = Self.createTestDocumentAnalysisResult()
        
        // 创建临时目录
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // 清理临时目录
        try? FileManager.default.removeItem(at: tempDirectory)
        
        super.tearDown()
    }
    
    /// 测试创建PowerPoint导出器
    func testCreateExporter() {
        // 使用默认选项创建导出器
        let options = PowerPointExportOptions()
        let exporter = PowerPointExporterImpl(result: testResult, options: options)
        
        // 验证导出器属性
        XCTAssertEqual(exporter.result.title, testResult.title)
        XCTAssertEqual(exporter.options.slideSize, options.slideSize)
    }
    
    /// 测试导出数据
    func testExportToData() {
        // 创建导出器
        let exporter = PowerPointExporterImpl(result: testResult, options: PowerPointExportOptions())
        
        // 尝试导出到数据
        do {
            let data = try exporter.exportToData()
            XCTAssertFalse(data.isEmpty, "导出的数据不应为空")
        } catch {
            XCTFail("导出过程中出现错误: \(error)")
        }
    }
    
    /// 测试导出到文件
    func testExportToFile() {
        // 创建导出器
        let exporter = PowerPointExporterImpl(result: testResult, options: PowerPointExportOptions())
        
        // 准备目标文件
        let targetURL = tempDirectory.appendingPathComponent("test_export.pptx")
        
        // 尝试导出到文件
        do {
            let success = try exporter.export(to: targetURL)
            XCTAssertTrue(success, "导出应该成功")
            XCTAssertTrue(FileManager.default.fileExists(atPath: targetURL.path), "导出文件应存在")
        } catch {
            XCTFail("导出过程中出现错误: \(error)")
        }
    }
    
    /// 测试导出选项符合协议
    func testExportOptionsProtocol() {
        let options = PowerPointExportOptions()
        
        // 测试默认选项静态方法
        let defaultOptions = PowerPointExportOptions.defaultOptions()
        XCTAssertEqual(defaultOptions.slideSize, options.slideSize)
        
        // 测试内容类型
        XCTAssertEqual(options.contentType, UTType.data)
        
        // 测试文件扩展名
        XCTAssertEqual(options.fileExtension, "pptx")
    }
    
    /// 测试错误处理
    func testErrorHandling() {
        // 创建导出器
        let exporter = PowerPointExporterImpl(result: testResult, options: PowerPointExportOptions())
        
        // 准备一个无效的URL（无写入权限的路径）
        let invalidURL = URL(fileURLWithPath: "/invalid/path/test.pptx")
        
        // 尝试导出到无效URL，应抛出错误
        XCTAssertThrowsError(try exporter.export(to: invalidURL)) { error in
            XCTAssertTrue(error is DocumentExportError, "应抛出DocumentExportError")
        }
    }
    
    // MARK: - 辅助方法
    
    /// 创建测试用的文档分析结果
    static func createTestDocumentAnalysisResult() -> DocumentAnalysisResult {
        // 创建内容项
        let contentItems: [ContentItem] = [
            ContentItem(type: .paragraph, text: "这是第一段", level: 0),
            ContentItem(type: .paragraph, text: "这是第二段", level: 0),
            ContentItem(type: .listItem, text: "这是列表项1", level: 0),
            ContentItem(type: .listItem, text: "这是列表项2", level: 0)
        ]
        
        // 创建分析结果
        return DocumentAnalysisResult(
            title: "测试文档",
            content: contentItems,
            metadata: [
                "作者": "测试用户",
                "日期": "2023-05-01"
            ]
        )
    }
} 