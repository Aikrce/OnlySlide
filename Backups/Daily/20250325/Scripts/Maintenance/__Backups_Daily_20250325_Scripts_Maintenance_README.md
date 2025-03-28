# 项目维护脚本

这个目录包含了用于维护OnlySlide项目的各种实用脚本。这些脚本主要用于代码清理、修复和构建过程的辅助。

## 脚本列表

### cleanup.sh

清理项目中的重复定义文件，并创建备份。处理了以下问题：
- 移除重复的SyncState、MigrationResult定义
- 备份原始文件到Backups目录
- 清理临时文件和构建目录

用法：
```bash
./cleanup.sh
```

### fix_imports.sh

修复导入语句，为使用统一定义的文件添加正确的导入注释。这有助于确保代码使用正确的类型定义。

用法：
```bash
./fix_imports.sh
```

### clean_xcode.sh

清理Xcode项目缓存和派生数据文件夹，确保干净的构建环境。同时创建rebuild.sh脚本用于重新构建项目。

用法：
```bash
./clean_xcode.sh
```

### pre_release_check.sh

发布前检查脚本，执行一系列检查以确保代码质量和编译正确性：
- 检查重复定义
- 验证导入语句正确性
- 执行构建测试
- 检查命名约定一致性
- 验证文档更新

用法：
```bash
./pre_release_check.sh
```

## 使用建议

在发生编译错误或准备发布前，按以下顺序运行脚本：

1. 首先运行`cleanup.sh`清理重复定义
2. 然后运行`fix_imports.sh`修复导入语句
3. 接着运行`clean_xcode.sh`清理构建环境
4. 最后运行`pre_release_check.sh`执行发布前检查

所有脚本都会创建必要的备份，确保可以在需要时恢复原始文件。 