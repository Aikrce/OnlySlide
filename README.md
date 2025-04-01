# OnlySlide

![OnlySlide Logo](https://placeholder.com/logo.png)

## AI驱动的演示文稿生成工具

OnlySlide是一款基于macOS的应用程序，利用人工智能技术将音频和视频内容自动转换为精美的演示文稿。

### 主要特点

- **自动转换**：将音频/视频内容转换为结构化的幻灯片
- **智能分析**：提取关键概念和主题，自动组织内容结构
- **美观设计**：提供多种专业设计模板和自定义选项
- **简单易用**：直观的用户界面，无需专业设计技能
- **多格式导出**：支持PowerPoint、Keynote、PDF等多种格式

## 项目概览

本项目使用SwiftUI和Swift开发，采用MVVM架构模式。主要功能模块包括：

- 媒体导入与处理
- 语音识别与文本转换
- 内容分析与结构化
- 幻灯片生成与编辑
- 多格式导出

## 项目文档

所有项目文档都已整理到`Documentation`目录，请参考以下主要文档：

- [文档索引](Documentation/INDEX.md) - 访问所有项目文档的入口
- [项目架构概览](Documentation/Architecture/ProjectArchitecture.md)
- [项目完成计划](Documentation/ProjectProgressAndSummary/CompletionPlan.md)
- [项目开发总结](Documentation/ProjectProgressAndSummary/DevelopmentSummary.md)
- [用户手册](Documentation/UserGuides/UserManual.md)
- [技术债务管理](Documentation/DeveloperGuides/TechnicalDebtManagement.md)
- [构建问题解决指南](Documentation/DeveloperGuides/BuildIssues.md)
- [iOS发布指南](Documentation/DeveloperGuides/iOSReleaseGuide.md)

## 系统要求

- macOS 12.0 (Monterey) 或更高版本
- 4GB RAM (推荐8GB或更多)
- 1GB可用磁盘空间

## 开发环境设置

### 前提条件

- Xcode 14.0 或更高版本
- Swift 5.7 或更高版本
- macOS 12.0 或更高版本

### 安装步骤

1. 克隆项目仓库
   ```bash
   git clone https://github.com/yourusername/OnlySlide.git
   cd OnlySlide
   ```

2. 打开Xcode项目
   ```bash
   open OnlySlide.xcodeproj
   ```

3. 安装依赖（如有需要）
   ```bash
   swift package resolve
   ```

4. 构建并运行项目
   在Xcode中，选择目标设备并点击运行按钮

## 项目结构

```
OnlySlide
├── Sources               # 源代码
│   ├── OnlySlideApp      # 应用程序主模块
│   ├── Models            # 数据模型
│   ├── Views             # UI视图组件
│   ├── ViewModels        # 视图模型
│   └── Services          # 业务逻辑服务
├── Resources             # 资源文件
│   ├── Assets            # 图像和图标
│   └── Templates         # 幻灯片模板
├── Tests                 # 测试代码
└── Documentation         # 项目文档（已整理）
    ├── Architecture      # 架构文档
    ├── DeveloperGuides   # 开发者指南
    ├── UserGuides        # 用户指南
    └── INDEX.md          # 文档索引
```

## 贡献指南

我们欢迎对OnlySlide项目的贡献！如果您想参与项目开发，请遵循以下步骤：

1. Fork项目仓库
2. 创建您的功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交您的更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 打开Pull Request

## 许可证

本项目采用MIT许可证 - 详见 [LICENSE](LICENSE) 文件

## 联系方式

项目团队 - team@onlyslide.com

项目链接: [https://github.com/yourusername/OnlySlide](https://github.com/yourusername/OnlySlide)