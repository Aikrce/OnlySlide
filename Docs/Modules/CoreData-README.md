# OnlySlide CoreData 模块

> **注意**: CoreData 模块的详细文档已被重组到以下位置:

## 主要文档

- [CoreDataModule 主文档](../../Sources/CoreDataModule/README.md) - 完整的迁移框架文档
- [CoreDataModule 目录结构](CoreDataModule-Structure.md) - 模块目录结构和组件说明
- [自定义映射模型指南](CustomMappingModelGuide.md) - 创建和使用自定义迁移映射的详细指南

## 子模块文档

- [性能模块](../../Sources/Core/Data/Persistence/CoreData/Performance/Performance-README.md)
- [同步模块](../../Sources/Core/Data/Persistence/CoreData/Sync/Sync-README.md)
- [测试模块](../../Sources/Core/Data/Persistence/CoreData/Test/Test-README.md)

## 模块迁移

作为项目重构的一部分，原始的 CoreData 相关代码已经被迁移到新的 CoreDataModule 中，
以提高代码组织的清晰度和可维护性。所有的迁移相关功能现在在 CoreDataModule 中统一管理。 