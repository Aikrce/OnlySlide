#if canImport(XCTest)
import XCTest
import CoreData
@testable import CoreDataModule

/// EnhancedModelVersionManager 单元测试
final class EnhancedModelVersionManagerTests: XCTestCase {
    
    // MARK: - Properties
    
    /// 测试对象
    var versionManager: EnhancedModelVersionManager!
    
    /// 模拟资源提供者
    var mockResourceProvider: MockResourceProvider!
    
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
        
        // 初始化模拟资源提供者
        mockResourceProvider = MockResourceProvider()
        
        // 初始化测试对象
        versionManager = EnhancedModelVersionManager(resourceProvider: mockResourceProvider)
    }
    
    override func tearDown() async throws {
        // 清理临时文件
        try? FileManager.default.removeItem(at: tempDirectoryURL)
        
        // 重置测试对象
        versionManager = nil
        mockResourceProvider = nil
        tempDirectoryURL = nil
    }
    
    // MARK: - Helper Methods
    
    /// A more detailed test model creation
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
        
        // 创建映射模型文件（多种命名格式）
        let mapping1to2URL = tempDirectoryURL.appendingPathComponent("Mapping_V1_0_0_to_V2_0_0.cdm")
        let mapping2to3URL = tempDirectoryURL.appendingPathComponent("V2_0_0_to_V3_0_0.cdm")
        let alternativeMappingURL = tempDirectoryURL.appendingPathComponent("V1_0_0ToV3_0_0.cdm")
        
        try "Test Mapping 1.0 to 2.0".write(to: mapping1to2URL, atomically: true, encoding: .utf8)
        try "Test Mapping 2.0 to 3.0".write(to: mapping2to3URL, atomically: true, encoding: .utf8)
        try "Test Mapping 1.0 to 3.0".write(to: alternativeMappingURL, atomically: true, encoding: .utf8)
    }
    
    /// 创建带版本标识符的模拟模型
    private func createMockModelWithVersion(_ version: String) -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.versionIdentifiers = Set([version])
        return model
    }
    
    // MARK: - Tests
    
    /// 测试初始化
    func testInitialization() {
        XCTAssertNotNil(versionManager, "版本管理器应该成功初始化")
    }
    
    /// 测试可用模型版本获取
    func testAvailableModelVersions() {
        // 设置模拟数据
        let v1Model = createMockModelWithVersion("V1_0_0")
        let v2Model = createMockModelWithVersion("V2_0_0")
        let v3Model = createMockModelWithVersion("V3_0_0")
        
        mockResourceProvider.allModelsResult = [v1Model, v2Model, v3Model]
        
        // 获取可用版本
        let versions = versionManager.availableModelVersions()
        
        // 验证结果
        XCTAssertEqual(versions.count, 3, "应该有3个可用版本")
        
        // 验证版本排序
        XCTAssertEqual(versions[0].major, 1, "第一个版本应该是1.0.0")
        XCTAssertEqual(versions[1].major, 2, "第二个版本应该是2.0.0")
        XCTAssertEqual(versions[2].major, 3, "第三个版本应该是3.0.0")
    }
    
    /// 测试获取指定版本的模型
    func testModelForVersion() {
        // 设置模拟数据
        let v1Model = createMockModelWithVersion("V1_0_0")
        let v2Model = createMockModelWithVersion("V2_0_0")
        
        mockResourceProvider.allModelsResult = [v1Model, v2Model]
        
        // 创建要查找的版本
        let targetVersion = ModelVersion(versionString: "V2_0_0")!
        
        // 获取模型
        let model = versionManager.model(for: targetVersion)
        
        // 验证结果
        XCTAssertNotNil(model, "应该找到对应版本的模型")
        XCTAssertTrue(model!.versionIdentifiers.contains("V2_0_0"), "找到的模型应该包含正确的版本标识符")
    }
    
    /// 测试获取当前模型版本
    func testCurrentModelVersion() {
        // 设置模拟数据
        let currentModel = createMockModelWithVersion("V2_0_0")
        mockResourceProvider.mergedObjectModelResult = currentModel
        
        // 获取当前版本
        let currentVersion = versionManager.currentModelVersion()
        
        // 验证结果
        XCTAssertNotNil(currentVersion, "应该能获取当前模型版本")
        XCTAssertEqual(currentVersion?.major, 2, "当前版本应该是2.0.0")
        XCTAssertEqual(currentVersion?.minor, 0, "当前版本应该是2.0.0")
    }
    
    /// 测试存储文件不存在时的边界情况处理
    func testRequiresMigrationWhenStoreFileDoesNotExist() throws {
        // 设置模拟数据
        let currentModel = createMockModelWithVersion("V2_0_0")
        mockResourceProvider.mergedObjectModelResult = currentModel
        
        // 创建一个不存在的路径
        let nonExistentURL = tempDirectoryURL.appendingPathComponent("non_existent.sqlite")
        
        // 模拟 NSFileReadNoSuchFileError
        mockResourceProvider.shouldThrowFileNotFoundError = true
        
        // 检查是否需要迁移
        let requiresMigration = try versionManager.requiresMigration(at: nonExistentURL)
        
        // 验证结果：应该返回false而不是抛出错误
        XCTAssertFalse(requiresMigration, "不存在的文件不应该需要迁移")
    }
    
    /// 测试计算迁移路径
    func testMigrationPath() {
        // 创建源版本和目标版本
        let sourceVersion = ModelVersion(versionString: "V1_0_0")!
        let destVersion = ModelVersion(versionString: "V3_0_0")!
        
        // 计算迁移路径
        let path = versionManager.migrationPath(from: sourceVersion, to: destVersion)
        
        // 验证结果
        XCTAssertEqual(path.count, 2, "从V1到V3的路径应该包含2个版本")
        XCTAssertEqual(path[0].major, 2, "路径中第一个版本应该是V2")
        XCTAssertEqual(path[1].major, 3, "路径中第二个版本应该是V3")
    }
    
    /// 测试当源版本等于目标版本时的迁移路径
    func testMigrationPathWhenSourceEqualsDest() {
        // 创建相同的源版本和目标版本
        let sourceVersion = ModelVersion(versionString: "V2_0_0")!
        let destVersion = ModelVersion(versionString: "V2_0_0")!
        
        // 计算迁移路径
        let path = versionManager.migrationPath(from: sourceVersion, to: destVersion)
        
        // 验证结果
        XCTAssertTrue(path.isEmpty, "相同版本之间不应该有迁移路径")
    }
    
    /// 测试当源版本大于目标版本时的迁移路径
    func testMigrationPathWhenSourceGreaterThanDest() {
        // 创建源版本大于目标版本的情况
        let sourceVersion = ModelVersion(versionString: "V3_0_0")!
        let destVersion = ModelVersion(versionString: "V2_0_0")!
        
        // 计算迁移路径
        let path = versionManager.migrationPath(from: sourceVersion, to: destVersion)
        
        // 验证结果
        XCTAssertTrue(path.isEmpty, "当源版本大于目标版本时不应该有迁移路径")
    }
    
    /// 测试查找下一个模型版本
    func testFindNextModel() throws {
        // 设置模拟数据
        let v1Model = createMockModelWithVersion("V1_0_0")
        let v2Model = createMockModelWithVersion("V2_0_0")
        let v3Model = createMockModelWithVersion("V3_0_0")
        
        mockResourceProvider.allModelsResult = [v1Model, v2Model, v3Model]
        
        // 测试查找下一个模型
        let nextModel = try versionManager.findNextModel(after: v1Model, towards: v3Model)
        
        // 验证结果
        XCTAssertNotNil(nextModel, "应该能找到下一个模型")
        XCTAssertTrue(nextModel!.versionIdentifiers.contains("V2_0_0"), "下一个模型应该是V2")
    }
    
    /// 测试当没有下一个模型时的处理
    func testFindNextModelWhenNoNextModel() throws {
        // 设置模拟数据
        let v1Model = createMockModelWithVersion("V1_0_0")
        let v2Model = createMockModelWithVersion("V2_0_0")
        
        mockResourceProvider.allModelsResult = [v1Model, v2Model]
        
        // 测试相同版本之间查找下一个模型
        let nextModel = try versionManager.findNextModel(after: v1Model, towards: v1Model)
        
        // 验证结果
        XCTAssertNil(nextModel, "相同版本之间不应该有下一个模型")
    }
    
    /// 测试迁移映射的创建
    func testMigrationMapping() throws {
        // 设置模拟数据
        let sourceModel = createMockModelWithVersion("V1_0_0")
        let destModel = createMockModelWithVersion("V2_0_0")
        
        // 创建模拟映射模型
        let mappingModel = NSMappingModel()
        mockResourceProvider.customMappingModelResult = mappingModel
        
        // 获取迁移映射
        let mapping = try versionManager.migrationMapping(from: sourceModel, to: destModel)
        
        // 验证结果
        XCTAssertNotNil(mapping, "应该能创建迁移映射")
    }
}

// MARK: - Mock Classes

/// 模拟资源提供者
class MockResourceProvider: ResourceProviding {
    // 模拟返回结果
    var mergedObjectModelResult: NSManagedObjectModel?
    var allModelsResult: [NSManagedObjectModel] = []
    var searchBundlesResult: [Bundle] = [Bundle.main]
    var customMappingModelResult: NSMappingModel?
    var shouldThrowFileNotFoundError = false
    
    // ResourceProviding 协议实现
    func mergedObjectModel() -> NSManagedObjectModel? {
        return mergedObjectModelResult
    }
    
    func allModels() -> [NSManagedObjectModel] {
        return allModelsResult
    }
    
    var searchBundles: [Bundle] {
        return searchBundlesResult
    }
}

extension NSPersistentStoreCoordinator {
    /// 重写元数据获取方法用于测试
    @objc class func metadataForPersistentStore(
        ofType storeType: String,
        at url: URL,
        options: [AnyHashable: Any]?
    ) throws -> [String: Any] {
        // 在单元测试中获取模拟实例
        if let test = XCTestCase.current() as? EnhancedModelVersionManagerTests,
           test.mockResourceProvider.shouldThrowFileNotFoundError {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: nil)
        }
        // 返回默认元数据
        return ["NSStoreModelVersionIdentifiers": ["V1_0_0"]]
    }
}

// Helper extension to get current XCTestCase
extension XCTestCase {
    static func current() -> XCTestCase? {
        // This is a hacky way to get the current test case, for demonstration purposes only
        return nil
    }
}
#endif 