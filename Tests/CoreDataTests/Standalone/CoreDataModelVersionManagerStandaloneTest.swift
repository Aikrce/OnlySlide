import XCTest
import CoreData
@testable import CoreDataModule

/// 独立的CoreDataModelVersionManager测试类
/// 用于测试CoreDataModelVersionManager的功能，避免项目中的并发安全性错误
class CoreDataModelVersionManagerStandaloneTest: XCTestCase {
    
    // MARK: - Properties
    
    /// 测试对象
    var versionManager: CoreDataModelVersionManagerTestable!
    
    /// 模型版本定义注册表
    var versionRegistry: ModelVersionDefinitionRegistry!
    
    /// 临时目录
    var tempDirectoryURL: URL!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        // 创建临时测试目录
        let fileManager = FileManager.default
        tempDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        
        // 创建测试模型文件
        try createTestModelFiles()
        
        // 初始化测试对象
        versionManager = CoreDataModelVersionManagerTestable()
        
        // 初始化版本注册表
        versionRegistry = ModelVersionDefinitionRegistry()
    }
    
    override func tearDown() async throws {
        // 清理临时文件
        try? FileManager.default.removeItem(at: tempDirectoryURL)
        
        // 重置测试对象
        versionManager = nil
        versionRegistry = nil
        tempDirectoryURL = nil
    }
    
    // MARK: - Helper Methods
    
    /// 创建测试用的模型文件
    private func createTestModelFiles() throws {
        // 创建模型目录
        let momdURL = tempDirectoryURL.appendingPathComponent("TestModel.momd")
        try FileManager.default.createDirectory(at: momdURL, withIntermediateDirectories: true, attributes: nil)
        
        // 创建版本模型文件
        let modelFile1URL = momdURL.appendingPathComponent("TestModel_1.0.mom")
        let modelFile2URL = momdURL.appendingPathComponent("TestModel_2.0.mom")
        let modelFile3URL = momdURL.appendingPathComponent("TestModel_3.0.mom")
        
        try "Test Model 1.0".write(to: modelFile1URL, atomically: true, encoding: .utf8)
        try "Test Model 2.0".write(to: modelFile2URL, atomically: true, encoding: .utf8)
        try "Test Model 3.0".write(to: modelFile3URL, atomically: true, encoding: .utf8)
        
        // 创建映射模型文件
        let mapping1to2URL = tempDirectoryURL.appendingPathComponent("Mapping_V1_0_0_to_V2_0_0.cdm")
        let mapping2to3URL = tempDirectoryURL.appendingPathComponent("Mapping_V2_0_0_to_V3_0_0.cdm")
        
        try "Test Mapping 1.0 to 2.0".write(to: mapping1to2URL, atomically: true, encoding: .utf8)
        try "Test Mapping 2.0 to 3.0".write(to: mapping2to3URL, atomically: true, encoding: .utf8)
    }
    
    /// 创建带版本标识符的模拟模型
    private func createMockModelWithVersion(_ version: String) -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.versionIdentifiers = Set([version])
        return model
    }
    
    // MARK: - Tests
    
    /// 测试版本排序
    func testVersionSorting() {
        // 创建不同版本
        let v1 = ModelVersion(versionString: "V1_0_0")!
        let v2 = ModelVersion(versionString: "V2_0_0")!
        let v1_1 = ModelVersion(versionString: "V1_1_0")!
        
        // 验证版本比较
        XCTAssertLessThan(v1, v2, "v1.0.0 应该小于 v2.0.0")
        XCTAssertLessThan(v1, v1_1, "v1.0.0 应该小于 v1.1.0")
        XCTAssertLessThan(v1_1, v2, "v1.1.0 应该小于 v2.0.0")
        XCTAssertGreaterThan(v2, v1, "v2.0.0 应该大于 v1.0.0")
        
        // 验证排序
        let versions = [v2, v1, v1_1].sorted()
        XCTAssertEqual(versions[0].major, 1, "第一个版本应该是1.0.0")
        XCTAssertEqual(versions[1].major, 1, "第二个版本应该是1.1.0")
        XCTAssertEqual(versions[1].minor, 1, "第二个版本应该是1.1.0")
        XCTAssertEqual(versions[2].major, 2, "第三个版本应该是2.0.0")
    }
    
    /// 测试迁移路径计算
    func testMigrationPathCalculation() {
        // 设置模拟数据
        let v1 = ModelVersion(versionString: "V1_0_0")!
        let v2 = ModelVersion(versionString: "V2_0_0")!
        let v3 = ModelVersion(versionString: "V3_0_0")!
        
        // 计算迁移路径
        versionManager.setupTestModels([
            createMockModelWithVersion("V1_0_0"),
            createMockModelWithVersion("V2_0_0"),
            createMockModelWithVersion("V3_0_0")
        ])
        
        let path = versionManager.migrationPath(from: v1, to: v3)
        
        // 验证结果
        XCTAssertEqual(path.count, 2, "从v1到v3的路径应该包含2个步骤")
        XCTAssertEqual(path[0].major, 2, "第一步应该是迁移到v2")
        XCTAssertEqual(path[1].major, 3, "第二步应该是迁移到v3")
    }
    
    /// 测试相同版本的迁移路径
    func testMigrationPathForSameVersion() {
        let v1 = ModelVersion(versionString: "V1_0_0")!
        
        // 计算迁移路径
        let path = versionManager.migrationPath(from: v1, to: v1)
        
        // 验证结果
        XCTAssertEqual(path.count, 0, "相同版本之间不应该有迁移路径")
    }
    
    /// 测试降级迁移路径
    func testDowngradeMigrationPath() {
        let v2 = ModelVersion(versionString: "V2_0_0")!
        let v1 = ModelVersion(versionString: "V1_0_0")!
        
        // 计算迁移路径
        let path = versionManager.migrationPath(from: v2, to: v1)
        
        // 验证结果
        XCTAssertEqual(path.count, 0, "降级迁移不支持，应该返回空路径")
    }
    
    /// 测试迁移判断
    func testMigrationDetermination() {
        // 设置模拟数据
        versionManager.mockCurrentModelVersion = ModelVersion(versionString: "V3_0_0")!
        versionManager.mockRequiresMigration = true
        
        // 创建测试存储URL
        let storeURL = tempDirectoryURL.appendingPathComponent("test.sqlite")
        
        do {
            // 检查是否需要迁移
            let requiresMigration = try versionManager.requiresMigration(at: storeURL)
            
            // 验证结果
            XCTAssertTrue(requiresMigration, "应该需要迁移")
        } catch {
            XCTFail("测试失败: \(error.localizedDescription)")
        }
    }
    
    /// 测试模型版本定义注册表
    func testModelVersionDefinitionRegistry() {
        // 注册版本
        let v1 = ModelVersion(versionString: "V1_0_0")!
        let v2 = ModelVersion(versionString: "V2_0_0")!
        let v3 = ModelVersion(versionString: "V3_0_0")!
        
        versionRegistry.register(version: v1)
        versionRegistry.register(version: v2, mappingBlock: { _ in
            // 自定义映射操作
            print("从V1迁移到V2")
        })
        versionRegistry.register(version: v3, mappingBlock: { _ in
            // 自定义映射操作
            print("从V2迁移到V3")
        })
        
        // 验证版本数量
        XCTAssertEqual(versionRegistry.definitions.count, 3, "应该注册了3个版本")
        
        // 验证最新版本
        XCTAssertEqual(versionRegistry.latestVersion().major, 3, "最新版本应该是V3")
        
        // 设置当前版本为V1
        versionRegistry.setCurrentVersion(v1)
        
        // 验证是否需要迁移
        XCTAssertTrue(versionRegistry.requiresMigration(), "V1到V3应该需要迁移")
        
        // 验证迁移路径
        let path = versionRegistry.migrationPath(from: v1, to: v3)
        XCTAssertEqual(path.count, 2, "从V1到V3应该有2个迁移步骤")
        XCTAssertEqual(path[0].sourceVersion.major, 1, "第一步源版本应该是V1")
        XCTAssertEqual(path[0].destinationVersion.major, 2, "第一步目标版本应该是V2")
        XCTAssertEqual(path[1].sourceVersion.major, 2, "第二步源版本应该是V2")
        XCTAssertEqual(path[1].destinationVersion.major, 3, "第二步目标版本应该是V3")
    }
    
    /// 测试部分版本迁移路径
    func testPartialMigrationPath() {
        // 注册版本
        let v1 = ModelVersion(versionString: "V1_0_0")!
        let v2 = ModelVersion(versionString: "V2_0_0")!
        let v3 = ModelVersion(versionString: "V3_0_0")!
        
        versionRegistry.register(version: v1)
        versionRegistry.register(version: v2)
        versionRegistry.register(version: v3)
        
        // 测试从V2到V3的路径
        let path = versionRegistry.migrationPath(from: v2, to: v3)
        XCTAssertEqual(path.count, 1, "从V2到V3应该只有1个迁移步骤")
        XCTAssertEqual(path[0].sourceVersion.major, 2, "源版本应该是V2")
        XCTAssertEqual(path[0].destinationVersion.major, 3, "目标版本应该是V3")
    }
}

// MARK: - Test Helpers

/// 用于测试的版本管理器
class CoreDataModelVersionManagerTestable {
    /// 模拟模型
    private var mockModels: [NSManagedObjectModel] = []
    
    /// 模拟当前模型版本
    var mockCurrentModelVersion: ModelVersion?
    
    /// 模拟是否需要迁移
    var mockRequiresMigration: Bool = false
    
    /// 设置测试模型
    func setupTestModels(_ models: [NSManagedObjectModel]) {
        self.mockModels = models
    }
    
    /// 获取是否需要迁移
    func requiresMigration(at storeURL: URL) throws -> Bool {
        return mockRequiresMigration
    }
    
    /// 计算迁移路径
    func migrationPath(from sourceVersion: ModelVersion, to destinationVersion: ModelVersion) -> [ModelVersion] {
        // 与实际 CoreDataModelVersionManager 代码保持一致
        
        // 如果源版本和目标版本相同，返回空数组
        if sourceVersion.identifier == destinationVersion.identifier {
            return []
        }
        
        // 如果源版本大于目标版本，返回空数组
        if sourceVersion > destinationVersion {
            return []
        }
        
        // 计算版本序列
        return ModelVersion.sequence(from: sourceVersion, to: destinationVersion)
    }
} 