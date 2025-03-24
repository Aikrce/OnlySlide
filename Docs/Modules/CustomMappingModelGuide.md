# 自定义映射模型创建指南

本文档提供了如何在 OnlySlide 项目中创建和使用自定义 CoreData 映射模型的详细说明。

## 前提条件

- Xcode 14.0 或更高版本
- Swift 5.7 或更高版本
- 对 CoreData 和模型迁移的基本了解

## 工具概述

OnlySlide 项目包含一个名为 `GenerateMappingModelTemplate.swift` 的工具脚本，它可以自动生成自定义映射模型所需的所有文件模板，包括：

1. 自定义映射策略类 (NSEntityMigrationPolicy 子类)
2. 映射测试类
3. 使用指南 README

## 使用工具生成模板

### 1. 确保脚本具有执行权限

```bash
chmod +x Scripts/GenerateMappingModelTemplate.swift
```

### 2. 运行脚本生成模板

```bash
./Scripts/GenerateMappingModelTemplate.swift <源版本> <目标版本> <实体名称> [--force]
```

示例：
```bash
./Scripts/GenerateMappingModelTemplate.swift version1 version2 Slide
```

这将生成以下文件：

- `Sources/CoreDataModule/Migration/CustomMappingModels/SlideV1ToSlideV2MappingModel.swift`
- `Tests/CoreDataModuleTests/Migration/SlideV1ToSlideV2MappingTests.swift`
- `Templates/MigrationModels/Slide_version1_to_version2_README.md`

### 3. 实现自定义映射逻辑

打开生成的 `SlideV1ToSlideV2MappingModel.swift` 文件，并根据您的迁移需求实现自定义映射逻辑：

```swift
// 从源实例提取数据
let title = sInstance.value(forKey: "title") as? String ?? ""
let createdAt = sInstance.value(forKey: "createdAt") as? Date ?? Date()

// 为新增的字段设置默认值
let slideDescription = "从version1迁移的幻灯片: \(title)"

// 设置默认值
dInstance.setValue(slideDescription, forKey: "slideDescription")
```

### 4. 创建 Xcode 映射模型文件

在 Xcode 中创建正式的映射模型文件：

1. 选择 File -> New -> File... -> Core Data -> Mapping Model
2. 选择源模型（例如 "ModelV1"）和目标模型（例如 "ModelV2"）
3. 命名为 `Mapping_ModelV1_to_ModelV2.xcmappingmodel`

### 5. 配置实体映射

1. 在 Xcode 映射模型编辑器中，选择需要自定义策略的实体映射
2. 在 Inspector 面板中，设置 "Custom Policy" 为您的自定义策略类名
   例如：`SlideV1ToSlideV2MappingModel`

### 6. 测试迁移

1. 实现生成的测试类中的测试方法
2. 运行测试以验证迁移功能

## 示例：从 version1 到 version2 迁移 Slide 实体

以下是一个完整的示例，说明如何处理 Slide 实体从 version1 到 version2 的迁移：

### 版本变更概述

- **version1 (ModelV1)**
  - Slide 实体包含: `title`, `createdAt`, `content`, `backgroundColor`

- **version2 (ModelV2)**
  - Slide 实体新增: `slideDescription`, `tags`, `lastModifiedAt`
  - Slide 实体重命名: `backgroundColor` -> `colorScheme`
  - Slide 实体添加关系: 一对多关系 `elements`

### 映射策略实现

```swift
override public func createDestinationInstances(
    forSource sInstance: NSManagedObject,
    in mapping: NSEntityMapping,
    manager: NSMigrationManager
) throws {
    // 调用父类方法创建基本实例
    try super.createDestinationInstances(
        forSource: sInstance,
        in: mapping,
        manager: manager
    )
    
    // 获取目标实例
    guard let dInstance = manager.destinationInstances(
        forEntityMappingName: mapping.name,
        sourceInstances: [sInstance]
    ).first else {
        throw NSError(domain: "MigrationError", code: 1, userInfo: nil)
    }
    
    // 从源实例提取数据
    let title = sInstance.value(forKey: "title") as? String ?? ""
    let createdAt = sInstance.value(forKey: "createdAt") as? Date ?? Date()
    let content = sInstance.value(forKey: "content") as? String ?? ""
    let backgroundColor = sInstance.value(forKey: "backgroundColor") as? String ?? "default"
    
    // 为新增的字段设置默认值
    let slideDescription = "从version1迁移的幻灯片: \(title)"
    let tags = ["迁移", "自动生成"]
    let lastModifiedAt = Date()
    
    // 转换颜色方案
    let colorScheme: [String: Any] = [
        "backgroundColor": backgroundColor,
        "textColor": "black",
        "accentColor": "blue"
    ]
    
    // 设置值
    dInstance.setValue(slideDescription, forKey: "slideDescription")
    dInstance.setValue(tags, forKey: "tags")
    dInstance.setValue(lastModifiedAt, forKey: "lastModifiedAt")
    
    // 处理 JSON 数据
    if let colorSchemeData = try? JSONSerialization.data(withJSONObject: colorScheme),
       let colorSchemeString = String(data: colorSchemeData, encoding: .utf8) {
        dInstance.setValue(colorSchemeString, forKey: "colorScheme")
    }
    
    // 创建默认元素
    createDefaultElements(for: dInstance, with: content, in: manager.destinationContext)
}

/// 创建默认元素
private func createDefaultElements(
    for slide: NSManagedObject,
    with content: String,
    in context: NSManagedObjectContext
) {
    // 创建文本元素
    guard let elementEntity = NSEntityDescription.entity(
        forEntityName: "SlideElement",
        in: context
    ) else {
        return
    }
    
    let textElement = NSManagedObject(entity: elementEntity, insertInto: context)
    textElement.setValue("text", forKey: "type")
    textElement.setValue(content, forKey: "content")
    textElement.setValue(slide, forKey: "slide")
    
    // 设置位置和大小
    let frame: [String: Double] = [
        "x": 50.0,
        "y": 50.0,
        "width": 300.0,
        "height": 200.0
    ]
    
    if let frameData = try? JSONSerialization.data(withJSONObject: frame),
       let frameString = String(data: frameData, encoding: .utf8) {
        textElement.setValue(frameString, forKey: "frameJSON")
    }
    
    // 将元素添加到幻灯片的元素集合中
    slide.setValue(Set([textElement]), forKey: "elements")
}
```

## 最佳实践

1. **为复杂的属性变更创建映射**：如果属性被重命名或类型发生变化，请务必在映射模型中设置适当的映射。

2. **测试覆盖所有场景**：确保测试包含各种不同的数据情况，特别是边缘情况。

3. **处理可选值**：始终安全地处理可选值，提供合理的默认值。

4. **保持迁移性能**：对于大型数据集，优化迁移性能至关重要。考虑批处理大量对象。

5. **记录迁移过程**：添加日志记录，以便在迁移出现问题时进行调试。

## 故障排除

### 常见问题

1. **错误: "无法找到自定义策略类"**
   - 确保自定义策略类的名称与映射模型中指定的完全一致
   - 检查策略类是否正确包含在编译目标中

2. **错误: "获取目标实例失败"**
   - 检查实体名称是否正确
   - 验证映射模型中的实体映射配置

3. **性能问题: "迁移非常缓慢"**
   - 考虑使用批处理方法
   - 优化复杂的转换逻辑
   - 在后台进程中执行迁移

## 参考资源

- [Core Data Programming Guide: Lightweight Migration](https://developer.apple.com/documentation/coredata/using_lightweight_migration)
- [WWDC 2019: Making Apps with Core Data](https://developer.apple.com/videos/play/wwdc2019/230/)
- [Apple Documentation: NSEntityMigrationPolicy](https://developer.apple.com/documentation/coredata/nsentitymigrationpolicy) 