# CoreDataModule 目录结构

本文档介绍了 CoreDataModule 的目录结构和各个组件的作用，帮助开发者快速理解项目组织。

## 顶层目录结构

```
CoreDataModule/
├── Sources/                   # 源代码
│   └── CoreDataModule/        # 模块源代码
├── Tests/                     # 测试代码
│   └── CoreDataModuleTests/   # 模块测试代码
├── Scripts/                   # 实用脚本
├── Templates/                 # 模板文件
│   └── MigrationModels/       # 迁移模型模板
└── Docs/                      # 文档
```

## 源代码结构

```
Sources/CoreDataModule/
├── AppStartup/                # 应用启动相关代码
│   ├── MigrationStartupHandler.swift  # 应用启动时的迁移处理器
│   └── ...
├── Core/                      # 核心组件
│   ├── CoreDataStack.swift    # CoreData 堆栈
│   └── ...
├── Migration/                 # 迁移相关代码
│   ├── CoreDataMigrationManager.swift          # 迁移管理器
│   ├── CoreDataModelVersionManager.swift       # 版本管理器
│   ├── MappingModelFinder.swift                # 映射模型查找器
│   ├── CustomMappingModels/                    # 自定义映射模型
│   │   ├── SlideToSlideV2MappingModel.swift    # Slide 实体映射模型
│   │   └── ...
│   └── ...
├── Models/                    # 数据模型
│   ├── ModelVersion.swift     # 模型版本枚举
│   └── ...
├── UI/                        # 用户界面组件
│   ├── MigrationProgressView.swift  # 迁移进度视图
│   └── ...
├── Demo/                      # 演示代码
│   ├── AppEntryDemo.swift     # 应用入口点演示
│   └── ...
└── README.md                  # 模块说明文档
```

## 测试代码结构

```
Tests/CoreDataModuleTests/
├── Migration/                 # 迁移测试
│   ├── MigrationTests.swift   # 通用迁移测试
│   ├── SlideV1ToSlideV2MappingTests.swift  # Slide 实体映射测试
│   └── ...
├── Core/                      # 核心功能测试
│   ├── CoreDataStackTests.swift  # CoreData 堆栈测试
│   └── ...
└── ...
```

## 脚本和工具

```
Scripts/
├── GenerateMappingModelTemplate.swift  # 生成映射模型模板的脚本
└── ...
```

## 文档

```
Docs/
├── README.md                      # 主要文档
├── CoreDataModule-Structure.md    # 目录结构文档（本文件）
├── CustomMappingModelGuide.md     # 自定义映射模型指南
└── ...
```

## 组件说明

### 1. 应用启动 (AppStartup)

- **MigrationStartupHandler**：应用启动时的迁移入口点，负责检测并执行数据库迁移

### 2. 核心组件 (Core)

- **CoreDataStack**：CoreData 堆栈，负责管理持久化存储和上下文

### 3. 迁移组件 (Migration)

- **CoreDataMigrationManager**：执行迁移操作，处理备份和恢复
- **CoreDataModelVersionManager**：管理模型版本，检测是否需要迁移
- **MappingModelFinder**：查找和加载适用的映射模型
- **自定义映射模型**：为特定实体和版本之间的复杂迁移提供定制逻辑

### 4. 数据模型 (Models)

- **ModelVersion**：定义模型版本枚举，支持模型之间的顺序比较

### 5. 用户界面 (UI)

- **MigrationProgressView**：显示迁移进度的 SwiftUI 视图

### 6. 演示代码 (Demo)

- **AppEntryDemo**：演示如何在应用启动时集成迁移框架

## 重要文件说明

| 文件 | 说明 |
|------|------|
| `MigrationStartupHandler.swift` | 应用启动时的迁移处理器，负责检测并执行数据库迁移 |
| `CoreDataMigrationManager.swift` | 迁移管理器，负责执行迁移操作，处理备份和恢复 |
| `CoreDataModelVersionManager.swift` | 版本管理器，负责管理模型版本，检测是否需要迁移 |
| `MappingModelFinder.swift` | 映射模型查找器，负责查找和加载适用的映射模型 |
| `ModelVersion.swift` | 模型版本枚举，定义所有可用的模型版本 |
| `MigrationProgressView.swift` | 迁移进度视图，显示迁移进度 |
| `AppEntryDemo.swift` | 应用入口点演示，演示如何在应用启动时集成迁移框架 |

## 工作流程

1. 应用启动时，`MigrationStartupHandler` 检测是否需要迁移
2. 如果需要迁移，`CoreDataMigrationManager` 执行迁移操作
3. `CoreDataModelVersionManager` 确定源版本和目标版本
4. `MappingModelFinder` 查找适用的映射模型
5. 如果找到自定义映射模型，使用自定义迁移策略
6. 迁移过程中，通过 `MigrationProgressView` 显示进度
7. 迁移完成后，应用继续正常启动

## 添加新版本的步骤

1. 在 Xcode 中创建新的 CoreData 模型版本
2. 更新 `ModelVersion` 枚举，添加新版本
3. 如果需要复杂迁移，使用 `GenerateMappingModelTemplate.swift` 脚本生成模板
4. 实现自定义映射策略
5. 创建 Xcode 映射模型文件
6. 编写迁移测试 