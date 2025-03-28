#if canImport(XCTest)
import XCTest
@testable import CoreDataModule

/// MigrationProgressReporter 单元测试
class MigrationProgressReporterTests: XCTestCase {
    
    // MARK: - Properties
    
    /// 测试对象
    var reporter: MigrationProgressReporter!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        reporter = MigrationProgressReporter()
    }
    
    override func tearDown() async throws {
        reporter = nil
    }
    
    // MARK: - Tests
    
    /// 测试初始状态
    func testInitialState() {
        XCTAssertEqual(reporter.state, .notStarted)
        XCTAssertNil(reporter.progress)
        XCTAssertNil(reporter.error)
        XCTAssertFalse(reporter.isInProgress)
        XCTAssertFalse(reporter.isCompleted)
        XCTAssertFalse(reporter.isFailed)
        XCTAssertEqual(reporter.progressPercentage, 0)
        XCTAssertEqual(reporter.progressFraction, 0)
    }
    
    /// 测试状态更新
    func testStateUpdate() {
        // 更新为备份状态
        reporter.reportBackupStarted()
        XCTAssertEqual(reporter.state, .backingUp)
        
        // 更新为恢复状态
        reporter.reportRestorationStarted()
        XCTAssertEqual(reporter.state, .restoring)
        
        // 更新为准备状态
        reporter.reportPreparationStarted()
        XCTAssertEqual(reporter.state, .preparing)
        
        // 更新为迁移状态
        reporter.reportMigrationStarted()
        XCTAssertEqual(reporter.state, .preparing)
        
        // 更新为完成状态
        let result = MigrationResult(storeURL: URL(fileURLWithPath: "/test"), backupURL: nil)
        reporter.reportMigrationCompleted(result: result)
        XCTAssertEqual(reporter.state, .completed(result: result))
        
        // 重置状态
        reporter.reset()
        XCTAssertEqual(reporter.state, .notStarted)
    }
    
    /// 测试进度更新
    func testProgressUpdate() {
        // 创建进度对象
        let progress = MigrationProgress(
            currentStep: 1,
            totalSteps: 2,
            description: "测试迁移",
            stepProgress: 0.5
        )
        
        // 更新进度
        reporter.updateProgress(progress)
        
        // 验证状态和进度
        XCTAssertEqual(reporter.state, .inProgress(progress: progress))
        XCTAssertEqual(reporter.progress, progress)
        XCTAssertTrue(reporter.isInProgress)
        XCTAssertEqual(reporter.progressPercentage, progress.percentage)
        XCTAssertEqual(reporter.progressFraction, progress.fraction)
        XCTAssertEqual(reporter.stepDescription, "测试迁移")
    }
    
    /// 测试错误处理
    func testErrorHandling() {
        // 创建错误
        let error = MigrationError.migrationFailed(reason: "测试错误")
        
        // 报告错误
        reporter.reportMigrationFailed(error: error)
        
        // 验证状态和错误
        XCTAssertEqual(reporter.state, .failed(error: error))
        XCTAssertEqual(reporter.error?.localizedDescription, error.localizedDescription)
        XCTAssertTrue(reporter.isFailed)
        
        // 测试普通错误转换
        let nsError = NSError(domain: "test", code: 100, userInfo: [NSLocalizedDescriptionKey: "普通错误"])
        reporter.reportMigrationFailed(error: nsError)
        
        // 验证错误被正确转换
        XCTAssertNotNil(reporter.error)
        XCTAssertTrue(reporter.isFailed)
    }
    
    /// 测试状态判断
    func testStateChecks() {
        // 测试进行中状态
        let progress = MigrationProgress(currentStep: 1, totalSteps: 1, description: "测试", stepProgress: 0.5)
        reporter.updateProgress(progress)
        XCTAssertTrue(reporter.isInProgress)
        XCTAssertFalse(reporter.isCompleted)
        XCTAssertFalse(reporter.isFailed)
        
        // 测试完成状态
        let result = MigrationResult(storeURL: URL(fileURLWithPath: "/test"), backupURL: nil)
        reporter.reportMigrationCompleted(result: result)
        XCTAssertFalse(reporter.isInProgress)
        XCTAssertTrue(reporter.isCompleted)
        XCTAssertFalse(reporter.isFailed)
        
        // 测试失败状态
        let error = MigrationError.migrationFailed(reason: "测试错误")
        reporter.reportMigrationFailed(error: error)
        XCTAssertFalse(reporter.isInProgress)
        XCTAssertFalse(reporter.isCompleted)
        XCTAssertTrue(reporter.isFailed)
    }
}
#endif 