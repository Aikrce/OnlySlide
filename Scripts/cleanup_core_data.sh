#!/bin/bash

# 显示要执行的操作
echo "准备清理Core模块中的冗余CoreData代码..."

# 要清理的目录
CORE_DATA_DIR="Sources/Core/Data/Persistence/CoreData"

# 创建备份目录
BACKUP_DIR="backup/CoreData-$(date '+%Y%m%d-%H%M%S')"
mkdir -p "$BACKUP_DIR"
echo "正在创建备份目录：$BACKUP_DIR"

# 备份当前文件
echo "正在备份当前文件..."
cp -R "$CORE_DATA_DIR"/* "$BACKUP_DIR"
echo "备份完成！"

# 移除冗余文件和目录
echo "移除以下冗余文件和目录："
echo "- CoreDataManager.swift"
echo "- CoreDataStack.swift"
echo "- CoreDataModelVersionManager.swift"
echo "- CoreDataError.swift"
echo "- Migration/"
echo "- Models/"
echo "- Error/"
echo "- Extensions/"

# 执行删除操作
rm -f "$CORE_DATA_DIR/CoreDataManager.swift"
rm -f "$CORE_DATA_DIR/CoreDataStack.swift"
rm -f "$CORE_DATA_DIR/CoreDataModelVersionManager.swift"
rm -f "$CORE_DATA_DIR/CoreDataError.swift"
rm -rf "$CORE_DATA_DIR/Migration"
rm -rf "$CORE_DATA_DIR/Models"
rm -rf "$CORE_DATA_DIR/Error"
rm -rf "$CORE_DATA_DIR/Extensions"

echo "清理完成！"
echo "如需恢复，请从备份目录复制：$BACKUP_DIR"

# 创建指导文件
echo "创建CoreData引用指导文件..."
mkdir -p "$CORE_DATA_DIR"
cat > "$CORE_DATA_DIR/README.md" << EOF
# CoreData 模块迁移指南

本目录下的CoreData相关代码已迁移到独立的\`CoreDataModule\`模块中。

## 如何引用CoreData功能

在Swift文件中，使用以下导入语句：

\`\`\`swift
import CoreDataModule
\`\`\`

## 主要类和结构

从\`Core\`模块引用以下CoreData类和结构：

- \`CoreDataManager\`: 核心数据管理器
- \`CoreDataStack\`: Core Data堆栈管理
- \`CoreDataMigrationManager\`: 数据迁移管理器
- \`CoreDataModelVersionManager\`: 模型版本管理器
- \`CoreDataError\`: 错误类型和处理

## 例子

\`\`\`swift
import CoreDataModule

// 使用CoreDataManager
let manager = CoreDataManager.shared

// 使用错误处理
do {
    // ...
} catch let error as CoreDataError {
    // 处理CoreData错误
}
\`\`\`

更多详情请参阅\`CoreDataModule\`模块文档。
EOF

echo "指导文件已创建：$CORE_DATA_DIR/README.md"
echo "清理操作全部完成！" 