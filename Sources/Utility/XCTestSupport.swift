// XCTestSupport.swift
// 这个文件提供XCTest框架的支持和兼容性

#if canImport(XCTest)
import XCTest

/// 测试辅助工具类
public struct TestSupport {
    /// 检查XCTest是否可用
    public static func isXCTestAvailable() -> Bool {
        return true
    }
    
    /// 运行指定的测试用例
    /// - Parameter testCase: 要运行的测试用例
    public static func runTest(_ testCase: XCTestCase) {
        // 这里可以添加测试运行前的设置代码
        // 例如环境变量、测试数据等
    }
}

#else

/// 测试辅助工具类 (XCTest不可用时的替代实现)
public struct TestSupport {
    /// 检查XCTest是否可用
    public static func isXCTestAvailable() -> Bool {
        return false
    }
    
    /// 模拟的断言
    public static func assert(_ condition: Bool, _ message: String = "") {
        if !condition {
            print("❌ 断言失败: \(message)")
        } else {
            print("✅ 断言通过: \(message)")
        }
    }
}

#endif 