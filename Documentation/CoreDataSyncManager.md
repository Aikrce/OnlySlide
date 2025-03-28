# CoreDataSyncManager 文档

`CoreDataSyncManager` 是 CoreDataModule 框架中的核心组件，负责协调 Core Data 数据的同步操作。本文档详细描述其设计、功能和使用方法。

## 1. 概述

`CoreDataSyncManager` 是一个 Swift actor，设计用于安全地管理跨设备或服务器的 Core Data 数据同步。它支持配置化的同步策略，提供状态追踪以及错误处理机制。

主要特点：

- **线程安全**：使用 actor 隔离确保状态管理的安全性
- **异步设计**：所有潜在的长时间运行操作都设计为异步
- **可配置性**：支持自定义同步间隔、批量大小等参数
- **错误处理**：提供健壮的错误处理机制
- **自动重试**：内置重试逻辑，应对临时失败

## 2. 核心组件

### 2.1 SyncConfiguration

定义同步操作的配置选项：

```swift
public struct SyncConfiguration: Sendable {
    /// 同步间隔，单位为秒
    public let syncInterval: TimeInterval
    
    /// 同步批次大小
    public let batchSize: Int
    
    /// 最大重试次数
    public let retryCount: Int
    
    /// 冲突解决策略
    public let conflictResolutionPolicy: NSMergePolicyType
    
    /// 默认配置
    public static let `default` = SyncConfiguration(
        syncInterval: 60.0,
        batchSize: 100,
        retryCount: 3,
        conflictResolutionPolicy: .mergeByPropertyObjectTrumpMergePolicyType
    )
}
```

### 2.2 CoreDataSyncState

表示同步操作的当前状态：

```swift
public enum CoreDataSyncState: Equatable, Sendable {
    /// 空闲状态
    case idle
    
    /// 同步中
    case syncing(progress: Double)
    
    /// 错误
    case error(Error)
}
```

### 2.3 SyncStateActor

管理同步状态的内部 actor：

```swift
actor SyncStateActor {
    private let stateSubject = CurrentValueSubject<CoreDataSyncState, Never>(.idle)
    
    var currentState: CoreDataSyncState {
        stateSubject.value
    }
    
    func updateState(_ state: CoreDataSyncState)
    
    func publisher() -> AnyPublisher<CoreDataSyncState, Never>
}
```

## 3. API 参考

### 3.1 初始化和设置

```swift
// 在应用启动时初始化
public static func initialize() async {
    // 设置观察者和定时器
    await shared.setupObservers()
    await shared.setupSyncTimer()
}
```

### 3.2 同步控制

```swift
// 开始同步操作
func startSync() async

// 停止同步操作
func stopSync()

// 获取同步状态观察器
var syncState: AnyPublisher<CoreDataSyncState, Never> {
    get async
}
```

### 3.3 内部方法

```swift
// 设置同步定时器
func setupSyncTimer()

// 设置变更观察器
private func setupObservers()

// 处理远程变更通知
private func handleRemoteChange() async

// 执行同步操作
private func performSync() async throws

// 批量处理更改
private func processBatchChanges(_ changes: [NSManagedObject], in context: NSManagedObjectContext) async throws

// 处理单个更改
private func processChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws

// 根据变更类型处理
private func handleInsertChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws
private func handleUpdateChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws
private func handleDeleteChange(_ change: NSManagedObject, in context: NSManagedObjectContext) throws

// 更新同步状态
private func updateSyncStatus(in context: NSManagedObjectContext) async throws

// 清理旧同步日志
private func clearSyncLogs(olderThan date: Date, in context: NSManagedObjectContext) throws
```

## 4. 使用示例

### 4.1 基本配置和启动

```swift
// 在应用启动时
Task {
    // 使用默认配置初始化
    await CoreDataSyncManager.initialize()
}
```

### 4.2 手动触发同步

```swift
// 在用户请求同步时
Task {
    await CoreDataSyncManager.shared.startSync()
}
```

### 4.3 监控同步状态

```swift
// 设置 UI 更新
Task {
    let publisher = await CoreDataSyncManager.shared.syncState
    
    publisher
        .receive(on: DispatchQueue.main)
        .sink { state in
            switch state {
            case .idle:
                // 更新 UI 为空闲状态
                self.updateUIForIdleState()
            case .syncing(let progress):
                // 更新进度指示器
                self.updateProgressIndicator(progress)
            case .error(let error):
                // 显示错误
                self.showError(error)
            }
        }
        .store(in: &cancellables)
}
```

### 4.4 高级配置

```swift
// 创建自定义配置
let customConfig = SyncConfiguration(
    syncInterval: 120.0, // 每2分钟同步一次
    batchSize: 200,      // 每批200条记录
    retryCount: 5,       // 最多重试5次
    conflictResolutionPolicy: .mergeByPropertyStoreTrumpMergePolicyType // 优先使用存储数据
)

// 初始化带自定义配置的管理器
let customSyncManager = CoreDataSyncManager(configuration: customConfig)
```

## 5. 最佳实践

### 5.1 性能考虑

- **批处理大小**：根据数据复杂性和设备性能调整批处理大小。复杂实体使用较小的批量（50-100），简单实体可以使用较大批量（200-500）。

- **同步频率**：根据应用需求和用户期望设置适当的同步间隔。用户交互频繁的数据可能需要更频繁的同步（30-60秒），而不太关键的数据可以使用较长间隔（5-15分钟）。

- **内存管理**：对于大型同步操作，请确保定期保存上下文（每处理10-20个对象）以避免内存压力。

### 5.2 错误处理

- **重试策略**：对于网络相关错误，使用指数退避策略，每次重试等待时间加倍，避免立即重试可能仍然失败的操作。

- **用户通知**：持续失败的同步操作应通知用户，并提供手动重试选项。

- **恢复机制**：集成 `CoreDataRecoveryExecutor` 处理严重错误，例如存储损坏或模型不兼容。

### 5.3 测试建议

- **模拟网络条件**：测试在不同网络条件下的同步性能，包括高延迟和断断续续的连接。

- **大数据集测试**：使用大量实体（1000+）测试同步性能和内存消耗。

- **冲突测试**：模拟并发修改场景，验证冲突解决策略是否按预期工作。

## 6. 排错指南

### 6.1 常见问题

- **同步无法启动**：
  - 检查配置是否正确
  - 验证网络连接
  - 确保 Core Data 栈已正确初始化

- **同步频繁失败**：
  - 检查服务器连接和身份验证
  - 验证数据模型兼容性
  - 确保没有实体或关系约束问题

- **内存使用过高**：
  - 减小批处理大小
  - 增加中间保存频率
  - 检查是否有强引用循环

### 6.2 日志分析

CoreDataSyncManager 使用 `CoreLogger` 记录各种操作：

- **信息日志**：跟踪同步开始、完成和进度
- **调试日志**：详细记录每批处理的更改
- **警告日志**：记录重试和轻微问题
- **错误日志**：记录严重问题和同步失败

分析日志时，关注：

- 错误模式和频率
- 重试频率
- 操作持续时间
- 内存和性能问题的指示

## 7. 异步编程注意事项

由于 `CoreDataSyncManager` 是一个 actor，并且大量使用异步方法，请注意：

- 所有调用异步方法的地方都需要使用 `await` 关键字
- 始终在 Task 或异步上下文中访问
- 避免在主线程阻塞等待异步操作
- 注意 `@Sendable` 闭包中捕获值的生命周期

例如：

```swift
// 正确调用异步方法
Task {
    await CoreDataSyncManager.shared.startSync()
}

// 错误：没有使用 await
Task {
    CoreDataSyncManager.shared.startSync() // 编译错误
}
```

## 8. 未来改进

计划中的改进：

- 支持多存储协调同步
- 优化增量同步以减少数据传输
- 添加加密和压缩选项
- 改进冲突解决策略，支持字段级合并
- 扩展监控和分析功能 