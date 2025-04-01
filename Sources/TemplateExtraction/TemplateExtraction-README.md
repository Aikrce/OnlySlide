# 模板提取与管理功能

这个模块实现了OnlySlide应用中的模板提取与管理功能，使用户能够从PowerPoint文件中提取布局和样式信息，管理模板库，并将模板应用于文档内容。

## 功能概述

- **PPT布局和样式提取**：解析PowerPoint文件，提取幻灯片布局、样式和设计元素
- **模板预览**：直观展示模板的布局、主题和样式
- **模板编辑**：修改模板的布局、主题和样式
- **模板库管理**：导入、导出、删除和组织模板

## 主要组件

### PPTLayoutExtractor

PowerPoint布局和样式提取器，用于从.pptx文件中提取布局、样式和设计元素。

```swift
// 从PPT文件提取布局和样式
let templateInfo = try await PPTLayoutExtractor.extractFrom(fileURL: pptFileURL)

// 提取预览图
let previewImage = try await PPTLayoutExtractor.extractPreviewImageFrom(fileURL: pptFileURL)
```

主要功能：

- 解析PowerPoint文件中的XML结构
- 提取幻灯片布局信息（占位符、元素位置等）
- 提取主题信息（颜色方案、字体方案等）
- 提取样式信息（文本样式、形状样式、表格样式等）
- 生成预览图

### TemplatePreviewView

模板预览视图，用于展示PPT模板的布局、主题和样式。

```swift
// 创建模板预览视图
TemplatePreviewView(templateInfo: templateInfo)
```

主要功能：

- 布局预览：展示模板的布局结构和占位符
- 主题预览：展示模板的颜色方案和字体方案
- 样式预览：展示模板的文本样式、形状样式等

### TemplateEditView

模板编辑视图，用于编辑PPT模板的布局、样式和主题。

```swift
// 创建模板编辑视图
TemplateEditView(templateInfo: templateInfo) { updatedInfo in
    // 处理更新后的模板信息
}
```

主要功能：

- 布局编辑：调整占位符位置、添加/删除布局元素
- 主题编辑：修改颜色方案、字体方案
- 样式编辑：自定义文本样式、形状样式等

### TemplateManager

模板管理器，负责模板的存储、加载和管理。

```swift
// 获取共享实例
let manager = TemplateManager.shared

// 加载模板
await manager.loadTemplates()

// 导入模板
let template = try await manager.importTemplate(from: fileURL)

// 其他管理功能
try await manager.updateTemplate(templateId: id, with: updatedDetails)
try await manager.deleteTemplate(templateId: id)
try await manager.setTemplateDefault(templateId: id, isDefault: true)
```

主要功能：

- 管理模板文件的存储和加载
- 提供模板导入/导出功能
- 维护默认模板集
- 提供模板预览和详细信息加载

### TemplateLibraryView

模板库视图，用于展示和管理模板集合。

```swift
// 显示模板库视图
TemplateLibraryView()
```

主要功能：

- 网格/列表视图展示模板
- 提供模板导入、编辑、删除等操作
- 管理默认模板设置
- 提供模板预览和详细信息查看

## 数据模型

### PPTTemplateInfo

表示从PowerPoint文件中提取的模板信息，包含：

- 模板名称和幻灯片尺寸
- 主题信息（PPTTheme）
- 母版集合（[PPTMasterSlide]）
- 布局集合（[PPTLayout]）
- 样式集合（PPTStyleCollection）

### PPTTheme

表示PowerPoint主题信息，包含：

- 颜色方案（ColorScheme）
- 字体方案（FontScheme）
- 效果方案（EffectScheme）

### PPTLayout

表示PowerPoint布局信息，包含：

- 布局类型（LayoutType）
- 占位符集合（[Placeholder]）
- 元素集合（[TemplateElement]）
- 背景设置（SlideBackground）

### TemplateInfo

表示模板管理器中的模板元数据，包含：

- 唯一标识符
- 名称和预览图
- 文件路径
- 创建/修改时间
- 默认状态标记

## 使用示例

### 导入并预览模板

```swift
// 导入模板
let templateURL = URL(fileURLWithPath: "/path/to/template.pptx")
let template = try await TemplateManager.shared.importTemplate(from: templateURL)

// 加载模板详细信息
let templateDetails = try await TemplateManager.shared.loadTemplateDetails(templateId: template.id)

// 预览模板
TemplatePreviewView(templateInfo: templateDetails)
```

### 编辑模板

```swift
// 加载模板详细信息
let templateDetails = try await TemplateManager.shared.loadTemplateDetails(templateId: templateId)

// 编辑模板
TemplateEditView(templateInfo: templateDetails) { updatedDetails in
    // 保存更新后的模板
    Task {
        try await TemplateManager.shared.updateTemplate(templateId: templateId, with: updatedDetails)
    }
}
```

### 管理模板库

```swift
// 显示模板库
TemplateLibraryView()
```

## 实现说明

1. PPT解析基于Office Open XML格式，通过解压缩.pptx文件并解析内部XML结构实现
2. 模板存储使用CoreData和文件系统结合的方式
3. 界面使用SwiftUI实现，支持macOS和iOS跨平台
4. 提供异步API，避免在主线程上执行耗时操作

## 依赖项

- SwiftUI
- CoreData
- ZIPFoundation (用于处理.pptx文件解压缩)

## 未来改进

- 支持从图片提取设计元素
- 增强模板编辑功能，支持更复杂的样式编辑
- 添加模板分类和标签功能
- 支持模板共享和云同步
- 增加模板搜索和过滤功能
