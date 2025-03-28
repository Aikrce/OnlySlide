# OnlySlide CoreDataModule 架构设计

本文档提供了 OnlySlide CoreDataModule 的架构设计详细说明，包括核心组件、层次结构和数据流。

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                      应用层 (Application Layer)               │
└───────────────────────────────┬─────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                      服务层 (Service Layer)                   │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ DataService     │  │ SyncService     │  │ ErrorService │ │
│  └────────┬────────┘  └────────┬────────┘  └──────┬───────┘ │
│           │                    │                   │        │
└───────────┼────────────────────┼───────────────────┼────────┘
            │                    │                   │
            ▼                    ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                      核心层 (Core Layer)                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │               依赖注入系统 (Dependency Injection)      │    │
│  │  ┌─────────────────┐  ┌─────────────────────────┐   │    │
│  │  │ DependencyRegistry│ │ ServiceProviderProtocol │   │    │
│  │  └─────────────────┘  └─────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────┐  ┌───────────────────────────┐ │
│  │ 数据存储 (Data Storage)   │  │ 同步系统 (Sync System)     │ │
│  │                         │  │                           │ │
│  │  ┌─────────────────┐    │  │  ┌─────────────────────┐  │ │
│  │  │ CoreDataManager │    │  │  │ EnhancedSyncManager │  │ │
│  │  └─────────────────┘    │  │  └─────────────────────┘  │ │
│  │  ┌─────────────────┐    │  │  ┌─────────────────────┐  │ │
│  │  │ ResourceManager │    │  │  │ SyncOptionsBuilder  │  │ │
│  │  └─────────────────┘    │  │  └─────────────────────┘  │ │
│  └─────────────────────────┘  └───────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────┐  ┌───────────────────────────┐ │
│  │ 迁移系统 (Migration)     │  │ 错误处理 (Error Handling)  │ │
│  │                         │  │                           │ │
│  │  ┌─────────────────────┐│  │  ┌─────────────────────┐  │ │
│  │  │ EnhancedVersionManager││  │  │ EnhancedErrorHandler│  │ │
│  │  └─────────────────────┘│  │  └─────────────────────┘  │ │
│  │  ┌─────────────────────┐│  │  ┌─────────────────────┐  │ │
│  │  │ MigrationManager    ││  │  │ RecoveryService     │  │ │
│  │  └─────────────────────┘│  │  └─────────────────────┘  │ │
│  └─────────────────────────┘  └───────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │               并发安全 (Concurrency Safety)           │    │
│  │  ┌─────────────────┐  ┌───────────────────────────┐ │    │
│  │  │ ThreadSafe      │  │ IsolatedPersistentContainer│ │    │
│  │  └─────────────────┘  └───────────────────────────┘ │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
            │                    │                   │
            ▼                    ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                      适配器层 (Adapter Layer)                 │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ LegacyAdapter   │  │ NSObjectAdapter  │  │ UIAdapter    │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 核心设计原则

1. **依赖注入优先**：通过依赖注入系统实现松耦合，便于测试和扩展
2. **值类型优先**：尽可能使用值类型（struct、enum）而非引用类型
3. **协议驱动设计**：通过协议定义组件接口，实现多种实现方式
4. **并发安全**：所有组件设计时考虑并发安全，使用现代 Swift 并发特性
5. **错误处理一致性**：统一的错误处理机制，确保错误可追踪和恢复
6. **适配器模式**：使用适配器模式兼容旧系统，便于渐进式迁移

## 层次结构详解

### 1. 核心层 (Core Layer)

核心层包含系统的基础组件，是整个架构的中心。

#### 1.1 依赖注入系统

**组件：**
- `DependencyRegistry`: 中央依赖注册表，管理所有服务的注册和解析
- `ServiceProviderProtocol`: 定义服务提供者接口，所有可注入服务需遵循此协议

**数据流：**
```
┌─────────────────┐       ┌─────────────────┐
│ 客户端组件       │───►   │ DependencyRegistry│
└─────────────────┘       └─────────┬─────────┘
                                    │
                                    ▼
                          ┌─────────────────────┐
                          │ 具体服务实现         │
                          └─────────────────────┘
```

#### 1.2 数据存储系统

**组件：**
- `CoreDataManager`: 管理 CoreData 栈，提供上下文和持久化存储
- `ResourceManager`: 管理资源文件加载，特别是 CoreData 模型文件

**数据流：**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Service 层      │◄───►│ CoreDataManager │◄───►│ 持久化存储       │
└─────────────────┘    └─────────┬───────┘    └─────────────────┘
                               │
                       ┌───────▼───────┐
                       │ ResourceManager│
                       └───────────────┘
```

#### 1.3 迁移系统

**组件：**
- `EnhancedModelVersionManager`: 管理模型版本，提供版本比较和路径计算
- `MigrationManager`: 执行实际的数据迁移，支持自动和手动迁移

**数据流：**
```
┌─────────────────┐    ┌─────────────────────┐
│ Service 层      │◄───►│ MigrationManager    │
└─────────────────┘    └─────────┬───────────┘
                               │
                       ┌───────▼────────────────┐
                       │ EnhancedModelVersionManager│
                       └────────────────────────┘
```

#### 1.4 同步系统

**组件：**
- `EnhancedSyncManager`: 管理数据同步，支持多种同步策略和选项
- `SyncOptionsBuilder`: 构建同步选项，便于客户端配置同步行为

**数据流：**
```
┌─────────────────┐    ┌─────────────────────┐
│ Service 层      │◄───►│ EnhancedSyncManager │
└─────────────────┘    └─────────┬───────────┘
                               │
                       ┌───────▼────────────┐
                       │ SyncOptionsBuilder │
                       └────────────────────┘
```

#### 1.5 错误处理系统

**组件：**
- `EnhancedErrorHandler`: 处理错误，提供转换和上下文功能
- `RecoveryService`: 提供错误恢复策略，支持自动和手动恢复

**数据流：**
```
┌─────────────────┐    ┌─────────────────────┐
│ Service 层      │◄───►│ EnhancedErrorHandler│
└─────────────────┘    └─────────┬───────────┘
                               │
                       ┌───────▼────────────┐
                       │ RecoveryService    │
                       └────────────────────┘
```

#### 1.6 并发安全系统

**组件：**
- `ThreadSafe`: 属性包装器，确保属性访问线程安全
- `IsolatedPersistentContainer`: 隔离的持久化容器，通过 actor 确保线程安全

**数据流：**
```
┌─────────────────┐    ┌─────────────────────────┐
│ 多线程访问       │◄───►│ ThreadSafe 保护的资源    │
└─────────────────┘    └─────────────────────────┘

┌─────────────────┐    ┌─────────────────────────┐
│ 多线程访问       │◄───►│ IsolatedPersistentContainer│
└─────────────────┘    └─────────────────────────┘
```

### 2. 服务层 (Service Layer)

服务层是业务逻辑的实现层，连接应用层和核心层。

**组件：**
- `DataService`: 提供数据操作服务，封装核心层的数据存储操作
- `SyncService`: 提供同步服务，封装核心层的同步操作
- `ErrorService`: 提供错误处理服务，封装核心层的错误处理

**数据流：**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ 应用层          │◄───►│ 服务层          │◄───►│ 核心层          │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 3. 适配器层 (Adapter Layer)

适配器层为旧系统提供兼容接口，便于渐进式迁移。

**组件：**
- `LegacyAdapter`: 适配旧版 API 到新架构
- `NSObjectAdapter`: 将基于 NSObject 的组件适配到值类型架构
- `UIAdapter`: 为 UI 层提供数据绑定适配器

**数据流：**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ 旧系统          │◄───►│ 适配器层        │◄───►│ 新架构核心层    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 4. 应用层 (Application Layer)

应用层是与用户交互的界面，使用服务层提供的功能。

**组件：**
- 各种视图和控制器
- UI 数据绑定逻辑

**数据流：**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ 用户界面        │◄───►│ 应用层逻辑      │◄───►│ 服务层          │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 关键组件详解

### 1. 依赖注入系统

依赖注入系统是整个架构的基础，通过协议和工厂方法实现松耦合。

#### DependencyRegistry

```swift
class DependencyRegistry {
    static let shared = DependencyRegistry()
    
    private var dependencies: [String: Any] = [:]
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        dependencies[key] = factory
    }
    
    func resolve<T>() -> T? {
        let key = String(describing: T.self)
        if let factory = dependencies[key] as? () -> T {
            return factory()
        }
        return nil
    }
}
```

#### ServiceProviderProtocol

```swift
protocol ServiceProviderProtocol {
    static func createDefault() -> Self
}
```

### 2. 并发安全系统

并发安全系统确保在并发环境中的数据安全访问。

#### ThreadSafe

```swift
@propertyWrapper
struct ThreadSafe<Value> {
    private let queue = DispatchQueue(label: "com.onlyslide.threadsafe", attributes: .concurrent)
    private var value: Value
    
    var wrappedValue: Value {
        get { queue.sync { value } }
        set { queue.async(flags: .barrier) { self.value = newValue } }
    }
    
    init(wrappedValue: Value) {
        self.value = wrappedValue
    }
}
```

#### IsolatedPersistentContainer

```swift
actor IsolatedPersistentContainer {
    private let container: NSPersistentContainer
    
    init(name: String) {
        container = NSPersistentContainer(name: name)
    }
    
    func loadPersistentStores() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            container.loadPersistentStores { description, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        return container.newBackgroundContext()
    }
    
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
}
```

### 3. 错误处理系统

错误处理系统提供统一的错误定义、上下文和恢复机制。

#### CoreDataError

```swift
enum CoreDataError: Error {
    case modelLoadFailed(modelName: String)
    case migrationFailed(from: String, to: String, underlyingError: Error?)
    case persistenceError(description: String)
    case contextSaveError(underlyingError: Error?)
    case syncError(reason: String)
    case invalidVersion(version: String)
    case missingResource(name: String)
}
```

#### EnhancedErrorHandler

```swift
struct EnhancedErrorHandler: ErrorHandling {
    private let recoveryService: RecoveryService
    
    init(recoveryService: RecoveryService) {
        self.recoveryService = recoveryService
    }
    
    func handle(_ error: Error, context: ErrorContext?) async -> ErrorResolution {
        // 错误处理逻辑
        if let coreDataError = error as? CoreDataError {
            switch coreDataError {
            case .migrationFailed:
                return await recoveryService.attemptRecovery(for: error, context: context)
            case .persistenceError:
                return .needsUserAttention(error, suggestions: ["重启应用", "删除数据库文件并重新同步"])
            default:
                return .unresolved(error)
            }
        }
        return .unresolved(error)
    }
}
```

### 4. 迁移系统

迁移系统管理数据库模型版本和数据迁移。

#### EnhancedModelVersionManager

```swift
struct EnhancedModelVersionManager: ModelVersionManaging {
    private let resourceManager: ResourceManaging
    
    init(resourceManager: ResourceManaging) {
        self.resourceManager = resourceManager
    }
    
    func availableModelVersions() throws -> [ModelVersion] {
        // 获取所有可用的模型版本
    }
    
    func currentModelVersion() throws -> ModelVersion {
        // 获取当前模型版本
    }
    
    func migrationPath(from sourceVersion: ModelVersion, to destinationVersion: ModelVersion) throws -> [ModelVersion] {
        // 计算从源版本到目标版本的迁移路径
    }
    
    func requiresMigration(at storeURL: URL) throws -> Bool {
        // 检查指定存储是否需要迁移
    }
    
    func sourceModel(for metadata: [String: Any]) throws -> NSManagedObjectModel {
        // 获取源模型
    }
    
    func customMappingModel(from sourceModel: NSManagedObjectModel, to destinationModel: NSManagedObjectModel) throws -> NSMappingModel? {
        // 获取自定义映射模型
    }
}
```

### 5. 同步系统

同步系统管理数据的云同步和冲突解决。

#### EnhancedSyncManager

```swift
struct EnhancedSyncManager: SyncManaging {
    // 同步状态
    enum SyncState {
        case idle
        case syncing
        case completed
        case failed(Error)
    }
    
    // 同步选项
    struct SyncOptions {
        let direction: SyncDirection
        let conflict: ConflictResolutionStrategy
        let priority: SyncPriority
    }
    
    @ThreadSafe private var state: SyncState = .idle
    private let coreDataManager: CoreDataManaging
    
    init(coreDataManager: CoreDataManaging) {
        self.coreDataManager = coreDataManager
    }
    
    func sync(with options: SyncOptions) async throws {
        // 执行同步操作
    }
    
    func cancelSync() {
        // 取消同步操作
    }
    
    func syncState() -> SyncState {
        return state
    }
}
```

## 架构特点与优势

1. **模块化设计**
   - 每个组件都有明确的职责
   - 组件之间通过协议交互，便于替换和测试
   - 新功能可以通过扩展现有协议添加

2. **可测试性**
   - 依赖注入便于模拟测试依赖
   - 值类型和纯函数便于单元测试
   - 隔离的组件可以独立测试

3. **并发安全**
   - 使用现代 Swift 并发特性
   - 线程安全的属性访问和数据操作
   - 明确的并发模型减少错误

4. **错误处理**
   - 统一的错误类型
   - 上下文感知的错误处理
   - 可恢复性和用户友好提示

5. **扩展性**
   - 松耦合设计便于添加新功能
   - 适配器模式便于兼容第三方库
   - 协议驱动便于多种实现

6. **可维护性**
   - 一致的架构模式
   - 明确的代码组织
   - 值类型减少状态问题

## 后续演进计划

1. **进一步减少 @preconcurrency 使用**
   - 继续优化并发模型
   - 使用 Swift 的 concurrency 特性替代旧有模式

2. **完全移除 NSObject 依赖**
   - 用值类型重写所有引用类型
   - 完善适配器模式隔离旧代码

3. **API 简化**
   - 提供更高级别的便捷方法
   - 实现流式接口改善使用体验

4. **性能优化**
   - 针对大型数据集优化
   - 改进批处理和预加载

5. **跨平台支持**
   - 确保架构在 iOS 和 macOS 上一致工作
   - 提供 watchOS 和 tvOS 特定适配 