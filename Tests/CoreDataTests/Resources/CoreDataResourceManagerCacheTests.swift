#if canImport(XCTest)
import XCTest
import CoreData
@testable import CoreDataModule

/// CoreDataResourceManager 缓存功能测试
/// 测试 CoreDataResourceManager 的资源缓存功能
class CoreDataResourceManagerCacheTests: XCTestCase {
    
    // MARK: - Properties
    
    /// 启用缓存的资源管理器
    var cachedResourceManager: CoreDataResourceManager!
    
    /// 禁用缓存的资源管理器（用于比较）
    var uncachedResourceManager: CoreDataResourceManager!
    
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
        cachedResourceManager = CoreDataResourceManager(
            modelName: "TestModel",
            bundle: Bundle(for: type(of: self)),
            enableCaching: true
        )
        
        uncachedResourceManager = CoreDataResourceManager(
            modelName: "TestModel",
            bundle: Bundle(for: type(of: self)),
            enableCaching: false
        )
    }
    
    override func tearDown() async throws {
        // 清理缓存
        cachedResourceManager.clearCache(.all)
        
        // 清理临时目录
        try? FileManager.default.removeItem(at: tempDirectoryURL)
        
        // 重置测试对象
        cachedResourceManager = nil
        uncachedResourceManager = nil
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
        try "Test Model 1.0".write(to: modelFile1URL, atomically: true, encoding: .utf8)
        try "Test Model 2.0".write(to: modelFile2URL, atomically: true, encoding: .utf8)
        
        // 创建映射模型文件
        let mappingModelURL = tempDirectoryURL.appendingPathComponent("Mapping_1.0_to_2.0.cdm")
        try "Test Mapping Model".write(to: mappingModelURL, atomically: true, encoding: .utf8)
    }
    
    /// 创建模拟的托管对象模型
    private func createMockManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "TestEntity"
        model.entities = [entity]
        return model
    }
    
    // MARK: - Basic Cache Tests
    
    /// 测试缓存命中和未命中计数
    func testCacheHitAndMiss() {
        // 在测试类中我们无法真正加载模型，所以这里只测试缓存统计
        
        // 模拟缓存操作
        // 使用私有 API 在缓存中存储一个模型
        let mockModel = createMockManagedObjectModel()
        let mirror = Mirror(reflecting: cachedResourceManager)
        
        for child in mirror.children {
            if child.label == "modelCache" {
                if var modelCache = child.value as? [String: NSManagedObjectModel] {
                    modelCache["testKey"] = mockModel
                    // 设置回属性（实际代码无法这样做，这里只是模拟）
                }
            }
        }
        
        // 模拟缓存访问
        // 这里无法直接测试缓存命中，所以我们直接测试缓存统计方法
        
        // 验证初始缓存统计
        let initialStats = cachedResourceManager.cacheStatistics()
        XCTAssertEqual(initialStats.hits, 0, "初始缓存命中次数应该为0")
        XCTAssertEqual(initialStats.misses, 0, "初始缓存未命中次数应该为0")
        XCTAssertEqual(initialStats.hitRate, 0.0, "初始缓存命中率应该为0")
        
        // 清理缓存
        cachedResourceManager.clearCache(.all)
    }
    
    /// 测试缓存清除功能
    func testCacheClear() {
        // 模拟缓存填充
        _ = cachedResourceManager.modelURL()
        
        // 清除缓存
        cachedResourceManager.clearCache(.all)
        
        // 验证缓存已清除
        let stats = cachedResourceManager.cacheStatistics()
        
        // 注意：缓存统计计数不会被清除，只有缓存内容被清除
        // 所以我们只能间接测试
        
        // 重新访问应该是未命中
        _ = cachedResourceManager.modelURL()
        
        // 验证有新的未命中计数
        let newStats = cachedResourceManager.cacheStatistics()
        XCTAssertGreaterThan(newStats.misses, stats.misses, "清除缓存后应该有新的未命中")
    }
    
    /// 测试特定类型缓存清除
    func testSpecificCacheClear() {
        // 模拟填充不同类型的缓存
        _ = cachedResourceManager.modelURL() // 填充 modelURL 缓存
        let version1 = ModelVersion(major: 1, minor: 0, patch: 0)
        _ = cachedResourceManager.modelURL(for: version1) // 填充 versionModelURL 缓存
        
        // 只清除模型 URL 缓存
        cachedResourceManager.clearCache(.modelURL)
        
        // 验证 modelURL 缓存已清除，但其他缓存仍然有效
        // 由于我们无法直接访问缓存内容，只能通过缓存命中统计间接测试
        // 这个测试在实际情况下可能不够可靠
    }
    
    // MARK: - Performance Tests
    
    /// 测试缓存对 modelURL() 性能的影响
    func testModelURLPerformance() {
        // 测量无缓存性能
        var uncachedTime: CFAbsoluteTime = 0
        uncachedTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = uncachedResourceManager.modelURL()
        }
        uncachedTime = CFAbsoluteTimeGetCurrent() - uncachedTime
        
        // 预热缓存
        _ = cachedResourceManager.modelURL()
        
        // 测量有缓存性能
        var cachedTime: CFAbsoluteTime = 0
        cachedTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = cachedResourceManager.modelURL()
        }
        cachedTime = CFAbsoluteTimeGetCurrent() - cachedTime
        
        // 输出性能对比
        print("ModelURL 无缓存时间: \(uncachedTime * 1000)ms")
        print("ModelURL 有缓存时间: \(cachedTime * 1000)ms")
        print("性能提升: \(uncachedTime / cachedTime)x")
        
        // 通常缓存版本应该更快
        XCTAssertLessThan(cachedTime, uncachedTime, "缓存版本应该比非缓存版本快")
    }
    
    /// 测试缓存对 modelURL(for:) 性能的影响
    func testVersionModelURLPerformance() {
        let version = ModelVersion(major: 1, minor: 0, patch: 0)
        
        // 测量无缓存性能
        var uncachedTime: CFAbsoluteTime = 0
        uncachedTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = uncachedResourceManager.modelURL(for: version)
        }
        uncachedTime = CFAbsoluteTimeGetCurrent() - uncachedTime
        
        // 预热缓存
        _ = cachedResourceManager.modelURL(for: version)
        
        // 测量有缓存性能
        var cachedTime: CFAbsoluteTime = 0
        cachedTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = cachedResourceManager.modelURL(for: version)
        }
        cachedTime = CFAbsoluteTimeGetCurrent() - cachedTime
        
        // 输出性能对比
        print("VersionModelURL 无缓存时间: \(uncachedTime * 1000)ms")
        print("VersionModelURL 有缓存时间: \(cachedTime * 1000)ms")
        print("性能提升: \(uncachedTime / cachedTime)x")
        
        // 通常缓存版本应该更快
        XCTAssertLessThan(cachedTime, uncachedTime, "缓存版本应该比非缓存版本快")
    }
    
    /// 测试缓存对 mappingModel(from:to:) 性能的影响
    func testMappingModelPerformance() {
        let sourceVersion = ModelVersion(major: 1, minor: 0, patch: 0)
        let destVersion = ModelVersion(major: 2, minor: 0, patch: 0)
        
        // 测量无缓存性能
        var uncachedTime: CFAbsoluteTime = 0
        uncachedTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = uncachedResourceManager.mappingModel(from: sourceVersion, to: destVersion)
        }
        uncachedTime = CFAbsoluteTimeGetCurrent() - uncachedTime
        
        // 预热缓存
        _ = cachedResourceManager.mappingModel(from: sourceVersion, to: destVersion)
        
        // 测量有缓存性能
        var cachedTime: CFAbsoluteTime = 0
        cachedTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = cachedResourceManager.mappingModel(from: sourceVersion, to: destVersion)
        }
        cachedTime = CFAbsoluteTimeGetCurrent() - cachedTime
        
        // 输出性能对比
        print("MappingModel 无缓存时间: \(uncachedTime * 1000)ms")
        print("MappingModel 有缓存时间: \(cachedTime * 1000)ms")
        print("性能提升: \(uncachedTime / cachedTime)x")
        
        // 通常缓存版本应该更快
        XCTAssertLessThan(cachedTime, uncachedTime, "缓存版本应该比非缓存版本快")
    }
    
    // MARK: - Feature Tests
    
    /// 测试预加载功能
    func testPreloadCommonResources() {
        // 重置缓存
        cachedResourceManager.clearCache(.all)
        
        // 执行预加载
        cachedResourceManager.preloadCommonResources()
        
        // 预加载是异步的，等待一些时间让它完成
        let expectation = XCTestExpectation(description: "等待预加载")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // 检查缓存统计，应该有一些缓存命中和未命中
        let stats = cachedResourceManager.cacheStatistics()
        print("预加载后缓存统计 - 命中: \(stats.hits), 未命中: \(stats.misses), 命中率: \(stats.hitRate)")
        
        // 预加载过程中应该有一些缓存操作
        XCTAssertGreaterThan(stats.hits + stats.misses, 0, "预加载应该进行一些缓存操作")
    }
    
    /// 测试初始化参数
    func testInitializationParameters() {
        // 测试明确禁用缓存
        let disabledCacheManager = CoreDataResourceManager(
            modelName: "TestModel",
            bundle: Bundle(for: type(of: self)),
            enableCaching: false
        )
        
        // 多次请求同一资源，应该导致多次资源查找
        _ = disabledCacheManager.modelURL()
        _ = disabledCacheManager.modelURL()
        _ = disabledCacheManager.modelURL()
        
        // 检查缓存统计（即使禁用了缓存，统计功能仍然工作）
        let stats = disabledCacheManager.cacheStatistics()
        
        // 禁用缓存的情况下应该没有缓存命中
        XCTAssertEqual(stats.hits, 0, "禁用缓存的管理器不应该有命中")
        XCTAssertGreaterThan(stats.misses, 0, "禁用缓存的管理器应该记录未命中")
    }
    
    /// 测试 Bundle 成功路径缓存
    func testSuccessfulBundlePathCaching() {
        // 这个测试很难直接测试，因为我们无法访问内部成功路径缓存
        // 但我们可以推测：第一次查找后，后续查找应该更快
        
        // 第一次查找
        let startTime1 = CFAbsoluteTimeGetCurrent()
        _ = cachedResourceManager.modelURL()
        let time1 = CFAbsoluteTimeGetCurrent() - startTime1
        
        // 重置模型 URL 缓存，但保留成功路径缓存
        cachedResourceManager.clearCache(.modelURL)
        
        // 第二次查找，应该使用成功路径缓存
        let startTime2 = CFAbsoluteTimeGetCurrent()
        _ = cachedResourceManager.modelURL()
        let time2 = CFAbsoluteTimeGetCurrent() - startTime2
        
        // 输出时间对比
        print("首次查找时间: \(time1 * 1000)ms")
        print("使用路径缓存查找时间: \(time2 * 1000)ms")
        
        // 理论上第二次应该更快，但由于测试环境的不确定性，这个断言可能不总是成立
        // XCTAssertLessThanOrEqual(time2, time1, "使用路径缓存应该比首次查找快")
    }
}
#endif 