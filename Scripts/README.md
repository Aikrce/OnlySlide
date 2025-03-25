# OnlySlide 脚本目录

此目录包含OnlySlide项目的各种脚本工具，按功能分类组织。

## 目录结构

- `Build/` - 构建相关脚本
  - `clean_xcode.sh` - 清理Xcode派生数据和项目缓存
  
- `Maintenance/` - 项目维护脚本
  - `cleanup.sh` - 清理项目中的重复定义
  - `fix_imports.sh` - 修复导入语句
  - `check_naming.sh` - 检查命名约定一致性
  - `optimize_imports.sh` - 导入语句优化
  - `pre_release_check.sh` - 发布前检查

- `Migration/` - 迁移相关脚本
  - `cleanup_core_data.sh` - 清理核心数据模块
  - `move_*_to_core_data_module.sh` - 将代码移动到核心数据模块
  - `update_core_data_imports.sh` - 更新核心数据导入语句

- `Swift/` - Swift脚本工具
  - `GenerateMappingModelTemplate.swift` - 生成映射模型模板
  - `backup.swift` - 备份工具

- `Hooks/` - Git hooks脚本
  - `pre-commit` - 提交前检查

## 使用指南

### 构建和清理

构建项目前清理Xcode环境：

```bash
./Scripts/Build/clean_xcode.sh
```

### 维护工具

执行发布前检查：

```bash
./Scripts/Maintenance/pre_release_check.sh
```

清理项目中的重复定义：

```bash
./Scripts/Maintenance/cleanup.sh
```

### 迁移工具

将测试移动到核心数据模块：

```bash
./Scripts/Migration/move_test_to_core_data_module.sh
```

### Swift脚本工具

生成映射模型模板：

```bash
swift Scripts/Swift/GenerateMappingModelTemplate.swift
```

### Git Hooks

将Git hooks复制到git目录：

```bash
cp Scripts/Hooks/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit
``` 