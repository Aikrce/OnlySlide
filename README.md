# OnlySlide

OnlySlide 是一个现代化的幻灯片制作和演示工具，基于 Swift 和 Core Data 构建。

## 架构说明

### 整体架构

项目采用清晰的分层架构设计：

```
OnlySlide
├── App          # 应用层：UI 和用户交互
├── Features     # 功能层：业务逻辑和功能模块
├── Core         # 核心层：基础设施和数据处理
└── Common       # 通用层：工具类和扩展
```

### 数据层设计

数据层采用 Core Data 作为本地存储引擎，主要包含以下组件：

- **CoreDataModelVersionManager**: 负责数据模型版本管理
- **CoreDataMigrationManager**: 处理数据迁移
- **CoreDataSyncManager**: 管理数据同步
- **CoreDataConflictResolver**: 处理数据冲突

### 同步机制

数据同步采用增量同步策略：

1. 本地变更追踪
2. 冲突检测
3. 自动合并
4. 手动解决

## API 文档

### 文档管理

```swift
// 创建文档
func create(title: String, content: String, type: DocumentType) async throws -> Document

// 更新文档
func update(id: UUID, title: String?, content: String?) async throws -> Document

// 删除文档
func delete(id: UUID) async throws
```

### 同步 API

```swift
// 执行同步
func sync() async throws

// 获取同步状态
var syncState: SyncState { get async }

// 解决冲突
func resolveConflict(localObject: NSManagedObject, serverObject: [String: Any]) throws -> NSManagedObject
```

### 数据迁移

```swift
// 执行数据迁移
func performMigration(at storeURL: URL, progress: ((MigrationProgress) -> Void)?) async throws -> Bool
```

## 使用说明

### 安装

1. 克隆仓库：
```bash
git clone https://github.com/yourusername/OnlySlide.git
```

2. 安装依赖：
```bash
swift package resolve
```

### 运行测试

```bash
swift test
```

### 开发流程

1. 创建新功能分支
2. 编写测试
3. 实现功能
4. 提交 PR

### 最佳实践

1. 始终编写测试
2. 遵循 Swift 风格指南
3. 使用适当的错误处理
4. 保持文档更新

## 性能优化

### 数据库优化

- 使用批量操作
- 索引关键字段
- 延迟加载

### 内存管理

- 使用自动引用计数
- 避免循环引用
- 及时释放资源

## 故障排除

### 常见问题

1. 同步失败
   - 检查网络连接
   - 验证认证状态
   - 查看日志

2. 数据迁移错误
   - 备份数据
   - 清理缓存
   - 重试迁移

### 调试技巧

1. 使用 Xcode 调试器
2. 检查 Core Data 日志
3. 监控内存使用

## 贡献指南

1. Fork 项目
2. 创建功能分支
3. 提交变更
4. 发起 Pull Request

## 许可证

MIT License 