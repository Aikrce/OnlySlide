import XCTest
@testable import DocumentAnalysis

final class TextAnalysisTests: XCTestCase {
    
    var strategy: TextAnalysisStrategy!
    
    override func setUp() {
        super.setUp()
        strategy = TextAnalysisStrategy()
    }
    
    override func tearDown() {
        strategy = nil
        super.tearDown()
    }
    
    func testSupportedTypes() throws {
        let supportedTypes = strategy.supportedTypes()
        XCTAssertFalse(supportedTypes.isEmpty)
        XCTAssertTrue(supportedTypes.contains(.plainText))
    }
    
    func testAnalyzeSimpleText() async throws {
        // 简单的文本示例
        let text = """
        这是一个测试文档
        
        这是正文第一段。这是一个简单的测试，用于验证文本分析功能是否正常工作。
        
        这是正文第二段，包含更多的内容和信息。
        """
        
        let data = text.data(using: .utf8)!
        let result = try await strategy.analyze(content: data, filename: "test.txt")
        
        // 验证分析结果
        XCTAssertEqual(result.title, "test")
        XCTAssertEqual(result.sourceType, .text)
        XCTAssertFalse(result.sections.isEmpty)
        
        // 应该至少有一个部分
        XCTAssertGreaterThanOrEqual(result.sections.count, 1)
        
        // 第一个部分应该有内容
        let firstSection = result.sections.first!
        XCTAssertFalse(firstSection.contentItems.isEmpty)
    }
    
    func testAnalyzeWithTitles() async throws {
        // 带有标题的文本示例
        let text = """
        # 主标题
        
        这是主标题下的内容。
        
        ## 二级标题1
        
        这是二级标题1下的内容。
        
        ## 二级标题2
        
        这是二级标题2下的内容。
        
        ### 三级标题
        
        这是三级标题下的内容。
        """
        
        let data = text.data(using: .utf8)!
        let result = try await strategy.analyze(content: data, filename: "test.txt")
        
        // 验证标题结构
        XCTAssertEqual(result.title, "test")
        
        // 应该有4个部分：主标题、二级标题1、二级标题2、三级标题
        XCTAssertEqual(result.sections.count, 4)
        
        // 验证标题级别
        XCTAssertEqual(result.sections[0].title, "主标题")
        XCTAssertEqual(result.sections[0].level, 1)
        
        XCTAssertEqual(result.sections[1].title, "二级标题1")
        XCTAssertEqual(result.sections[1].level, 2)
        
        XCTAssertEqual(result.sections[2].title, "二级标题2")
        XCTAssertEqual(result.sections[2].level, 2)
        
        XCTAssertEqual(result.sections[3].title, "三级标题")
        XCTAssertEqual(result.sections[3].level, 3)
    }
    
    func testAnalyzeWithListItems() async throws {
        // 带有列表项的文本示例
        let text = """
        # 测试列表
        
        以下是一些列表项：
        
        - 第一个列表项
        - 第二个列表项
        - 第三个列表项
        
        编号列表：
        
        1. 第一步
        2. 第二步
        3. 第三步
        """
        
        let data = text.data(using: .utf8)!
        let result = try await strategy.analyze(content: data, filename: "test.txt")
        
        // 验证列表项
        XCTAssertEqual(result.sections.count, 1)
        let section = result.sections[0]
        
        // 找出所有列表项
        let listItems = section.contentItems.filter { $0.type == .listItem }
        
        // 应该有6个列表项
        XCTAssertEqual(listItems.count, 6)
        
        // 验证列表项内容
        let listItemTexts = listItems.map { $0.text }
        XCTAssertTrue(listItemTexts.contains("第一个列表项"))
        XCTAssertTrue(listItemTexts.contains("第二个列表项"))
        XCTAssertTrue(listItemTexts.contains("第三个列表项"))
        XCTAssertTrue(listItemTexts.contains("第一步"))
        XCTAssertTrue(listItemTexts.contains("第二步"))
        XCTAssertTrue(listItemTexts.contains("第三步"))
    }
} 