# OnlySlide 核心数据模块

## 概述

CoreData模块是OnlySlide应用的数据持久化层，负责管理和维护应用程序的数据模型。本文档详细介绍了CoreData模块的架构、核心实体以及最佳实践，为开发者提供全面的指南。

## 基础架构

CoreData模块采用了分层设计，包含以下核心组件：

1. **数据模型层**：定义应用的实体、属性和关系
2. **持久化存储层**：负责数据的物理存储
3. **上下文管理层**：管理数据的加载、修改和保存
4. **同步层**：处理多设备间的数据同步
5. **迁移管理层**：处理数据模型的版本迁移

整体架构如下图所示：

```
┌─────────────────────────────────┐
│         应用逻辑层               │
└─────────────┬───────────────────┘
              │
┌─────────────▼───────────────────┐
│         数据访问接口             │
└─────────────┬───────────────────┘
              │
┌─────────────▼───────────────────┐
│         上下文管理层             │
└┬────────────┬─────────────┬─────┘
 │            │             │
┌▼──────────┐┌▼──────────┐┌─▼────────┐
│主上下文   ││后台上下文 ││UI上下文   │
└───────────┘└───────────┘└───────────┘
      │            │             │
┌─────▼────────────▼─────────────▼────┐
│             持久化存储层             │
└┬────────────────┬───────────────────┘
 │                │
┌▼───────────────▼┐
│SQLite存储        │
└─────────────────┘
```

## 核心实体

OnlySlide中的主要实体及其关系如下：

### 1. Document（文档）

中心实体，代表用户创建的幻灯片文档。

**主要属性**：
- `id`: UUID - 文档唯一标识符
- `title`: String - 文档标题 
- `createdAt`: Date - 创建时间
- `modifiedAt`: Date - 最后修改时间
- `thumbnailData`: Data? - 文档缩略图
- `syncStatus`: Int16 - 同步状态标记

**关系**：
- `slides`: 一对多关系到Slide
- `templateReference`: 多对一关系到Template
- `author`: 多对一关系到User
- `collaborators`: 多对多关系到User

### 2. Slide（幻灯片）

代表文档中的单个幻灯片。

**主要属性**：
- `id`: UUID - 幻灯片唯一标识符
- `index`: Int16 - 幻灯片在文档中的索引位置
- `title`: String? - 幻灯片标题
- `backgroundColorHex`: String? - 背景颜色（十六进制格式）
- `layoutType`: Int16 - 布局类型枚举值

**关系**：
- `document`: 多对一关系到Document
- `elements`: 一对多关系到Element
- `notes`: 一对多关系到Note

### 3. Element（元素）

幻灯片上的内容元素（文本、图片、形状等）。

**主要属性**：
- `id`: UUID - 元素唯一标识符
- `typeIdentifier`: String - 元素类型标识
- `positionX`: Float - X坐标位置
- `positionY`: Float - Y坐标位置
- `width`: Float - 宽度
- `height`: Float - 高度
- `rotationDegrees`: Float - 旋转角度
- `zIndex`: Int16 - 层叠顺序
- `contentData`: Data - 元素内容数据

**关系**：
- `slide`: 多对一关系到Slide
- `styleSettings`: 一对多关系到StyleSetting

### 4. Template（模板）

幻灯片模板，可用于创建新文档。

**主要属性**：
- `id`: UUID - 模板唯一标识符
- `name`: String - 模板名称
- `category`: String - 模板分类
- `thumbnailData`: Data? - 模板缩略图

**关系**：
- `documents`: 一对多关系到Document
- `templateSlides`: 一对多关系到TemplateSlide

### 5. User（用户）

应用用户信息。

**主要属性**：
- `id`: UUID - 用户唯一标识符
- `displayName`: String - 显示名称
- `email`: String - 电子邮件
- `profileImageData`: Data? - 用户头像

**关系**：
- `ownedDocuments`: 一对多关系到Document
- `collaboratingDocuments`: 多对多关系到Document

## 数据访问模式

OnlySlide采用了仓储模式（Repository Pattern）和服务层模式，为上层提供清晰的数据访问API。核心组件包括：

### 1. 仓储类

```swift
protocol DocumentRepository {
    func fetchDocument(withID id: UUID) -> Document?
    func fetchDocuments(sortBy: DocumentSortOption) -> [Document]
    func createDocument(title: String, template: Template?) -> Document
    func saveDocument(_ document: Document) throws
    func deleteDocument(_ document: Document) throws
}

class CoreDataDocumentRepository: DocumentRepository {
    // 实现省略...
}
```

### 2. 上下文管理

```swift
class CoreDataStack {
    static let shared = CoreDataStack()
    
    // 主上下文（主线程）
    let mainContext: NSManagedObjectContext
    
    // 后台上下文（后台线程）
    func newBackgroundContext() -> NSManagedObjectContext
    
    // 持久化存储协调器
    private let persistentContainer: NSPersistentContainer
    
    // 保存上下文
    func saveContext(_ context: NSManagedObjectContext) throws
    
    // 私有初始化方法
    private init() {
        // 初始化代码...
    }
}
```

### 3. 数据访问服务

```swift
class DocumentService {
    private let repository: DocumentRepository
    
    init(repository: DocumentRepository = CoreDataDocumentRepository()) {
        self.repository = repository
    }
    
    func getRecentDocuments(limit: Int = 10) -> [DocumentViewModel] {
        // 实现省略...
    }
    
    func createNewDocument(title: String, withTemplate templateID: UUID?) -> DocumentViewModel {
        // 实现省略...
    }
    
    // 其他方法...
}
```

## 性能优化

为确保CoreData在处理大型幻灯片文档时的性能，我们实施了以下优化措施：

### 1. 批处理和预取

```swift
// 批量获取示例
let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
fetchRequest.fetchBatchSize = 20

// 关系预取示例
fetchRequest.relationshipKeyPathsForPrefetching = ["slides", "templateReference"]
```

### 2. 后台处理

```swift
// 后台保存示例
func saveDocumentInBackground(_ document: Document, completion: @escaping (Error?) -> Void) {
    let backgroundContext = CoreDataStack.shared.newBackgroundContext()
    backgroundContext.perform {
        // 执行保存操作...
        do {
            try backgroundContext.save()
            completion(nil)
        } catch {
            completion(error)
        }
    }
}
```

### 3. 懒加载关系

对于大型关系（如包含多个幻灯片的文档），使用懒加载关系减少初始加载时间：

```swift
// 在数据模型中设置关系为懒加载
// 在代码中按需获取关系对象
```

## 数据迁移

OnlySlide通过轻量级迁移和手动迁移的组合策略处理数据模型变更。

### 轻量级迁移

对于简单的模型更改（添加属性、重命名实体等），启用轻量级迁移：

```swift
let description = NSPersistentStoreDescription()
description.shouldMigrateStoreAutomatically = true
description.shouldInferMappingModelAutomatically = true
persistentContainer.persistentStoreDescriptions = [description]
```

### 手动迁移

对于复杂迁移，使用`MigrationManager`执行手动迁移：

```swift
class MigrationManager {
    static func migrateStore(from sourceURL: URL, to destinationURL: URL) throws {
        // 实现多步迁移逻辑...
    }
}
```

## 数据同步

OnlySlide使用以下策略处理数据同步：

1. **并发控制**：使用版本标记和时间戳解决冲突
2. **增量同步**：只同步自上次同步以来修改的数据
3. **合并策略**：定义清晰的合并规则处理冲突数据

```swift
class SyncManager {
    // 推送本地更改到服务器
    func pushChanges(completion: @escaping (Error?) -> Void)
    
    // 从服务器拉取更改
    func pullChanges(completion: @escaping (Error?) -> Void)
    
    // 解决冲突
    private func resolveConflicts(_ conflicts: [SyncConflict]) throws
}
```

## 错误处理

CoreData操作中的错误处理遵循以下模式：

```swift
do {
    try context.save()
} catch let error as NSError {
    if error.domain == NSCocoaErrorDomain {
        switch error.code {
        case NSManagedObjectValidationError:
            // 处理验证错误
        case NSPersistentStoreOperationError:
            // 处理存储操作错误
        default:
            // 处理其他CoreData错误
        }
    } else {
        // 处理非CoreData错误
    }
}
```

## 测试策略

CoreData模块的测试采用多层次策略：

1. **单元测试**：使用内存存储测试仓储类和服务类
2. **集成测试**：测试完整的CoreData栈（使用临时文件存储）
3. **性能测试**：测试大量数据的加载和处理性能

```swift
// 为测试设置内存存储的示例
func setupInMemoryManagedObjectModel() -> NSManagedObjectContext {
    let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle.main])!
    let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
    
    do {
        try persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
    } catch {
        fatalError("添加内存存储失败: \(error)")
    }
    
    let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
    
    return managedObjectContext
}
```

## 最佳实践

### 1. 实体的创建与管理

```swift
// 推荐：使用工厂方法创建实体
extension Document {
    static func create(in context: NSManagedObjectContext, title: String) -> Document {
        let document = Document(context: context)
        document.id = UUID()
        document.title = title
        document.createdAt = Date()
        document.modifiedAt = Date()
        return document
    }
}

// 使用示例
let newDocument = Document.create(in: context, title: "新演示文稿")
```

### 2. 谓词构建

```swift
// 推荐：使用扩展方法构建常用谓词
extension Document {
    static func predicateForTitle(containing text: String) -> NSPredicate {
        return NSPredicate(format: "title CONTAINS[cd] %@", text)
    }
    
    static func predicateForCreatedAfter(date: Date) -> NSPredicate {
        return NSPredicate(format: "createdAt >= %@", date as NSDate)
    }
}

// 使用示例
let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
fetchRequest.predicate = Document.predicateForTitle(containing: "项目")
```

### 3. 上下文管理

```swift
// 推荐：清晰分离上下文职责
// 1. 主上下文：UI更新和用户交互
// 2. 后台上下文：耗时操作和批处理
// 3. 临时上下文：导入和临时操作
```

## 常见问题与解决方案

### 问题1: 数据加载缓慢

**解决方案**:
- 使用批处理和分页加载
- 优化获取请求（只获取需要的属性）
- 使用后台上下文进行预加载

### 问题2: 上下文保存冲突

**解决方案**:
- 实施清晰的上下文层次结构
- 在更改完成后立即保存
- 使用上下文通知监控变更

### 问题3: 高内存使用

**解决方案**:
- 限制获取结果数量
- 实现对象缓存管理
- 优化大型二进制数据的处理

### 问题4: 迁移失败

**解决方案**:
- 保持清晰的版本控制
- 为复杂变更使用手动迁移
- 添加迁移验证和恢复选项

## 代码示例

### 完整的文档加载和保存流程

```swift
class DocumentManager {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = CoreDataStack.shared.mainContext) {
        self.context = context
    }
    
    func loadDocument(withID id: UUID) -> Document? {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("加载文档失败: \(error)")
            return nil
        }
    }
    
    func saveDocument(_ document: Document) -> Bool {
        document.modifiedAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("保存文档失败: \(error)")
            context.rollback()
            return false
        }
    }
    
    func createNewSlide(in document: Document, at index: Int16) -> Slide {
        let slide = Slide(context: context)
        slide.id = UUID()
        slide.document = document
        slide.index = index
        
        // 重新排序现有幻灯片
        for existingSlide in document.slides ?? [] {
            guard let slide = existingSlide as? Slide else { continue }
            if slide.index >= index {
                slide.index += 1
            }
        }
        
        return slide
    }
}
```

## 结论

CoreData模块是OnlySlide应用的基础，为应用提供强大、高效且可靠的数据管理能力。通过遵循本文档中的最佳实践和指南，开发团队可以有效地利用CoreData的全部功能，同时避免常见陷阱。

## 相关资源

- [苹果CoreData文档](https://developer.apple.com/documentation/coredata)
- [OnlySlide数据模型图表](../Architecture/DataModel.pdf)
- [迁移策略详细文档](../Maintenance/DataMigrationGuide.md)

---

**最后更新日期**: 2025年3月30日  
**版本**: 1.2  
**作者**: 数据库团队 