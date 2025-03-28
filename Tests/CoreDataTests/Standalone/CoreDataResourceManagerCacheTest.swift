import XCTest
import CoreData
@testable import CoreDataModule

/// 简单独立测试：测试 CoreDataResourceManager 的缓存功能
class CoreDataResourceManagerCacheTest: XCTestCase {
    
    // MARK: - Properties
    
    /// 启用缓存的资源管理器
    var cachedResourceManager: CoreDataResourceManager!
    
    /// 禁用缓存的资源管理器
    var uncachedResourceManager: CoreDataResourceManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
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
    
    override func tearDown() {
        // 清理缓存
        cachedResourceManager.clearCache(.all)
        
        // 重置测试对象
        cachedResourceManager = nil
        uncachedResourceManager = nil
        
        super.tearDown()
    }
    
    // MARK: - Tests
    
    /// 测试初始缓存状态
    func testInitialCacheState() {
        // 获取初始缓存统计
        let stats = cachedResourceManager.cacheStatistics()
        
        // 初始状态应该没有命中和未命中
        XCTAssertEqual(stats.hits, 0, "初始命中次数应该为0")
        XCTAssertEqual(stats.misses, 0, "初始未命中次数应该为0")
        XCTAssertEqual(stats.hitRate, 0.0, "初始命中率应该为0")
    }
    
    /// 测试缓存命中和未命中计数
    func testCacheHitAndMissCount() {
        // 首次访问 (缓存未命中)
        _ = cachedResourceManager.modelURL()
        
        // 第二次访问 (缓存命中)
        _ = cachedResourceManager.modelURL()
        
        // 获取缓存统计
        let stats = cachedResourceManager.cacheStatistics()
        
        // 应该有1次命中和1次未命中
        XCTAssertEqual(stats.hits, 1, "应该有1次缓存命中")
        XCTAssertEqual(stats.misses, 1, "应该有1次缓存未命中")
        XCTAssertEqual(stats.hitRate, 0.5, "命中率应该为0.5")
    }
    
    /// 测试清除缓存
    func testClearCache() {
        // 填充缓存
        _ = cachedResourceManager.modelURL()
        _ = cachedResourceManager.modelURL() // 命中
        
        // 清除缓存
        cachedResourceManager.clearCache(.all)
        
        // 再次访问 (应该是未命中)
        _ = cachedResourceManager.modelURL()
        
        // 获取缓存统计
        let stats = cachedResourceManager.cacheStatistics()
        
        // 应该有1次命中和2次未命中
        XCTAssertEqual(stats.hits, 1, "清除缓存后应保留命中统计")
        XCTAssertEqual(stats.misses, 2, "应该有2次缓存未命中")
    }
    
    /// 测试禁用缓存
    func testDisabledCache() {
        // 多次访问禁用缓存的管理器
        _ = uncachedResourceManager.modelURL()
        _ = uncachedResourceManager.modelURL()
        
        // 获取缓存统计
        let stats = uncachedResourceManager.cacheStatistics()
        
        // 应该有0次命中和多次未命中
        XCTAssertEqual(stats.hits, 0, "禁用缓存时不应有命中")
        XCTAssertGreaterThan(stats.misses, 0, "禁用缓存时应有未命中")
    }
    
    /// 测试缓存对性能的影响
    func testCachePerformance() {
        // 初始填充缓存
        _ = cachedResourceManager.modelURL()
        
        // 测量有缓存时的性能
        let startWithCache = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = cachedResourceManager.modelURL()
        }
        let timeWithCache = CFAbsoluteTimeGetCurrent() - startWithCache
        
        // 测量无缓存时的性能
        let startWithoutCache = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = uncachedResourceManager.modelURL()
        }
        let timeWithoutCache = CFAbsoluteTimeGetCurrent() - startWithoutCache
        
        // 输出性能比较
        print("有缓存时间: \(timeWithCache * 1000)ms")
        print("无缓存时间: \(timeWithoutCache * 1000)ms")
        print("性能提升: \(timeWithoutCache / timeWithCache)x")
        
        // 有缓存的版本应该明显更快
        XCTAssertLessThan(timeWithCache, timeWithoutCache, "有缓存应该比无缓存快")
    }
}
