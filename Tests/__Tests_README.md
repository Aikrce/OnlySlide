# OnlySlide 测试指南

## 概述

这个目录包含 OnlySlide 项目的所有测试用例，涵盖单元测试、集成测试、UI测试和性能测试。

## 测试目录结构

### 核心测试
- **[核心业务逻辑测试](./CoreTests/CORE_TESTING.md)**: 核心功能和业务逻辑验证
- **[数据层测试](./CoreDataTests/COREDATA_TESTING.md)**: CoreData 数据层测试
- **[功能模块测试](./FeaturesTests/FEATURES_TESTING.md)**: 独立功能模块测试

### 集成与性能
- **[集成测试](./IntegrationTests/INTEGRATION_TESTING.md)**: 模块间集成测试
- **[性能测试](./PerformanceTests/PERFORMANCE_TESTING.md)**: 性能指标测试
- **[UI测试](./UITests/UI_TESTING.md)**: 用户界面自动化测试

### 其他测试
- **[单元测试](./UnitTests/UNIT_TESTING.md)**: 基础组件单元测试
- **[应用测试](./AppTests/APP_TESTING.md)**: 应用级别测试
- **[归档测试](./archive/ARCHIVE_GUIDE.md)**: 已归档的测试代码

## 运行测试

### 运行所有测试

```bash
swift test
```

### 运行特定目录的测试

```bash
swift test --filter CoreTests
```

### 运行特定测试类

```bash
swift test --filter CoreTests.DocumentServiceTests
```

## 测试覆盖率

要生成测试覆盖率报告：

```bash
swift test --enable-code-coverage
```

## 测试标准

所有添加到项目的测试应遵循以下标准：

1. 测试应该是独立的，不依赖其他测试的状态
2. 测试应该有清晰的目的和预期结果
3. 测试命名应该描述被测试的行为
4. 测试失败时应提供有用的错误消息

## 文档规范

- 每个测试目录都应包含一个专门的测试说明文档（如 `CORE_TESTING.md`）
- 文档命名应使用大写字母，以 `_TESTING.md` 或 `_GUIDE.md` 结尾
- 文档应包含测试范围、运行方法和注意事项

## CI/CD 集成

所有测试都集成在CI/CD流程中，每次提交都会自动运行测试。详情参见 `.github/workflows/tests.yml` 配置文件。 