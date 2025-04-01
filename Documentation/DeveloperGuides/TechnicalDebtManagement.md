# OnlySlide 技术债务管理指南

## 概述

本文档提供了OnlySlide项目中技术债务的管理策略，特别关注构建错误和模块依赖性问题。技术债务是指在软件开发过程中，为了短期收益而采取的设计或实现上的妥协，这些妥协将在未来需要额外的工作来修复。

## 当前技术债务清单

### 1. 构建错误

#### 1.1 README.md文件名冲突

**问题描述**: 多个模块中的README.md文件被配置为复制到同一目标位置，导致构建冲突。

**解决方案**:
- 将每个模块的README.md重命名为模块专用名称，如`ModuleName-README.md`
- 在Xcode项目的"Copy Bundle Resources"构建阶段中更新对这些文件的引用
- 或者创建一个脚本，将重命名后的文件复制到正确的位置

**具体步骤**:

```bash
# 在模块目录中执行
MODULE=$(basename $(pwd))
cp README.md ${MODULE}-README.md

# 从Xcode中移除对原始README.md的引用
# 添加对新命名文件的引用或使用Run Script构建阶段
```

#### 1.2 .stringsdata文件冲突

**问题描述**: 多个Swift任务尝试生成相同的.stringsdata文件，特别是:
- `HomeView.stringsdata`
- `OnlySlideApp.stringsdata`
- `DocumentAnalysisExample.stringsdata`

**原因**: 这通常发生在相同的Swift文件在多个目标中被编译的情况下。

**解决方案**:
- 确保每个Swift文件仅属于一个目标
- 检查目标成员身份(Target Membership)设置
- 建立正确的模块依赖关系，而不是直接在多个目标中包含相同的源文件

### 2. 代码组织问题

#### 2.1 文档散落问题

**问题描述**: 文档分散在项目各处，重复内容多，缺乏统一标准

**解决方案**:
- 创建统一的文档目录结构
- 使用索引文件组织所有文档
- 采用一致的命名约定
- 移除或合并重复内容

#### 2.2 模块边界不清晰

**问题描述**: 部分模块边界不明确，导致依赖关系复杂

**解决方案**:
- 重构模块结构，明确职责
- 使用接口隔离原则定义清晰的模块API
- 记录模块间依赖关系
- 添加单元测试验证模块边界

## 技术债务解决优先级

| 问题 | 严重性 | 优先级 | 估计工作量 |
|------|--------|--------|------------|
| README.md文件名冲突 | 高 | 高 | 1人日 |
| .stringsdata文件冲突 | 高 | 高 | 2人日 |
| 文档散落问题 | 中 | 中 | 3人日 |
| 模块边界不清晰 | 中 | 中 | 5人日 |

## 预防措施

为防止类似问题再次发生，我们建立以下预防措施:

1. **构建前检查脚本**: 创建自动化脚本，在构建前检查潜在冲突
2. **命名约定**: 建立并执行严格的命名约定，特别是对于资源文件
3. **模块化设计审查**: 在添加新模块前进行设计审查，确保职责清晰
4. **持续重构**: 定期进行小规模重构，防止技术债务累积
5. **文档标准**: 建立文档标准，并使用工具验证文档结构

## 具体解决方案示例

### README.md冲突解决脚本

```bash
#!/bin/bash
# 该脚本在Run Script构建阶段执行，解决README.md冲突问题

# 定义目标资源目录
RESOURCES_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

# 复制重命名后的README文件到各自的目标位置
cp "${SRCROOT}/Sources/ContentFusion/ContentFusion-README.md" "${RESOURCES_DIR}/ContentFusion-README.md"
cp "${SRCROOT}/Sources/DocumentAnalysis/Export/DocumentAnalysis-README.md" "${RESOURCES_DIR}/DocumentAnalysis-README.md"
cp "${SRCROOT}/Sources/TemplateExtraction/TemplateExtraction-README.md" "${RESOURCES_DIR}/TemplateExtraction-README.md"

echo "专用README文件已成功复制到资源目录"
```

### 解决.stringsdata文件冲突

1. 在Xcode中，选择项目导航器中的项目文件
2. 选择相关的Swift文件（如HomeView.swift）
3. 在右侧面板中检查"Target Membership"设置
4. 确保每个文件只属于必要的目标
5. 在构建设置中，添加以下设置到冲突目标:

```
DERIVED_FILE_DIR=$(CONFIGURATION_BUILD_DIR)/DerivedSources/$(TARGET_NAME)
```

这确保每个目标有自己的派生文件目录，避免冲突。

## 持续监控

为持续跟踪技术债务状况，我们将:

1. 维护本文档作为技术债务清单
2. 在每次冲刺计划中分配时间处理技术债务
3. 使用静态分析工具监控代码质量
4. 每月进行代码健康度评审

## 结论

积极管理技术债务对保持项目健康至关重要。通过及时识别和解决问题，可以防止小问题发展成严重障碍。本文档将随项目发展持续更新。 