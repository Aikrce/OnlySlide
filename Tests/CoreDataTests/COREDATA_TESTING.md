# CoreData 模块测试

## 概述

这个目录包含 CoreData 模块的测试用例，涵盖了核心数据模型、数据迁移、性能和同步等方面的测试。

## 测试范围

- 数据模型测试：验证数据模型的正确性和一致性
- 数据迁移测试：测试数据模型版本之间的迁移功能
- 性能测试：衡量 CoreData 操作的性能指标
- 同步测试：验证数据同步和冲突解决功能
- 持久化存储测试：确保数据正确存储和检索

## 运行测试

执行以下命令运行所有 CoreData 测试：

```bash
swift test --filter CoreDataTests
```

要运行特定测试类：

```bash
swift test --filter CoreDataTests.MigrationTests
```

## 测试数据

测试使用模拟数据和内存存储，确保测试环境的独立性和一致性。测试中使用的 `TestModel.xcdatamodeld` 模型位于 `TestModel.xcdatamodeld` 目录中。

## 添加新测试

添加新测试时，请遵循以下规则：

1. 测试类使用 `XCTestCase` 子类，并以 `Tests` 结尾
2. 使用 `CoreDataTestHelper` 类设置测试环境
3. 每个测试方法应该是自包含的，不依赖其他测试的状态
4. 使用断言验证预期结果 