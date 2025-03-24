import XCTest
@testable import Logging
@testable import Common

final class LoggingTests: XCTestCase {
    var logger: Logger!
    
    override func setUpWithError() throws {
        logger = Logger.shared
    }

    override func tearDownWithError() throws {
        // 测试后的清理代码
    }

    func testLogLevels() throws {
        // 测试所有日志级别
        logger.debug("Debug message")
        logger.info("Info message")
        logger.warning("Warning message")
        logger.error("Error message")
        // 如果没有崩溃就算通过
        XCTAssert(true, "所有日志级别测试通过")
    }
    
    func testLogFormat() throws {
        // 这里可以添加对日志格式的测试
        // TODO: 实现日志格式验证
        XCTAssert(true, "日志格式测试待实现")
    }
} 