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
