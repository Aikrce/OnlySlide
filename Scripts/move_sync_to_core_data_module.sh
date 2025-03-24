#!/bin/bash

# 显示要执行的操作
echo "准备将同步相关文件移动到CoreDataModule..."

# 源目录和目标目录
SOURCE_DIR="Sources/Core/Data/Persistence/CoreData/Sync"
TARGET_DIR="Sources/CoreDataModule/Sync"

# 创建目标目录
echo "创建目标目录: $TARGET_DIR"
mkdir -p "$TARGET_DIR"

# 移动文件
echo "移动以下文件:"
for file in "$SOURCE_DIR"/*.swift; do
  if [ -f "$file" ]; then
    filename=$(basename "$file")
    echo "- $filename"
    cp "$file" "$TARGET_DIR/"
    
    # 更新导入语句
    sed -i '' 's/import Core/import Core\nimport CoreDataModule/g' "$TARGET_DIR/$filename"
    
    # 备份原文件而不是删除
    mv "$file" "$file.bak"
  fi
done

# 创建README以说明文件已移动
echo "创建README文件..."
cat > "$SOURCE_DIR/README.md" << EOF
# CoreData 同步组件已移动

本目录下的CoreData同步相关代码已迁移到\`CoreDataModule/Sync\`目录。

请从新位置导入和使用这些组件：

\`\`\`swift
import CoreDataModule

// 使用同步管理器
let syncManager = CoreDataSyncManager.shared
\`\`\`

原始文件的备份保存为\`.bak\`文件。
EOF

echo "移动操作完成！"
echo "同步相关文件已移动到: $TARGET_DIR" 