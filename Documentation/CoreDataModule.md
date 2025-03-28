# CoreDataModule 框架文档

本文档描述了 CoreDataModule 框架的架构、主要组件和使用方法，特别关注了并发安全和性能优化方面的改进。

## 1. 架构概述

CoreDataModule 框架提供了对 Core Data 的高级封装，处理数据持久化、迁移、同步和错误恢复等功能。框架采用了 Swift 现代并发模型，确保在异步环境中安全使用 Core Data。

主要组件包括：

- **CoreDataStack**: 核心数据栈，负责管理持久化容器和上下文
- **CoreDataSyncManager**: 数据同步管理器，处理本地与远程数据的同步
- **EnhancedSyncManager**: 增强的同步管理器，提供更灵活的同步策略
- **CoreDataResourceManager**: 资源管理器，处理模型文件和存储资源
- **CoreDataRecoveryExecutor**: 错误恢复执行器，提供错误恢复策略
- **EnhancedModelVersionManager**: 版本管理器，处理模型版本和迁移映射

## 2. 并发安全

框架已进行全面修改，采用 Swift 的现代并发模型确保线程安全：

### 2.1 Actor 隔离

- 关键管理器类使用 `actor` 关键字隔离状态，防止数据竞争
- 例如 `CoreDataSyncManager` 和内部的 `SyncStateActor` 使用 actor 隔离确保状态更新的安全性

```swift
public actor CoreDataSyncManager {
    // 状态被 actor 隔离，防止数据竞争
}

actor SyncStateActor {
    private let stateSubject = CurrentValueSubject<CoreDataSyncState, Never>(.idle)
    // 安全地管理状态更新
}
```

### 2.2 异步 API

- 所有可能阻塞的操作都设计为异步 API，使用 `async/await` 模式
- 资源访问方法已修改为异步，例如 `allModels()`, `mergedObjectModel()` 等

```swift
// 异步加载所有模型
func allModels() async throws -> [NSManagedObjectModel] {
    // 异步实现
}
```

### 2.3 Sendable 遵循

- 数据结构已标记为 `Sendable`，确保可以安全地跨 actor 边界传递
- 例如 `SyncConfiguration` 和 `CoreDataSyncState` 都实现了 `Sendable` 协议

```swift
public struct SyncConfiguration: Sendable {
    // 可以安全地在 actor 边界间传递
}

public enum CoreDataSyncState: Equatable, Sendable {
    // 可以安全地在 actor 边界间传递
}
```

### 2.4 @Sendable 闭包

- 异步上下文中的闭包使用 `@Sendable` 标记，确保捕获值的安全性
- 避免在 Sendable 闭包中捕获非 Sendable 类型

```swift
Task { @Sendable [weak self] in
    // 安全的闭包实现
}
```

## 3. 性能优化

框架包含多种性能优化策略：

### 3.1 批处理技术

- 大型数据集使用分页批处理，避免内存压力
- `processBatchedData` 方法在 `EnhancedSyncManager` 中实现批处理逻辑

```swift
// 使用分页批处理数据
func processBatchedData<T>(
    fetchRequest: NSFetchRequest<T>,
    batchSize: Int = 100,
    handler: @escaping ([T]) throws -> Void
) async throws where T: NSFetchRequestResult {
    // 批处理实现
}
```

### 3.2 上下文优化

- 为同步和批量操作优化 NSManagedObjectContext 设置
- 使用 `optimizeContextForSync` 配置上下文提高性能

```swift
// 为同步优化上下文
private func optimizeContextForSync(_ context: NSManagedObjectContext) {
    context.stalenessInterval = 0 // 避免缓存陈旧对象
    context.shouldDeleteInaccessibleFaults = true // 释放不可访问的错误对象
    context.retainsRegisteredObjects = false // 不保留已注册对象
    // 其他优化...
}
```

### 3.3 智能缓存

- 实现 `NSCache` 缓存常用对象，减少磁盘访问
- 为 `CoreDataResourceManager` 优化模型缓存策略

```swift
// 高效缓存实现
private lazy var objectCache: NSCache<NSString, AnyObject> = {
    let cache = NSCache<NSString, AnyObject>()
    cache.name = "com.onlyslide.enhancedsyncmanager.cache"
    cache.countLimit = 1000  // 最多缓存1000个对象
    cache.totalCostLimit = 10 * 1024 * 1024  // 最大10MB
    return cache
}()
```

### 3.4 批量更新操作

- 使用 `NSBatchUpdateRequest` 直接在持久化存储上执行批量更新
- 避免加载大量对象到内存中

```swift
// 批量保存操作
private func batchSaveChanges<T: NSManagedObject>(
    entities: [T],
    propertiesToUpdate: [String]
) async throws {
    // 批量更新实现
}
```

## 4. 错误处理和恢复

框架提供了全面的错误处理和恢复策略：

### 4.1 错误类型

- 定义了 `CoreDataError` 类型，包含各种特定错误情况
- 错误包含丰富的上下文信息，便于调试和恢复

### 4.2 恢复策略

- 采用策略模式实现错误恢复
- `RecoveryStrategy` 协议定义了恢复策略接口
- 多种恢复策略实现：`StoreResetRecoveryStrategy`, `ContextResetRecoveryStrategy`, `MigrationRecoveryStrategy` 等

```swift
// 恢复策略接口
public protocol RecoveryStrategy {
    var name: String { get }
    func attemptRecovery(from error: Error, context: String) async -> RecoveryResult
    func canHandle(_ error: Error) -> Bool
}
```

### 4.3 恢复执行器

- `CoreDataRecoveryExecutor` 协调不同恢复策略的执行
- 自动选择适合当前错误的恢复策略

```swift
// 恢复执行器
public final class CoreDataRecoveryExecutor: @unchecked Sendable {
    public static let shared = CoreDataRecoveryExecutor()
    
    // 尝试恢复
    public func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        // 查找并应用合适的恢复策略
    }
}
```

## 5. 使用指南

### 5.1 初始化框架

在应用启动时初始化 CoreDataModule：

```swift
import CoreDataModule

// 在 App 启动时
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // 初始化 Core Data 栈
    CoreDataStack.shared.setupPersistentContainer(name: "YourModelName")
    
    // 设置同步管理器
    Task {
        await CoreDataSyncManager.initialize()
    }
    
    return true
}
```

### 5.2 执行同步操作

使用同步管理器执行数据同步：

```swift
// 在需要同步的地方
Task {
    do {
        await CoreDataSyncManager.shared.startSync()
    } catch {
        // 处理同步错误
    }
}
```

### 5.3 处理错误和恢复

使用恢复执行器处理错误：

```swift
do {
    // 尝试执行 Core Data 操作
} catch {
    // 尝试错误恢复
    let result = await CoreDataRecoveryExecutor.shared.attemptRecovery(from: error, context: "yourOperationContext")
    
    switch result {
    case .success:
        // 恢复成功，重试操作
    case .failure(let recoveryError):
        // 恢复失败，处理错误
    case .requiresUserInteraction:
        // 需要用户干预
    case .partialSuccess(let message):
        // 部分恢复成功
    }
}
```

## 6. 最佳实践

### 6.1 并发使用

- 始终使用 `await` 关键字调用异步方法
- 不要在 actor 构造器中调用异步方法
- 使用静态工厂方法代替直接在构造器中进行异步初始化

### 6.2 性能考虑

- 对大型数据集使用批处理操作
- 避免在主线程上执行阻塞性 Core Data 操作
- 定期清理缓存和陈旧数据

### 6.3 错误处理

- 为特定操作上下文使用正确的错误恢复策略
- 考虑备份重要数据，以防需要恢复
- 记录并监控持久性错误，以检测潜在问题

## 7. 调试技术

- 使用 CoreLogger 进行日志记录和调试
- 监控性能指标，如缓存命中率和同步时间
- 为复杂操作添加断点和检测点 