# CoreData 同步模块

> **注意**: 此文档已移至 [CoreDataModule 文档目录](../../../../../CoreDataModule/README.md)

本目录包含CoreData模块的同步相关代码。

详细文档请参考：
- [CoreDataModule-Structure.md](../../../../../Docs/Modules/CoreDataModule-Structure.md)
- [CustomMappingModelGuide.md](../../../../../Docs/Modules/CustomMappingModelGuide.md)

# CoreData 同步组件已移动

本目录下的CoreData同步相关代码已迁移到`CoreDataModule/Sync`目录。

请从新位置导入和使用这些组件：

```swift
import CoreDataModule

// 使用同步管理器
let syncManager = CoreDataSyncManager.shared
```

原始文件的备份保存为`.bak`文件。
