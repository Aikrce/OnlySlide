import XCTest
@testable import CoreDataModule

final class CoreDataRecoveryTests: XCTestCase {
    
    func testRecoveryStrategyRegistration() {
        // 测试恢复策略注册
        let executor = CoreDataRecoveryExecutor.shared
        
        // 创建自定义恢复策略
        let customStrategy = MockRecoveryStrategy(name: "MockStrategy")
        
        // 注册策略
        executor.register(strategy: customStrategy)
        
        // 创建恢复策略可以处理的错误
        let error = NSError(domain: "test.domain", code: 123, userInfo: nil)
        
        // 验证策略注册成功并能处理预期错误
        // 注意：这里假设我们有一种方法来检查注册的策略
        // 由于恢复执行器的策略是私有的，可能需要修改访问级别或使用间接方法验证
        
        // 替代验证方法：尝试恢复并检查结果
        let expectation = XCTestExpectation(description: "Recovery attempt")
        
        Task {
            let result = await executor.attemptRecovery(from: error, context: "test")
            
            // 验证结果与模拟策略的预期输出匹配
            if case .success = result {
                expectation.fulfill()
            } else {
                XCTFail("恢复结果应该成功")
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testRecoveryStrategySelection() async {
        // 测试恢复策略选择逻辑
        let executor = CoreDataRecoveryExecutor.shared
        
        // 创建几个模拟策略，每个处理不同类型的错误
        let strategy1 = MockRecoveryStrategy(name: "Strategy1", canHandleErrorTypes: [1, 2, 3])
        let strategy2 = MockRecoveryStrategy(name: "Strategy2", canHandleErrorTypes: [4, 5, 6])
        
        // 注册策略
        executor.register(strategy: strategy1)
        executor.register(strategy: strategy2)
        
        // 创建每个策略可以处理的错误
        let error1 = NSError(domain: "test.domain", code: 2, userInfo: nil)
        let error2 = NSError(domain: "test.domain", code: 5, userInfo: nil)
        
        // 尝试恢复并验证选择了正确的策略
        let result1 = await executor.attemptRecovery(from: error1, context: "test1")
        let result2 = await executor.attemptRecovery(from: error2, context: "test2")
        
        // 验证结果
        if case .success = result1 {
            // 成功
        } else {
            XCTFail("Strategy1 应该成功处理 error1")
        }
        
        if case .success = result2 {
            // 成功
        } else {
            XCTFail("Strategy2 应该成功处理 error2")
        }
    }
    
    func testRecoveryFailureHandling() async {
        // 测试恢复失败的处理
        let executor = CoreDataRecoveryExecutor.shared
        
        // 创建一个总是失败的模拟策略
        let failingStrategy = MockRecoveryStrategy(name: "FailingStrategy", alwaysFail: true)
        
        // 注册策略
        executor.register(strategy: failingStrategy)
        
        // 创建错误
        let error = NSError(domain: "test.domain", code: 999, userInfo: nil)
        
        // 尝试恢复
        let result = await executor.attemptRecovery(from: error, context: "failure_test")
        
        // 验证结果是失败的
        if case .failure = result {
            // 预期的失败
        } else {
            XCTFail("应该返回失败结果")
        }
    }
}

// MARK: - 测试辅助类

/// 模拟恢复策略，用于测试
final class MockRecoveryStrategy: RecoveryStrategy {
    let name: String
    private let errorTypes: [Int]
    private let shouldFail: Bool
    
    init(name: String, canHandleErrorTypes: [Int] = [123], alwaysFail: Bool = false) {
        self.name = name
        self.errorTypes = canHandleErrorTypes
        self.shouldFail = alwaysFail
    }
    
    func canHandle(_ error: Error) -> Bool {
        let nsError = error as NSError
        return errorTypes.contains(nsError.code)
    }
    
    func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        if shouldFail {
            return .failure(error)
        }
        return .success
    }
} 