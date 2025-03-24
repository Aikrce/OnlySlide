# OnlySlide - 专业幻灯片创建工具

OnlySlide是一个专业的跨平台幻灯片创建工具，旨在提供简洁、高效且功能强大的演示文稿创建体验。

## 快速开始

### 环境要求
- Swift 5.9+
- macOS 13+ / iOS 16+
- Xcode 15+

### 构建与运行
```bash
# 克隆仓库
git clone https://github.com/yourusername/OnlySlide.git
cd OnlySlide

# 构建项目
swift build

# 运行应用
swift run OnlySlide
```

## 项目结构

```
OnlySlide/
├── Sources/                # 源代码
│   ├── OnlySlide/         # 主应用入口
│   ├── Core/              # 核心业务逻辑
│   ├── CoreDataModule/    # CoreData数据管理
│   ├── App/               # UI层
│   ├── Features/          # 功能模块
│   └── Common/            # 公共组件
├── Tests/                 # 测试
├── Docs/                  # 文档
│   ├── Architecture/      # 架构文档
│   ├── Development/       # 开发指南
│   └── Modules/           # 模块文档
└── Scripts/               # 脚本工具
```

## 文档

### 架构与设计
- [项目架构](Docs/Architecture/ARCHITECTURE.md)
- [解决方案计划](Docs/Architecture/SOLUTION_PLAN.md)
- [方案总结](Docs/Architecture/SOLUTION_SUMMARY.md)

### 开发指南
- [开发手册](Docs/Development/DEVELOPMENT.md)
- [测试指南](Docs/Development/TESTING.md)

### 模块文档
- [CoreData模块](Docs/Modules/CoreData-README.md)
- [CoreData模块结构](Docs/Modules/CoreDataModule-Structure.md)
- [自定义映射模型指南](Docs/Modules/CustomMappingModelGuide.md)

## 贡献指南

欢迎贡献代码、报告问题或提出功能建议。请参考我们的[开发手册](Docs/Development/DEVELOPMENT.md)了解更多信息。

## 许可证

本项目采用 [MIT 许可证](LICENSE)。 