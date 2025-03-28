# CoreData 迁移架构文档

## 概述

OnlySlide 应用使用 CoreData 作为其数据持久化解决方案。随着应用的演进，数据模型也会发生变化，需要进行迁移以保证用户数据的完整性。本文档描述了我们的 CoreData 迁移架构，该架构设计用于安全、高效地处理数据模型升级过程。

## 设计目标

1. **安全性**: 确保迁移过程不会丢失或损坏用户数据
2. **可靠性**: 提供备份和恢复机制，防止迁移失败导致的数据损失
3. **并发安全**: 确保所有组件在并发环境下安全工作
4. **用户体验**: 提供进度反馈，让用户了解迁移进度
5. **可测试性**: 架构设计便于单元测试和集成测试
6. **可维护性**: 组件职责明确，易于理解和维护
7. **模块化**: 支持模块化应用架构，确保在不同部署场景下都能可靠工作

## 架构组件

我们的迁移架构采用组件式设计，将不同职责分配给专门的组件：

![CoreData 迁移架构图](../Images/CoreDataMigrationArchitecture.png)

### 1. CoreDataMigrationManager

核心协调组件，负责整个迁移过程的协调和管理。

**主要职责**:
- 接收迁移请求并协调各组件完成迁移
- 提供简单的公共 API
- 处理迁移过程中的错误
- 协调备份和恢复操作

**关键方法**:
- `checkAndMigrateStoreIfNeeded(at:)`: 检查是否需要迁移，并在需要时执行迁移
- `performMigration(at:)`: 执行迁移过程
- `getCurrentProgress()`: 获取当前迁移进度
- `getCurrentState()`: 获取当前迁移状态

### 2. BackupManager

负责 CoreData 存储的备份和恢复功能。

**主要职责**:
- 创建数据库备份
- 从备份恢复数据
- 管理备份版本和清理旧备份

**关键方法**:
- `createBackup(for:)`: 创建数据库备份
- `restoreFromBackup(_:to:)`: 从指定备份恢复
- `restoreFromLatestBackup(to:)`: 从最新备份恢复
- `cleanupOldBackups()`: 清理旧备份文件

### 3. MigrationPlanner

负责确定迁移路径和计划。

**主要职责**:
- 检查是否需要迁移
- 确定源模型和目标模型
- 计算迁移路径
- 创建迁移步骤

**关键方法**:
- `requiresMigration(at:)`: 检查是否需要迁移
- `createMigrationPlan(for:)`: 创建迁移计划
- `sourceModel(for:)`: 获取迁移步骤的源模型
- `destinationModel(for:)`: 获取迁移步骤的目标模型
- `mappingModel(for:)`: 获取迁移步骤的映射模型

### 4. MigrationExecutor

负责执行迁移计划中的步骤。

**主要职责**:
- 执行单个迁移步骤
- 执行完整的迁移计划
- 提供进度更新

**关键方法**:
- `executeStep(_:at:)`: 执行单个迁移步骤
- `executePlan(_:progressHandler:)`: 执行完整迁移计划

### 5. MigrationProgressReporter

负责管理和报告迁移进度。

**主要职责**:
- 跟踪迁移状态
- 更新迁移进度
- 报告迁移错误
- 与 UI 层集成

**关键方法**:
- `updateState(_:)`: 更新迁移状态
- `updateProgress(_:)`: 更新迁移进度
- `reportMigrationStarted()`: 报告迁移开始
- `reportMigrationCompleted(result:)`: 报告迁移完成
- `reportMigrationFailed(error:)`: 报告迁移失败

### 6. CoreDataResourceManager

负责管理 CoreData 资源，是架构中的基础组件。

**主要职责**:
- 获取模型 URL
- 加载对象模型
- 管理备份目录
- 生成存储 URL
- 在多 Bundle 环境中查找资源

**关键特性**:
- **多 Bundle 支持**: 能够在多个 Bundle 中查找资源，适应模块化应用架构
- **灵活初始化**: 支持自定义模型名称和 Bundle 集合
- **智能资源查找**: 支持多种命名格式和目录结构
- **内置日志系统**: 提供详细的错误和警告信息，便于诊断问题

**关键方法**:
- `modelURL()`: 获取模型 URL
- `mergedObjectModel()`: 获取合并的对象模型
- `allModels()`: 获取所有模型
- `createBackupDirectory()`: 创建备份目录
- `backupStoreURL()`: 生成备份存储 URL
- `cleanupBackups(keepLatest:)`: 清理旧备份
- `modelURL(for:)`: 获取特定版本的模型 URL
- `mappingModel(from:to:)`: 获取特定版本间的映射模型

### 7. CoreDataModelVersionManager

负责管理模型版本。

**主要职责**:
- 管理模型版本信息
- 确定源模型和目标模型
- 确定迁移路径
- 加载映射模型

**关键方法**:
- `sourceModelVersion(for:)`: 确定源模型版本
- `destinationModelVersion()`: 确定目标模型版本
- `requiresMigration(at:)`: 检查是否需要迁移
- `migrationPath(from:to:)`: 确定迁移路径
- `migrationMapping(from:to:)`: 获取迁移映射

## 多 Bundle 资源管理

在模块化应用中，资源文件可能分散在多个 Bundle 中。CoreDataResourceManager 提供了强大的多 Bundle 支持功能：

### Bundle 搜索策略

CoreDataResourceManager 按以下顺序搜索资源：

1. **主要 Bundle**: 通过初始化器指定的主要 Bundle
2. **额外的 Bundle**: 通过初始化器提供的额外 Bundle 数组
3. **模块 Bundle**: 包含 CoreDataResourceManager 类的 Bundle
4. **资源 Bundle**: 模块相关的特定资源 Bundle

### 模型文件查找

支持多种模型文件命名和组织方式：

1. **标准 .momd 目录**:
   - `ModelName.momd/`
   - `ModelName.momd/VersionName.mom`

2. **单独的 .mom 文件**:
   - `ModelName.mom`
   - `ModelName_VersionIdentifier.mom`
   - `VersionIdentifier.mom`

### 映射模型查找

支持多种映射模型命名约定：

1. `Mapping_SourceVersion_to_DestinationVersion.cdm`
2. `ModelName_Mapping_SourceVersion_to_DestinationVersion.cdm`
3. `Mapping_SourceMajor.SourceMinor_to_DestinationMajor.DestinationMinor.cdm`

如果找不到自定义映射模型，则尝试使用 CoreData 的自动推断功能创建映射模型。

## 并发安全策略

迁移架构的所有关键组件都使用现代 Swift 并发特性，确保线程安全：

1. **@MainActor**: 标记需要在主线程上执行的类和方法，特别是与 UI 交互的组件。
2. **Sendable 协议**: 所有需要跨任务边界传递的类型都实现 Sendable 协议。
3. **async/await**: 使用结构化并发替代回调，简化异步代码。
4. **隔离状态**: 确保状态仅在单个异步上下文中修改。

## 数据保护策略

为了确保用户数据的安全，我们实施了以下保护措施：

1. **迁移前备份**: 在迁移开始前创建数据库备份。
2. **渐进式迁移**: 通过多步骤渐进式迁移，减少单步迁移的复杂性。
3. **临时存储**: 使用临时存储进行迁移，成功后才替换原始存储。
4. **错误恢复**: 迁移失败时，自动从备份中恢复。
5. **备份管理**: 定期清理旧备份，避免占用过多存储空间。
6. **辅助文件处理**: 适当处理 WAL 和 SHM 文件，确保数据完整性。

## 错误处理策略

迁移过程中的错误处理遵循以下策略：

1. **全面错误分类**: 使用 `MigrationError` 枚举对错误进行分类。
2. **错误传播**: 通过 throws 和 async/throws 机制传播错误。
3. **错误恢复**: 对于关键错误，尝试自动恢复操作。
4. **用户反馈**: 向用户提供清晰的错误信息和可能的解决方案。
5. **错误日志**: 记录详细的错误信息，便于诊断和改进。
6. **分级日志**: 使用不同级别的日志（信息、警告、错误）记录系统状态。

## 测试策略

迁移架构的测试策略包括：

1. **单元测试**: 测试各个组件的独立功能。
2. **集成测试**: 测试组件之间的交互。
3. **模拟测试**: 使用模拟对象测试特定场景和错误条件。
4. **性能测试**: 测试大型数据集的迁移性能。
5. **恢复测试**: 测试从备份恢复的功能。
6. **Bundle 测试**: 测试在不同 Bundle 环境下的资源加载。

## 使用示例

以下是迁移架构的基本使用示例：

```swift
// 获取应用存储 URL
let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
  .appendingPathComponent("OnlySlide.sqlite")

// 执行迁移
Task {
  do {
    let migrationManager = CoreDataMigrationManager.shared
    let needsMigration = try await migrationManager.checkAndMigrateStoreIfNeeded(at: storeURL)
    
    if needsMigration {
      print("迁移成功完成")
    } else {
      print("不需要迁移")
    }
  } catch {
    print("迁移失败: \(error.localizedDescription)")
  }
}
```

### 自定义 Bundle 的使用示例

```swift
// 创建自定义 Bundle 集合的资源管理器
let mainBundle = Bundle.main
let frameworkBundle = Bundle(for: MyFrameworkClass.self)
let resourceManager = CoreDataResourceManager.shared(withBundles: [mainBundle, frameworkBundle])

// 使用自定义资源管理器创建其他组件
let backupManager = BackupManager(resourceManager: resourceManager)
let planner = MigrationPlanner(resourceManager: resourceManager)
let executor = MigrationExecutor(planner: planner)

// 创建迁移管理器
let migrationManager = CoreDataMigrationManager(
    progressReporter: MigrationProgressReporter(),
    backupManager: backupManager,
    planner: planner,
    executor: executor
)

// 执行迁移
Task {
    try await migrationManager.checkAndMigrateStoreIfNeeded(at: storeURL)
}
```

## 结论

我们的 CoreData 迁移架构采用现代化、组件化的设计，确保了数据迁移过程的安全性、可靠性和用户友好性。通过明确组件职责、实施并发安全策略、全面的错误处理以及强大的资源管理，该架构能够有效管理 CoreData 模型的演进过程，保护用户数据的完整性，同时适应模块化应用架构的需求。 