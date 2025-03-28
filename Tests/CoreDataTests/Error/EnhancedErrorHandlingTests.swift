#if canImport(XCTest)
import XCTest
import Combine
import CoreData
@testable import CoreDataModule

/// 增强错误处理单元测试
final class EnhancedErrorHandlingTests: XCTestCase {
    
    // MARK: - Properties
    
    /// 测试对象
    var errorHandler: EnhancedErrorHandler!
    
    /// 测试恢复服务
    var recoveryService: MockRecoveryService!
    
    /// 测试错误转换器
    var errorConverter: MockErrorConverter!
    
    /// 测试策略解析器
    var strategyResolver: MockStrategyResolver!
    
    /// 订阅取消器
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // 创建模拟依赖
        recoveryService = MockRecoveryService()
        errorConverter = MockErrorConverter()
        strategyResolver = MockStrategyResolver()
        
        // 创建测试对象
        errorHandler = EnhancedErrorHandler(
            recoveryService: recoveryService,
            errorConverter: errorConverter,
            strategyResolver: strategyResolver
        )
    }
    
    override func tearDown() {
        errorHandler = nil
        recoveryService = nil
        errorConverter = nil
        strategyResolver = nil
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Tests
    
    /// 测试错误处理
    func testErrorHandling() {
        // 设置预期
        let testError = NSError(domain: "test", code: 1, userInfo: nil)
        errorConverter.convertedError = CoreDataError.modelNotFound("测试转换")
        
        // 处理错误
        errorHandler.handle(testError, context: "测试上下文")
        
        // 验证错误被转换
        XCTAssertTrue(errorConverter.convertCalled)
        XCTAssertTrue(strategyResolver.errorWasHandled)
    }
    
    /// 测试错误转换
    func testErrorConversion() {
        // 设置预期
        let testError = NSError(domain: "test", code: 1, userInfo: nil)
        let convertedError = CoreDataError.modelNotFound("已转换")
        errorConverter.convertedError = convertedError
        
        // 转换错误
        let result = errorHandler.convertError(testError)
        
        // 验证结果
        XCTAssertEqual((result as? CoreDataError)?.localizedDescription, convertedError.localizedDescription)
    }
    
    /// 测试错误恢复
    func testErrorRecovery() async {
        // 设置预期
        let testError = CoreDataError.migrationFailed("恢复测试")
        let expectedResult = RecoveryResult.success
        recoveryService.recoveryResult = expectedResult
        
        // 尝试恢复
        let result = await errorHandler.attemptRecovery(from: testError, context: "测试上下文")
        
        // 验证结果
        XCTAssertEqual(result, expectedResult)
        XCTAssertTrue(recoveryService.attemptRecoveryCalled)
    }
    
    /// 测试错误策略应用
    func testErrorStrategyApplication() {
        // 设置预期
        let testError = CoreDataError.migrationFailed("策略测试")
        let strategyApplied = true
        strategyResolver.strategyApplied = strategyApplied
        
        // 应用策略
        let result = errorHandler.applyErrorStrategy(for: testError, context: "测试上下文")
        
        // 验证结果
        XCTAssertEqual(result, strategyApplied)
        XCTAssertTrue(strategyResolver.applyStrategyCalled)
    }
    
    /// 测试错误发布
    func testErrorPublishing() {
        // 设置预期
        let expectation = XCTestExpectation(description: "错误发布")
        let testError = CoreDataError.migrationFailed("发布测试")
        
        // 订阅错误发布
        errorHandler.errorPublisher
            .sink { error in
                XCTAssertEqual((error as? CoreDataError)?.localizedDescription, testError.localizedDescription)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // 触发错误
        errorHandler.publishError(testError)
        
        // 等待期望
        wait(for: [expectation], timeout: 1.0)
    }
    
    /// 测试创建默认实例
    func testCreateDefault() {
        // 创建默认实例
        let defaultHandler = EnhancedErrorHandler.createDefault()
        
        // 验证非空
        XCTAssertNotNil(defaultHandler)
    }
}

// MARK: - Mock Classes

/// 模拟恢复服务
class MockRecoveryService: RecoveryService {
    var recoveryStrategies: [String : (Error, String) async -> RecoveryResult] = [:]
    var recoveryResult: RecoveryResult = .failure(NSError(domain: "mock", code: 0, userInfo: nil))
    var attemptRecoveryCalled = false
    var registerStrategyCalled = false
    
    func registerRecoveryStrategy(for errorType: any Error.Type, handler: @escaping (Error, String) async -> RecoveryResult) {
        registerStrategyCalled = true
        recoveryStrategies[String(describing: errorType)] = handler
    }
    
    func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        attemptRecoveryCalled = true
        return recoveryResult
    }
}

/// 模拟错误转换器
class MockErrorConverter {
    var convertedError: Error = NSError(domain: "mock", code: 0, userInfo: nil)
    var convertCalled = false
    
    func convert(_ error: Error) -> Error {
        convertCalled = true
        return convertedError
    }
}

/// 模拟策略解析器
class MockStrategyResolver {
    var strategyApplied = false
    var applyStrategyCalled = false
    var errorWasHandled = false
    
    func applyStrategy(for error: Error, context: String) -> Bool {
        applyStrategyCalled = true
        errorWasHandled = true
        return strategyApplied
    }
}

/// 使Mock与接口匹配
extension EnhancedErrorHandler {
    convenience init(
        recoveryService: MockRecoveryService,
        errorConverter: MockErrorConverter,
        strategyResolver: MockStrategyResolver
    ) {
        self.init(
            recoveryService: recoveryService,
            errorConverter: { errorConverter.convert($0) },
            strategyResolver: { error, context in
                strategyResolver.applyStrategy(for: error, context: context)
            }
        )
    }
}
#endif 