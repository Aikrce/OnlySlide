import XCTest
@testable import CoreDataModule

/// 测试ModelVersion结构体的功能
class ModelVersionTests: XCTestCase {
    
    // MARK: - Tests
    
    /// 测试从版本字符串创建ModelVersion
    func testInitWithVersionString() {
        // 测试有效的版本字符串
        let version1 = ModelVersion(versionString: "V1_0_0")
        XCTAssertNotNil(version1, "应该能从有效版本字符串创建ModelVersion")
        XCTAssertEqual(version1?.major, 1, "主版本号应该正确")
        XCTAssertEqual(version1?.minor, 0, "次版本号应该正确")
        XCTAssertEqual(version1?.patch, 0, "修订号应该正确")
        XCTAssertEqual(version1?.identifier, "V1_0_0", "标识符应该正确")
        
        // 测试部分版本号
        let version2 = ModelVersion(versionString: "V2_3")
        XCTAssertNotNil(version2, "应该能从有效部分版本字符串创建ModelVersion")
        XCTAssertEqual(version2?.major, 2, "主版本号应该正确")
        XCTAssertEqual(version2?.minor, 3, "次版本号应该正确")
        XCTAssertEqual(version2?.patch, 0, "修订号应该默认为0")
        
        // 测试无效的版本字符串
        let invalidVersion = ModelVersion(versionString: "Invalid")
        XCTAssertNil(invalidVersion, "无效版本字符串应该返回nil")
    }
    
    /// 测试从版本标识符集合创建ModelVersion
    func testInitWithVersionIdentifiers() {
        // 测试有效的版本标识符集合
        let identifiers = Set(["V1_0_0", "OtherIdentifier"])
        let version = ModelVersion(versionIdentifiers: identifiers)
        XCTAssertNotNil(version, "应该能从有效版本标识符创建ModelVersion")
        XCTAssertEqual(version?.major, 1, "主版本号应该正确")
        
        // 测试空集合
        let emptyVersion = ModelVersion(versionIdentifiers: Set<String>())
        XCTAssertNil(emptyVersion, "空标识符集合应该返回nil")
        
        // 测试无效标识符集合
        let invalidIdentifiers = Set(["Invalid", "AlsoInvalid"])
        let invalidVersion = ModelVersion(versionIdentifiers: invalidIdentifiers)
        XCTAssertNil(invalidVersion, "无有效版本标识符的集合应该返回nil")
    }
    
    /// 测试从AnyHashable集合创建ModelVersion
    func testInitWithAnyHashableVersionIdentifiers() {
        // 测试有效的AnyHashable版本标识符集合
        let identifiers: Set<AnyHashable> = ["V2_1_0", "OtherIdentifier"]
        let version = ModelVersion(versionIdentifiers: identifiers)
        XCTAssertNotNil(version, "应该能从有效AnyHashable版本标识符创建ModelVersion")
        XCTAssertEqual(version?.major, 2, "主版本号应该正确")
        XCTAssertEqual(version?.minor, 1, "次版本号应该正确")
        
        // 测试空集合
        let emptyVersion = ModelVersion(versionIdentifiers: Set<AnyHashable>())
        XCTAssertNil(emptyVersion, "空AnyHashable标识符集合应该返回nil")
        
        // 测试包含非字符串的AnyHashable集合
        let mixedIdentifiers: Set<AnyHashable> = [123, "V3_0_0"]
        let mixedVersion = ModelVersion(versionIdentifiers: mixedIdentifiers)
        XCTAssertNotNil(mixedVersion, "包含有效版本标识符的混合集合应该返回正确的ModelVersion")
        XCTAssertEqual(mixedVersion?.major, 3, "主版本号应该正确")
    }
    
    /// 测试版本比较
    func testVersionComparison() {
        let v1_0_0 = ModelVersion(versionString: "V1_0_0")!
        let v1_1_0 = ModelVersion(versionString: "V1_1_0")!
        let v1_0_1 = ModelVersion(versionString: "V1_0_1")!
        let v2_0_0 = ModelVersion(versionString: "V2_0_0")!
        
        XCTAssertLessThan(v1_0_0, v1_1_0, "V1_0_0 应该小于 V1_1_0")
        XCTAssertLessThan(v1_0_0, v1_0_1, "V1_0_0 应该小于 V1_0_1")
        XCTAssertLessThan(v1_1_0, v2_0_0, "V1_1_0 应该小于 V2_0_0")
        XCTAssertGreaterThan(v2_0_0, v1_0_0, "V2_0_0 应该大于 V1_0_0")
        
        // 测试排序
        let unsortedVersions = [v2_0_0, v1_0_0, v1_1_0, v1_0_1]
        let sortedVersions = unsortedVersions.sorted()
        
        XCTAssertEqual(sortedVersions[0].description, "v1.0.0", "排序后第一个应该是V1_0_0")
        XCTAssertEqual(sortedVersions[1].description, "v1.0.1", "排序后第二个应该是V1_0_1")
        XCTAssertEqual(sortedVersions[2].description, "v1.1.0", "排序后第三个应该是V1_1_0")
        XCTAssertEqual(sortedVersions[3].description, "v2.0.0", "排序后第四个应该是V2_0_0")
    }
    
    /// 测试版本序列生成
    func testVersionSequence() {
        let v1_0_0 = ModelVersion(versionString: "V1_0_0")!
        let v3_2_0 = ModelVersion(versionString: "V3_2_0")!
        
        // 获取从v1.0.0到v3.2.0的序列
        let sequence = ModelVersion.sequence(from: v1_0_0, to: v3_2_0)
        
        // 验证序列
        XCTAssertFalse(sequence.isEmpty, "版本序列不应该为空")
        XCTAssertTrue(sequence.contains(where: { $0.major == 2 && $0.minor == 0 }), "序列应该包含V2_0_0")
        XCTAssertTrue(sequence.contains(where: { $0.major == 3 && $0.minor == 0 }), "序列应该包含V3_0_0")
        XCTAssertTrue(sequence.contains(where: { $0.major == 3 && $0.minor == 1 }), "序列应该包含V3_1_0")
        XCTAssertTrue(sequence.contains(where: { $0.major == 3 && $0.minor == 2 }), "序列应该包含V3_2_0")
        
        // 测试相同版本
        let sameVersionSequence = ModelVersion.sequence(from: v1_0_0, to: v1_0_0)
        XCTAssertTrue(sameVersionSequence.isEmpty, "相同版本的序列应该为空")
        
        // 测试降级序列
        let downgradeSequence = ModelVersion.sequence(from: v3_2_0, to: v1_0_0)
        XCTAssertTrue(downgradeSequence.isEmpty, "降级版本的序列应该为空")
    }
    
    /// 测试版本描述
    func testVersionDescription() {
        let v2_3_1 = ModelVersion(versionString: "V2_3_1")!
        XCTAssertEqual(v2_3_1.description, "v2.3.1", "版本描述应该格式正确")
    }
} 