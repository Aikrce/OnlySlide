import XCTest
import CoreData
@testable import Core

class DocumentMetadataTests: XCTestCase {
    // MARK: - Properties
    
    private var testMetadata: DocumentMetadata!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // 创建测试元数据
        testMetadata = DocumentMetadata(
            tags: ["测试", "文档", "元数据"],
            documentDescription: "这是一个测试文档",
            lastViewedAt: Date(),
            customProperties: [
                "priority": 1,
                "status": "draft",
                "isArchived": false
            ]
        )
    }
    
    override func tearDown() {
        testMetadata = nil
        super.tearDown()
    }
    
    // MARK: - Codable Tests
    
    func testEncodeDecode() throws {
        // 编码为 JSON 数据
        let encoder = JSONEncoder()
        let data = try encoder.encode(testMetadata)
        
        // 解码 JSON 数据
        let decoder = JSONDecoder()
        let decodedMetadata = try decoder.decode(DocumentMetadata.self, from: data)
        
        // 验证解码结果
        XCTAssertEqual(decodedMetadata.tags, testMetadata.tags)
        XCTAssertEqual(decodedMetadata.documentDescription, testMetadata.documentDescription)
        
        // 验证日期（注意：JSON编码可能导致精度损失，因此使用接近比较）
        if let originalDate = testMetadata.lastViewedAt, let decodedDate = decodedMetadata.lastViewedAt {
            XCTAssertEqual(
                Int(originalDate.timeIntervalSince1970),
                Int(decodedDate.timeIntervalSince1970),
                "日期应该大致相同"
            )
        } else {
            XCTFail("lastViewedAt 日期应该存在")
        }
        
        // 注意：customProperties 在 Codable 实现中被忽略了，所以这里不验证
    }
    
    func testDecodeMissingFields() throws {
        // 创建只包含部分字段的 JSON
        let partialJSON = """
        {
            "tags": ["部分", "数据"]
        }
        """.data(using: .utf8)!
        
        // 解码 JSON 数据
        let decoder = JSONDecoder()
        let decodedMetadata = try decoder.decode(DocumentMetadata.self, from: partialJSON)
        
        // 验证解码结果
        XCTAssertEqual(decodedMetadata.tags, ["部分", "数据"])
        XCTAssertNil(decodedMetadata.documentDescription)
        XCTAssertNil(decodedMetadata.lastViewedAt)
        XCTAssertEqual(decodedMetadata.customProperties.count, 0)
    }
    
    // MARK: - NSSecureCoding Tests
    
    func testSecureCoding() {
        // 验证是否支持安全编码
        XCTAssertTrue(DocumentMetadata.supportsSecureCoding)
        
        // 创建归档
        let archiver = NSKeyedArchiver.archiveRootObject(
            testMetadata,
            toSecurelyEncodedData: DocumentMetadata.supportsSecureCoding
        )
        
        // 解档
        let unarchivedMetadata = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: DocumentMetadata.self,
            from: archiver
        )
        
        // 验证解档结果
        XCTAssertNotNil(unarchivedMetadata)
        
        if let unarchivedMetadata = unarchivedMetadata {
            // 验证基本属性
            XCTAssertEqual(unarchivedMetadata.tags, testMetadata.tags)
            XCTAssertEqual(unarchivedMetadata.documentDescription, testMetadata.documentDescription)
            
            // 验证日期
            if let originalDate = testMetadata.lastViewedAt, let unarchivedDate = unarchivedMetadata.lastViewedAt {
                XCTAssertEqual(
                    Int(originalDate.timeIntervalSince1970),
                    Int(unarchivedDate.timeIntervalSince1970),
                    "日期应该大致相同"
                )
            } else {
                XCTFail("lastViewedAt 日期应该存在")
            }
            
            // 验证自定义属性
            XCTAssertEqual(unarchivedMetadata.customProperties.count, testMetadata.customProperties.count)
            
            // 验证单个自定义属性
            XCTAssertEqual(unarchivedMetadata.customProperties["priority"] as? Int, 1)
            XCTAssertEqual(unarchivedMetadata.customProperties["status"] as? String, "draft")
            XCTAssertEqual(unarchivedMetadata.customProperties["isArchived"] as? Bool, false)
        }
    }
    
    func testSecureCodingEmptyValues() {
        // 创建空值元数据
        let emptyMetadata = DocumentMetadata()
        
        // 创建归档
        let archiver = NSKeyedArchiver.archiveRootObject(
            emptyMetadata,
            toSecurelyEncodedData: DocumentMetadata.supportsSecureCoding
        )
        
        // 解档
        let unarchivedMetadata = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: DocumentMetadata.self,
            from: archiver
        )
        
        // 验证解档结果
        XCTAssertNotNil(unarchivedMetadata)
        
        if let unarchivedMetadata = unarchivedMetadata {
            // 验证基本属性
            XCTAssertEqual(unarchivedMetadata.tags.count, 0)
            XCTAssertNil(unarchivedMetadata.documentDescription)
            XCTAssertNil(unarchivedMetadata.lastViewedAt)
            XCTAssertEqual(unarchivedMetadata.customProperties.count, 0)
        }
    }
    
    // MARK: - Description Tests
    
    func testDescription() {
        // 获取描述字符串
        let description = testMetadata.description
        
        // 验证描述包含关键信息
        XCTAssertTrue(description.contains("测试"))
        XCTAssertTrue(description.contains("文档"))
        XCTAssertTrue(description.contains("元数据"))
        XCTAssertTrue(description.contains("这是一个测试文档"))
        XCTAssertTrue(description.contains("priority"))
        XCTAssertTrue(description.contains("status"))
        XCTAssertTrue(description.contains("isArchived"))
    }
    
    // MARK: - Performance Tests
    
    func testEncodingPerformance() {
        // 测试编码性能
        measure {
            // 创建大量标签的元数据
            var largeTags: [String] = []
            for i in 0..<1000 {
                largeTags.append("标签\(i)")
            }
            
            let largeMetadata = DocumentMetadata(
                tags: largeTags,
                documentDescription: "大量数据测试",
                lastViewedAt: Date()
            )
            
            // 执行编码
            let encoder = JSONEncoder()
            do {
                _ = try encoder.encode(largeMetadata)
            } catch {
                XCTFail("编码失败: \(error)")
            }
        }
    }
    
    func testSecureCodingPerformance() {
        // 测试NSSecureCoding性能
        measure {
            // 创建大量自定义属性的元数据
            var largeCustomProperties: [String: Any] = [:]
            for i in 0..<1000 {
                largeCustomProperties["属性\(i)"] = "值\(i)"
            }
            
            let largeMetadata = DocumentMetadata(
                tags: ["性能测试"],
                documentDescription: "安全编码性能测试",
                lastViewedAt: Date(),
                customProperties: largeCustomProperties
            )
            
            // 执行安全编码
            _ = NSKeyedArchiver.archiveRootObject(
                largeMetadata,
                toSecurelyEncodedData: DocumentMetadata.supportsSecureCoding
            )
        }
    }
} 