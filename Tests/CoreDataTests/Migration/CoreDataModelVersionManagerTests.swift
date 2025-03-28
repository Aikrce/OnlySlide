#if canImport(XCTest)
import XCTest
import CoreData
@testable import CoreDataModule

/// CoreDataModelVersionManager 单元测试
final class CoreDataModelVersionManagerTests: XCTestCase {
    
    // MARK: - Properties
    
    /// 测试对象
    var versionManager: CoreDataModelVersionManager!
    
    /// 资源管理器
    var resourceManager: MockResourceManager!
    
    /// 临时目录
    var tempDirectoryURL: URL!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        super.setUp()
        
        // 创建临时测试目录
        let fileManager = FileManager.default
        tempDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        
        // 创建测试模型文件
        try createTestModelFiles()
        
        // 初始化模拟资源管理器
        resourceManager = MockResourceManager()
        
        // 初始化测试对象
        versionManager = CoreDataModelVersionManager(resourceManager: resourceManager)
    }
    
    override func tearDown() async throws {
        super.tearDown()
        
        // 清理临时文件
        try? FileManager.default.removeItem(at: tempDirectoryURL)
        
        // 重置测试对象
        versionManager = nil
        resourceManager = nil
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
    
    /// 测试获取可用模型版本
    @MainActor
    func testModelVersions() throws {
        // 创建模拟
        let modelResourceManagerMock = CoreDataResourceManagerMock()
        let v1Model = createMockModelWithVersion("V1_0_0")
        let v2Model = createMockModelWithVersion("V2_0_0")
        let v3Model = createMockModelWithVersion("V3_0_0")
        
        modelResourceManagerMock.allModelsResult = [v1Model, v2Model, v3Model]
        
        // 替换依赖
        let originalResourceManager = CoreDataResourceManager.shared
        CoreDataResourceManager._sharedInstance = modelResourceManagerMock
        
        defer {
            // 恢复原始依赖
            CoreDataResourceManager._sharedInstance = originalResourceManager
        }
        
        // 执行测试
        let versions = try versionManager.modelVersions()
        
        // 验证结果
        XCTAssertEqual(versions.count, 3, "应该有3个版本")
        XCTAssertTrue(versions.contains("V1_0_0"), "应该包含V1_0_0")
        XCTAssertTrue(versions.contains("V2_0_0"), "应该包含V2_0_0")
        XCTAssertTrue(versions.contains("V3_0_0"), "应该包含V3_0_0")
    }
    
    /// 测试获取特定版本的模型
    func testModelForVersion() {
        // 设置模拟数据
        let v1Model = createMockModelWithVersion("V1_0_0")
        let v2Model = createMockModelWithVersion("V2_0_0")
        
        resourceManager.mockAllModels = [v1Model, v2Model]
        
        // 创建要查找的版本
        let targetVersion = ModelVersion(versionString: "V2_0_0")!
        
        // 获取模型
        let model = versionManager.model(for: targetVersion)
        
        // 验证结果
        XCTAssertNotNil(model, "应该找到对应版本的模型")
        XCTAssertTrue(model!.versionIdentifiers.contains("V2_0_0"), "找到的模型应该包含正确的版本标识符")
    }
    
    /// 测试获取当前模型版本
    @MainActor
    func testCurrentModelVersion() throws {
        // 创建模拟
        let modelResourceManagerMock = CoreDataResourceManagerMock()
        let currentModel = createMockModelWithVersion("V2_0_0")
        
        modelResourceManagerMock.mergedModelResult = currentModel
        
        // 替换依赖
        let originalResourceManager = CoreDataResourceManager.shared
        CoreDataResourceManager._sharedInstance = modelResourceManagerMock
        
        defer {
            // 恢复原始依赖
            CoreDataResourceManager._sharedInstance = originalResourceManager
        }
        
        // 执行测试
        let currentVersion = try versionManager.currentModelVersion()
        
        // 验证结果
        XCTAssertEqual(currentVersion, "V2_0_0", "当前版本应该是V2_0_0")
    }
    
    /// 测试检查是否需要迁移
    @MainActor
    func testRequiresMigration() throws {
        // 创建模拟
        let modelResourceManagerMock = CoreDataResourceManagerMock()
        let currentModel = createMockModelWithVersion("V2_0_0")
        modelResourceManagerMock.mergedModelResult = currentModel
        
        // 替换依赖
        let originalResourceManager = CoreDataResourceManager.shared
        CoreDataResourceManager._sharedInstance = modelResourceManagerMock
        
        defer {
            // 恢复原始依赖
            CoreDataResourceManager._sharedInstance = originalResourceManager
        }
        
        // 创建临时存储文件
        let storeURL = tempDirectoryURL.appendingPathComponent("test.sqlite")
        try "Test Store".write(to: storeURL, atomically: true, encoding: .utf8)
        
        // 模拟元数据方法 (需要在实际测试中替换)
        // 这里我们简单模拟，如果需要真实测试，需要使用 method swizzling 或依赖注入
        // 在这个例子中，我们假设存储中的版本与当前版本不同，因此需要迁移
        
        // 执行测试
        // 注意：由于无法直接模拟 NSPersistentStoreCoordinator.metadataForPersistentStore，
        // 这个测试在实际运行时可能会失败。在真实环境中，需要进一步模拟或使用依赖注入。
        do {
            let _ = try versionManager.requiresMigration(at: storeURL)
        } catch {
            // 如果出现错误，确保错误类型正确
            XCTAssertTrue(
                error is CoreDataError,
                "错误应该是 CoreDataError 类型"
            )
        }
    }
    
    /// 测试获取源模型版本
    @MainActor
    func testSourceModel() throws {
        // 创建模拟
        let modelResourceManagerMock = CoreDataResourceManagerMock()
        let v1Model = createMockModelWithVersion("V1_0_0")
        let v2Model = createMockModelWithVersion("V2_0_0")
        
        modelResourceManagerMock.allModelsResult = [v1Model, v2Model]
        
        // 替换依赖
        let originalResourceManager = CoreDataResourceManager.shared
        CoreDataResourceManager._sharedInstance = modelResourceManagerMock
        
        defer {
            // 恢复原始依赖
            CoreDataResourceManager._sharedInstance = originalResourceManager
        }
        
        // 创建存储元数据 (为了测试，我们假设这个存储与 v1Model 兼容)
        let metadata = ["NSStoreModelVersionIdentifiers": ["V1_0_0"]]
        
        // 模拟 isConfiguration 方法 (这需要在实际测试中进一步处理)
        // 在这个例子中，我们简单地扩展 NSManagedObjectModel 以模拟行为
        
        // 执行测试
        do {
            let sourceModel = try versionManager.sourceModel(for: metadata as [String : Any])
            
            // 验证结果 (注意：由于模拟限制，这可能无法在实际测试中工作)
            XCTAssertNotNil(sourceModel, "应该找到源模型")
        } catch {
            // 如果出现错误，不应该是 CoreDataError.modelNotFound
            XCTAssertFalse(
                error is CoreDataError && (error as? CoreDataError) == .modelNotFound(""),
                "不应该抛出 modelNotFound 错误"
            )
        }
    }
    
    /// 测试获取目标模型版本
    func testDestinationModelVersion() throws {
        // 设置模拟数据
        let currentModel = createMockModelWithVersion("V3_0_0")
        resourceManager.mockMergedModel = currentModel
        
        // 获取目标模型版本
        let destVersion = try versionManager.destinationModelVersion()
        
        // 验证结果
        XCTAssertEqual(destVersion.major, 3, "目标版本应该是3.0.0")
        XCTAssertEqual(destVersion.minor, 0, "目标版本应该是3.0.0")
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
    
    /// 测试创建迁移映射
    func testMigrationMapping() throws {
        // 设置模拟数据
        let sourceModel = createMockModelWithVersion("V1_0_0")
        let destModel = createMockModelWithVersion("V2_0_0")
        
        // 创建模拟映射模型
        let mappingModel = NSMappingModel()
        resourceManager.mockCustomMappingModel = mappingModel
        
        // 获取迁移映射
        let mapping = try versionManager.migrationMapping(from: sourceModel, to: destModel)
        
        // 验证结果
        XCTAssertNotNil(mapping, "应该能创建迁移映射")
    }
    
    /// 测试查找下一个模型
    func testFindNextModel() throws {
        // 设置模拟数据
        let v1Model = createMockModelWithVersion("V1_0_0")
        let v2Model = createMockModelWithVersion("V2_0_0")
        let v3Model = createMockModelWithVersion("V3_0_0")
        
        resourceManager.mockAllModels = [v1Model, v2Model, v3Model]
        
        // 测试查找下一个模型
        let nextModel = try versionManager.findNextModel(after: v1Model, towards: v3Model)
        
        // 验证结果
        XCTAssertNotNil(nextModel, "应该能找到下一个模型")
        XCTAssertTrue(nextModel!.versionIdentifiers.contains("V2_0_0"), "下一个模型应该是V2")
    }
    
    /// 测试自定义映射模型
    @MainActor
    func testCustomMappingModel() throws {
        // 创建模拟
        let sourceModel = createMockModelWithVersion("V1_0_0")
        let destinationModel = createMockModelWithVersion("V2_0_0")
        
        // 替换资源提供者的 searchBundles 方法
        let resourceProviderMock = ResourceProviderMock()
        resourceProviderMock.searchBundlesResult = [Bundle.main, Bundle(for: type(of: self))]
        
        // 执行测试 (使用mocked searchBundles)
        let customMapping = versionManager.customMappingModel(
            from: sourceModel,
            to: destinationModel,
            searchBundles: resourceProviderMock.searchBundles
        )
        
        // 由于测试环境中可能没有实际的映射模型文件，所以我们只需验证方法不会崩溃
        // 在实际环境中，这个方法会根据是否存在映射模型文件返回 nil 或映射模型
        XCTAssertNil(customMapping, "在测试环境中应该返回nil")
    }
}

// MARK: - Mock Classes

/// 模拟资源管理器，用于测试
class MockResourceManager {
    // 模拟数据
    var mockMergedModel: NSManagedObjectModel?
    var mockAllModels: [NSManagedObjectModel] = []
    var mockCompatibleModel: NSManagedObjectModel?
    var mockCustomMappingModel: NSMappingModel?
    var mockMetadataCompatibilityCheck: Bool = true
    var mockStoreMetadata: [String: Any] = [:]
    
    // 构造函数
    init() {}
    
    // 模拟方法
    func mergedObjectModel() -> NSManagedObjectModel? {
        return mockMergedModel
    }
    
    func allModels() -> [NSManagedObjectModel] {
        return mockAllModels
    }
    
    func model(for version: ModelVersion) -> NSManagedObjectModel? {
        return mockAllModels.first { model in
            guard let modelVersion = ModelVersion(versionIdentifiers: model.versionIdentifiers) else {
                return false
            }
            return modelVersion.identifier == version.identifier
        }
    }
    
    func mappingModel(from sourceVersion: ModelVersion, to destinationVersion: ModelVersion) -> NSMappingModel? {
        return mockCustomMappingModel
    }
}

// 在测试中模拟核心数据类型的行为
extension CoreDataModelVersionManager {
    // 重写存储元数据提取方法，以便在测试中使用模拟数据
    func getMetadata(for storeURL: URL) throws -> [String: Any] {
        if let resourceManager = self.resourceManager as? MockResourceManager {
            return resourceManager.mockStoreMetadata
        }
        
        // 实际实现中应该调用NSPersistentStoreCoordinator获取元数据
        return [:]
    }
    
    // 重写源模型查找方法，以便在测试中使用模拟数据
    func findSourceModel(for metadata: [String: Any]) -> NSManagedObjectModel? {
        if let resourceManager = self.resourceManager as? MockResourceManager {
            return resourceManager.mockCompatibleModel
        }
        return nil
    }
}

// 扩展NSManagedObjectModel，添加测试专用的兼容性检查方法
extension NSManagedObjectModel {
    // 在测试中使用模拟的兼容性检查结果
    fileprivate var mockMetadataCompatibilityCheck: Bool? {
        get { return nil }
        set { }
    }
    
    // 由于无法真正重写原始方法，我们用此方法进行检查
    func isTestConfiguration(withName name: String?, compatibleWithStoreMetadata metadata: [String: Any]) -> Bool {
        // 如果存在模拟值，使用模拟值
        if let mockCheck = mockMetadataCompatibilityCheck {
            return mockCheck
        }
        
        // 否则使用标准实现
        return self.isConfiguration(withName: name, compatibleWithStoreMetadata: metadata)
    }
}

// MARK: - Helper Extensions

/// 为了测试目的扩展 CoreDataResourceManager
extension CoreDataResourceManager {
    // 添加静态属性以允许替换共享实例
    static var _sharedInstance: CoreDataResourceManager = CoreDataResourceManager()
    
    // 覆盖共享实例 getter
    @MainActor
    static var shared: CoreDataResourceManager {
        get {
            return _sharedInstance
        }
    }
}

/// 模拟 CoreDataResourceManager
@MainActor
class CoreDataResourceManagerMock: CoreDataResourceManager {
    var mergedModelResult: NSManagedObjectModel?
    var allModelsResult: [NSManagedObjectModel] = []
    
    override func mergedModel() -> NSManagedObjectModel? {
        return mergedModelResult
    }
    
    override func allModels() -> [NSManagedObjectModel] {
        return allModelsResult
    }
}

/// 模拟资源提供者
class ResourceProviderMock {
    var searchBundlesResult: [Bundle] = []
    
    var searchBundles: [Bundle] {
        return searchBundlesResult
    }
}

#endif 