# OnlySlide

OnlySlide 是一款智能幻灯片创建应用，旨在简化演示文稿的制作过程。通过分析 PPT 模板和结构化内容，OnlySlide 帮助用户快速生成符合专业设计标准的演示文稿。

## 项目架构

OnlySlide 采用模块化 MVVM 架构，分为两个主要模块：

```
┌─────────────────────────────────────────────────────────────┐
│                    OnlySlide Application                    │
├────────────────────────────┬────────────────────────────────┤
│                            │                                │
│    ┌────────────────────┐  │  ┌────────────────────────┐    │
│    │   OnlySlideCore    │  │  │      OnlySlideUI       │    │
│    │                    │  │  │     (MVVM 架构)         │    │
│    │ ┌────────────────┐ │  │  │ ┌────────────────────┐ │    │
│    │ │     Models     │ │  │  │ │       Views        │ │    │
│    │ └────────────────┘ │  │  │ └────────────────────┘ │    │
│    │                    │  │  │           ▲            │    │
│    │ ┌────────────────┐ │  │  │           │            │    │
│    │ │    Services    │ │  │  │ ┌────────────────────┐ │    │
│    │ └────────────────┘ │  │  │ │    ViewModels      │ │    │
│    │         ▲          │  │  │ └────────────────────┘ │    │
│    │         │          │  │  │           ▲            │    │
│    │ ┌────────────────┐ │  │  │           │            │    │
│    │ │   Protocols    │◄┼──┼──┼───────────┘            │    │
│    │ └────────────────┘ │  │  │                        │    │
│    │                    │  │  │ ┌────────────────────┐ │    |
│    │ ┌────────────────┐ │  │  │ │  Models(引用)       │ │    │
│    │ │    CoreData    │◄┼──┼──┼─┤                    │ │    │
│    │ └────────────────┘ │  │  │ └────────────────────┘ │    │
│    └────────────────────┘  │  └────────────────────────┘    │
│                            │                                │
│             依赖方向：       │                                │
│     OnlySlideUI ──────────►─── OnlySlideCore                │
│                            │                                │
└────────────────────────────┴────────────────────────────────┘
```

- **OnlySlideCore**：核心业务逻辑和数据处理，不依赖任何 UI 框架
- **OnlySlideUI**：基于 SwiftUI 的用户界面层，采用 MVVM 架构

## 开发工作清单

### 1. 项目基础架构设置

- [x] 创建项目基本结构
  - [x] 创建 OnlySlide.xcodeproj
  - [x] 设置目标平台 (iOS 18.0+/macOS 15.0+)
  - [x] 配置基础构建设置
- [x] 建立模块化框架
  - [x] 创建 OnlySlideCore 模块
  - [x] 创建 OnlySlideUI 模块
  - [x] 设置模块间依赖关系
- [x] 配置版本控制
  - [x] 设置 .gitignore
  - [x] 设置 .gitattributes
  - [x] 创建初始文档
- [ ] 设置构建流水线
  - [ ] 配置 CI/CD (.github/workflows)
  - [ ] 设置测试自动化

### 2. OnlySlideCore 模块实现

#### 2.1 Models 目录结构完善

- [ ] Document 目录
  - [ ] Document.swift (文档主模型)
  - [ ] Slide.swift (幻灯片模型)
  - [ ] SlideContent.swift (幻灯片内容模型)
- [x] Template 目录
  - [x] Template.swift (模板基础模型)
  - [ ] TemplateMetadata.swift (模板元数据)
- [ ] Style 目录
  - [x] ColorStyle.swift (颜色样式，已在Template.swift中实现)
  - [x] FontStyle.swift (字体样式，已在Template.swift中实现)
  - [ ] LayoutStyle.swift (布局样式，已部分在TemplateAnalyzerProtocol.swift中实现)
- [ ] Content 目录
  - [ ] TextContent.swift (文本内容)
  - [ ] ImageContent.swift (图片内容)
  - [ ] ChartContent.swift (图表内容)

#### 2.2 Protocols 实现

- [ ] FileManagement 目录
  - [ ] FileImporting.swift (文件导入协议)
  - [ ] FileExporting.swift (文件导出协议)
- [x] TemplateAnalysis 目录
  - [x] TemplateAnalyzerProtocol.swift (模板分析协议)
  - [ ] StyleExtracting.swift (样式提取协议)
- [ ] ContentProcessing 目录
  - [ ] ContentStructuring.swift (内容结构化协议)
  - [ ] ContentAnalyzing.swift (内容分析协议)
- [ ] SlideGeneration 目录
  - [ ] SlideGenerating.swift (幻灯片生成协议)
  - [ ] StyleApplying.swift (样式应用协议)

#### 2.3 Services 实现

- [ ] FileService 目录
  - [ ] FileImportService.swift (文件导入服务实现)
  - [ ] FileExportService.swift (文件导出服务)
- [ ] AnalysisService 目录
  - [ ] TemplateAnalyzerService.swift (模板分析服务)
  - [ ] StyleExtractor.swift (样式提取器)
  - [ ] LayoutAnalyzer.swift (布局分析器)
- [ ] GenerationService 目录
  - [ ] SlideGeneratorService.swift (幻灯片生成器)
  - [ ] ContentFormatter.swift (内容格式化)
  - [ ] LayoutEngine.swift (布局引擎)
- [ ] AIService 目录 (v1.5/v2.0)
  - [ ] ContentAnalyzer.swift (内容分析服务)
  - [ ] StyleSuggestionService.swift (样式建议服务)
  - [ ] TextSummarizer.swift (文本摘要服务)

#### 2.4 CoreData 实现

- [ ] Models 目录
  - [ ] OnlySlide.xcdatamodeld (数据模型定义)
  - [ ] ProjectEntity.swift (项目实体扩展)
  - [ ] TemplateEntity.swift (模板实体扩展)
- [ ] Repositories 目录
  - [ ] Repository.swift (通用仓库协议)
  - [ ] ProjectRepository.swift (项目仓库)
  - [ ] TemplateRepository.swift (模板仓库)
- [ ] Migrations 目录
  - [ ] DataMigrationManager.swift (迁移管理器)
  - [ ] MigrationVersions/ (版本迁移目录)

### 3. OnlySlideUI 模块实现

#### 3.1 Views 实现

- [ ] Home 目录
  - [ ] HomeView.swift (主页视图)
  - [x] TemplateListView.swift (模板列表视图)
  - [ ] ProjectGridView.swift (项目网格视图)
- [ ] Analysis 目录
  - [ ] AnalysisView.swift (分析主视图)
  - [ ] StylePreviewView.swift (样式预览视图)
  - [ ] TemplateDetailsView.swift (模板详情视图)
- [ ] Content 目录
  - [ ] ContentEditorView.swift (内容编辑视图)
  - [ ] TextEditorView.swift (文本编辑视图)
  - [ ] OutlineEditorView.swift (大纲编辑视图)
- [ ] Generation 目录
  - [ ] GenerationView.swift (生成主视图)
  - [ ] SlidePreviewView.swift (幻灯片预览视图)
  - [ ] ExportOptionsView.swift (导出选项视图)

#### 3.2 ViewModels 实现

- [ ] Base 目录
  - [ ] BaseViewModel.swift (视图模型基类)
  - [ ] ViewModelState.swift (视图模型状态)
- [ ] Home 目录
  - [ ] HomeViewModel.swift (主页视图模型)
  - [ ] TemplateListViewModel.swift (模板列表视图模型)
- [ ] Analysis 目录
  - [ ] AnalysisViewModel.swift (分析视图模型)
  - [ ] StylePreviewViewModel.swift (样式预览视图模型)
- [ ] Content 目录
  - [ ] ContentEditorViewModel.swift (内容编辑视图模型)
  - [ ] OutlineViewModel.swift (大纲视图模型)

#### 3.3 DesignSystem 实现

- [ ] Foundations 目录
  - [ ] Colors.swift (颜色系统)
  - [ ] Typography.swift (排版系统)
  - [ ] Spacing.swift (间距系统)
- [ ] Components 目录
  - [ ] Buttons.swift (按钮组件)
  - [ ] InputFields.swift (输入框组件)
  - [ ] Cards.swift (卡片组件)
- [ ] Patterns 目录
  - [ ] ListItems.swift (列表项组件)
  - [ ] Dialogs.swift (对话框组件)
  - [ ] NavigationPatterns.swift (导航模式组件)

#### 3.4 其他UI组件

- [ ] ViewModifiers/ (视图修饰器)
- [ ] PlatformAdapters/ (平台适配层)
- [ ] State/ (全局状态管理)
- [ ] Utilities/ (UI工具类)

### 4. OnlySlide 主应用实现

- [ ] App/ (应用入口)
  - [ ] OnlySlideApp.swift
  - [ ] AppDelegate.swift
- [ ] Resources/ (应用资源)
  - [ ] Assets/
  - [ ] Localization/
- [ ] Configuration/ (应用配置)
  - [ ] Info.plist
  - [ ] Environment.swift
  - [ ] FeatureFlags.swift

### 5. 测试框架实现

- [ ] UnitTests/ (单元测试)
- [ ] UITests/ (UI测试)
- [ ] PerformanceTests/ (性能测试)
- [ ] TestUtilities/ (测试工具)

### 6. 功能实现计划

#### 6.1 v1.0 MVP 阶段 (0-3个月)

- [ ] 基础模板导入和分析
- [ ] 基础内容编辑功能
- [ ] 简单幻灯片生成
- [ ] 基础导出功能

#### 6.2 v1.5 增强阶段 (4-6个月)

- [ ] 高级模板分析
- [ ] 内容编辑增强
- [ ] 基础AI辅助
- [ ] 云同步功能

#### 6.3 v2.0 完整阶段 (7-10个月)

- [ ] 高级AI功能
- [ ] 协作功能
- [ ] 高级导出选项
- [ ] 平台深度集成

## 设置说明

### 环境要求

- Xcode 15.0+
- Swift 5.9+
- iOS 18.0+ / macOS 15.0+

### 开发环境设置

1. 克隆仓库
```bash
git clone https://github.com/yourusername/OnlySlide.git
cd OnlySlide
```

2. 打开项目
```bash
open OnlySlide.xcodeproj
```

3. 构建运行
   - 选择目标设备
   - 点击运行按钮或按 Cmd+R

## 贡献指南

欢迎贡献代码、报告问题或提出改进建议。请确保遵循以下准则：

- 使用类似 `feature/feature-name` 或 `bugfix/issue-number` 的分支命名
- 遵循项目设计文档中的架构和命名约定
- 提交前确保通过所有测试
- 提交消息遵循 Angular 规范格式：`type(scope): message`

## 版本计划

- **v1.0 MVP** (0-3个月): 基础功能可用版本
- **v1.5 增强版** (4-6个月): 功能和用户体验增强
- **v2.0 完整版** (7-10个月): 全功能产品发布

## 许可证

[待定] 