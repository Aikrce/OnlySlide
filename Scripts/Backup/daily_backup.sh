#!/bin/bash

# 创建备份目录
BACKUP_DIR="./Backups/DailyBackup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 备份关键文件
cp -r Sources/CoreDataModule/Models "$BACKUP_DIR"/
cp OnlySlide.xcodeproj/project.pbxproj "$BACKUP_DIR"/
cp -r Sources/Core/Data/Persistence/CoreData/OnlySlide.xcdatamodeld "$BACKUP_DIR"/

# 如果有.xcignore文件，也备份它
if [ -f .xcignore ]; then
  cp .xcignore "$BACKUP_DIR"/
fi

echo "备份已创建在: $BACKUP_DIR"
echo "正在提交Git更改..." 