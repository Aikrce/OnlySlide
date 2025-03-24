# CoreData 性能模块

> **注意**: 此文档已移至 [CoreDataModule 文档目录](../../../../../CoreDataModule/README.md)

本目录包含CoreData模块的性能优化相关代码。

详细文档请参考：
- [CoreDataModule-Structure.md](../../../../../Docs/Modules/CoreDataModule-Structure.md)
- [CustomMappingModelGuide.md](../../../../../Docs/Modules/CustomMappingModelGuide.md)

# CoreData 性能监控组件已移动

本目录下的CoreData性能监控相关代码已迁移到`CoreDataModule/Performance`目录。

请从新位置导入和使用这些组件：

```swift
import CoreDataModule

// 使用性能监控
let monitor = CoreDataPerformanceMonitor.shared
```

原始文件的备份保存为`.bak`文件。
