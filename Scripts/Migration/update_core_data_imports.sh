#!/bin/bash

# 显示要执行的操作
echo "准备更新CoreData引用..."

# 需要搜索的目录
SEARCH_DIRS=("Sources/Core" "Sources/Features" "Sources/App" "Tests")

# 创建临时文件
TEMP_FILE=$(mktemp)

# 查找包含特定CoreData引用但不包含import CoreDataModule的文件
echo "查找需要更新的文件..."
FILES_TO_UPDATE=()

for dir in "${SEARCH_DIRS[@]}"; do
  echo "搜索目录: $dir"
  
  # 找出包含CoreData相关类引用的文件
  grep -l "CoreDataManager\|CoreDataStack\|CoreDataMigrationManager\|CoreDataModelVersionManager\|CoreDataError" "$dir"/**/*.swift 2>/dev/null | while read file; do
    # 检查文件是否已经导入CoreDataModule
    if ! grep -q "import CoreDataModule" "$file"; then
      echo "  找到需要更新的文件: $file"
      FILES_TO_UPDATE+=("$file")
      
      # 添加CoreDataModule导入
      echo "  - 添加CoreDataModule导入"
      
      # 检查是否有其他import语句
      if grep -q "^import " "$file"; then
        # 读取文件并添加导入语句到最后一个import下方
        awk '
          /^import / { last_import = NR }
          { print }
          END { if (last_import > 0) system("sed -i \"" last_import "a\\import CoreDataModule\" \"'$file'\"") }
        ' "$file" > /dev/null
      else
        # 如果没有其他import语句，添加到文件顶部
        sed -i '1i\import CoreDataModule' "$file"
      fi
    fi
  done
done

echo "更新完成！"

# 创建一个报告文件
echo "创建更新报告..."
REPORT_FILE="update_report_$(date '+%Y%m%d-%H%M%S').txt"

echo "CoreData引用更新报告" > "$REPORT_FILE"
echo "日期: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "更新的文件:" >> "$REPORT_FILE"

if [ ${#FILES_TO_UPDATE[@]} -eq 0 ]; then
  echo "没有需要更新的文件" >> "$REPORT_FILE"
else
  for file in "${FILES_TO_UPDATE[@]}"; do
    echo "- $file" >> "$REPORT_FILE"
  done
fi

echo "" >> "$REPORT_FILE"
echo "完成时间: $(date)" >> "$REPORT_FILE"

echo "报告已保存到: $REPORT_FILE"
echo "所有更新操作已完成！" 