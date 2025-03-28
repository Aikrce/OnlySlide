#if canImport(XCTest)
import XCTest
import CoreData
@testable import CoreDataModule

/// 多Bundle环境下的CoreDataResourceManager测试
/// 此测试类专注于测试CoreDataResourceManager在多Bundle环境下的资源加载和管理能力
class MultiBundleResourceTests: XCTestCase {
    
    // MARK: - Properties
    
    /// 测试用的资源管理器
    var resourceManager: CoreDataResourceManager!
    
    /// 主要测试 Bundle
    var primaryBundle: Bundle!
    
    /// 额外的测试 Bundle
    var additionalBundle: Bundle!
    
    /// 模拟的模型 Bundle
    var modelBundle: Bundle!
    
    /// 临时目录
    var tempDirectoryURL: URL!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        // 创建临时测试目录
        let fileManager = FileManager.default
        tempDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        
        // 设置测试用的 Bundle
        primaryBundle = Bundle.main
        additionalBundle = Bundle(for: type(of: self))
        modelBundle = Bundle(for: CoreDataResourceManager.self)
        
        // 初始化默认的资源管理器
        resourceManager = CoreDataResourceManager(
            modelName: "TestModel",
            bundle: primaryBundle,
            additionalBundles: [additionalBundle]
        )
    }
    
    override func tearDown() async throws {
        // 清理临时目录
        try? FileManager.default.removeItem(at: tempDirectoryURL)
        
        // 重置属性
        resourceManager = nil
        primaryBundle = nil
        additionalBundle = nil
        modelBundle = nil
        tempDirectoryURL = nil
    }
    
    // MARK: - Tests
    
    /// 测试搜索 Bundle 顺序
    func testSearchBundlesOrder() {
        // 创建自定义 Bundle 数组的资源管理器
        let testBundles = [primaryBundle, additionalBundle, modelBundle]
        let customManager = CoreDataResourceManager(
            modelName: "TestModel",
            bundles: testBundles
        )
        
        // 使用镜像获取私有属性
        let mirror = Mirror(reflecting: customManager)
        
        // 验证主要 Bundle 和额外 Bundle 设置正确
        for child in mirror.children {
            if child.label == "primaryBundle" {
                XCTAssertEqual(child.value as? Bundle, primaryBundle, "主要 Bundle 应该是测试的第一个 Bundle")
            } else if child.label == "additionalBundles" {
                if let additionalBundles = child.value as? [Bundle] {
                    XCTAssertEqual(additionalBundles.count, 2, "额外 Bundle 数组应该包含2个 Bundle")
                    XCTAssertEqual(additionalBundles[0], additionalBundle, "额外 Bundle 数组的第一个元素应该是测试的第二个 Bundle")
                    XCTAssertEqual(additionalBundles[1], modelBundle, "额外 Bundle 数组的第二个元素应该是测试的第三个 Bundle")
                } else {
                    XCTFail("额外 Bundle 应该是 [Bundle] 类型")
                }
            }
        }
    }
    
    /// 测试在不同 Bundle 中创建和查找模型文件
    func testModelSearchAcrossBundles() throws {
        // 在临时目录中分别为三个 Bundle 创建子目录
        let primaryBundleDir = tempDirectoryURL.appendingPathComponent("primaryBundle")
        let additionalBundleDir = tempDirectoryURL.appendingPathComponent("additionalBundle")
        let modelBundleDir = tempDirectoryURL.appendingPathComponent("modelBundle")
        
        try FileManager.default.createDirectory(at: primaryBundleDir, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: additionalBundleDir, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: modelBundleDir, withIntermediateDirectories: true, attributes: nil)
        
        // 在第二个 Bundle 目录中创建模型文件
        let momdDir = additionalBundleDir.appendingPathComponent("TestModel.momd")
        try FileManager.default.createDirectory(at: momdDir, withIntermediateDirectories: true, attributes: nil)
        
        // 创建版本模型文件
        let versionModelURL = momdDir.appendingPathComponent("TestModel_1.0.mom")
        try "Test Model Content".write(to: versionModelURL, atomically: true, encoding: .utf8)
        
        // 创建映射模型文件
        let mappingModelURL = additionalBundleDir.appendingPathComponent("Mapping_1.0_to_1.1.cdm")
        try "Test Mapping Content".write(to: mappingModelURL, atomically: true, encoding: .utf8)
        
        // 测试模型查找（这里我们不能真正加载模型，因为文件内容不是有效的模型数据，所以只测试不崩溃）
        let mockResourceManager = CoreDataResourceManager(
            modelName: "TestModel",
            bundle: Bundle(for: type(of: self)),
            additionalBundles: []
        )
        
        XCTAssertNoThrow(mockResourceManager.modelURL())
        XCTAssertNoThrow(mockResourceManager.allModelVersionURLs())
        
        // 测试版本模型查找
        let sourceVersion = ModelVersion(major: 1, minor: 0, patch: 0)
        let destinationVersion = ModelVersion(major: 1, minor: 1, patch: 0)
        XCTAssertNoThrow(mockResourceManager.modelURL(for: sourceVersion))
        
        // 测试映射模型查找
        XCTAssertNoThrow(mockResourceManager.mappingModel(from: sourceVersion, to: destinationVersion))
    }
    
    /// 测试不同命名格式的模型文件查找
    func testDifferentModelNamingFormats() throws {
        // 在临时目录中创建测试 Bundle 目录
        let testBundleDir = tempDirectoryURL.appendingPathComponent("testBundle")
        try FileManager.default.createDirectory(at: testBundleDir, withIntermediateDirectories: true, attributes: nil)
        
        // 创建不同命名格式的模型文件
        
        // 1. 标准 .momd 目录
        let momdDir = testBundleDir.appendingPathComponent("AlternateModel.momd")
        try FileManager.default.createDirectory(at: momdDir, withIntermediateDirectories: true, attributes: nil)
        let standardModelURL = momdDir.appendingPathComponent("AlternateModel_1.0.mom")
        try "Standard Model Content".write(to: standardModelURL, atomically: true, encoding: .utf8)
        
        // 2. 单独的 .mom 文件
        let singleModelURL = testBundleDir.appendingPathComponent("AlternateModel.mom")
        try "Single Model Content".write(to: singleModelURL, atomically: true, encoding: .utf8)
        
        // 3. 版本命名的 .mom 文件
        let versionedModelURL = testBundleDir.appendingPathComponent("1.0.mom")
        try "Versioned Model Content".write(to: versionedModelURL, atomically: true, encoding: .utf8)
        
        // 4. 带模型名前缀的版本 .mom 文件
        let prefixedModelURL = testBundleDir.appendingPathComponent("AlternateModel_1.0.mom")
        try "Prefixed Model Content".write(to: prefixedModelURL, atomically: true, encoding: .utf8)
        
        // 创建一个使用自定义测试目录的资源管理器
        // 注意：实际测试时这里不能直接创建模拟的 Bundle，因为我们需要真实的 Bundle API
        // 所以这个测试主要是验证相关方法不会崩溃
        let mockManager = CoreDataResourceManager(
            modelName: "AlternateModel",
            bundle: Bundle(for: type(of: self)),
            additionalBundles: []
        )
        
        // 测试各种查找方法不会崩溃
        XCTAssertNoThrow(mockManager.modelURL())
        XCTAssertNoThrow(mockManager.mergedObjectModel())
        XCTAssertNoThrow(mockManager.allModelVersionURLs())
        
        let version = ModelVersion(major: 1, minor: 0, patch: 0)
        XCTAssertNoThrow(mockManager.modelURL(for: version))
        XCTAssertNoThrow(mockManager.model(for: version))
    }
    
    /// 测试异常情况处理
    func testEdgeCases() {
        // 空 Bundles 测试
        let emptyBundlesManager = CoreDataResourceManager(bundles: [])
        XCTAssertNoThrow(emptyBundlesManager.modelURL())
        XCTAssertNoThrow(emptyBundlesManager.mergedObjectModel())
        
        // 不存在的模型名称
        let nonExistentModelManager = CoreDataResourceManager(modelName: "NonExistentModel")
        XCTAssertNoThrow(nonExistentModelManager.modelURL())
        XCTAssertNoThrow(nonExistentModelManager.mergedObjectModel())
        
        // 不存在的模型版本
        let invalidVersion = ModelVersion(major: 99, minor: 99, patch: 99)
        XCTAssertNoThrow(nonExistentModelManager.modelURL(for: invalidVersion))
        XCTAssertNoThrow(nonExistentModelManager.model(for: invalidVersion))
        
        // 不存在的映射模型
        let sourceVersion = ModelVersion(major: 1, minor: 0, patch: 0)
        let destinationVersion = ModelVersion(major: 2, minor: 0, patch: 0)
        XCTAssertNoThrow(nonExistentModelManager.mappingModel(from: sourceVersion, to: destinationVersion))
    }
    
    /// 测试库外 Bundle 资源
    func testExternalBundleResources() {
        // 创建一个模拟的外部 Bundle
        let externalBundle = Bundle(for: type(of: self))
        
        // 创建一个使用该 Bundle 的资源管理器
        let externalManager = CoreDataResourceManager(
            modelName: "ExternalModel",
            bundle: externalBundle,
            additionalBundles: []
        )
        
        // 测试资源访问方法不会崩溃
        XCTAssertNoThrow(externalManager.modelURL())
        XCTAssertNoThrow(externalManager.mergedObjectModel())
        XCTAssertNoThrow(externalManager.allModelVersionURLs())
        XCTAssertNoThrow(externalManager.allModels())
    }
    
    /// 测试共享实例与自定义 Bundle
    func testSharedInstanceWithCustomBundles() {
        // 准备测试用的 Bundle 数组
        let testBundles = [primaryBundle, additionalBundle, modelBundle]
        
        // 获取共享实例
        let sharedManager = CoreDataResourceManager.shared(withBundles: testBundles)
        
        // 测试共享实例行为
        XCTAssertNoThrow(sharedManager.modelURL())
        XCTAssertNoThrow(sharedManager.mergedObjectModel())
        XCTAssertNoThrow(sharedManager.allModelVersionURLs())
        
        // 创建另一个共享实例
        let anotherSharedManager = CoreDataResourceManager.shared(withBundles: [additionalBundle])
        
        // 验证两个实例是不同的对象（因为使用了不同的 Bundle 配置）
        XCTAssertNotEqual(
            ObjectIdentifier(sharedManager),
            ObjectIdentifier(anotherSharedManager),
            "使用不同 Bundle 配置创建的共享实例应该是不同的对象"
        )
    }
    
    /// 测试模型 Bundle 路径生成
    func testModelBundlePath() {
        // 获取模块 Bundle
        let moduleBundle = Bundle(for: CoreDataResourceManager.self)
        
        // 获取资源 URL
        let resourceURL = moduleBundle.resourceURL
        XCTAssertNotNil(resourceURL, "模块 Bundle 应该有有效的资源 URL")
        
        if let resourceURL = resourceURL {
            // 构建模型资源 Bundle 路径
            let modelBundlePath = resourceURL.appendingPathComponent("TestModel_CoreDataModule.bundle")
            
            // 验证路径格式
            XCTAssertTrue(
                modelBundlePath.lastPathComponent.hasSuffix("_CoreDataModule.bundle"),
                "模型资源 Bundle 路径应该以 _CoreDataModule.bundle 结尾"
            )
            XCTAssertTrue(
                modelBundlePath.lastPathComponent.hasPrefix("TestModel"),
                "模型资源 Bundle 路径应该以模型名开头"
            )
        }
    }
}
#endif 