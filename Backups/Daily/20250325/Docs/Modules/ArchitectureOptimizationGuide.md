# CoreDataModule 架构优化指南

本文档提供了将现有 CoreDataModule 架构优化升级的指南，侧重于以下几个方面：

1. 使用依赖注入替代硬编码的单例依赖
2. 使用值类型（结构体）替代引用类型（类）
3. 使用协议与组合替代继承
4. 使用 Swift 现代并发模型
5. 减少对 NSObject 的依赖

## 目录

- [架构优化概述](#架构优化概述)
- [新增组件介绍](#新增组件介绍)
- [迁移步骤](#迁移步骤)
- [代码示例](#代码示例)
- [测试策略](#测试策略)
- [常见问题](#常见问题)

## 架构优化概述

当前的 CoreDataModule 架构有以下几个主要问题：

1. **过度使用单例**：几乎所有关键类都采用单例模式，这导致了强耦合和测试困难
2. **过度使用引用类型**：大量使用类而非结构体，增加了内存管理复杂性
3. **NSObject 依赖**：部分类仍然依赖 NSObject，阻碍了向纯 Swift 架构的过渡
4. **并发安全性**：使用 `@unchecked Sendable` 临时解决了并发问题，但需要更彻底的架构改进

新架构通过以下方式解决这些问题：

1. **依赖注入**：使用 `DependencyRegistry` 进行依赖管理和注入
2. **值类型**：使用结构体替代类，尤其是对于状态简单的组件
3. **协议抽象**：定义清晰的协议界面，而非依赖具体实现
4. **结构化并发**：充分利用 Swift 现代并发模型
5. **向后兼容**：保持与现有 API 的兼容性，允许渐进式迁移

## 新增组件介绍

本次优化引入了以下新组件：

### 依赖管理

- **DependencyRegistry**：中央依赖注册和解析服务
- **Provider 协议**：定义依赖提供者的能力
- **Factory 协议**：定义组件工厂的接口

### 错误处理

- **EnhancedErrorHandler**：基于值类型的错误处理器
- **ErrorHandlingService 协议**：定义错误处理服务能力
- **RecoveryService 协议**：定义错误恢复服务能力

### 迁移管理

- **EnhancedMigrationManager**：基于值类型的迁移管理器
- **MigrationPlannerProtocol**：定义迁移规划器
- **MigrationExecutorProtocol**：定义迁移执行器
- **BackupManagerProtocol**：定义备份管理器

## 迁移步骤

将现有代码迁移到新架构可以分为以下几个步骤进行：

### 1. 引入依赖注册表

首先，在项目中引入 `DependencyRegistry` 并启用依赖注册：

```swift
// 在应用启动时
func setupDependencies() {
    // 注册已有服务
    DependencyRegistry.shared.registerShared { CoreDataManager.shared }
    
    // 注册新的增强服务
    DependencyRegistry.shared.registerShared { EnhancedMigrationManager.createDefault() }
    DependencyRegistry.shared.registerShared { EnhancedErrorHandler.createDefault() }
}
```

### 2. 渐进式替换单例引用

在新代码中，逐步使用依赖注入替代硬编码的单例引用：

```swift
// 旧方式
let manager = CoreDataMigrationManager.shared

// 新方式
let manager: EnhancedMigrationManager = resolve()
// 或者通过构造函数注入
init(migrationManager: EnhancedMigrationManager = resolve()) {
    self.migrationManager = migrationManager
}
```

### 3. 使用新的服务接口

采用协议定义的服务接口，以减少对具体实现的依赖：

```swift
// 使用服务接口而不是具体实现
func handleError(_ error: Error, in context: String) {
    let service: ErrorHandlingService = resolve()
    service.handle(error, context: context)
}
```

### 4. 迁移到值类型

尽可能将类转换为结构体，特别是那些不需要引用语义的类：

```swift
// 旧方式
class SomeManager {
    // ...
}

// 新方式
struct SomeManager {
    // ...
}
```

### 5. 更新测试

更新单元测试以使用依赖注入，这将大大简化测试：

```swift
// 测试前重置依赖注册表
DependencyRegistry.shared.reset()

// 注册测试替身
DependencyRegistry.shared.register { MockErrorHandler() }

// 获取被测试组件
let component: ComponentUnderTest = resolve()
```

## 代码示例

### 错误处理示例

下面是使用新架构进行错误处理的示例：

```swift
// 创建错误处理服务
let errorService = ErrorHandlingService()

do {
    try someRiskyOperation()
} catch {
    // 处理错误
    errorService.handle(error, context: "数据保存")
    
    // 尝试恢复
    Task {
        let result = await errorService.attemptRecovery(from: error, context: "数据保存")
        switch result {
        case .success:
            print("恢复成功")
        case .partialSuccess(let message):
            print("部分恢复: \(message)")
        case .requiresUserInteraction:
            // 显示用户交互界面
            await showErrorUI(for: error)
        case .failure(let recoveryError):
            print("恢复失败: \(recoveryError)")
        }
    }
}
```

### 迁移操作示例

下面是使用新架构进行数据迁移的示例：

```swift
// 创建迁移服务
let migrationService = MigrationService()

// 检查并执行迁移
Task {
    do {
        // 获取存储 URL
        guard let storeURL = CoreDataStack.shared.persistentContainer.persistentStoreDescriptions.first?.url else {
            throw CoreDataError.storeNotFound("无法获取存储URL")
        }
        
        // 检查是否需要迁移
        if try await migrationService.needsMigration(at: storeURL) {
            // 配置迁移选项
            let options = MigrationOptions(
                shouldCreateBackup: true,
                shouldRestoreFromBackupOnFailure: true,
                mode: .customMapping
            )
            
            // 执行迁移
            let result = try await migrationService.migrate(storeAt: storeURL, options: options)
            
            switch result {
            case .success:
                print("迁移成功")
            case .notNeeded:
                print("无需迁移")
            }
        }
    } catch {
        print("迁移失败: \(error)")
    }
}
```

### 依赖注入示例

在需要多个依赖的组件中使用依赖注入：

```swift
// 定义组件
struct DataSyncCoordinator {
    private let migrationService: MigrationService
    private let errorService: ErrorHandlingService
    private let coreDataManager: CoreDataManager
    
    // 使用依赖注入
    init(
        migrationService: MigrationService = resolve(),
        errorService: ErrorHandlingService = resolve(),
        coreDataManager: CoreDataManager = resolve()
    ) {
        self.migrationService = migrationService
        self.errorService = errorService
        self.coreDataManager = coreDataManager
    }
    
    // 组件方法...
}
```

## 测试策略

新架构极大地提高了代码的可测试性。以下是测试策略：

### 单元测试

1. **隔离测试**：使用依赖注入提供测试替身（模拟对象）
2. **状态验证**：对于值类型，验证操作后的状态是否符合预期
3. **接口测试**：针对协议接口而非具体实现进行测试

### 示例：测试错误处理

```swift
func testErrorRecovery() async {
    // 准备
    let mockRecoveryService = MockRecoveryService()
    mockRecoveryService.mockResult = .success
    
    // 重置依赖注册表
    DependencyRegistry.shared.reset()
    
    // 注册模拟服务
    DependencyRegistry.shared.register { mockRecoveryService }
    
    // 创建被测试组件
    let errorService = ErrorHandlingService()
    
    // 执行
    let result = await errorService.attemptRecovery(from: TestError.sample, context: "测试")
    
    // 验证
    XCTAssertEqual(result, .success)
    XCTAssertEqual(mockRecoveryService.recoveryAttempts, 1)
    XCTAssertEqual(mockRecoveryService.lastError as? TestError, .sample)
}
```

## 常见问题

### Q: 如何与现有代码共存？

A: 新架构设计为与现有代码共存，并提供向后兼容性。在 `DependencyRegistry` 中，我们注册了现有的单例实现，因此现有代码可以继续使用。新代码应该逐步采用基于依赖注入的方式。

### Q: 是否需要一次性迁移所有代码？

A: 不需要。您可以采用渐进式迁移策略，首先迁移那些最容易隔离的组件，然后逐步扩展到其他部分。依赖注册表和工厂模式设计使得新旧代码可以共存。

### Q: 如何处理现有的单元测试？

A: 现有的单元测试仍然有效。对于新的单元测试，建议采用依赖注入的方式，这将使测试更加简单和可靠。

### Q: 单例完全不用了吗？

A: 单例仍然在某些场景中有用，例如全局配置或资源管理。但在大多数情况下，依赖注入是更好的选择。在新架构中，我们仅在 `DependencyRegistry` 中使用单例，其他组件通过依赖注入获取。

## 结论

本指南提供了将 CoreDataModule 迁移到更现代、更可靠架构的路线图。通过采用依赖注入、值类型和协议抽象，我们可以显著提高代码的可维护性、可测试性和并发安全性。

迁移过程可以是渐进式的，允许团队在不中断现有功能的情况下逐步采用新架构。每个迁移步骤都为代码库带来立即的价值，同时为未来的改进奠定基础。 