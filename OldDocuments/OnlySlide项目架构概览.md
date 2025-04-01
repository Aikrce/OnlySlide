# OnlySlide项目架构概览

## 应用总体架构

OnlySlide应用采用MVVM (Model-View-ViewModel)架构模式，结合了Swift和SwiftUI的最佳实践。整体架构分为以下几个主要层次：

```
OnlySlide
├── 表示层 (Presentation Layer)
│   ├── 视图 (Views)
│   └── 视图模型 (ViewModels)
├── 业务逻辑层 (Business Logic Layer)
│   ├── 服务 (Services)
│   └── 工作流管理 (Workflow Management)
├── 数据层 (Data Layer)
│   ├── 模型 (Models)
│   ├── 存储 (Storage)
│   └── 网络 (Network)
└── 核心功能模块 (Core Feature Modules)
    ├── 媒体导入模块 (Media Import)
    ├── 语音识别模块 (Speech Recognition)
    ├── 内容分析模块 (Content Analysis)
    ├── 幻灯片生成模块 (Slide Generation)
    └── 导出模块 (Export)
```

## 视图层次结构

OnlySlide的用户界面组件按照用户工作流程进行组织：

```
MainView (应用程序主视图)
├── WelcomeView (欢迎视图)
│   ├── MediaImportView (媒体导入组件)
│   └── RecentDocumentsView (最近文档组件)
├── AnalysisProgressView (分析进度视图)
│   ├── ProgressIndicatorView (进度指示器)
│   └── StatusUpdateView (状态更新组件)
├── HomeView (主页视图)
│   ├── DocumentListView (文档列表组件)
│   └── DocumentPreviewView (文档预览组件)
├── DocumentView (文档编辑视图)
│   ├── SlideListView (幻灯片列表组件)
│   ├── SlideEditorView (幻灯片编辑器组件)
│   └── ContentToolbarView (内容工具栏组件)
└── ExportView (导出视图)
    ├── FormatSelectorView (格式选择器组件)
    ├── OptionsConfigView (选项配置组件)
    └── ExportProgressView (导出进度组件)
```

## 数据流

OnlySlide中的数据流遵循单向数据流原则，通过Combine框架实现响应式编程：

1. **用户交互** → **视图** → **视图模型** → **服务** → **数据管理**
2. **数据变更** → **视图模型更新** → **视图刷新** → **用户界面更新**

```
用户操作 → Action → ViewModel → 状态更新 → View重新渲染
  ↑                                       ↓
  └───────── 数据流循环 ──────────────────┘
```

## 核心模块详细说明

### 1. 媒体导入模块

负责处理音频和视频文件的导入，支持拖放、文件选择器和URL导入。

**主要组件**:
- `MediaImporter`: 处理文件导入和初始验证
- `MediaValidator`: 验证媒体格式和内容
- `MediaMetadataExtractor`: 提取媒体元数据

### 2. 语音识别模块

将音频内容转换为文本，支持多种语言和方言。

**主要组件**:
- `SpeechRecognizer`: 集成系统语音识别功能
- `TranscriptProcessor`: 处理转录结果，包括分段和标点
- `SpeakerIdentifier`: 识别多人对话中的不同说话者（高级功能）

### 3. 内容分析模块

分析文本内容，提取关键信息和结构。

**主要组件**:
- `ContentAnalyzer`: 主要分析引擎
- `KeypointExtractor`: 提取关键点和重要信息
- `ContentStructurer`: 组织内容结构
- `SummaryGenerator`: 生成内容摘要

### 4. 幻灯片生成模块

根据分析结果创建结构化的幻灯片。

**主要组件**:
- `SlideGenerator`: 主要生成引擎
- `TemplateManager`: 管理幻灯片模板
- `ContentLayoutEngine`: 安排幻灯片内容布局
- `StyleApplier`: 应用设计样式和主题

### 5. 导出模块

将生成的演示文稿导出为多种格式。

**主要组件**:
- `ExportManager`: 协调导出过程
- `FormatConverter`: 转换为目标格式
- `MetadataWriter`: 写入文档元数据
- `OutputValidator`: 验证导出结果

## 状态管理

OnlySlide使用Combine框架进行状态管理，实现以下功能：

- **应用状态**: 通过`AppState`对象管理全局状态
- **文档状态**: 通过`DocumentState`对象管理当前文档状态
- **工作流状态**: 通过`WorkflowState`对象管理处理流程状态
- **用户偏好**: 通过`UserPreferences`对象管理用户设置

## 存储架构

应用数据持久化策略如下：

- **文档存储**: 使用自定义文档格式（基于包结构）
- **用户偏好**: 使用UserDefaults和AppStorage
- **缓存数据**: 使用FileManager管理临时文件
- **应用数据**: 对于复杂数据关系使用Core Data

## 扩展系统

为支持未来功能扩展，OnlySlide设计了插件架构：

- **模板插件**: 扩展演示文稿设计模板
- **导出插件**: 支持额外导出格式
- **分析插件**: 增强内容分析能力
- **集成插件**: 与其他应用和服务集成

## 技术依赖关系

OnlySlide依赖的主要技术组件包括：

- **SwiftUI**: 用户界面框架
- **Combine**: 响应式编程和状态管理
- **AVFoundation**: 媒体处理
- **Speech**: 语音识别
- **Core ML**: 机器学习功能
- **Core Data**: 数据持久化
- **PDFKit**: PDF生成和处理
- **AppKit/UIKit**: 特定平台功能集成

## 质量保证架构

OnlySlide的质量保证策略包括：

- **单元测试**: 使用XCTest框架
- **UI测试**: 使用XCUITest
- **性能测试**: 使用Instruments工具集
- **崩溃报告**: 集成崩溃报告系统
- **用户反馈**: 内置反馈收集机制

## 部署策略

应用的部署流程包括：

1. **开发环境**: 开发人员本地构建和测试
2. **测试环境**: TestFlight内部和外部测试
3. **生产环境**: Mac App Store发布
4. **更新管理**: 通过App Store提供版本更新 