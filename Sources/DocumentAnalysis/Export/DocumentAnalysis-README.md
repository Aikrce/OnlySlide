# OnlySlide 导出模块

本模块负责将文档分析结果导出为各种格式，包括PDF、PowerPoint、图片和文本。

## 架构概述

导出模块采用模块化架构，包含以下主要组件：

### 基础协议

- `ExportOptionsProtocol`: 定义导出选项的通用接口
- `DocumentExporter`: 定义导出器的通用接口
- `ProgressReporting`: 定义进度报告的通用接口

### 文件处理工具

- `TemporaryFileManager`: 提供临时文件处理的通用工具

### 视图组件

- `ExportViewState`: 管理导出视图的状态
- `ExportViewProtocol`: 定义导出视图的通用接口
- `ExportButton`, `DocumentInfoSection` 等: 可复用的UI组件

### 文档类

- `GenericExportDocument`: 通用的FileDocument实现
- `ZipExportDocument`: 用于ZIP文件的FileDocument实现
- `DirectoryExportDocument`: 用于目录的FileDocument实现

### 导出格式

每种导出格式都有以下组件：

- 导出选项 (如 `PowerPointExportOptions`)
- 导出器 (如 `PowerPointExporterImpl`)
- 导出视图 (如 `PowerPointExportViewBase`)

## 支持的格式

- **PDF**: 导出为PDF文档，支持自定义页面大小、页眉页脚等选项
- **PowerPoint**: 导出为PPTX演示文稿，支持自定义幻灯片大小、主题等选项
- **图片**: 导出为PNG或JPEG图片集，支持自定义尺寸、水印等选项
- **文本**: 导出为纯文本或Markdown，支持自定义编码、行尾等选项

## 技术债务处理

我们正在逐步重构导出模块，以降低技术债务：

### 已完成
- 创建统一的基础协议和基类
- 实现通用的临时文件管理和进度报告
- 创建可复用的SwiftUI组件
- 重构PowerPoint导出功能，使其适配新架构
- 为PowerPoint导出器添加单元测试

### 进行中
- 完善PowerPoint导出的内容生成逻辑
- 统一错误处理机制

### 计划中
- 重构其他导出格式（PDF, 图片, 文本）
- 实现流式处理和分块渲染
- 优化大型文档处理

## 使用示例

```swift
// 创建导出选项
let options = PowerPointExportOptions()
options.slideSize = .widescreen
options.includeTableOfContents = true

// 创建导出器
let exporter = PowerPointExporterImpl(result: documentResult, options: options)

// 执行导出
try exporter.export(to: fileURL)
```

```swift
// 使用SwiftUI视图进行导出
struct ContentView: View {
    let documentResult: DocumentAnalysisResult
    
    var body: some View {
        PowerPointExportViewBase(documentResult: documentResult)
    }
}
```

## 贡献指南

添加新的导出格式时，请按照以下步骤操作：

1. 创建导出选项结构体，实现`ExportOptionsProtocol`
2. 创建导出器类，实现`DocumentExporter`
3. 创建导出视图，实现`ExportViewProtocol`
4. 添加适当的单元测试

详见 `TECH_DEBT.md` 了解更多关于当前技术债务和改进计划的信息。 