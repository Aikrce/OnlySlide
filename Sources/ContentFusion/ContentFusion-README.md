# 内容与模板融合功能

这个模块实现了OnlySlide应用中的内容与模板融合功能，使用户能够将文档分析结果应用到PowerPoint模板中，生成美观的演示文稿。

## 功能概述

- **智能内容分配**：基于内容类型、长度等特性，将文档内容智能分配到合适的幻灯片布局中
- **样式智能匹配**：将内容样式与模板风格相匹配，实现一致的视觉效果
- **文本溢出处理**：提供多种文本溢出处理策略，确保内容正确显示
- **布局自动调整**：根据内容特性自动调整元素布局，优化显示效果
- **融合结果预览**：提供融合结果的预览和微调功能

## 主要组件

### TemplateFusionManager

内容与模板融合管理器，负责协调内容分配、风格匹配、布局调整和渲染流程。

```swift
// 获取共享实例
let manager = TemplateFusionManager.shared

// 应用模板（完整选项）
let result = try await manager.applyTemplate(
    to: documentContent,
    using: templateId,
    options: fusionOptions,
    progressHandler: { progress in
        // 处理进度更新
    }
)

// 快速应用模板（默认选项）
let result = try await manager.quickFusion(
    documentContent: documentContent,
    templateId: templateId
)
```

主要功能：

- 管理内容与模板的融合流程
- 提供进度跟踪和错误处理机制
- 支持自定义融合选项
- 返回融合结果，包含生成的幻灯片数量、预览图像等信息

### ContentDistributor

内容分配器，负责将文档内容合理分配到幻灯片布局中。

主要功能：

- 分析文档内容结构和特性
- 根据不同策略分配内容（按内容类型、按内容长度、固定数量等）
- 将内容与布局占位符进行智能匹配
- 处理内容层次结构的保持和分割

### StyleApplier

样式应用器，负责将模板样式应用到内容上，并进行适当调整。

主要功能：

- 分析内容原始样式和模板目标样式
- 根据匹配选项调整内容样式（字体、颜色、大小等）
- 处理特殊内容类型的样式匹配（图表、表格、代码等）
- 保持内容可读性和视觉一致性

### LayoutAdjuster

布局调整器，负责优化元素排列和处理溢出情况。

主要功能：

- 根据内容实际大小调整元素位置和尺寸
- 处理文本溢出（调整字体大小、创建新幻灯片等）
- 优化图片和表格的显示效果
- 确保元素间距合适和对齐方式正确

### SlideRenderer

幻灯片渲染器，负责生成最终的幻灯片预览和导出数据。

主要功能：

- 将融合后的内容渲染为视觉表示
- 生成幻灯片预览图像
- 准备导出数据（用于后续的PPT生成）
- 应用最终的视觉效果（动画、过渡等）

### TemplateFusionView

内容与模板融合视图，提供用户友好的界面来应用模板。

```swift
// 创建融合视图
TemplateFusionView(documentContent: content) { result in
    if let result = result {
        // 处理融合结果
    } else {
        // 用户取消操作
    }
}
```

主要功能：

- 显示文档内容概览
- 提供模板选择界面
- 支持自定义融合选项
- 展示融合进度和结果预览

## 融合选项

### 内容分配策略

- **按内容类型**：根据内容类型（文本、图片、表格等）选择合适的布局
- **按内容长度**：根据内容长度决定如何分配
- **固定数量**：每张幻灯片放置固定数量的内容项
- **手动分配**：由用户手动指定内容分配

### 风格匹配选项

- **颜色主题匹配**：调整内容颜色以匹配模板主题
- **字体匹配**：使用模板中定义的字体
- **文本大小调整**：根据容器大小调整文本大小
- **匹配强度**：控制风格匹配的程度（0-100%）

### 文本溢出处理

- **调整字体大小**：自动缩小字体以适应容器
- **创建新幻灯片**：将溢出内容放到新幻灯片
- **裁剪文本**：截断溢出内容并显示省略号
- **显示溢出指示器**：显示指示器并保留原文大小

## 使用示例

### 基本用法

```swift
// 获取文档内容（从文档分析模块）
let documentContent = documentAnalysisResult.content

// 初始化融合视图
let fusionView = TemplateFusionView(documentContent: documentContent) { result in
    if let result = result {
        print("融合完成，生成了 \(result.slideCount) 张幻灯片")
        // 处理融合结果
    }
}

// 显示融合视图
presentView(fusionView)
```

### 自定义融合选项

```swift
// 创建自定义融合选项
var options = TemplateFusionManager.FusionOptions()
options.distributionStrategy = .byContentLength
options.textOverflowHandling = .createNewSlide
options.preserveImageAspectRatio = true
options.generateCoverSlide = true
options.styleMatch.matchingStrength = 0.8

// 直接应用模板，不使用UI
let result = try await TemplateFusionManager.shared.applyTemplate(
    to: documentContent,
    using: templateId,
    options: options
)
```

## 实现说明

1. 内容分配算法基于启发式规则和机器学习模型，优化内容分布
2. 样式匹配使用相似度评分机制，确保视觉和谐
3. 文本溢出处理采用渐进式策略，优先调整大小，必要时创建新幻灯片
4. 布局调整使用约束求解器，优化元素排布
5. 使用异步API，避免UI卡顿和响应延迟

## 依赖项

- SwiftUI
- TemplateExtraction模块（提供模板解析和管理功能）
- DocumentAnalysis模块（提供文档内容结构）

## 未来改进

- 增强自动排版算法，处理更复杂的内容结构
- 添加模板推荐功能，基于内容特性推荐合适的模板
- 提供更精细的布局微调控制
- 支持用户自定义样式匹配规则
- 添加内容智能缩减功能，生成简洁版演示文稿 