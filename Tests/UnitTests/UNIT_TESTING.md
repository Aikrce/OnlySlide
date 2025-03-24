# 单元测试指南

## 概述

单元测试是OnlySlide项目的基础测试层，专注于验证独立组件和函数的正确性。这些测试确保基础构建块按预期工作，为更高层次的测试提供可靠基础。

## 测试原则

1. **单一职责**: 每个测试只验证一个行为
2. **独立性**: 测试之间不应有依赖
3. **可重复性**: 测试结果应该是确定的
4. **快速执行**: 单元测试应该快速完成

## 测试范围

- 工具函数
- 数据结构
- 算法实现
- 辅助类
- 基础组件

## 测试结构

### 命名约定

```swift
func test_[功能名称]_[测试场景]_[预期结果]() {
    // 测试实现
}
```

### 测试组织

```swift
class StringUtilsTests: XCTestCase {
    // 设置和清理
    override func setUp() { }
    override func tearDown() { }
    
    // 测试方法
    func test_trim_withWhitespace_returnsTrimmmedString() { }
}
```

## 运行测试

### 运行所有单元测试

```bash
swift test --filter UnitTests
```

### 运行特定测试类

```bash
swift test --filter UnitTests.StringUtilsTests
```

## 最佳实践

1. 使用 `XCTAssert` 系列函数进行断言
2. 包含正面和负面测试用例
3. 测试边界条件
4. 保持测试简单明了
5. 适当使用 `setUp` 和 `tearDown`

## 代码覆盖率

- 目标覆盖率：80%以上
- 定期检查覆盖率报告
- 优先测试关键路径
- 识别并补充测试盲点

## 维护指南

- 定期审查和更新测试
- 删除重复或过时的测试
- 确保测试与实现同步更新
- 持续改进测试质量 