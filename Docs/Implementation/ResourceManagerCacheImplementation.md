# CoreDataResourceManager 资源缓存实现计划

## 概述

本文档详细描述了为 `CoreDataResourceManager` 添加资源缓存功能的实现计划。缓存策略旨在减少重复加载资源的开销，提高应用性能，特别是在频繁访问相同资源的情况下。

## 当前状况

目前，`CoreDataResourceManager` 在每次请求资源时都会执行完整的资源查找过程，包括：

1. 在多个 Bundle 中查找模型 URL
2. 从 URL 加载模型
3. 查找并加载映射模型

这种方式在资源频繁访问时效率低下，特别是在应用启动和数据迁移期间。

## 实现目标

通过添加缓存机制，我们期望：

1. 减少重复资源查找和加载的时间
2. 降低应用启动时的资源加载延迟
3. 提高迁移操作的性能
4. 减少内存和 CPU 占用

## 性能目标

| 操作 | 当前性能 | 目标性能 | 提升百分比 |
|-----|---------|---------|-----------|
| 加载合并模型 | ~150ms | <50ms | >66% |
| 加载特定版本模型 | ~100ms | <30ms | >70% |
| 加载映射模型 | ~120ms | <40ms | >66% |

## 实现步骤

### 1. 添加缓存属性

在 `CoreDataResourceManager` 类中添加以下缓存属性：

```swift
/// 模型 URL 缓存
private var modelURLCache: [String: URL] = [:]

/// 版本模型 URL 缓存
private var versionModelURLCache: [String: URL] = [:]

/// 模型对象缓存
private var modelCache: [String: NSManagedObjectModel] = [:]

/// 映射模型缓存
private var mappingModelCache: [String: NSMappingModel] = [:]

/// 缓存统计
private var cacheHits: Int = 0
private var cacheMisses: Int = 0
```

### 2. 修改 modelURL() 方法

```swift
public func modelURL() -> URL? {
    // 检查缓存
    if let cachedURL = modelURLCache["default"] {
        cacheHits += 1
        return cachedURL
    }
    
    cacheMisses += 1
    
    // 原始查找逻辑
    let foundURL = findModelURL()
    
    // 存入缓存
    if let url = foundURL {
        modelURLCache["default"] = url
    }
    
    return foundURL
}
```

### 3. 修改 modelURL(for:) 方法

```swift
public func modelURL(for version: ModelVersion) -> URL? {
    let cacheKey = version.identifier
    
    // 检查缓存
    if let cachedURL = versionModelURLCache[cacheKey] {
        cacheHits += 1
        return cachedURL
    }
    
    cacheMisses += 1
    
    // 原始查找逻辑
    // ...省略现有逻辑...
    
    // 存入缓存
    if let url = foundURL {
        versionModelURLCache[cacheKey] = url
    }
    
    return foundURL
}
```

### 4. 修改 model(for:) 方法

```swift
public func model(for version: ModelVersion) -> NSManagedObjectModel? {
    let cacheKey = version.identifier
    
    // 检查缓存
    if let cachedModel = modelCache[cacheKey] {
        cacheHits += 1
        return cachedModel
    }
    
    cacheMisses += 1
    
    // 加载模型
    guard let url = modelURL(for: version) else {
        return nil
    }
    
    guard let model = NSManagedObjectModel(contentsOf: url) else {
        return nil
    }
    
    // 存入缓存
    modelCache[cacheKey] = model
    
    return model
}
```

### 5. 修改 mergedObjectModel() 方法

```swift
public func mergedObjectModel() -> NSManagedObjectModel? {
    // 检查缓存
    if let cachedModel = modelCache["merged"] {
        cacheHits += 1
        return cachedModel
    }
    
    cacheMisses += 1
    
    // 原始加载逻辑
    let model: NSManagedObjectModel?
    
    // 首先尝试从所有 Bundles 合并模型
    if let mergedModel = NSManagedObjectModel.mergedModel(from: searchBundles) {
        model = mergedModel
    }
    // 如果合并失败，尝试直接加载单个模型文件
    else if let modelURL = findModelURL() {
        model = NSManagedObjectModel(contentsOf: modelURL)
    }
    else {
        Logger.error("无法加载合并模型或单个模型文件", category: .coreData)
        model = nil
    }
    
    // 存入缓存
    if let model = model {
        modelCache["merged"] = model
    }
    
    return model
}
```

### 6. 修改 mappingModel(from:to:) 方法

```swift
public func mappingModel(from sourceVersion: ModelVersion, to destinationVersion: ModelVersion) -> NSMappingModel? {
    let cacheKey = "mapping_\(sourceVersion.identifier)_to_\(destinationVersion.identifier)"
    
    // 检查缓存
    if let cachedModel = mappingModelCache[cacheKey] {
        cacheHits += 1
        return cachedModel
    }
    
    cacheMisses += 1
    
    // 原始查找和加载逻辑
    // ...省略现有逻辑...
    
    // 存入缓存
    if let mappingModel = foundMappingModel {
        mappingModelCache[cacheKey] = mappingModel
    }
    
    return foundMappingModel
}
```

### 7. 添加缓存管理方法

```swift
/// 清除特定类型的缓存
public func clearCache(_ cacheType: CacheType) {
    switch cacheType {
    case .modelURL:
        modelURLCache.removeAll()
        versionModelURLCache.removeAll()
    case .model:
        modelCache.removeAll()
    case .mappingModel:
        mappingModelCache.removeAll()
    case .all:
        modelURLCache.removeAll()
        versionModelURLCache.removeAll()
        modelCache.removeAll()
        mappingModelCache.removeAll()
    }
    
    Logger.info("已清除 \(cacheType) 缓存", category: .coreData)
}

/// 获取缓存统计信息
public func cacheStatistics() -> (hits: Int, misses: Int, hitRate: Double) {
    let total = cacheHits + cacheMisses
    let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
    return (cacheHits, cacheMisses, hitRate)
}

/// 缓存类型枚举
public enum CacheType {
    case modelURL
    case model
    case mappingModel
    case all
}
```

### 8. 添加预加载方法

```swift
/// 预加载常用资源
public func preloadCommonResources() {
    Task {
        // 预加载合并模型
        _ = self.mergedObjectModel()
        
        // 预加载当前版本和前一版本
        if let currentVersion = try? CoreDataModelVersionManager(resourceManager: self).destinationModelVersion() {
            _ = self.model(for: currentVersion)
            
            // 如果有前一版本，也预加载
            if currentVersion.major > 1 || currentVersion.minor > 0 {
                let previousVersion: ModelVersion
                if currentVersion.minor > 0 {
                    previousVersion = ModelVersion(major: currentVersion.major, minor: currentVersion.minor - 1, patch: 0)
                } else {
                    previousVersion = ModelVersion(major: currentVersion.major - 1, minor: 0, patch: 0)
                }
                
                _ = self.model(for: previousVersion)
                _ = self.mappingModel(from: previousVersion, to: currentVersion)
            }
        }
        
        Logger.info("已预加载常用资源", category: .coreData)
    }
}
```

### 9. 更新初始化方法

```swift
public init(
    modelName: String = "OnlySlide",
    bundle: Bundle = .main,
    additionalBundles: [Bundle] = [],
    enableCaching: Bool = true
) {
    self.modelName = modelName
    self.primaryBundle = bundle
    self.additionalBundles = additionalBundles
    self.cachingEnabled = enableCaching
    
    // 如果启用缓存，预加载常用资源
    if enableCaching {
        Task { 
            self.preloadCommonResources()
        }
    }
}
```

## 测试计划

1. **单元测试**：
   - 创建 `CoreDataResourceManagerCacheTests` 测试类
   - 测试缓存命中和未命中情况
   - 测试缓存清除功能
   - 测试预加载功能

2. **性能测试**：
   - 测试缓存前后的资源加载性能
   - 测试缓存对迁移性能的影响
   - 测量内存使用情况

3. **集成测试**：
   - 测试在实际应用场景中的性能提升
   - 验证缓存与迁移流程的兼容性

## 示例测试代码

```swift
class CoreDataResourceManagerCacheTests: XCTestCase {
    
    var resourceManager: CoreDataResourceManager!
    
    override func setUp() {
        super.setUp()
        resourceManager = CoreDataResourceManager(enableCaching: true)
    }
    
    override func tearDown() {
        resourceManager.clearCache(.all)
        resourceManager = nil
        super.tearDown()
    }
    
    func testCacheHit() {
        // 第一次加载 - 缓存未命中
        let model1 = resourceManager.mergedObjectModel()
        
        // 第二次加载 - 应该从缓存获取
        let model2 = resourceManager.mergedObjectModel()
        
        // 验证缓存统计
        let stats = resourceManager.cacheStatistics()
        XCTAssertEqual(stats.hits, 1)
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.hitRate, 0.5)
    }
    
    func testCachePerformance() {
        // 测量无缓存性能
        let uncachedManager = CoreDataResourceManager(enableCaching: false)
        measure {
            _ = uncachedManager.mergedObjectModel()
        }
        
        // 预热缓存
        _ = resourceManager.mergedObjectModel()
        
        // 测量有缓存性能
        measure {
            _ = resourceManager.mergedObjectModel()
        }
    }
}
```

## 风险和缓解策略

| 风险 | 可能性 | 影响 | 缓解策略 |
|-----|-------|-----|---------|
| 缓存导致过时数据 | 中 | 高 | 在特定事件（如应用更新）后清除缓存 |
| 内存使用增加 | 高 | 中 | 优化缓存大小，仅缓存常用资源 |
| 线程安全问题 | 中 | 高 | 确保缓存操作是线程安全的 |
| 缓存逻辑错误 | 低 | 高 | 全面的单元测试和集成测试 |

## 线程安全考虑

为确保缓存操作的线程安全，我们将：

1. 利用 `CoreDataResourceManager` 已有的 `@MainActor` 标记
2. 对缓存字典的访问使用锁或并发安全的结构

```swift
@MainActor public final class CoreDataResourceManager: @unchecked Sendable {
    // 使用线程安全的缓存实现
    private let cacheLock = NSLock()
    
    // 线程安全的缓存读取
    private func getCachedValue<T>(from cache: [String: T], forKey key: String) -> T? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache[key]
    }
    
    // 线程安全的缓存写入
    private func setCachedValue<T>(_ value: T, in cache: inout [String: T], forKey key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache[key] = value
    }
}
```

## 实现时间表

| 任务 | 预计时间 | 优先级 |
|-----|---------|-------|
| 添加缓存属性和基础结构 | 1 天 | 高 |
| 修改资源加载方法 | 2 天 | 高 |
| 添加缓存管理方法 | 1 天 | 中 |
| 实现预加载功能 | 1 天 | 中 |
| 添加线程安全机制 | 1 天 | 高 |
| 编写单元测试 | 2 天 | 高 |
| 性能测试和优化 | 2 天 | 中 |
| 文档和代码审查 | 1 天 | 中 |

总计：约 11 个工作日

## 结论

通过实现 `CoreDataResourceManager` 的资源缓存功能，我们预计可以显著提高资源加载性能，特别是在应用启动和数据迁移过程中。缓存策略的设计要平衡性能提升和内存使用，同时确保缓存的线程安全和数据一致性。

实施这一优化是 CoreData 性能优化计划的第一步，为后续更复杂的优化奠定基础。 