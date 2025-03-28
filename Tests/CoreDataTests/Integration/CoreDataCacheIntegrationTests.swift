#if canImport(XCTest)
import XCTest
import CoreData
@testable import CoreDataModule

/// CoreData 缓存集成测试
/// 测试缓存功能在实际应用场景中的效果
class CoreDataCacheIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    /// 资源管理器（启用缓存）
    var resourceManager: CoreDataResourceManager!
    
    /// 模型版本管理器
    var versionManager: CoreDataModelVersionManager!
    
    /// 临时存储 URL
    var tempStoreURL: URL!
    
    /// 临时目录
    var tempDirectoryURL: URL!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        // 创建临时测试目录
        let fileManager = FileManager.default
        tempDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        
        // 创建临时数据库文件
        tempStoreURL = tempDirectoryURL.appendingPathComponent("TestStore.sqlite")
        
        // 创建测试模型文件
        try createTestModelFiles()
        
        // 初始化资源管理器
        resourceManager = CoreDataResourceManager(
            modelName: "TestModel",
            bundle: Bundle(for: type(of: self)),
            enableCaching: true
        )
        
        // 初始化版本管理器
        versionManager = try CoreDataModelVersionManager(resourceManager: resourceManager)
    }
    
    override func tearDown() async throws {
        // 清理缓存
        resourceManager.clearCache(.all)
        
        // 清理临时文件
        try? FileManager.default.removeItem(at: tempDirectoryURL)
        
        // 重置测试对象
        resourceManager = nil
        versionManager = nil
        tempStoreURL = nil
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
    
    /// 创建迁移执行器
    private func createMigrationExecutor() throws -> MigrationExecutor {
        let planner = MigrationPlanner(
            resourceManager: resourceManager,
            modelVersionManager: versionManager
        )
        return MigrationExecutor(planner: planner)
    }
    
    /// 创建持久化容器
    private func createPersistentContainer() throws -> NSPersistentContainer {
        guard let model = resourceManager.mergedObjectModel() else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法加载合并模型"])
        }
        
        let container = NSPersistentContainer(name: "TestModel", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: tempStoreURL)
        container.persistentStoreDescriptions = [description]
        
        return container
    }
    
    // MARK: - Integration Tests
    
    /// 测试应用启动场景
    func testApplicationStartupScenario() async throws {
        // 1. 模拟应用启动前的缓存预热
        resourceManager.preloadCommonResources()
        
        // 等待预加载完成
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // 测量启动性能
        let startupTime = CFAbsoluteTimeGetCurrent()
        
        // 2. 模拟应用启动时的操作
        let container = try createPersistentContainer()
        
        // 3. 加载持久化存储
        let loadExpectation = expectation(description: "加载持久化存储")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "加载持久化存储应该成功")
            loadExpectation.fulfill()
        }
        
        await fulfillment(of: [loadExpectation], timeout: 5.0)
        
        // 测量启动耗时
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startupTime
        print("模拟应用启动时间: \(elapsedTime * 1000)ms")
        
        // 获取缓存统计
        let stats = resourceManager.cacheStatistics()
        print("应用启动后缓存统计 - 命中: \(stats.hits), 未命中: \(stats.misses), 命中率: \(stats.hitRate)")
        
        // 应用启动时应该有一些缓存命中
        XCTAssertGreaterThan(stats.hits, 0, "应用启动时应该有缓存命中")
    }
    
    /// 测试数据迁移场景
    func testDataMigrationScenario() async throws {
        // 1. 预热缓存
        resourceManager.preloadCommonResources()
        
        // 等待预加载完成
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // 2. 模拟创建迁移计划
        let executor = try createMigrationExecutor()
        let planner = executor.planner
        
        // 重置缓存统计
        resourceManager.clearCache(.all)
        
        // 3. 测量迁移计划创建性能
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 创建迁移计划（这里只是模拟，实际上没有真正的存储）
        let plan = try await MigrationPlan(steps: [
            MigrationStep(
                sourceVersion: ModelVersion(major: 1, minor: 0, patch: 0),
                destinationVersion: ModelVersion(major: 2, minor: 0, patch: 0)
            )
        ])
        
        // 4. 模拟执行迁移
        // 注意：这里不会真正执行迁移，因为我们没有实际的数据库文件
        // 但我们可以测量资源加载部分的性能
        
        for step in plan.steps {
            _ = try planner.sourceModel(for: step)
            _ = try planner.destinationModel(for: step)
            _ = try planner.mappingModel(for: step)
        }
        
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        print("模拟迁移资源加载时间: \(elapsedTime * 1000)ms")
        
        // 获取缓存统计
        let stats = resourceManager.cacheStatistics()
        print("迁移后缓存统计 - 命中: \(stats.hits), 未命中: \(stats.misses), 命中率: \(stats.hitRate)")
        
        // 由于我们预加载了资源，迁移过程中应该有缓存命中
        XCTAssertGreaterThan(stats.hits, 0, "迁移过程中应该有缓存命中")
    }
    
    /// 测试重复查询场景
    func testRepeatedQueryScenario() {
        // 1. 清除缓存
        resourceManager.clearCache(.all)
        
        // 2. 首次执行一系列查询
        let firstRunTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<10 {
            _ = resourceManager.modelURL()
            _ = resourceManager.modelURL(for: ModelVersion(major: 1, minor: 0, patch: 0))
            _ = resourceManager.modelURL(for: ModelVersion(major: 2, minor: 0, patch: 0))
            _ = resourceManager.mergedObjectModel()
        }
        
        let firstRunElapsed = CFAbsoluteTimeGetCurrent() - firstRunTime
        print("首次查询批次耗时: \(firstRunElapsed * 1000)ms")
        
        // 3. 再次执行相同的查询
        let secondRunTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<10 {
            _ = resourceManager.modelURL()
            _ = resourceManager.modelURL(for: ModelVersion(major: 1, minor: 0, patch: 0))
            _ = resourceManager.modelURL(for: ModelVersion(major: 2, minor: 0, patch: 0))
            _ = resourceManager.mergedObjectModel()
        }
        
        let secondRunElapsed = CFAbsoluteTimeGetCurrent() - secondRunTime
        print("第二次查询批次耗时: \(secondRunElapsed * 1000)ms")
        
        // 获取缓存统计
        let stats = resourceManager.cacheStatistics()
        print("重复查询后缓存统计 - 命中: \(stats.hits), 未命中: \(stats.misses), 命中率: \(stats.hitRate)")
        
        // 第二次查询应该比第一次快
        XCTAssertLessThan(secondRunElapsed, firstRunElapsed, "启用缓存后，重复查询应该更快")
        
        // 第二次查询应该有缓存命中
        XCTAssertGreaterThan(stats.hits, 0, "重复查询应该有缓存命中")
        XCTAssertGreaterThan(stats.hitRate, 0.0, "应该有大于0的缓存命中率")
    }
    
    /// 测试内存压力场景
    func testMemoryPressureScenario() throws {
        // 1. 填充缓存
        for i in 1...5 {
            for j in 0...9 {
                _ = resourceManager.modelURL(for: ModelVersion(major: i, minor: j, patch: 0))
            }
        }
        
        // 获取初始缓存统计
        let initialStats = resourceManager.cacheStatistics()
        print("内存压力前缓存统计 - 命中: \(initialStats.hits), 未命中: \(initialStats.misses)")
        
        // 2. 模拟内存压力
        // 在实际情况下，系统会发送内存警告通知
        // 这里我们直接调用清除方法
        resourceManager.clearCache(.model) // 清除占用内存最多的模型缓存
        
        // 3. 重新加载一些资源
        _ = resourceManager.modelURL()
        _ = resourceManager.modelURL(for: ModelVersion(major: 1, minor: 0, patch: 0))
        
        // 获取最终缓存统计
        let finalStats = resourceManager.cacheStatistics()
        print("内存压力后缓存统计 - 命中: \(finalStats.hits), 未命中: \(finalStats.misses)")
        
        // 清除缓存后，应该有新的缓存未命中记录
        XCTAssertGreaterThan(finalStats.misses, initialStats.misses, "清除缓存后应有新的未命中")
    }
}
#endif 