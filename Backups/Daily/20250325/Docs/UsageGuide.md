# OnlySlide CoreDataModule 使用指南

本文档提供了关于如何在您的项目中使用 OnlySlide 的 CoreDataModule 的详细指导。这个模块提供了强大的数据管理功能，包括数据存储、迁移和同步。

## 目录

- [快速开始](#快速开始)
- [依赖注入系统](#依赖注入系统)
- [数据存储](#数据存储)
- [模型版本管理](#模型版本管理)
- [数据迁移](#数据迁移)
- [错误处理](#错误处理)
- [数据同步](#数据同步)
- [并发安全](#并发安全)
- [适配器使用](#适配器使用)
- [最佳实践](#最佳实践)
- [故障排除](#故障排除)

## 快速开始

### 安装

将 CoreDataModule 添加到您的项目中：

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/yourorganization/onlyslide-coredatamodule.git", from: "1.0.0")
]
```

### 基本用法

```swift
import CoreDataModule

// 初始化依赖注册表
DependencyRegistry.shared.registerDefaults()

// 获取迁移管理器
let migrationManager: EnhancedMigrationManager = resolve()

// 检查是否需要迁移
let storeURL = URL(fileURLWithPath: "/path/to/store.sqlite")
if try await migrationManager.needsMigration(at: storeURL) {
    // 执行迁移
    let result = try await migrationManager.migrate(storeAt: storeURL)
    print("迁移结果: \(result)")
}

// 获取数据上下文
let context = CoreDataStack.shared.viewContext

// 使用上下文进行数据操作
// ...
```

## 依赖注入系统

CoreDataModule 使用依赖注入系统管理组件依赖，避免硬编码的单例引用。

### 注册依赖

```swift
// 注册自定义实现
DependencyRegistry.shared.register(ModelVersionManaging.self) { 
    MyCustomModelVersionManager() 
}

// 注册工厂
DependencyRegistry.shared.registerShared(MyServiceFactory())

// 注册共享实例
DependencyRegistry.shared.registerShared { MyService.createDefault() }
```

### 解析依赖

```swift
// 通过类型解析
let versionManager: ModelVersionManaging = resolve()

// 通过协议解析
let errorHandler = resolve(ErrorHandlingService.self)

// 可选解析
if let service: MyOptionalService = optional() {
    service.doSomething()
}
```

### 自定义工厂

```swift
struct MyServiceFactory: Factory {
    func create() -> MyService {
        return MyService(
            dependency1: resolve(),
            dependency2: resolve()
        )
    }
}
```

## 数据存储

### 获取 CoreData 上下文

```swift
// 获取主线程上下文
let viewContext = CoreDataStack.shared.viewContext

// 创建后台上下文
let backgroundContext = CoreDataStack.shared.newBackgroundContext()
```

### 使用并发安全的上下文访问

```swift
// 创建安全访问器
let contextAccessor = CoreDataContextAccessor(context: viewContext)

// 在主线程上下文执行操作
try contextAccessor.perform { context in
    let entity = MyEntity(context: context)
    entity.name = "Test"
    try context.save()
}

// 异步执行
try await contextAccessor.performAsync { context in
    // 在主线程安全地执行异步操作
    let request = NSFetchRequest<MyEntity>(entityName: "MyEntity")
    let results = try context.fetch(request)
    return results
}
```

### 使用隔离的 PersistentContainer

```swift
// 创建隔离的容器
let container = IsolatedPersistentContainer(name: "MyModel")

// 加载存储
try await container.loadPersistentStores()

// 执行后台任务
let results = try await container.performBackgroundTask { context in
    let request = NSFetchRequest<MyEntity>(entityName: "MyEntity")
    return try context.fetch(request)
}
```

## 模型版本管理

### 获取模型版本管理器

```swift
// 通过依赖注入获取
let versionManager: ModelVersionManaging = resolve()

// 或者直接创建
let versionManager = EnhancedModelVersionManager.createDefault()
```

### 检查版本和迁移需求

```swift
// 获取当前模型版本
let currentVersion = try versionManager.currentModelVersion()

// 获取所有可用版本
let allVersions = try versionManager.modelVersions()

// 检查是否需要迁移
let needsMigration = try versionManager.requiresMigration(at: storeURL)

// 获取迁移路径
let sourceVersion = try versionManager.sourceModelVersion(for: metadata)
let destVersion = try versionManager.destinationModelVersion()
let migrationPath = versionManager.migrationPath(from: sourceVersion, to: destVersion)
```

## 数据迁移

### 配置迁移选项

```swift
// 创建迁移选项
let options = MigrationOptions(
    progressReporting: true,
    backupStore: true,
    recoveryEnabled: true,
    migrationMode: .automatic
)
```

### 执行迁移

```swift
// 获取迁移管理器
let migrationManager: EnhancedMigrationManager = resolve()

// 检查迁移需求
if try await migrationManager.needsMigration(at: storeURL) {
    // 执行迁移
    let result = try await migrationManager.migrate(storeAt: storeURL, options: options)
    
    switch result {
    case .success:
        print("迁移成功")
    case .noMigrationNeeded:
        print("无需迁移")
    case .cancelled:
        print("迁移被取消")
    }
}
```

### 监听迁移进度

```swift
// 获取进度发布者
let progressPublisher = migrationManager.migrationProgressPublisher

// 订阅进度更新
let cancellable = progressPublisher.sink { progress in
    // 更新 UI 或记录日志
    print("迁移进度: \(Int(progress.fractionCompleted * 100))%")
    print("当前步骤: \(progress.localizedDescription)")
}
```

## 错误处理

### 使用错误处理器

```swift
// 获取错误处理器
let errorHandler: EnhancedErrorHandler = resolve()

// 处理错误
do {
    try someFunctionThatMightThrow()
} catch {
    errorHandler.handle(error, context: "数据操作")
}
```

### 注册恢复策略

```swift
// 获取恢复服务
let recoveryService: EnhancedRecoveryService = resolve()

// 注册恢复策略
recoveryService.registerRecoveryStrategy(for: CoreDataError.migrationFailed) { error, context in
    // 实现恢复逻辑
    // 例如，尝试从备份恢复
    let backupManager = resolve(BackupManagerProtocol.self)
    return try await backupManager.restoreFromLatestBackup()
}
```

### 尝试错误恢复

```swift
do {
    try someFunctionThatMightThrow()
} catch {
    // 尝试恢复
    let result = await recoveryService.attemptRecovery(from: error, context: "数据操作")
    
    switch result {
    case .recovered:
        print("成功恢复")
    case .partiallyRecovered(let info):
        print("部分恢复: \(info)")
    case .failed(let reason):
        print("恢复失败: \(reason)")
    }
}
```

## 数据同步

### 配置同步选项

```swift
// 创建同步选项
let options = SyncOptions(
    direction: .bidirectional,
    autoMergeStrategy: .serverWins,
    rollbackOnFailure: true
)
```

### 执行同步

```swift
// 获取同步管理器
let syncManager: EnhancedSyncManager = resolve()

// 执行同步
do {
    let success = try await syncManager.sync(with: options)
    if success {
        print("同步成功")
    } else {
        print("同步已在进行中")
    }
} catch {
    print("同步失败: \(error.localizedDescription)")
}
```

### 监听同步状态和进度

```swift
// 订阅状态更新
let statusCancellable = syncManager.statePublisher
    .sink { state in
        switch state {
        case .idle:
            print("空闲")
        case .preparing:
            print("准备中")
        case .syncing:
            print("同步中")
        case .completed:
            print("已完成")
        case .failed(let error):
            print("失败: \(error.localizedDescription)")
        }
    }

// 订阅进度更新
let progressCancellable = syncManager.progressPublisher
    .sink { progress in
        print("同步进度: \(Int(progress * 100))%")
    }
```

## 并发安全

### 使用 ThreadSafe 属性包装器

```swift
class MyManager {
    // 使用 ThreadSafe 包装可变状态
    @ThreadSafe private var cache: [String: Data] = [:]
    @ThreadSafe private var isProcessing = false
    
    func getData(for key: String) -> Data? {
        return cache[key]
    }
    
    func setData(_ data: Data, for key: String) {
        cache[key] = data
    }
    
    func process() -> Bool {
        // 安全地修改状态
        return $isProcessing.mutate { current in
            if current {
                return false
            }
            current = true
            return true
        }
    }
}
```

### 使用 ConcurrentDictionary

```swift
class CacheManager {
    private let cache = ConcurrentDictionary<String, Data>()
    
    func getData(for key: String) -> Data? {
        return cache[key]
    }
    
    func setData(_ data: Data, for key: String) {
        cache[key] = data
    }
    
    func clearCache() {
        cache.removeAll()
    }
}
```

### 使用资源访问器

```swift
class ResourceManager {
    private let resource = MyResource()
    private let accessor = AsyncResourceAccessor(resource)
    
    func readResource() async -> String {
        return await accessor.read { resource in
            return resource.getValue()
        }
    }
    
    func updateResource(with value: String) async {
        await accessor.write { resource in
            resource.setValue(value)
        }
    }
}
```

## 适配器使用

CoreDataModule 提供了适配器，帮助您逐步从旧 API 迁移到新 API。

### 使用错误处理适配器

```swift
// 旧代码
CoreDataErrorManager.shared.handleError(error)

// 新代码 (使用适配器)
ErrorHandlerAdapter.shared.handleError(error)

// 完全迁移后
let errorHandler: ErrorHandlingService = resolve()
errorHandler.handle(error, context: "操作上下文")
```

### 使用同步管理器适配器

```swift
// 旧代码
CoreDataSyncManager.shared.sync()

// 新代码 (使用适配器)
try await SyncManagerAdapter.shared.compatibleSync()

// 完全迁移后
let syncManager: EnhancedSyncManager = resolve()
try await syncManager.sync()
```

## 最佳实践

### 1. 依赖注入优于直接创建

```swift
// 不推荐
let manager = EnhancedMigrationManager.createDefault()

// 推荐
let manager: EnhancedMigrationManager = resolve()
```

### 2. 使用协议而非具体类型

```swift
// 不推荐
func process(manager: EnhancedModelVersionManager) {
    // ...
}

// 推荐
func process(manager: ModelVersionManaging) {
    // ...
}
```

### 3. 始终在安全的线程访问 CoreData

```swift
// 不推荐
func fetchEntities() async throws -> [MyEntity] {
    // 直接在异步函数中访问上下文
    let request = MyEntity.fetchRequest()
    return try viewContext.fetch(request)
}

// 推荐
func fetchEntities() async throws -> [MyEntity] {
    // 使用上下文访问器
    return try await contextAccessor.performAsync { context in
        let request = MyEntity.fetchRequest()
        return try context.fetch(request)
    }
}
```

### 4. 使用值类型进行状态传递

```swift
// 不推荐
class MigrationState {
    var progress: Double = 0
    var isComplete = false
    var hasError = false
    var error: Error?
}

// 推荐
struct MigrationState: Equatable {
    let progress: Double
    let status: MigrationStatus
    
    enum MigrationStatus: Equatable {
        case notStarted
        case inProgress
        case completed
        case failed(Error)
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            // 根据 case 实现相等性判断
            // ...
        }
    }
}
```

### 5. 在后台进行大量处理

```swift
// 执行耗时操作
func processLargeDataSet() async throws {
    try await executeInBackground {
        // 在后台执行耗时操作
        // ...
    }
}
```

## 故障排除

### 常见问题与解决方案

#### 1. 迁移失败

**症状**: 迁移过程中出现错误，应用无法启动。

**解决方法**: 
- 检查迁移路径是否正确
- 确认自定义映射模型已正确配置
- 使用带备份选项的迁移管理器，以便在失败时恢复

```swift
// 启用备份和恢复的迁移选项
let options = MigrationOptions(
    backupStore: true,
    recoveryEnabled: true
)

// 迁移失败时进行恢复
do {
    try await migrationManager.migrate(storeAt: storeURL, options: options)
} catch {
    // 尝试从备份恢复
    try await migrationManager.recoverFromFailedMigration(at: storeURL)
}
```

#### 2. 并发访问问题

**症状**: 出现 Core Data 并发错误，例如 "Context is already associated with a managed object"。

**解决方法**:
- 使用 `CoreDataContextAccessor` 确保在正确的线程上访问上下文
- 避免在不同线程间传递托管对象，而是传递对象 ID

```swift
// 获取对象 ID 而非对象
let objectID = try await contextAccessor.performAsync { context in
    let entity = MyEntity(context: context)
    entity.name = "Test"
    try context.save()
    return entity.objectID
}

// 在另一个上下文中使用对象 ID
let object = try await anotherContextAccessor.performAsync { context in
    guard let entity = try context.existingObject(with: objectID) as? MyEntity else {
        throw CoreDataError.objectNotFound
    }
    return entity
}
```

#### 3. 依赖解析失败

**症状**: 尝试解析依赖时出现运行时错误。

**解决方法**:
- 确保已注册所有必要的依赖
- 检查依赖类型是否与注册类型匹配

```swift
// 在应用启动时注册所有依赖
func registerAllDependencies() {
    let registry = DependencyRegistry.shared
    registry.registerDefaults() // 注册默认依赖
    
    // 注册自定义实现
    registry.register(CustomService.self) { CustomServiceImpl() }
}
```

## 更多资源

- [Core Data 架构文档](Architecture/CoreDataArchitecture.md)
- [迁移指南](Migration/MigrationGuide.md)
- [错误处理最佳实践](ErrorHandling/BestPractices.md)
- [示例项目](Examples/README.md)

## 联系与支持

如果您遇到任何问题或需要进一步的帮助，请联系我们的支持团队：

- 邮件: support@onlyslide.com
- 内部讨论组: #onlyslide-support 