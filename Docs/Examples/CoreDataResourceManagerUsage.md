# CoreDataResourceManager 使用示例

本文档提供了关于如何在实际项目中使用增强版 `CoreDataResourceManager` 的详细示例和最佳实践。

## 基本用法

### 使用默认配置

最简单的使用方式是使用共享实例和默认配置：

```swift
import CoreDataModule

// 获取共享实例
let resourceManager = CoreDataResourceManager.shared

// 使用资源管理器加载模型
let model = resourceManager.mergedObjectModel()

// 创建持久化存储协调器
let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model!)

// 获取默认存储 URL
let storeURL = resourceManager.defaultStoreURL()

// 添加持久化存储
do {
    try coordinator.addPersistentStore(
        ofType: NSSQLiteStoreType,
        configurationName: nil,
        at: storeURL,
        options: nil
    )
    print("成功加载存储")
} catch {
    print("加载存储失败: \(error)")
}
```

### 自定义模型名称

如果您的模型名称不是默认的 "OnlySlide"，可以指定自定义名称：

```swift
// 创建使用自定义模型名称的资源管理器
let resourceManager = CoreDataResourceManager(modelName: "MyCustomModel")

// 使用资源管理器
let model = resourceManager.mergedObjectModel()
let storeURL = resourceManager.defaultStoreURL()
```

### 使用多个 Bundle

在模块化应用中，模型文件可能分布在多个 Bundle 中。可以指定多个 Bundle 进行搜索：

```swift
// 准备需要搜索的 Bundle 数组
let mainBundle = Bundle.main
let frameworkBundle = Bundle(for: MyFrameworkClass.self)
let pluginBundle = Bundle(url: pluginURL)!

// 创建使用多个 Bundle 的资源管理器
let resourceManager = CoreDataResourceManager(
    modelName: "MyApp",
    bundles: [mainBundle, frameworkBundle, pluginBundle]
)

// 使用资源管理器
let model = resourceManager.mergedObjectModel()
```

或者使用共享实例工厂方法：

```swift
let bundles = [Bundle.main, Bundle(for: MyFrameworkClass.self)]
let resourceManager = CoreDataResourceManager.shared(withBundles: bundles)
```

## 高级用法

### 使用备份功能

```swift
// 创建备份
let backupURL = resourceManager.backupStoreURL()
let storeURL = resourceManager.defaultStoreURL()

// 复制当前存储到备份位置
do {
    try FileManager.default.copyItem(at: storeURL, to: backupURL)
    
    // 同时复制辅助文件（WAL 和 SHM）
    let walURL = storeURL.appendingPathExtension("wal")
    let shmURL = storeURL.appendingPathExtension("shm")
    let backupWalURL = backupURL.appendingPathExtension("wal")
    let backupShmURL = backupURL.appendingPathExtension("shm")
    
    if FileManager.default.fileExists(atPath: walURL.path) {
        try FileManager.default.copyItem(at: walURL, to: backupWalURL)
    }
    
    if FileManager.default.fileExists(atPath: shmURL.path) {
        try FileManager.default.copyItem(at: shmURL, to: backupShmURL)
    }
    
    print("备份创建成功: \(backupURL.lastPathComponent)")
} catch {
    print("创建备份失败: \(error)")
}

// 清理旧备份
resourceManager.cleanupBackups(keepLatest: 3)
```

### 查找模型版本

```swift
// 定义模型版本
let version1_0 = ModelVersion(major: 1, minor: 0, patch: 0)
let version1_1 = ModelVersion(major: 1, minor: 1, patch: 0)

// 获取特定版本的模型
if let modelURL = resourceManager.modelURL(for: version1_0),
   let model = NSManagedObjectModel(contentsOf: modelURL) {
    print("成功加载版本 \(version1_0.identifier) 的模型")
}

// 获取版本之间的映射模型
if let mappingModel = resourceManager.mappingModel(from: version1_0, to: version1_1) {
    print("成功加载从 \(version1_0.identifier) 到 \(version1_1.identifier) 的映射模型")
}
```

### 在迁移架构中使用

```swift
// 创建使用自定义资源管理器的迁移组件
let resourceManager = CoreDataResourceManager(
    modelName: "MyApp", 
    bundle: Bundle.main,
    additionalBundles: [Bundle(for: MyFrameworkClass.self)]
)

// 创建模型版本管理器
let versionManager = CoreDataModelVersionManager(resourceManager: resourceManager)

// 创建迁移规划器
let planner = MigrationPlanner(
    resourceManager: resourceManager,
    modelVersionManager: versionManager
)

// 创建备份管理器
let backupManager = BackupManager(
    resourceManager: resourceManager,
    configuration: BackupConfiguration(
        maxBackups: 5,
        backupBeforeMigration: true
    )
)

// 创建迁移执行器
let executor = MigrationExecutor(planner: planner)

// 创建迁移进度报告器
let progressReporter = MigrationProgressReporter()

// 创建迁移管理器
let migrationManager = CoreDataMigrationManager(
    progressReporter: progressReporter,
    backupManager: backupManager,
    planner: planner,
    executor: executor
)

// 执行迁移
Task {
    do {
        let storeURL = resourceManager.defaultStoreURL()
        let migrated = try await migrationManager.checkAndMigrateStoreIfNeeded(at: storeURL)
        
        if migrated {
            print("迁移成功完成")
        } else {
            print("不需要迁移")
        }
    } catch {
        print("迁移失败: \(error)")
    }
}
```

## 最佳实践

### 1. 统一模型命名约定

为避免混淆，建议采用一致的命名约定：

- 模型文件: `ModelName.xcdatamodeld`
- 版本模型文件: `ModelName_VersionIdentifier.mom` 或在 `.momd` 目录中的 `VersionIdentifier.mom`
- 映射模型文件: `Mapping_SourceVersion_to_DestinationVersion.cdm`

### 2. Bundle 管理策略

- **主应用 Bundle**: 放置主要模型文件和当前版本
- **框架 Bundle**: 包含框架特定的实体和版本
- **插件 Bundle**: 可能包含扩展实体和关系

### 3. 资源加载性能优化

- 缓存已加载的模型和映射模型
- 在应用启动时预加载常用模型
- 在后台线程执行资源查找和加载

### 4. 错误处理

```swift
do {
    guard let model = resourceManager.mergedObjectModel() else {
        throw NSError(
            domain: "com.onlyslide.coredata",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: "无法加载合并模型"]
        )
    }
    
    // 使用模型...
} catch {
    // 记录错误
    print("模型加载失败: \(error)")
    
    // 尝试恢复策略
    if let backupModel = resourceManager.allModels().first {
        print("使用备用模型")
        // 使用备用模型...
    } else {
        // 向用户显示错误
        print("无法恢复，请重新安装应用")
    }
}
```

### 5. 备份管理

- 定期创建数据库备份
- 在重要操作前创建备份
- 实现自动和手动备份选项
- 合理清理旧备份，避免占用过多存储空间

## 故障排除

### 问题: 找不到模型文件

**解决方案**:
1. 检查模型名称是否正确
2. 验证模型文件是否包含在目标的资源中
3. 检查 Bundle 设置是否正确
4. 使用资源管理器的日志功能诊断问题

```swift
// 启用详细日志（在DEBUG配置中）
// 查看控制台输出以获取更多信息
let resourceManager = CoreDataResourceManager(modelName: "MyModel")
```

### 问题: 迁移失败

**解决方案**:
1. 确保提供了正确的映射模型
2. 检查版本标识符是否匹配
3. 从备份恢复数据

```swift
// 恢复最新备份
let backups = resourceManager.allBackups()
if let latestBackup = backups.sorted(by: { /* 排序逻辑 */ }).first {
    // 恢复备份
}
```

## 结论

增强版的 `CoreDataResourceManager` 提供了强大的功能，使得在模块化环境中管理 CoreData 资源变得更加简单和可靠。通过遵循本文档提供的示例和最佳实践，您可以充分利用这些功能，构建健壮的数据管理解决方案。 