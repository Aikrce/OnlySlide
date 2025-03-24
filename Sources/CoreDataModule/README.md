# CoreDataModule 迁移框架

## 概述

CoreDataModule 迁移框架是 OnlySlide 项目的一个核心组件，用于处理 CoreData 数据模型的版本升级和数据迁移。该框架提供了自动化的迁移流程，支持从任意版本迁移到最新版本，同时提供友好的用户界面展示迁移进度。

## 主要特性

- **自动迁移检测**：在应用启动时自动检测是否需要迁移
- **渐进式迁移**：支持多个版本间的渐进式迁移
- **映射模型管理**：内置映射模型查找器，支持自定义映射模型
- **备份与恢复**：迁移前自动备份，失败时自动恢复
- **SwiftUI 集成**：提供现代 SwiftUI 界面展示迁移进度
- **测试支持**：完整的测试套件确保迁移功能正常工作
- **自定义策略**：支持实体级别的自定义迁移策略

## 架构

迁移框架由以下主要组件组成：

1. **CoreDataModelVersionManager**：管理模型版本，检测是否需要迁移
2. **CoreDataMigrationManager**：执行迁移操作，处理备份和恢复
3. **MappingModelFinder**：查找适用的映射模型，支持自定义映射模型
4. **CustomEntityMigrationPolicies**：实体级别的自定义迁移策略
5. **MigrationStartupHandler**：应用启动时的迁移入口点
6. **MigrationProgressView**：显示迁移进度的 SwiftUI 视图

## 使用方法

### 基本用法

在应用入口点（如 SwiftUI 应用的 `App` 结构体）中集成迁移框架：

```swift
import SwiftUI
import CoreDataModule

@main
struct MyApp: App {
    @StateObject private var migrationManager = MigrationManager()
    
    var body: some Scene {
        WindowGroup {
            MigrationProgressView(migrationManager: migrationManager) {
                ContentView()  // 迁移完成后显示的主内容视图
            }
        }
    }
}
```

这将在应用启动时自动检查是否需要迁移，并在需要时执行迁移操作。迁移过程中会显示进度界面，迁移完成后自动切换到主内容视图。

### 自定义存储位置

如果您的 CoreData 存储不在默认位置，可以指定存储 URL：

```swift
migrationManager.checkAndMigrateStoreIfNeeded(at: customStoreURL)
```

### 监听迁移状态

您可以观察 `MigrationManager` 的状态变化：

```swift
migrationManager.$status.sink { status in
    switch status {
    case .inProgress:
        print("迁移正在进行中")
    case .completed:
        print("迁移已完成")
    case .failed(let error):
        print("迁移失败: \(error.localizedDescription)")
    }
}
```

## 添加新的模型版本

当您需要更新数据模型时，请按照以下步骤操作：

1. 在 Xcode 中添加新的模型版本：
   - 选择 .xcdatamodeld 文件
   - Editor -> Add Model Version...
   - 命名为有意义的名称（如 "ModelV2"）

2. 更新 `ModelVersion` 枚举，添加新版本：

```swift
public enum ModelVersion: String, CaseIterable, Comparable {
    case version1 = "ModelV1"
    case version2 = "ModelV2"
    case version3 = "ModelV3"  // 新添加的版本
    
    // 确保更新 latestVersion
    public static var latestVersion: ModelVersion {
        return .version3  // 更新为最新版本
    }
    
    // 实现 Comparable 协议的方法
    public static func < (lhs: ModelVersion, rhs: ModelVersion) -> Bool {
        return lhs.sortOrder < rhs.sortOrder
    }
    
    private var sortOrder: Int {
        switch self {
        case .version1: return 1
        case .version2: return 2
        case .version3: return 3  // 为新版本添加排序值
        }
    }
}
```

3. 如果需要自定义迁移逻辑，创建映射模型和自定义策略类。

## 创建自定义映射模型

对于复杂的模型变更（如实体重命名、属性类型变更等），需要创建自定义映射模型：

1. 创建 `.xcmappingmodel` 文件：
   - File -> New -> File... -> Core Data -> Mapping Model
   - 选择源模型和目标模型
   - 命名为 `Mapping_[Source]_to_[Destination].xcmappingmodel`

2. 配置实体映射：
   - 设置正确的映射类型（Copy, Transform, Add, Remove）
   - 配置属性映射
   - 如果需要，指定自定义实体迁移策略类

3. 创建自定义实体迁移策略类：

```swift
import Foundation
import CoreData

public final class MyEntityMigrationPolicy: NSEntityMigrationPolicy {
    override public func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // 调用父类方法创建基本实例
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
        
        // 获取目标实例
        guard let dInstance = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else {
            throw NSError(domain: "MigrationError", code: 1, userInfo: nil)
        }
        
        // 执行自定义迁移逻辑
        // ...
    }
}
```

4. 将自定义策略类添加到映射模型中：
   - 在 Xcode 的映射模型编辑器中，选择实体映射
   - 在 Inspector 面板中，设置 "Custom Policy" 为您的策略类名

## 测试迁移

框架提供了测试套件来验证迁移功能。您可以扩展测试套件来测试新的版本迁移：

```swift
func testMigrationFromVersion2ToVersion3() async throws {
    // 创建版本2的测试存储
    try createAndPopulateTestStore(
        version: .version2,
        at: tempStoreURL
    )
    
    // 执行迁移
    let didMigrate = try await migrationManager.performMigration(
        at: tempStoreURL
    )
    
    XCTAssertTrue(didMigrate, "迁移应该成功执行")
    
    // 验证迁移结果
    // ...
}
```

## 疑难解答

### 常见问题

1. **错误: "无法找到从版本X到版本Y的映射模型"**
   - 确保已创建并添加正确命名的映射模型文件
   - 验证映射模型中的实体和属性映射配置是否正确

2. **错误: "迁移操作无法完成"**
   - 检查自定义迁移策略类中是否有逻辑错误
   - 确保数据库文件未损坏
   - 查看备份目录是否存在可恢复的备份

3. **警告: "自动推断的映射模型可能不准确"**
   - 对于复杂变更，应创建自定义映射模型而非依赖自动推断

### 调试技巧

启用详细日志记录以帮助调试迁移问题：

```swift
// 在应用启动时设置
CoreDataMigrationManager.loggingEnabled = true
```

## 扩展点

### 1. 自定义迁移进度视图

您可以创建自定义迁移进度视图来替代默认的 `MigrationProgressView`：

```swift
struct MyCustomProgressView: View {
    @ObservedObject var migrationManager: MigrationManager
    
    var body: some View {
        // 自定义迁移界面...
    }
}
```

### 2. 自定义备份策略

可以通过修改 `MigrationConfiguration` 自定义备份行为：

```swift
let config = MigrationConfiguration(
    shouldCreateBackup: true,
    shouldRestoreFromBackupOnFailure: true,
    shouldRemoveOldBackups: true,
    maxBackupsToKeep: 5
)

let migrationManager = CoreDataMigrationManager(configuration: config)
```

### 3. 实现自定义恢复机制

在迁移失败后，您可以实现自定义恢复机制：

```swift
if case .failed(let error) = migrationManager.status {
    // 实现自定义恢复逻辑
    // ...
}
```

## 最佳实践

1. **始终在开发过程中测试迁移**：在更改数据模型时，同时测试从所有先前版本的迁移。

2. **为复杂变更创建自定义映射模型**：不要依赖自动推断的映射模型处理复杂的数据模型变更。

3. **保持迁移路径连续**：确保存在从任何旧版本到最新版本的迁移路径。

4. **使用轻量级迁移优化性能**：对于简单变更，使用轻量级迁移（无需映射模型）。

5. **备份关键数据**：在执行迁移前，确保关键用户数据已备份。

## 贡献

欢迎提交问题报告和改进建议！请按照以下步骤：

1. Fork 本仓库
2. 创建您的特性分支: `git checkout -b feature/my-new-feature`
3. 提交您的更改: `git commit -am 'Add some feature'`
4. 推送到分支: `git push origin feature/my-new-feature`
5. 提交拉取请求

## 许可证

本项目采用 [MIT 许可证](LICENSE.md) 进行授权。 