# OnlySlide 项目架构文档

## 项目概述

OnlySlide 是一个用于创建和编辑幻灯片的应用程序，使用Swift开发，采用模块化架构，以支持跨平台（macOS和iOS）。

## 架构设计

项目采用分层架构设计，清晰分离关注点，提高代码可维护性和可测试性。

### 核心模块结构

项目划分为以下主要模块：

1. **核心模块 (Core)**
   - 包含业务逻辑和领域模型
   - 与UI无关，可独立测试
   - 依赖于CoreDataModule进行数据持久化

2. **CoreData模块 (CoreDataModule)**
   - 负责数据持久化存储
   - 包含CoreData数据模型、迁移管理和持久化操作
   - 可被Core和其他模块复用，降低耦合性

3. **UI模块 (App)**
   - 负责用户界面展示
   - 将用户操作转换为业务逻辑调用
   - 依赖于Core和CoreDataModule

4. **功能模块 (Features)**
   - 实现具体应用功能
   - 可以按功能划分子模块
   - 依赖于Core和CoreDataModule

5. **通用模块 (Common)**
   - 提供共用工具和组件
   - 被所有其他模块使用
   - 不依赖于其他任何模块

### 目录结构

```
OnlySlide/
├── Sources/
│   ├── Core/               # 核心业务逻辑
│   │   ├── Domain/         # 领域模型和业务规则
│   │   ├── Application/    # 应用服务和用例
│   │   └── Common/         # 核心模块内部共享代码
│   │
│   ├── CoreDataModule/     # CoreData持久化
│   │   ├── Manager/        # 核心管理器类
│   │   ├── Error/          # 错误处理
│   │   ├── Migration/      # 迁移相关
│   │   ├── Extensions/     # 扩展
│   │   └── Models/         # 数据模型
│   │
│   ├── App/                # UI层
│   │   ├── Views/          # 视图
│   │   ├── ViewModels/     # 视图模型
│   │   └── Controllers/    # 控制器
│   │
│   ├── Features/           # 功能模块
│   │   ├── Editor/         # 编辑器功能
│   │   ├── Presentation/   # 演示功能
│   │   └── Export/         # 导出功能
│   │
│   ├── Common/             # 通用模块
│   │   ├── Extensions/     # 扩展方法
│   │   ├── Utils/          # 工具类
│   │   └── UI/             # 通用UI组件
│   │
│   └── OnlySlide/          # 应用入口
│
├── Tests/                  # 测试目录
│   ├── CoreTests/          # 核心测试
│   ├── CoreDataTests/      # CoreData测试
│   ├── AppTests/           # UI测试
│   └── FeaturesTests/      # 功能测试
│
├── Docs/                   # 项目文档
└── Resources/              # 资源文件
```

## 设计决策

### 1. CoreData独立模块化

将CoreData相关代码抽取成独立模块的主要原因：

- **关注点分离**：持久化逻辑与业务逻辑分离
- **可复用性**：可以在不同模块中复用相同的持久化逻辑
- **单一职责**：每个模块专注于一个功能领域
- **独立测试**：可以独立测试持久化逻辑，不受业务逻辑影响

### 2. 错误处理策略

- 统一的错误类型：`CoreDataError`
- 集中式错误处理服务
- 清晰的错误恢复策略

### 3. 数据迁移策略

- 轻量级迁移支持
- 重型迁移管理
- 渐进式迁移支持多版本

## 测试策略

### 1. 单元测试

- **CoreTests**: 测试核心业务逻辑
- **CoreDataTests**: 测试数据持久化逻辑，使用内存存储
- **内部依赖注入**：允许注入模拟实现以隔离测试

### 2. 集成测试

- 测试模块间的集成
- 验证跨模块交互

### 3. UI测试

- 测试界面和用户交互
- 端到端功能验证

## 最佳实践

1. **依赖注入**：使用协议和依赖注入减少模块间硬编码依赖
2. **错误处理**：统一的错误处理和传播策略
3. **文档**：详细的接口和实现文档
4. **代码规范**：遵循统一的代码风格和命名约定

## 扩展计划

1. **性能优化**：对CoreData查询和批量操作的性能优化
2. **新功能支持**：模块化设计便于添加新功能
3. **跨平台扩展**：支持其他Apple平台，如iPad OS 