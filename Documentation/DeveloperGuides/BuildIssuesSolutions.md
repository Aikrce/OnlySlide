# Xcode 构建问题解决方案

本文档提供了常见 Xcode 构建问题的解决方案。

## 目录

1. [多个命令产生相同文件错误](#多个命令产生相同文件错误)
2. [模块未找到错误](#模块未找到错误)

## 多个命令产生相同文件错误

### 问题表现

错误消息类似于:

```
error: Multiple commands produce '/Users/username/Library/Developer/Xcode/DerivedData/ProjectName/Build/Intermediates.noindex/ProjectName.build/Debug/ProjectName.build/Objects-normal/arm64/FileName.stringsdata'
```

### 常见原因

这个错误通常由以下原因引起:

1. **相同的文件被多次包含在项目中**
   - 同一个文件被添加到多个目标(targets)
   - 同一个文件在项目中有多个引用

2. **命名冲突**
   - 在不同目录中存在同名的源文件

3. **缓存问题**
   - Xcode 的构建缓存可能已损坏

### OnlySlide项目中的特定问题

OnlySlide项目中发现以下具体冲突:

1. **重复的DocumentAnalysisExample.swift文件**
   - `/Sources/DocumentAnalysis/Examples/DocumentAnalysisExample.swift`
   - `/Sources/DocumentAnalysis/UI/DocumentAnalysisExample.swift`

2. **HomeView.swift文件在多个目标中**
   - 该文件可能被同时包含在OnlySlide和OnlySlideApp目标中

3. **OnlySlideApp.swift文件在多个目标中**
   - 该文件可能被同时包含在OnlySlide和OnlySlideApp目标中

### 解决方案

#### 解决步骤1: 重命名冲突的文件

对于 DocumentAnalysisExample.swift 的冲突，我们可以:

```swift
// 将 /Sources/DocumentAnalysis/UI/DocumentAnalysisExample.swift 重命名为:
// /Sources/DocumentAnalysis/UI/DocumentAnalysisUtil.swift

// 并更新文件中的类名:
// 从:
public enum DocumentAnalysisExample { 
    // ... 
}

// 改为:
public enum DocumentAnalysisUtil {
    // ...
}

// 然后更新所有引用点
```

#### 解决步骤2: 确保每个文件只属于一个目标

1. 在Xcode中选择项目文件
2. 查看目标成员配置:
   - 选择 "HomeView.swift"
   - 在右侧检查器中查看"Target Membership"
   - 确保该文件只勾选了一个目标(通常是OnlySlideApp)

3. 对OnlySlideApp.swift进行相同操作

#### 解决步骤3: 清理派生数据

有时清理Xcode的派生数据可以解决这个问题:

1. 关闭Xcode
2. 删除派生数据:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/OnlySlide-*
   ```
3. 重新打开Xcode并构建项目

## 模块未找到错误

// ... 现有内容 ... 