# 创建自定义映射模型文件指南

本文档介绍了如何为OnlySlide项目创建和使用自定义映射模型文件(`.xcmappingmodel`)，用于处理CoreData模型的重大架构变更。

## 什么是映射模型文件？

映射模型文件(`.xcmappingmodel`)是一种特殊的资源文件，它精确描述了如何将数据从一个CoreData模型版本迁移到另一个版本。当自动推断的迁移规则不足以处理复杂的架构变更时，自定义映射模型可以提供明确的迁移路径。

## 何时需要创建自定义映射模型文件？

在以下情况下，您应该考虑创建自定义映射模型文件：

1. 实体重命名
2. 属性重命名或类型转换
3. 关系重组
4. 复杂的数据转换逻辑
5. 实体合并或拆分
6. 需要使用自定义迁移策略类

## 创建步骤

### 1. 准备源和目标数据模型

确保您已经创建了源版本和目标版本的数据模型。例如，如果要从V1_0_0迁移到V2_0_0：

- 已有V1_0_0.xcdatamodel
- 已创建V2_0_0.xcdatamodel并设置为当前版本

### 2. 使用Xcode创建映射模型

1. 在Xcode中，选择**File → New → File...**
2. 选择**Core Data → Mapping Model**
3. 在向导中，选择源数据模型（如V1_0_0）和目标数据模型（如V2_0_0）
4. 命名映射模型，使用格式`Mapping_V1_0_0_to_V2_0_0.xcmappingmodel`
5. 选择保存位置（建议存放在`Resources/Migrations`目录下）

### 3. 配置实体映射

在生成的映射模型文件中，您将看到所有需要迁移的实体映射。对于每个实体映射：

1. 设置映射类型：
   - `Copy`：简单拷贝数据
   - `Transform`：根据映射规则转换数据
   - `Add`：添加新实体
   - `Remove`：移除旧实体

2. 配置属性映射：
   - 可以设置值表达式，例如`$source.oldAttribute`或更复杂的转换表达式
   - 对于新增属性，设置默认值

3. 配置关系映射：
   - 设置源实体和目标实体的关系映射

4. 指定自定义实体迁移策略（如需要）：
   - 在Entity Mapping的Inspector面板中，设置"Custom Policy"为您的自定义策略类名
   - 例如：`DocumentEntityMigrationPolicy`

### 4. 将映射模型添加到项目

1. 确保映射模型文件已添加到项目的target中
2. 修改`Info.plist`，添加`NSMigrateMappingModelsBundle`键，值为包含映射模型的bundle标识符

### 5. 在代码中使用自定义映射模型

当使用映射模型查找器时，自定义映射模型将被自动发现和使用：

```swift
// MappingModelFinder.swift中已实现的方法
private func findCustomMappingModel(
    from sourceModel: NSManagedObjectModel,
    to destinationModel: NSManagedObjectModel
) -> NSMappingModel? {
    // 获取源模型和目标模型的版本
    guard let sourceVersion = ModelVersion(versionIdentifiers: sourceModel.versionIdentifiers),
          let destinationVersion = ModelVersion(versionIdentifiers: destinationModel.versionIdentifiers) else {
        return nil
    }
    
    // 映射模型的命名约定
    let mappingName = "Mapping_\(sourceVersion.identifier)_to_\(destinationVersion.identifier)"
    
    // 尝试在bundle中查找映射模型
    if let mappingPath = Bundle.module.path(forResource: mappingName, ofType: "cdm"),
       let mapping = NSMappingModel(contentsOf: URL(fileURLWithPath: mappingPath)) {
        return mapping
    }
    
    // 回退到系统API
    return try? NSMappingModel(
        from: [Bundle.module],
        forSourceModel: sourceModel,
        destinationModel: destinationModel
    )
}
```

## 示例：Document实体迁移

假设我们在V2_0_0中对Document实体进行了以下修改：
- 将`content`属性重命名为`documentContent`
- 添加了新的`metadata`字典属性
- 将多个样式属性合并到一个`style`字典属性中

以下是如何配置映射模型：

1. 创建`Mapping_V1_0_0_to_V2_0_0.xcmappingmodel`
2. 在Document实体映射中：
   - 将`content`映射到`documentContent`（设置值表达式为`$source.content`）
   - 为`metadata`设置默认值：`{ "createdWith": "OnlySlide", "version": "2.0.0" }`
   - 使用表达式将旧样式属性合并：`{ "color": $source.textColor, "backgroundColor": $source.backgroundColor, "fontSize": $source.fontSize }`
3. 指定自定义策略类：`DocumentEntityMigrationPolicy`

## 注意事项

1. **命名约定**：确保映射模型使用正确的命名约定，以便自动发现
2. **版本序列**：对于跨多个版本的迁移，需要为每对相邻版本创建映射模型
3. **测试**：每次创建映射模型后，务必测试迁移过程
4. **备份**：确保迁移前始终创建数据库备份

## 故障排除

如果映射模型不被发现或不正常工作：

1. 确认映射模型文件名格式正确
2. 检查映射模型是否包含在编译资源中
3. 验证源模型和目标模型的版本标识符
4. 检查自定义迁移策略类名是否正确
5. 使用调试日志跟踪迁移过程 