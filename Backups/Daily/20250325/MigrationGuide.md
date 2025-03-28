# OnlySlide 架构迁移指南

本指南旨在帮助团队从旧架构逐步迁移到新架构，特别关注 Core Data 模块的现代化改进。

## 迁移目标

我们的目标是将 Core Data 模块完全迁移到基于值类型、协议驱动和依赖注入的现代 Swift 架构，具体包括：

1. **移除 NSObject 依赖**：减少对引用类型的依赖，提高并发安全性
2. **采用依赖注入**：降低组件耦合度，提高可测试性
3. **使用值类型**：优先使用结构体和枚举，而非类
4. **基于协议设计**：通过协议分离接口和实现
5. **现代并发模型**：采用 Swift 现代并发特性

## 迁移策略

我们采用渐进式迁移策略，分为三个阶段：

### 阶段1：并行使用（现在 - 1个月）

这个阶段，新旧组件并行存在：

1. **新功能使用新架构**：所有新功能和模块都使用新架构组件
2. **现有代码继续使用旧架构**：通过适配器保持兼容性
3. **在测试环境中验证**：对新组件进行全面测试

具体步骤：

- 使用适配器（`ModelVersionManagerAdapter`、`MigrationManagerAdapter`、`ErrorHandlerAdapter`）与现有代码集成
- 通过依赖注册表注册新组件
- 在关键场景下编写集成测试

### 阶段2：逐步替换（1-3个月）

这个阶段，逐步替换旧组件：

1. **用新组件替换旧组件**：先从底层工具类开始，后扩展到高层业务逻辑
2. **使用适配器确保兼容性**：保持API兼容，减少破坏性变更
3. **持续监控和测试**：确保每次替换后功能正常

具体步骤：

- 确定组件替换优先级（模型版本管理 → 错误处理 → 迁移管理）
- 在非关键路径先进行替换
- 使用 A/B 测试比较新旧组件性能和稳定性

### 阶段3：完全迁移（3-6个月）

这个阶段，完成全部迁移：

1. **移除适配器和兼容层**：直接使用新API
2. **重构业务逻辑**：充分利用新架构特性
3. **移除旧组件**：完全移除对旧架构的依赖

具体步骤：

- 设定截止日期，在此日期后移除兼容层
- 对直接使用新组件的代码进行性能优化
- 更新文档和开发指南

## 代码示例

### 旧架构用法

```swift
// 获取单例
let migrationManager = CoreDataMigrationManager.shared

// 检查迁移
do {
    let needsMigration = try migrationManager.requiresMigration(at: storeURL)
    if needsMigration {
        try migrationManager.performMigration(at: storeURL)
    }
} catch {
    CoreDataErrorManager.shared.handleError(error)
}
```

### 新架构用法

```swift
// 使用依赖注入
let migrationManager: EnhancedMigrationManager = resolve()
let errorHandler: EnhancedErrorHandler = resolve()

// 使用 async/await
do {
    let needsMigration = try await migrationManager.needsMigration(at: storeURL)
    if needsMigration {
        _ = try await migrationManager.migrate(storeAt: storeURL)
    }
} catch {
    errorHandler.handle(error, context: "数据迁移")
}
```

### 过渡期用法

```swift
// 使用适配器
let adapter = MigrationManagerAdapter.shared

// 兼容方法使用
do {
    let success = try await adapter.compatibleCheckAndMigrateStoreIfNeeded(at: storeURL)
    if !success {
        throw CoreDataError.migrationFailed("迁移失败")
    }
} catch {
    ErrorHandlerAdapter.shared.compatibleHandleError(error)
}
```

## 测试策略

1. **单元测试**：为每个新组件编写全面的单元测试
2. **集成测试**：确保新组件与现有系统正确集成
3. **性能测试**：比较新旧架构的性能差异
4. **并发测试**：验证在多线程环境下的稳定性

## 常见问题

### 如何处理现有的单例引用？

使用适配器和全局函数：

```swift
// 旧代码
let manager = CoreDataModelVersionManager.shared

// 新代码
let manager = getModelVersionManager()
// 或
let manager: ModelVersionManaging = resolve()
```

### 如何确保向后兼容？

适配器类提供了与旧API兼容的接口，允许渐进式迁移：

```swift
// 通过适配器使用新功能
let result = await ModelVersionManagerAdapter.shared.compatibleRequiresMigration(at: storeURL)
```

### 如何在新项目中正确使用新架构？

从一开始就使用依赖注入和协议：

```swift
// 注册服务
func setupServices() {
    DependencyRegistry.shared.register(ModelVersionManaging.self) {
        EnhancedModelVersionManager.createDefault()
    }
    
    DependencyRegistry.shared.register(ErrorHandlingService.self) {
        EnhancedErrorHandler.createDefault()
    }
}

// 使用服务
struct MyService {
    private let versionManager: ModelVersionManaging = resolve()
    
    func doSomething() {
        // 使用 versionManager
    }
}
```

## 联系人

如果在迁移过程中遇到问题，请联系架构团队：

- 架构负责人：[联系方式]
- 技术支持：[联系方式]

## 时间线

- **第1周**：完成单元测试套件
- **第2-4周**：在新功能中使用新架构
- **第5-8周**：开始替换非关键路径上的旧组件
- **第9-12周**：扩展到关键路径
- **第13-16周**：移除兼容层，完全迁移
- **第17-24周**：优化和稳定化 