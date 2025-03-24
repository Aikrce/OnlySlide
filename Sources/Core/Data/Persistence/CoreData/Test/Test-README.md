# CoreData 测试模块

> **注意**: 此文档已移至 [CoreDataModule 文档目录](../../../../../CoreDataModule/README.md)

本目录包含CoreData模块的测试相关代码。

详细文档请参考：
- [CoreDataModule-Structure.md](../../../../../Docs/Modules/CoreDataModule-Structure.md)
- [CustomMappingModelGuide.md](../../../../../Docs/Modules/CustomMappingModelGuide.md)

# CoreData 测试辅助组件已移动

本目录下的CoreData测试相关代码已迁移到`CoreDataModule/Test`目录。

请从新位置导入和使用这些组件：

```swift
import CoreDataModule

// 使用测试管理器
let testManager = CoreDataTestManager()
```

原始文件的备份保存为`.bak`文件。
