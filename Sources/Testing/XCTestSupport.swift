/// XCTestSupport.swift
/// 提供跨平台的测试支持，在XCTest不可用时提供替代方案

#if canImport(XCTest)
import XCTest

/// TestSupport工具，用于辅助测试
public struct TestSupport {
    /// 检查XCTest是否可用
    public static var isXCTestAvailable: Bool {
        return true
    }
    
    /// 运行指定的测试用例
    /// - Parameter testCase: 要运行的测试用例
    public static func runTest(_ testCase: XCTestCase) {
        // 在此环境中，测试会通过XCTest框架自动运行
        print("使用XCTest框架运行测试")
    }
    
    /// 断言条件为真
    /// - Parameters:
    ///   - condition: 要检查的条件
    ///   - message: 断言失败时的消息
    public static func assert(_ condition: Bool, _ message: String = "") {
        XCTAssert(condition, message)
    }
    
    /// 断言条件为假
    /// - Parameters:
    ///   - condition: 要检查的条件
    ///   - message: 断言失败时的消息
    public static func assertFalse(_ condition: Bool, _ message: String = "") {
        XCTAssertFalse(condition, message)
    }
    
    /// 断言相等
    /// - Parameters:
    ///   - expression1: 第一个表达式
    ///   - expression2: 第二个表达式
    ///   - message: 断言失败时的消息
    public static func assertEqual<T: Equatable>(_ expression1: T, _ expression2: T, _ message: String = "") {
        XCTAssertEqual(expression1, expression2, message)
    }
    
    /// 断言抛出错误
    /// - Parameters:
    ///   - block: 要执行的代码块
    ///   - message: 断言失败时的消息
    public static func assertThrows(_ block: () throws -> Void, _ message: String = "") {
        XCTAssertThrowsError(try block(), message)
    }
    
    /// 测试失败
    /// - Parameter message: 失败消息
    public static func fail(_ message: String) {
        XCTFail(message)
    }
}

#else
import Foundation

/// TestSupport工具，用于辅助测试
public struct TestSupport {
    /// 检查XCTest是否可用
    public static var isXCTestAvailable: Bool {
        return false
    }
    
    /// 运行指定的测试用例
    /// - Parameter testCase: 要运行的测试用例（泛型参数，仅用于兼容性）
    public static func runTest<T>(_ testCase: T) {
        print("警告：XCTest框架不可用，无法运行标准测试")
        print("请使用条件编译的替代测试方法")
    }
    
    /// 断言条件为真
    /// - Parameters:
    ///   - condition: 要检查的条件
    ///   - message: 断言失败时的消息
    public static func assert(_ condition: Bool, _ message: String = "") {
        if !condition {
            print("❌ 断言失败: \(message)")
        } else {
            print("✅ 断言通过: \(message)")
        }
    }
    
    /// 断言条件为假
    /// - Parameters:
    ///   - condition: 要检查的条件
    ///   - message: 断言失败时的消息
    public static func assertFalse(_ condition: Bool, _ message: String = "") {
        if condition {
            print("❌ 断言失败: \(message)")
        } else {
            print("✅ 断言通过: \(message)")
        }
    }
    
    /// 断言相等
    /// - Parameters:
    ///   - expression1: 第一个表达式
    ///   - expression2: 第二个表达式
    ///   - message: 断言失败时的消息
    public static func assertEqual<T: Equatable>(_ expression1: T, _ expression2: T, _ message: String = "") {
        if expression1 != expression2 {
            print("❌ 断言失败: \(message). 预期 \(expression1) 等于 \(expression2)")
        } else {
            print("✅ 断言通过: \(message)")
        }
    }
    
    /// 断言抛出错误
    /// - Parameters:
    ///   - block: 要执行的代码块
    ///   - message: 断言失败时的消息
    public static func assertThrows(_ block: () throws -> Void, _ message: String = "") {
        do {
            try block()
            print("❌ 断言失败: \(message). 预期应抛出错误但没有")
        } catch {
            print("✅ 断言通过: \(message). 如预期抛出错误: \(error)")
        }
    }
    
    /// 测试失败
    /// - Parameter message: 失败消息
    public static func fail(_ message: String) {
        print("❌ 测试失败: \(message)")
    }
}
#endif 