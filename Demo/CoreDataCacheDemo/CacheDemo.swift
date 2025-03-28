import Foundation
import CoreData

/// 模型版本
struct ModelVersion: Hashable, Equatable, Sendable {
    /// 主版本
    let major: Int
    /// 副版本
    let minor: Int
    /// 补丁版本
    let patch: Int
    
    /// 创建版本
    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    /// 从URL创建版本
    static func from(url: URL) -> ModelVersion? {
        // 解析文件名以提取版本信息
        let fileName = url.deletingPathExtension().lastPathComponent
        let parts = fileName.split(separator: "_")
        guard parts.count >= 2 else { return nil }
        
        let versionString = parts[1]
        let versionParts = versionString.split(separator: ".")
        
        if versionParts.count >= 3 {
            if let major = Int(versionParts[0]),
               let minor = Int(versionParts[1]),
               let patch = Int(versionParts[2]) {
                return ModelVersion(major: major, minor: minor, patch: patch)
            }
        } else if versionParts.count >= 2 {
            if let major = Int(versionParts[0]),
               let minor = Int(versionParts[1]) {
                return ModelVersion(major: major, minor: minor, patch: 0)
            }
        } else if versionParts.count >= 1 {
            if let major = Int(versionParts[0]) {
                return ModelVersion(major: major, minor: 0, patch: 0)
            }
        }
        
        return nil
    }
}

extension ModelVersion: CustomStringConvertible {
    var description: String {
        return "\(major).\(minor).\(patch)"
    }
}

/// 缓存类型
struct CacheType: OptionSet {
    let rawValue: Int
    
    static let none = CacheType(rawValue: 0)
    static let modelURL = CacheType(rawValue: 1 << 0)
    static let versionModelURL = CacheType(rawValue: 1 << 1)
    static let model = CacheType(rawValue: 1 << 2)
    static let mappingModel = CacheType(rawValue: 1 << 3)
    static let all: CacheType = [.modelURL, .versionModelURL, .model, .mappingModel]
}

/// 缓存统计
struct CacheStatistics {
    let hits: Int
    let misses: Int
    
    var total: Int {
        return hits + misses
    }
    
    var hitRate: Double {
        if total == 0 {
            return 0.0
        }
        return Double(hits) / Double(total)
    }
}

/// CoreData资源管理器
class CoreDataResourceManager {
    // MARK: - Properties
    
    /// 模型名称
    let modelName: String
    
    /// 包含模型的Bundle集合
    let bundles: [Bundle]
    
    /// 缓存控制参数
    private let cachingEnabled: Bool
    
    // 缓存属性
    private var modelURLCache: [String: URL] = [:]
    private var versionModelURLCache: [ModelVersion: URL] = [:]
    private var modelCache: [String: NSManagedObjectModel] = [:]
    private var mappingModelCache: [String: NSMappingModel] = [:]
    
    // 缓存统计
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    
    // 线程安全
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    /// 初始化资源管理器
    /// - Parameters:
    ///   - modelName: 模型名称
    ///   - bundle: 包含模型的 Bundle
    ///   - enableCaching: 是否启用缓存功能
    init(modelName: String, bundle: Bundle? = nil, enableCaching: Bool = true) {
        self.modelName = modelName
        self.bundles = [bundle ?? Bundle.main]
        self.cachingEnabled = enableCaching
    }
    
    // MARK: - Resource Loading Methods
    
    /// 获取模型URL
    /// - Returns: 模型URL
    func modelURL() -> URL? {
        let cacheKey = "baseModel"
        
        // 检查缓存
        if cachingEnabled {
            lock.lock()
            if let cachedURL = modelURLCache[cacheKey] {
                cacheHits += 1
                lock.unlock()
                print("缓存命中: 基础模型URL")
                return cachedURL
            }
            lock.unlock()
        }
        
        // 缓存未命中，执行查找
        lock.lock()
        cacheMisses += 1
        lock.unlock()
        
        print("缓存未命中: 搜索基础模型URL")
        
        // 查找模型URL
        var modelURL: URL? = nil
        
        // 检查是否有 .momd 目录（模型包）
        for bundle in bundles {
            if let url = bundle.url(forResource: modelName, withExtension: "momd") {
                modelURL = url
                print("找到模型目录: \(url.path)")
                break
            }
        }
        
        // 如果没有找到 .momd，则尝试直接查找 .mom 文件
        if modelURL == nil {
            for bundle in bundles {
                if let url = bundle.url(forResource: modelName, withExtension: "mom") {
                    modelURL = url
                    print("找到模型文件: \(url.path)")
                    break
                }
            }
        }
        
        // 更新缓存
        if let url = modelURL, cachingEnabled {
            lock.lock()
            modelURLCache[cacheKey] = url
            lock.unlock()
            print("已缓存基础模型URL: \(url.path)")
        }
        
        return modelURL
    }
    
    /// 获取指定版本的模型URL
    /// - Parameter version: 模型版本
    /// - Returns: 模型URL
    func modelURL(for version: ModelVersion) -> URL? {
        // 检查缓存
        if cachingEnabled {
            lock.lock()
            if let cachedURL = versionModelURLCache[version] {
                cacheHits += 1
                lock.unlock()
                print("缓存命中: 版本模型URL \(version)")
                return cachedURL
            }
            lock.unlock()
        }
        
        // 缓存未命中，执行查找
        lock.lock()
        cacheMisses += 1
        lock.unlock()
        
        print("缓存未命中: 搜索版本模型URL \(version)")
        
        // 构建版本化模型名称
        let versionedModelName = "\(modelName)_\(version.major).\(version.minor)"
        var modelURL: URL? = nil
        
        // 首先，尝试在主模型目录中查找
        if let baseURL = self.modelURL()?.deletingLastPathComponent() {
            let momdURL = baseURL.appendingPathComponent("\(modelName).momd")
            let versionedURL = momdURL.appendingPathComponent("\(versionedModelName).mom")
            
            if FileManager.default.fileExists(atPath: versionedURL.path) {
                modelURL = versionedURL
                print("在主模型目录中找到版本模型: \(versionedURL.path)")
            }
        }
        
        // 如果在主目录中未找到，则在所有 bundle 中搜索
        if modelURL == nil {
            for bundle in bundles {
                // 尝试直接查找版本化模型
                if let url = bundle.url(forResource: versionedModelName, withExtension: "mom") {
                    modelURL = url
                    print("在 bundle 中找到版本模型: \(url.path)")
                    break
                }
                
                // 检查 .momd 目录内
                if let momdURL = bundle.url(forResource: modelName, withExtension: "momd") {
                    let versionedURL = momdURL.appendingPathComponent("\(versionedModelName).mom")
                    if FileManager.default.fileExists(atPath: versionedURL.path) {
                        modelURL = versionedURL
                        print("在 .momd 目录中找到版本模型: \(versionedURL.path)")
                        break
                    }
                }
            }
        }
        
        // 更新缓存
        if let url = modelURL, cachingEnabled {
            lock.lock()
            versionModelURLCache[version] = url
            lock.unlock()
            print("已缓存版本模型URL: \(url.path) for \(version)")
        }
        
        return modelURL
    }
    
    /// 获取合并对象模型
    /// - Returns: 合并后的托管对象模型
    func mergedObjectModel() -> NSManagedObjectModel? {
        let cacheKey = "mergedModel"
        
        // 检查缓存
        if cachingEnabled {
            lock.lock()
            if let cachedModel = modelCache[cacheKey] {
                cacheHits += 1
                lock.unlock()
                print("缓存命中: 合并对象模型")
                return cachedModel
            }
            lock.unlock()
        }
        
        // 缓存未命中，执行加载
        lock.lock()
        cacheMisses += 1
        lock.unlock()
        
        print("缓存未命中: 加载合并对象模型")
        
        // 尝试从每个 bundle 创建合并模型
        var model: NSManagedObjectModel? = nil
        
        // 尝试从URL加载
        if let modelURL = self.modelURL() {
            model = NSManagedObjectModel(contentsOf: modelURL)
            print("从 URL 加载模型: \(modelURL.path)")
        }
        
        // 如果URL加载失败，尝试合并
        if model == nil {
            model = NSManagedObjectModel.mergedModel(from: bundles)
            print("从 bundles 合并模型")
        }
        
        // 更新缓存
        if let loadedModel = model, cachingEnabled {
            lock.lock()
            modelCache[cacheKey] = loadedModel
            lock.unlock()
            print("已缓存合并对象模型")
        }
        
        return model
    }
    
    /// 获取特定版本的模型
    /// - Parameter version: 模型版本
    /// - Returns: 托管对象模型
    func model(for version: ModelVersion) -> NSManagedObjectModel? {
        let cacheKey = "model_\(version)"
        
        // 检查缓存
        if cachingEnabled {
            lock.lock()
            if let cachedModel = modelCache[cacheKey] {
                cacheHits += 1
                lock.unlock()
                print("缓存命中: 版本对象模型 \(version)")
                return cachedModel
            }
            lock.unlock()
        }
        
        // 缓存未命中，执行加载
        lock.lock()
        cacheMisses += 1
        lock.unlock()
        
        print("缓存未命中: 加载版本对象模型 \(version)")
        
        var model: NSManagedObjectModel? = nil
        
        // 获取对应版本的URL
        if let modelURL = modelURL(for: version) {
            model = NSManagedObjectModel(contentsOf: modelURL)
            print("从 URL 加载版本模型: \(modelURL.path)")
        }
        
        // 更新缓存
        if let loadedModel = model, cachingEnabled {
            lock.lock()
            modelCache[cacheKey] = loadedModel
            lock.unlock()
            print("已缓存版本对象模型: \(version)")
        }
        
        return model
    }
    
    /// 获取映射模型
    /// - Parameters:
    ///   - sourceVersion: 源版本
    ///   - destinationVersion: 目标版本
    /// - Returns: 映射模型
    func mappingModel(from sourceVersion: ModelVersion, to destinationVersion: ModelVersion) -> NSMappingModel? {
        let cacheKey = "mapping_\(sourceVersion)_\(destinationVersion)"
        
        // 检查缓存
        if cachingEnabled {
            lock.lock()
            if let cachedModel = mappingModelCache[cacheKey] {
                cacheHits += 1
                lock.unlock()
                print("缓存命中: 映射模型 \(sourceVersion) -> \(destinationVersion)")
                return cachedModel
            }
            lock.unlock()
        }
        
        // 缓存未命中，执行加载
        lock.lock()
        cacheMisses += 1
        lock.unlock()
        
        print("缓存未命中: 加载映射模型 \(sourceVersion) -> \(destinationVersion)")
        
        var mappingModel: NSMappingModel? = nil
        
        // 尝试查找手动创建的映射模型
        // 命名格式：
        // 1. Mapping_1.0_to_2.0.cdm
        // 2. ModelName_1.0_to_2.0.cdm
        // 3. ModelNameMapping_1.0_to_2.0.cdm
        let mappingFormats = [
            "Mapping_\(sourceVersion)_to_\(destinationVersion).cdm",
            "\(modelName)_\(sourceVersion)_to_\(destinationVersion).cdm",
            "\(modelName)Mapping_\(sourceVersion)_to_\(destinationVersion).cdm"
        ]
        
        mappingLoop: for mappingName in mappingFormats {
            for bundle in bundles {
                if let url = bundle.url(forResource: mappingName.components(separatedBy: ".").first, withExtension: "cdm") {
                    mappingModel = NSMappingModel(contentsOf: url)
                    if mappingModel != nil {
                        print("找到手动创建的映射模型: \(url.path)")
                        break mappingLoop
                    }
                }
            }
        }
        
        // 如果没有找到手动创建的映射模型，尝试推断映射模型
        if mappingModel == nil, 
           let sourceModel = model(for: sourceVersion),
           let destinationModel = model(for: destinationVersion) {
            do {
                mappingModel = try NSMappingModel.inferredMappingModel(
                    forSourceModel: sourceModel,
                    destinationModel: destinationModel
                )
                if mappingModel != nil {
                    print("已推断映射模型: \(sourceVersion) -> \(destinationVersion)")
                }
            } catch {
                print("无法创建自动映射模型: \(error.localizedDescription)")
            }
        }
        
        // 更新缓存
        if let loadedModel = mappingModel, cachingEnabled {
            lock.lock()
            mappingModelCache[cacheKey] = loadedModel
            lock.unlock()
            print("已缓存映射模型: \(sourceVersion) -> \(destinationVersion)")
        }
        
        return mappingModel
    }
    
    // MARK: - Cache Management
    
    /// 清除指定类型的缓存
    /// - Parameter type: 要清除的缓存类型
    func clearCache(_ type: CacheType) {
        guard cachingEnabled else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        print("清除缓存: \(type)")
        
        if type.contains(.modelURL) {
            modelURLCache.removeAll()
            print("已清除基础模型URL缓存")
        }
        
        if type.contains(.versionModelURL) {
            versionModelURLCache.removeAll()
            print("已清除版本模型URL缓存")
        }
        
        if type.contains(.model) {
            modelCache.removeAll()
            print("已清除对象模型缓存")
        }
        
        if type.contains(.mappingModel) {
            mappingModelCache.removeAll()
            print("已清除映射模型缓存")
        }
    }
    
    /// 获取缓存统计
    /// - Returns: 缓存统计信息
    func cacheStatistics() -> CacheStatistics {
        lock.lock()
        let stats = CacheStatistics(hits: cacheHits, misses: cacheMisses)
        lock.unlock()
        return stats
    }
    
    /// 预加载常用的资源到缓存中
    /// 此方法可在应用启动时或进入数据密集型部分之前调用，以提前填充缓存
    func preloadCommonResources() {
        guard cachingEnabled else {
            print("预加载被跳过，因为缓存已禁用")
            return
        }
        
        print("开始预加载常用资源")
        
        // 预加载基本模型 URL
        _ = self.modelURL()
        
        // 预加载合并对象模型
        _ = self.mergedObjectModel()
        
        // 输出缓存统计
        let stats = self.cacheStatistics()
        print("资源预加载完成。缓存命中: \(stats.hits), 未命中: \(stats.misses), 命中率: \(stats.hitRate)")
    }
}

// MARK: - Demo Code

class CacheDemo {
    static func run() {
        print("===== CoreData Resource Manager 缓存演示 =====\n")
        
        // 原有测试
        testBasicModelURLCaching()
        testVersionedModelURLCaching()
        testPreloadAndCacheStatistics()
        testCacheClearing()
        
        // 新增性能比较测试
        testPerformanceComparison()
        
        print("演示完成!")
    }
    
    static func testBasicModelURLCaching() {
        print("\n测试 1: 重复访问基本模型URL")
        
        // 创建启用缓存的资源管理器
        let cachedManager = CoreDataResourceManager(
            modelName: "DemoModel",
            enableCaching: true
        )
        
        // 创建禁用缓存的资源管理器
        let uncachedManager = CoreDataResourceManager(
            modelName: "DemoModel",
            enableCaching: false
        )
        
        measurePerformance("有缓存") {
            for _ in 0..<100 {
                _ = cachedManager.modelURL()
            }
        }
        
        measurePerformance("无缓存") {
            for _ in 0..<100 {
                _ = uncachedManager.modelURL()
            }
        }
    }
    
    static func testVersionedModelURLCaching() {
        print("\n测试 2: 访问版本化模型")
        
        let v1 = ModelVersion(major: 1, minor: 0, patch: 0)
        let v2 = ModelVersion(major: 2, minor: 0, patch: 0)
        
        // 创建启用缓存的资源管理器
        let cachedManager = CoreDataResourceManager(
            modelName: "DemoModel",
            enableCaching: true
        )
        
        // 创建禁用缓存的资源管理器
        let uncachedManager = CoreDataResourceManager(
            modelName: "DemoModel",
            enableCaching: false
        )
        
        measurePerformance("有缓存") {
            for _ in 0..<50 {
                _ = cachedManager.modelURL(for: v1)
                _ = cachedManager.modelURL(for: v2)
            }
        }
        
        measurePerformance("无缓存") {
            for _ in 0..<50 {
                _ = uncachedManager.modelURL(for: v1)
                _ = uncachedManager.modelURL(for: v2)
            }
        }
    }
    
    static func testPreloadAndCacheStatistics() {
        print("\n测试 3: 预加载和缓存统计")
        
        // 清除缓存
        let cachedManager = CoreDataResourceManager(modelName: "DemoModel", enableCaching: true)
        cachedManager.clearCache(.all)
        
        // 执行预加载
        cachedManager.preloadCommonResources()
        
        // 显示缓存统计
        let stats = cachedManager.cacheStatistics()
        print("预加载后缓存统计:")
        print("- 命中次数: \(stats.hits)")
        print("- 未命中次数: \(stats.misses)")
        print("- 命中率: \(String(format: "%.2f%%", stats.hitRate * 100))")
    }
    
    static func testCacheClearing() {
        print("\n测试 4: 缓存清除")
        
        // 填充缓存
        let cachedManager = CoreDataResourceManager(modelName: "DemoModel", enableCaching: true)
        _ = cachedManager.modelURL()
        _ = cachedManager.modelURL(for: ModelVersion(major: 1, minor: 0, patch: 0))
        _ = cachedManager.mergedObjectModel()
        
        print("清除前缓存统计: \(cachedManager.cacheStatistics().hits) 命中, \(cachedManager.cacheStatistics().misses) 未命中")
        
        // 清除部分缓存
        cachedManager.clearCache(.modelURL)
        
        // 重新访问
        _ = cachedManager.modelURL()
        _ = cachedManager.modelURL(for: ModelVersion(major: 1, minor: 0, patch: 0))
        
        print("部分清除后缓存统计: \(cachedManager.cacheStatistics().hits) 命中, \(cachedManager.cacheStatistics().misses) 未命中")
        
        // 清除所有缓存
        cachedManager.clearCache(.all)
        
        // 重新访问
        _ = cachedManager.modelURL()
        _ = cachedManager.modelURL(for: ModelVersion(major: 1, minor: 0, patch: 0))
        
        print("完全清除后缓存统计: \(cachedManager.cacheStatistics().hits) 命中, \(cachedManager.cacheStatistics().misses) 未命中")
    }
    
    static func testPerformanceComparison() {
        print("\n测试 5: 缓存性能比较")
        
        // 创建一个带缓存的资源管理器
        let cachedManager = CoreDataResourceManager(modelName: "TestModel", bundles: [], cachingEnabled: true)
        
        // 创建一个不带缓存的资源管理器
        let uncachedManager = CoreDataResourceManager(modelName: "TestModel", bundles: [], cachingEnabled: false)
        
        // 清除缓存，确保测试起点相同
        cachedManager.clearCache(.all)
        
        // 预热阶段 - 加载一些资源到缓存
        for _ in 0..<10 {
            _ = cachedManager.modelURL()
            _ = cachedManager.modelURL(for: ModelVersion(major: 1, minor: 0, patch: 0))
            _ = cachedManager.modelURL(for: ModelVersion(major: 2, minor: 0, patch: 0))
        }
        
        // 测试批量操作 - 有缓存
        let cachedStartTime = Date()
        for _ in 0..<500 {
            _ = cachedManager.modelURL()
            _ = cachedManager.modelURL(for: ModelVersion(major: 1, minor: 0, patch: 0))
            _ = cachedManager.modelURL(for: ModelVersion(major: 2, minor: 0, patch: 0))
        }
        let cachedDuration = Date().timeIntervalSince(cachedStartTime)
        
        // 测试批量操作 - 无缓存
        let uncachedStartTime = Date()
        for _ in 0..<500 {
            _ = uncachedManager.modelURL()
            _ = uncachedManager.modelURL(for: ModelVersion(major: 1, minor: 0, patch: 0))
            _ = uncachedManager.modelURL(for: ModelVersion(major: 2, minor: 0, patch: 0))
        }
        let uncachedDuration = Date().timeIntervalSince(uncachedStartTime)
        
        // 计算性能差异
        let performanceImprovement = (uncachedDuration / cachedDuration) - 1.0
        let percentImprovement = performanceImprovement * 100
        
        print("性能测试结果:")
        print("- 启用缓存执行时间: \(String(format: "%.4f", cachedDuration)) 秒")
        print("- 禁用缓存执行时间: \(String(format: "%.4f", uncachedDuration)) 秒")
        print("- 性能提升: \(String(format: "%.2f", percentImprovement))%")
        
        // 缓存命中率
        let stats = cachedManager.cacheStatistics()
        print("- 缓存命中率: \(String(format: "%.2f", stats.hitRate * 100))%")
        print("- 总请求次数: \(stats.hits + stats.misses)")
        print("- 缓存命中次数: \(stats.hits)")
    }
    
    static func measurePerformance(_ label: String, operation: () -> Void) {
        let start = CFAbsoluteTimeGetCurrent()
        operation()
        let time = CFAbsoluteTimeGetCurrent() - start
        print("\(label) 执行时间: \(String(format: "%.3f", time)) 秒")
    }
}

// 运行演示
print("开始运行 CoreDataResourceManager 缓存演示...")
CacheDemo.run()
print("演示完成!") 