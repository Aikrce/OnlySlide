import XCTest
@testable import CoreDataModule

/// ModelVersion独立测试
/// 不依赖于项目中的其他模块，避免并发安全性问题
class ModelVersionStandaloneTest: XCTestCase {
    
    // MARK: - Tests
    
    /// 测试ModelVersion的初始化和比较功能
    func testModelVersionBasics() {
        // 创建版本
        let v1_0_0 = ModelVersion(versionString: "V1_0_0")!
        let v1_0_1 = ModelVersion(versionString: "V1_0_1")!
        let v1_1_0 = ModelVersion(versionString: "V1_1_0")!
        let v2_0_0 = ModelVersion(versionString: "V2_0_0")!
        
        // 测试属性
        XCTAssertEqual(v1_0_0.major, 1)
        XCTAssertEqual(v1_0_0.minor, 0)
        XCTAssertEqual(v1_0_0.patch, 0)
        XCTAssertEqual(v1_0_0.identifier, "V1_0_0")
        XCTAssertEqual(v1_0_0.description, "v1.0.0")
        
        // 测试比较
        XCTAssertLessThan(v1_0_0, v1_0_1)
        XCTAssertLessThan(v1_0_1, v1_1_0)
        XCTAssertLessThan(v1_1_0, v2_0_0)
        
        // 测试排序
        let versions = [v2_0_0, v1_0_0, v1_1_0, v1_0_1].sorted()
        XCTAssertEqual(versions, [v1_0_0, v1_0_1, v1_1_0, v2_0_0])
    }
    
    /// 测试从集合初始化ModelVersion
    func testModelVersionFromIdentifiers() {
        // 字符串集合
        let stringSet: Set<String> = ["V1_0_0", "OtherIdentifier"]
        let version1 = ModelVersion(versionIdentifiers: stringSet)
        XCTAssertNotNil(version1)
        XCTAssertEqual(version1?.identifier, "V1_0_0")
        
        // 混合类型集合
        let mixedSet: Set<AnyHashable> = ["V2_0_0", 123, true]
        let version2 = ModelVersion(versionIdentifiers: mixedSet)
        XCTAssertNotNil(version2)
        XCTAssertEqual(version2?.identifier, "V2_0_0")
        
        // 无效集合
        let invalidSet: Set<String> = ["Invalid", "NoVersion"]
        let invalidVersion = ModelVersion(versionIdentifiers: invalidSet)
        XCTAssertNil(invalidVersion)
    }
    
    /// 测试ModelVersion序列生成
    func testModelVersionSequence() {
        let v1_0_0 = ModelVersion(versionString: "V1_0_0")!
        let v3_0_0 = ModelVersion(versionString: "V3_0_0")!
        
        let sequence = ModelVersion.sequence(from: v1_0_0, to: v3_0_0)
        
        // 验证序列内容
        XCTAssertEqual(sequence.count, 3)
        XCTAssertEqual(sequence[0].identifier, "V1_99_0")
        XCTAssertEqual(sequence[1].identifier, "V2_0_0")
        XCTAssertEqual(sequence[2].identifier, "V3_0_0")
        
        // 测试边界情况
        let emptySequence = ModelVersion.sequence(from: v3_0_0, to: v1_0_0)
        XCTAssertTrue(emptySequence.isEmpty)
        
        let sameVersionSequence = ModelVersion.sequence(from: v1_0_0, to: v1_0_0)
        XCTAssertTrue(sameVersionSequence.isEmpty)
    }
    
    /// 测试从URL创建ModelVersion
    func testModelVersionFromURL() {
        // 创建测试URL
        let url1 = URL(fileURLWithPath: "/path/to/ModelV1_0_0.mom")
        let url2 = URL(fileURLWithPath: "/path/to/Model_V2_3_1.xcdatamodeld")
        
        // 测试从URL提取版本
        let version1 = ModelVersion.from(url: url1)
        XCTAssertNotNil(version1)
        XCTAssertEqual(version1?.identifier, "V1_0_0")
        
        let version2 = ModelVersion.from(url: url2)
        XCTAssertNotNil(version2)
        XCTAssertEqual(version2?.identifier, "V2_3_1")
        
        // 测试无效URL
        let invalidURL = URL(fileURLWithPath: "/path/to/ModelNoVersion.mom")
        let invalidVersion = ModelVersion.from(url: invalidURL)
        XCTAssertNil(invalidVersion)
    }
    
    /// 测试ModelVersionDefinition基本功能
    func testModelVersionDefinition() {
        let v1 = ModelVersion(versionString: "V1_0_0")!
        
        // 创建不带映射块的定义
        let def1 = ModelVersionDefinition(version: v1)
        XCTAssertEqual(def1.version.identifier, "V1_0_0")
        XCTAssertNil(def1.mappingBlock)
        
        // 创建带映射块的定义
        var mappingBlockCalled = false
        let def2 = ModelVersionDefinition(version: v1) { _ in
            mappingBlockCalled = true
        }
        
        XCTAssertEqual(def2.version.identifier, "V1_0_0")
        XCTAssertNotNil(def2.mappingBlock)
        
        // 执行映射块
        def2.mappingBlock?(NSMappingModel())
        XCTAssertTrue(mappingBlockCalled)
    }
    
    /// 测试ModelVersionDefinitionRegistry基本功能
    func testModelVersionDefinitionRegistry() {
        let registry = ModelVersionDefinitionRegistry()
        
        // 注册版本
        let v1 = ModelVersion(versionString: "V1_0_0")!
        let v2 = ModelVersion(versionString: "V2_0_0")!
        let v3 = ModelVersion(versionString: "V3_0_0")!
        
        registry.register(version: v1)
        registry.register(version: v2)
        registry.register(version: v3)
        
        // 测试定义数量
        XCTAssertEqual(registry.definitions.count, 3)
        
        // 测试排序
        let sorted = registry.sortedDefinitions()
        XCTAssertEqual(sorted[0].version.identifier, "V1_0_0")
        XCTAssertEqual(sorted[1].version.identifier, "V2_0_0")
        XCTAssertEqual(sorted[2].version.identifier, "V3_0_0")
        
        // 测试获取最新版本
        XCTAssertEqual(registry.latestVersion().identifier, "V3_0_0")
    }
    
    /// 测试迁移路径生成
    func testMigrationPath() {
        let registry = ModelVersionDefinitionRegistry()
        
        // 注册版本
        let v1 = ModelVersion(versionString: "V1_0_0")!
        let v2 = ModelVersion(versionString: "V2_0_0")!
        let v3 = ModelVersion(versionString: "V3_0_0")!
        
        // 添加映射块
        var mappingBlockCalls: [String] = []
        
        registry.register(version: v1)
        registry.register(version: v2) { _ in
            mappingBlockCalls.append("V1_to_V2")
        }
        registry.register(version: v3) { _ in
            mappingBlockCalls.append("V2_to_V3")
        }
        
        // 获取迁移路径
        let path = registry.migrationPath(from: v1, to: v3)
        
        // 验证路径
        XCTAssertEqual(path.count, 2)
        XCTAssertEqual(path[0].sourceVersion.identifier, "V1_0_0")
        XCTAssertEqual(path[0].destinationVersion.identifier, "V2_0_0")
        XCTAssertEqual(path[1].sourceVersion.identifier, "V2_0_0")
        XCTAssertEqual(path[1].destinationVersion.identifier, "V3_0_0")
        
        // 验证映射块
        XCTAssertNotNil(path[0].mappingBlock)
        XCTAssertNotNil(path[1].mappingBlock)
        
        // 调用映射块
        path[0].mappingBlock?(NSMappingModel())
        path[1].mappingBlock?(NSMappingModel())
        
        XCTAssertEqual(mappingBlockCalls, ["V1_to_V2", "V2_to_V3"])
    }
    
    /// 测试当前版本和迁移需求判断
    func testCurrentVersionAndMigrationRequirement() {
        let registry = ModelVersionDefinitionRegistry()
        
        // 注册版本
        let v1 = ModelVersion(versionString: "V1_0_0")!
        let v2 = ModelVersion(versionString: "V2_0_0")!
        
        registry.register(version: v1)
        registry.register(version: v2)
        
        // 初始状态，未设置当前版本
        XCTAssertNil(registry.currentVersion())
        XCTAssertTrue(registry.requiresMigration())
        
        // 设置当前版本为V1
        registry.setCurrentVersion(v1)
        XCTAssertEqual(registry.currentVersion()?.identifier, "V1_0_0")
        XCTAssertTrue(registry.requiresMigration())
        
        // 设置当前版本为最新版本
        registry.setCurrentVersion(v2)
        XCTAssertEqual(registry.currentVersion()?.identifier, "V2_0_0")
        XCTAssertFalse(registry.requiresMigration())
    }
} 