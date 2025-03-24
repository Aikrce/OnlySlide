# OnlySlide 测试指南

本文档描述OnlySlide项目的测试策略、结构和最佳实践。

## 测试组织结构

测试按照项目模块分类组织，保持清晰的职责分离：

```Tests/
├── CoreTests/          # 核心业务逻辑测试
├── CoreDataTests/      # 数据持久化测试
├── AppTests/           # UI测试
└── FeaturesTests/      # 功能测试
```

## 测试类型

### 单元测试

针对单个组件的独立测试，不依赖外部系统。

- **范围**：单个类或函数
- **模式**：给定输入验证输出
- **工具**：XCTest框架

示例：
```swift
func testDocumentCreation() {
    let document = Document(title: "Test", content: "Content")
    XCTAssertEqual(document.title, "Test")
    XCTAssertEqual(document.content, "Content")
}
```

### 集成测试

测试多个组件之间的交互。

- **范围**：模块间集成
- **工具**：XCTest + 集成测试扩展

示例：
```swift
func testCoreDataIntegration() {
    // 测试业务逻辑与持久化层的集成
    let manager = DocumentManager()
    let document = manager.createDocument(title: "Test")
    XCTAssertNotNil(document.id)
    // 验证持久化
    let fetched = manager.getDocument(byId: document.id)
    XCTAssertEqual(fetched?.title, "Test")
}
```

### UI测试

测试用户界面和用户交互。

- **范围**：整个应用程序
- **工具**：XCUITest

## CoreData测试策略

为了有效测试CoreData功能，我们采用以下策略：

### 1. 内存存储

在测试环境中使用内存存储替代持久化存储：

```swift
// 测试设置
let container = NSPersistentContainer(name: "TestModel")
let description = NSPersistentStoreDescription()
description.type = NSInMemoryStoreType
container.persistentStoreDescriptions = [description]
```

### 2. 测试数据模型

为测试创建简化的数据模型：

- 位置：`Tests/CoreDataTests/TestModel.xcdatamodeld`
- 只包含测试必要的实体和关系

### 3. 模拟对象

使用模拟对象隔离测试：

```swift
class MockPersistentContainer: NSPersistentContainer {
    // 实现用于测试的行为
}
```

## 最佳实践

### 1. 测试命名规范

使用清晰且描述性的测试命名：

- `test<功能>_<情景>_<预期结果>`

例如：
```swift
func testSaveDocument_WithValidData_ShouldSucceed() { ... }
func testSaveDocument_WithInvalidData_ShouldThrowError() { ... }
```

### 2. 测试隔离

确保每个测试相互独立：

- 在setup中初始化新的测试环境
- 在tearDown中清理资源
- 避免测试间的依赖

### 3. 边界测试

测试边缘情况和错误条件：

- 空值和极端值
- 错误处理
- 边界条件

### 4. 测试数据

使用专门的测试数据生成器：

```swift
// TestFactory.swift
struct TestFactory {
    static func createTestDocument() -> Document {
        return Document(title: "Test Title", content: "Test Content")
    }
}
```

## 运行测试

### 命令行

```bash
# 运行所有测试
swift test

# 运行特定测试
swift test --filter CoreDataTests
```

### Xcode

1. 选择测试目标
2. 使用Product > Test或⌘U运行测试

## 持续集成

项目使用GitHub Actions进行持续集成：

- 每次PR会自动运行测试
- 测试通过是合并的前提条件

## 测试覆盖率

定期监控测试覆盖率：

1. 运行测试并生成覆盖率报告
2. 目标覆盖率：核心模块 > 90%，其他模块 > 80%

## 测试驱动开发

鼓励采用测试驱动开发(TDD)：

1. 先编写测试，定义期望行为
2. 实现功能，使测试通过
3. 重构代码，保持测试通过 