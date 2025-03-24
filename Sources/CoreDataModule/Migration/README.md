# CoreData 迁移框架

这个文档介绍了 OnlySlide 项目中的 CoreData 迁移框架的设计与使用方法。该框架旨在提供一个强大且灵活的机制，用于处理 CoreData 数据模型的版本迁移，确保应用更新后用户数据的顺利过渡。

## 框架概述

本迁移框架包含以下主要组件：

1. **CoreDataModelVersionManager**：模型版本管理器，负责管理数据模型版本和提供版本之间的迁移路径。
2. **CoreDataMigrationManager**：迁移管理器，负责执行实际的迁移过程。
3. **MappingModelFinder**：映射模型查找器，用于发现或创建数据模型间的映射规则。
4. **EntityMigrationPolicy**：实体迁移策略，用于自定义实体迁移逻辑。

## 迁移流程

迁移过程分为以下几个步骤：

1. 检查数据库是否需要迁移
2. 创建数据库备份（可选）
3. 确定迁移路径
4. 执行渐进式迁移
5. 替换原始数据库
6. 清理临时文件和旧备份

## 使用示例

### 基本用法

```swift
import CoreDataModule

// 在应用启动时执行迁移
func performMigrationIfNeeded() async {
    do {
        let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("OnlySlide.sqlite")
        
        let migrationManager = CoreDataMigrationManager.shared
        
        let didMigrate = try await migrationManager.performMigration(at: storeURL) { progress in
            // 更新UI显示迁移进度
            DispatchQueue.main.async {
                updateProgressUI(progress)
            }
        }
        
        if didMigrate {
            print("数据库迁移成功")
        } else {
            print("数据库无需迁移")
        }
    } catch {
        print("数据库迁移失败: \(error.localizedDescription)")
    }
}

// 更新UI显示迁移进度
func updateProgressUI(_ progress: MigrationProgress) {
    let percentage = Int(progress.percentage)
    progressBar.progress = Float(percentage) / 100.0
    progressLabel.text = "\(percentage)% - \(progress.description)"
}
```

### 使用自定义配置

```swift
// 创建自定义迁移配置
let configuration = MigrationConfiguration(
    shouldCreateBackup: true,           // 是否创建备份
    shouldRestoreFromBackupOnFailure: true,  // 失败时是否恢复备份
    shouldRemoveOldBackups: true,       // 是否清理旧备份
    maxBackupsToKeep: 3                 // 保留的最大备份数量
)

// 创建使用自定义配置的迁移管理器
let migrationManager = CoreDataMigrationManager(
    bundle: Bundle.module,
    configuration: configuration
)
```

### 手动恢复备份

```swift
// 列出可用备份
func listAvailableBackups() async -> [String] {
    do {
        let backups = try CoreDataMigrationManager.shared.listAvailableBackups()
        return backups.map { backup in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            let dateString = dateFormatter.string(from: backup.date)
            return "备份 \(dateString)"
        }
    } catch {
        print("获取备份列表失败: \(error.localizedDescription)")
        return []
    }
}

// 恢复到指定备份
func restoreToBackup(at index: Int) async {
    do {
        let backups = try CoreDataMigrationManager.shared.listAvailableBackups()
        guard index < backups.count else { return }
        
        let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("OnlySlide.sqlite")
        
        try CoreDataMigrationManager.shared.restoreFromBackup(
            backupURL: backups[index].url,
            to: storeURL
        )
        
        print("已成功恢复到备份")
    } catch {
        print("恢复备份失败: \(error.localizedDescription)")
    }
}

// 恢复到最新备份
func restoreToLatestBackup() async {
    do {
        let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("OnlySlide.sqlite")
        
        try CoreDataMigrationManager.shared.restoreToLatestBackup(for: storeURL)
        print("已成功恢复到最新备份")
    } catch {
        print("恢复到最新备份失败: \(error.localizedDescription)")
    }
}
```

## 创建自定义实体迁移策略

如果需要为特定实体提供自定义迁移逻辑，可以继承 `EntityMigrationPolicy` 并重写 `customMigrate` 方法：

```swift
// 自定义实体迁移策略
class CustomEntityMigrationPolicy: EntityMigrationPolicy {
    
    override func customMigrate(
        source: NSManagedObject, 
        destination: NSManagedObject,
        mapping: NSEntityMapping, 
        manager: NSMigrationManager
    ) throws {
        // 首先调用父类方法
        try super.customMigrate(source: source, destination: destination, mapping: mapping, manager: manager)
        
        // 添加自定义迁移逻辑
        if let title = source.value(forKey: "title") as? String {
            // 例如：在标题前加上前缀
            destination.setValue("迁移后: " + title, forKey: "title")
        }
        
        // 设置新增属性的默认值
        if destination.entity.attributesByName["newAttribute"] != nil {
            destination.setValue("默认值", forKey: "newAttribute")
        }
    }
}
```

然后将这个自定义策略类添加到 `MappingModelFinder` 的 `getMigrationPolicyClassName` 方法中：

```swift
private func getMigrationPolicyClassName(for entityName: String) -> String? {
    switch entityName {
    case "YourEntity":
        return String(describing: CustomEntityMigrationPolicy.self)
    // 其他实体...
    default:
        return String(describing: EntityMigrationPolicy.self)
    }
}
```

## 最佳实践

1. **总是创建备份**：在执行迁移前创建数据库备份，确保数据安全。
2. **渐进式迁移**：不要尝试直接从很早的版本迁移到最新版本，而是通过中间版本逐步迁移。
3. **测试数据迁移**：在发布应用更新前，使用不同版本的测试数据测试迁移过程。
4. **提供进度反馈**：对于大型数据库，向用户显示迁移进度，避免他们认为应用卡住。
5. **处理错误**：实现适当的错误处理和恢复机制。
6. **保持轻量级迁移**：尽可能使用轻量级迁移（使用推断映射），减少手动映射模型的需求。

## 故障排除

如果遇到迁移问题，请尝试以下步骤：

1. 检查错误日志，了解具体失败原因。
2. 确保数据模型版本更新正确，包括版本号和模型标识符。
3. 验证实体、属性和关系的名称是否正确。
4. 尝试使用备份恢复数据库。
5. 如果问题依然存在，考虑提供数据导出功能，让用户保存数据，然后重新创建数据库。 