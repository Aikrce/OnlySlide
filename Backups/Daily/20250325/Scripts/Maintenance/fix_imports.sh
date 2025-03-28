#!/bin/bash

# 在文件中的import语句后添加注释行
add_comment_after_imports() {
    local file=$1
    local comment=$2
    sed -i.bak "s/import.*$/&\n$comment/" "$file"
    rm -f "${file}.bak"
}

# 查找使用SyncState但不是SyncState.swift的文件
FILES_USING_SYNCSTATE=$(grep -l "SyncState" --include="*.swift" Sources/ | grep -v "/Sync/SyncState.swift")

# 查找使用MigrationResult但不是MigrationResult.swift的文件
FILES_USING_MIGRATIONRESULT=$(grep -l "MigrationResult" --include="*.swift" Sources/ | grep -v "/Migration/MigrationResult.swift")

# 为使用SyncState的文件添加导入注释
for file in $FILES_USING_SYNCSTATE; do
    echo "Adding SyncState import comment to $file"
    add_comment_after_imports "$file" "// 使用统一的SyncState定义"
done

# 为使用MigrationResult的文件添加导入注释
for file in $FILES_USING_MIGRATIONRESULT; do
    echo "Adding MigrationResult import comment to $file"
    add_comment_after_imports "$file" "// 使用统一的MigrationResult定义"
done

echo "完成添加导入注释。" 