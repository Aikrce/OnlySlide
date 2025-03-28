# CoreData 模块迁移指南

本目录下的CoreData相关代码已迁移到独立的`CoreDataModule`模块中。

## 如何引用CoreData功能

在Swift文件中，使用以下导入语句：

```swift
import CoreDataModule
```

## 主要类和结构

从`Core`模块引用以下CoreData类和结构：

- `CoreDataManager`: 核心数据管理器
- `CoreDataStack`: Core Data堆栈管理
- `CoreDataMigrationManager`: 数据迁移管理器
- `CoreDataModelVersionManager`: 模型版本管理器
- `CoreDataError`: 错误类型和处理

## 例子

```swift
import CoreDataModule

// 使用CoreDataManager
let manager = CoreDataManager.shared

// 使用错误处理
do {
    // ...
} catch let error as CoreDataError {
    // 处理CoreData错误
}
```

更多详情请参阅`CoreDataModule`模块文档。
