#!/bin/bash
# 项目根目录整理脚本
# 用于整理OnlySlide项目根目录中散落的各种格式文件

set -e
echo "===== 开始整理项目根目录 ====="

# 创建必要的目录结构
mkdir -p Docs/Reports
mkdir -p Scripts/Build
mkdir -p Scripts/Release
mkdir -p Scripts/Maintenance
mkdir -p Backups/ConfigBackups

# 移动构建和维护脚本到对应目录
if [ -f rebuild.sh ] && [ ! -f Scripts/Build/rebuild.sh ]; then
  echo "移动 rebuild.sh 到 Scripts/Build/"
  mv rebuild.sh Scripts/Build/
fi

if [ -f fix_empty_folders.sh ] && [ "$(dirname "$(realpath fix_empty_folders.sh)")" != "$(realpath Scripts/Maintenance)" ]; then
  echo "移动 fix_empty_folders.sh 到 Scripts/Maintenance/"
  mv fix_empty_folders.sh Scripts/Maintenance/
fi

if [ -f prepare_ios_release.sh ] && [ ! -f Scripts/Release/prepare_ios_release.sh ]; then
  echo "移动 prepare_ios_release.sh 到 Scripts/Release/"
  mv prepare_ios_release.sh Scripts/Release/
fi

# 清理符号链接
if [ -L fix_empty_folders.sh ]; then
  echo "移除符号链接 fix_empty_folders.sh"
  rm fix_empty_folders.sh
fi

# 整理报告文件
for report in Build_Fix_Report_*.md; do
  if [ -f "$report" ]; then
    echo "移动 $report 到 Docs/Reports/"
    mv "$report" Docs/Reports/
  fi
done

# 处理备份文件
if [ -f Package.swift.bak ]; then
  echo "移动 Package.swift.bak 到 Backups/ConfigBackups/"
  mv Package.swift.bak Backups/ConfigBackups/
fi

# 创建目录索引文档
cat > DIRECTORY.md << EOF
# OnlySlide 项目目录结构

## 主要目录
- **Frameworks/** - 框架和依赖
- **LocalPackages/** - 本地Swift包
- **OnlySlide/** - 主应用程序代码
- **Resources/** - 资源文件
- **Scripts/** - 构建和维护脚本
  - **Build/** - 构建相关脚本
  - **Maintenance/** - 维护和辅助脚本
  - **Release/** - 发布相关脚本
  - **Backup/** - 备份脚本
- **Sources/** - 源代码
  - **Core/** - 核心功能
  - **CoreDataModule/** - CoreData相关模块
- **Tests/** - 测试代码
- **Docs/** - 文档
  - **Reports/** - 构建和修复报告
- **Backups/** - 备份文件
  - **ConfigBackups/** - 配置文件备份
  - **DailyBackup_*/** - 每日备份

## 配置文件
- **.gitignore** - Git忽略规则
- **.xcignore** - Xcode忽略规则
- **.xcode.env** - Xcode环境变量
- **.swiftlint.yml** - SwiftLint配置

## 核心文件
- **Package.swift** - Swift Package Manager配置
- **README.md** - 项目主要说明文档
- **DIRECTORY.md** - 本文件，项目目录结构概览
EOF

echo "创建了 DIRECTORY.md 文件，提供项目目录结构概览"
echo "===== 目录整理完成 =====" 