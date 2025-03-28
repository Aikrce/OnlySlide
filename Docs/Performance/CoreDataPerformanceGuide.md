# CoreData 性能优化指南

本文档提供了关于 CoreData 性能优化的全面指南，特别关注 `CoreDataResourceManager` 和数据迁移过程的性能优化策略。

## 目录

1. [资源加载性能优化](#资源加载性能优化)
2. [查询性能优化](#查询性能优化)
3. [迁移性能优化](#迁移性能优化)
4. [批量操作优化](#批量操作优化)
5. [内存管理优化](#内存管理优化)
6. [后台操作优化](#后台操作优化)
7. [性能测试与基准](#性能测试与基准)
8. [性能监控与分析](#性能监控与分析)

## 资源加载性能优化

### CoreDataResourceManager 缓存策略

`CoreDataResourceManager` 目前在每次调用时都会进行资源查找，这可能导致重复工作。实现缓存策略可以显著提高性能：

```swift
@MainActor public final class CoreDataResourceManager: @unchecked Sendable {
    // ... 现有代码 ...
    
    // 添加模型缓存
    private var modelCache: [String: NSManagedObjectModel] = [:]
    private var modelURLCache: [String: URL] = [:]
    private var mappingModelCache: [String: NSMappingModel] = [:]
    
    // 修改 model(for:) 方法使用缓存
    public func model(for version: ModelVersion) -> NSManagedObjectModel? {
        let cacheKey = "\(modelName)_\(version.identifier)"
        
        // 检查缓存
        if let cachedModel = modelCache[cacheKey] {
            return cachedModel
        }
        
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
    
    // 类似地修改其他资源加载方法
    // ...
}
```

### 预加载常用资源

在应用启动时预加载常用的模型和映射模型：

```swift
// 在应用启动时调用
func preloadCommonResources() {
    Task {
        // 预加载当前模型
        _ = resourceManager.mergedObjectModel()
        
        // 预加载最常用的版本
        let currentVersion = ModelVersion(major: 1, minor: 5, patch: 0)
        let previousVersion = ModelVersion(major: 1, minor: 4, patch: 0)
        
        // 预加载模型
        _ = resourceManager.model(for: currentVersion)
        _ = resourceManager.model(for: previousVersion)
        
        // 预加载映射模型
        _ = resourceManager.mappingModel(from: previousVersion, to: currentVersion)
    }
}
```

### 优化 Bundle 搜索

当前的 Bundle 搜索可能会遍历多个位置。我们可以根据以往的成功查找结果调整搜索顺序：

```swift
// 跟踪成功的搜索位置
private var successfulSearchPaths: [String: String] = [:]

// 优化搜索顺序
private func optimizedBundleSearch(for resourceType: String, name: String) -> URL? {
    let cacheKey = "\(resourceType)_\(name)"
    
    // 如果之前找到过，先检查那个路径
    if let successPath = successfulSearchPaths[cacheKey],
       let successBundle = Bundle(path: successPath),
       let resourceURL = findResource(ofType: resourceType, named: name, in: successBundle) {
        return resourceURL
    }
    
    // 正常搜索
    for bundle in searchBundles {
        if let resourceURL = findResource(ofType: resourceType, named: name, in: bundle) {
            // 记录成功的搜索路径
            successfulSearchPaths[cacheKey] = bundle.bundlePath
            return resourceURL
        }
    }
    
    return nil
}
```

## 查询性能优化

### 添加索引

在 CoreData 模型中为经常用于查询的属性添加索引：

1. 打开 `.xcdatamodeld` 文件
2. 选择实体和属性
3. 在属性的 Inspectors 面板中勾选 "Indexed"
4. 为复合查询添加复合索引

### 批量查询

使用批量查询减少内存使用和提高大数据集的查询效率：

```swift
let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Slide")
fetchRequest.fetchBatchSize = 100

let asyncFetchRequest = NSAsynchronousFetchRequest(fetchRequest: fetchRequest) { result in
    guard let slides = result.finalResult as? [Slide] else { return }
    // 处理结果
}

try context.execute(asyncFetchRequest)
```

### 预取关系

当需要访问关系时，使用预取减少查询次数：

```swift
let fetchRequest: NSFetchRequest<Presentation> = Presentation.fetchRequest()
fetchRequest.relationshipKeyPathsForPrefetching = ["slides", "author"]
```

### 使用合适的谓词

优化查询谓词以提高查询效率：

```swift
// 不推荐 - 使用通配符开头的 LIKE 查询
let badPredicate = NSPredicate(format: "title LIKE[cd] %@", "*presentation*")

// 推荐 - 使用 CONTAINS 或 BEGINSWITH
let goodPredicate = NSPredicate(format: "title CONTAINS[cd] %@", "presentation")
```

## 迁移性能优化

### 渐进式迁移

对于复杂的模型变化，使用多个中间步骤进行渐进式迁移，而不是一次性迁移：

```swift
// 迁移路径计算
func migrationPath(from sourceVersion: ModelVersion, to destinationVersion: ModelVersion) -> [ModelVersion] {
    // 如果版本差异大，创建中间步骤
    if destinationVersion.major > sourceVersion.major + 1 {
        var path: [ModelVersion] = [sourceVersion]
        
        // 添加中间版本
        for major in sourceVersion.major + 1...destinationVersion.major {
            path.append(ModelVersion(major: major, minor: 0, patch: 0))
        }
        
        return path
    }
    
    // 简单迁移路径
    return [sourceVersion, destinationVersion]
}
```

### 映射模型优化

创建自定义映射模型，避免使用自动推断的映射模型：

```swift
// 自定义映射模型逻辑
func customMappingModel(from sourceModel: NSManagedObjectModel, to destinationModel: NSManagedObjectModel) -> NSMappingModel {
    // 创建自定义映射模型
    let mappingModel = NSMappingModel()
    
    // 配置实体映射
    // ...
    
    return mappingModel
}
```

### 并行迁移

对大型数据集，考虑使用并行迁移技术：

```swift
func performParallelMigration(at storeURL: URL, to destinationURL: URL) async throws {
    // 将数据拆分为多个子集
    let subsets = try await splitDataIntoSubsets(at: storeURL)
    
    // 并行迁移每个子集
    try await withThrowingTaskGroup(of: Void.self) { group in
        for subset in subsets {
            group.addTask {
                try await self.migrateSubset(subset, to: destinationURL)
            }
        }
    }
    
    // 合并结果
    try await mergeSubsets(to: destinationURL)
}
```

## 批量操作优化

### 批量插入

使用批量插入减少上下文保存频率：

```swift
// 批量插入数据
func batchInsertItems(items: [[String: Any]], entityName: String, in context: NSManagedObjectContext) throws {
    let batchInsertRequest = NSBatchInsertRequest(entityName: entityName, objects: items)
    batchInsertRequest.resultType = .statusOnly
    
    let result = try context.execute(batchInsertRequest) as! NSBatchInsertResult
    if let status = result.result as? Bool, status {
        print("批量插入成功")
    }
}
```

### 批量更新

使用批量更新减少内存使用和提高性能：

```swift
// 批量更新数据
func batchUpdateItems(entityName: String, propertiesToUpdate: [String: Any], predicate: NSPredicate, in context: NSManagedObjectContext) throws {
    let batchUpdateRequest = NSBatchUpdateRequest(entityName: entityName)
    batchUpdateRequest.propertiesToUpdate = propertiesToUpdate
    batchUpdateRequest.predicate = predicate
    batchUpdateRequest.resultType = .statusOnly
    
    let result = try context.execute(batchUpdateRequest) as! NSBatchUpdateResult
    if let status = result.result as? Bool, status {
        print("批量更新成功")
    }
}
```

### 批量删除

使用批量删除提高大量数据的删除效率：

```swift
// 批量删除数据
func batchDeleteItems(entityName: String, predicate: NSPredicate, in context: NSManagedObjectContext) throws {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
    fetchRequest.predicate = predicate
    
    let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
    batchDeleteRequest.resultType = .resultTypeStatusOnly
    
    let result = try context.execute(batchDeleteRequest) as! NSBatchDeleteResult
    if let status = result.result as? Bool, status {
        print("批量删除成功")
    }
}
```

## 内存管理优化

### 持久历史跟踪

启用持久历史跟踪以更好地管理多上下文环境中的变更：

```swift
// 配置持久存储协调器
let persistentStoreDescription = NSPersistentStoreDescription(url: storeURL)
persistentStoreDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
persistentStoreDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

let container = NSPersistentContainer(name: "MyModel")
container.persistentStoreDescriptions = [persistentStoreDescription]
```

### 上下文重置

定期重置不再需要的上下文，减少内存占用：

```swift
// 在处理大量数据后重置上下文
func processLargeDataSet(in context: NSManagedObjectContext) throws {
    var count = 0
    
    for item in largeDataSet {
        // 处理数据
        let entity = NSEntityDescription.insertNewObject(forEntityName: "Item", into: context)
        // 设置属性...
        
        count += 1
        
        // 每处理1000条数据，保存并重置上下文
        if count % 1000 == 0 {
            try context.save()
            context.reset()
        }
    }
    
    // 保存最后的更改
    try context.save()
}
```

### 临时对象

使用临时对象减少内存占用：

```swift
// 创建临时对象
let temporaryContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
temporaryContext.persistentStoreCoordinator = coordinator
temporaryContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

temporaryContext.perform {
    let temporaryObject = NSEntityDescription.insertNewObject(forEntityName: "Item", into: temporaryContext)
    // 处理临时对象
    // ...
    
    // 完成后不保存，直接丢弃
    temporaryContext.reset()
}
```

## 后台操作优化

### 队列与线程管理

创建适当的队列结构，确保 CoreData 操作在正确的线程上执行：

```swift
// 设置 CoreData 堆栈
lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: "MyModel")
    container.loadPersistentStores { _, error in
        if let error = error {
            fatalError("无法加载持久化存储: \(error)")
        }
    }
    return container
}()

// 主上下文
lazy var mainContext: NSManagedObjectContext = {
    return persistentContainer.viewContext
}()

// 后台上下文
func newBackgroundContext() -> NSManagedObjectContext {
    let context = persistentContainer.newBackgroundContext()
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    return context
}

// 在后台执行操作
func performBackgroundTask(_ task: @escaping (NSManagedObjectContext) -> Void) {
    let context = newBackgroundContext()
    context.perform {
        task(context)
    }
}
```

### 预加载与缓存

在后台线程中预加载数据并缓存结果：

```swift
// 预加载器
class DataPreloader {
    let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // 预加载常用数据
    func preloadCommonData() {
        context.perform {
            // 加载常用查询结果并缓存
            let fetchRequest: NSFetchRequest<RecentItem> = RecentItem.fetchRequest()
            fetchRequest.fetchLimit = 100
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastAccessDate", ascending: false)]
            
            do {
                let recentItems = try self.context.fetch(fetchRequest)
                // 缓存结果
                CacheManager.shared.storeItems(recentItems)
            } catch {
                print("预加载失败: \(error)")
            }
        }
    }
}
```

## 性能测试与基准

### 创建性能测试

为关键操作创建性能测试：

```swift
// CoreDataPerformanceTests.swift
import XCTest
@testable import YourApp

class CoreDataPerformanceTests: XCTestCase {
    
    var coreDataStack: CoreDataStack!
    
    override func setUp() {
        super.setUp()
        // 设置测试环境
        coreDataStack = TestCoreDataStack()
    }
    
    override func tearDown() {
        // 清理测试环境
        coreDataStack = nil
        super.tearDown()
    }
    
    // 测试查询性能
    func testFetchPerformance() {
        // 准备测试数据
        prepareTestData(count: 1000)
        
        // 测量性能
        measure {
            // 执行查询
            let fetchRequest: NSFetchRequest<TestEntity> = TestEntity.fetchRequest()
            do {
                let results = try coreDataStack.mainContext.fetch(fetchRequest)
                XCTAssertEqual(results.count, 1000)
            } catch {
                XCTFail("查询失败: \(error)")
            }
        }
    }
    
    // 测试迁移性能
    func testMigrationPerformance() {
        // 准备需要迁移的测试存储
        let sourceStoreURL = prepareTestStore(version: "1.0")
        
        // 测量性能
        measure {
            // 执行迁移
            do {
                let migrationManager = CoreDataMigrationManager.shared
                let migrated = try migrationManager.migrateStore(at: sourceStoreURL, toVersion: "2.0")
                XCTAssertTrue(migrated)
            } catch {
                XCTFail("迁移失败: \(error)")
            }
        }
    }
    
    // 测试资源加载性能
    func testResourceManagerPerformance() {
        let resourceManager = CoreDataResourceManager()
        
        // 测量性能
        measure {
            // 执行资源加载
            let model = resourceManager.mergedObjectModel()
            XCTAssertNotNil(model)
        }
    }
}
```

### 建立性能基准

为各种操作建立性能基准，作为优化的参考：

| 操作 | 数据量 | 基准时间 | 目标时间 |
|-----|--------|---------|---------|
| 加载合并模型 | N/A | 150ms | <100ms |
| 查询全部实体 | 100 条 | 50ms | <30ms |
| 查询全部实体 | 1000 条 | 300ms | <200ms |
| 批量插入 | 1000 条 | 1200ms | <800ms |
| 完整迁移 | 1000 条 | 5000ms | <3000ms |

## 性能监控与分析

### 实现性能监控

在关键操作中添加性能监控：

```swift
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private init() {}
    
    // 测量操作执行时间
    func measure<T>(operation: String, _ block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // 记录性能数据
        logPerformance(operation: operation, time: timeElapsed)
        
        return result
    }
    
    // 记录性能数据
    private func logPerformance(operation: String, time: CFAbsoluteTime) {
        #if DEBUG
        print("性能监控: \(operation) 耗时 \(time * 1000)ms")
        #endif
        
        // 将数据存储到性能日志
        storePerformanceData(operation: operation, time: time)
    }
    
    // 存储性能数据
    private func storePerformanceData(operation: String, time: CFAbsoluteTime) {
        // 实现存储逻辑，如写入文件或发送到分析服务
    }
}

// 使用方法
let result = PerformanceMonitor.shared.measure(operation: "加载模型") {
    return resourceManager.mergedObjectModel()
}
```

### 使用 Instruments 进行性能分析

利用 Xcode 的 Instruments 工具进行详细的性能分析：

1. 在 Xcode 中选择 Product > Profile (⌘+I)
2. 选择 Time Profiler 或 Allocations 工具
3. 运行应用并执行需要分析的操作
4. 分析结果，找出性能瓶颈

重点关注的性能指标：

- **CPU 使用率**：查看耗时操作
- **内存分配**：找出内存泄漏或过度分配
- **I/O 操作**：分析文件读写效率
- **垃圾回收**：分析内存管理效率

## 结论

通过实施本文档中的性能优化策略，可以显著提高 CoreData 操作的效率，特别是在资源加载、查询和迁移方面。优化应该是一个持续的过程，结合性能监控、基准测试和用户反馈不断改进。

在 OnlySlide 应用中，我们将首先实施资源加载缓存策略和批量操作优化，这些改进预计将带来最直接的性能提升。后续将根据性能监控数据进一步优化其他方面。

---

### 附录：性能优化清单

- [ ] 实现 `CoreDataResourceManager` 的资源缓存
- [ ] 添加关键实体的索引
- [ ] 实现批量操作 API
- [ ] 优化查询谓词
- [ ] 实现渐进式迁移策略
- [ ] 添加性能监控工具
- [ ] 建立性能测试和基准
- [ ] 优化后台任务管理
- [ ] 实现内存管理策略
- [ ] 使用 Instruments 进行性能分析