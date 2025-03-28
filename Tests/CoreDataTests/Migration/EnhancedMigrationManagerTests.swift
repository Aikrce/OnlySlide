#if canImport(XCTest)
import XCTest
import Combine
import CoreData
@testable import CoreDataModule

/// 增强迁移管理器单元测试
final class EnhancedMigrationManagerTests: XCTestCase {
    
    // MARK: - Properties
    
    /// 测试对象
    var migrationManager: EnhancedMigrationManager!
    
    /// 测试依赖
    var mockPlanner: MockMigrationPlanner!
    var mockExecutor: MockMigrationExecutor!
    var mockBackupManager: MockBackupManager!
    var mockProgressReporter: MockMigrationProgressReporter!
    
    /// 临时测试目录
    var tempDirectory: URL!
    
    /// 订阅取消器
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        super.setUp()
        
        // 创建临时目录
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // 创建模拟依赖
        mockPlanner = MockMigrationPlanner()
        mockExecutor = MockMigrationExecutor()
        mockBackupManager = MockBackupManager()
        mockProgressReporter = MockMigrationProgressReporter()
        
        // 创建测试对象
        migrationManager = EnhancedMigrationManager(
            planner: mockPlanner,
            executor: mockExecutor,
            backupManager: mockBackupManager,
            progressReporter: mockProgressReporter
        )
    }
    
    override func tearDown() async throws {
        // 清理临时目录
        if let tempDirectory = tempDirectory, FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        
        // 清理测试对象
        migrationManager = nil
        mockPlanner = nil
        mockExecutor = nil
        mockBackupManager = nil
        mockProgressReporter = nil
        
        // 清理订阅
        cancellables.removeAll()
        
        super.tearDown()
    }
    
    // MARK: - Tests
    
    /// 测试迁移需求检查
    func testNeedsMigration() async throws {
        // 设置预期
        let storeURL = tempDirectory.appendingPathComponent("test.sqlite")
        mockPlanner.needsMigrationResult = true
        
        // 执行测试
        let result = try await migrationManager.needsMigration(at: storeURL)
        
        // 验证结果
        XCTAssertTrue(result)
        XCTAssertTrue(mockPlanner.needsMigrationCalled)
    }
    
    /// 测试迁移执行
    func testMigrate() async throws {
        // 设置预期
        let storeURL = tempDirectory.appendingPathComponent("test.sqlite")
        let options = MigrationOptions.default
        let expectedResult = MigrationResult.success
        
        mockPlanner.needsMigrationResult = true
        mockExecutor.migrateResult = expectedResult
        
        // 执行测试
        let result = try await migrationManager.migrate(storeAt: storeURL, options: options)
        
        // 验证结果
        XCTAssertEqual(result, expectedResult)
        XCTAssertTrue(mockPlanner.needsMigrationCalled)
        XCTAssertTrue(mockExecutor.migrateCalled)
    }
    
    /// 测试不需要迁移时的行为
    func testMigrateWhenNotNeeded() async throws {
        // 设置预期
        let storeURL = tempDirectory.appendingPathComponent("test.sqlite")
        let options = MigrationOptions.default
        
        mockPlanner.needsMigrationResult = false
        
        // 执行测试
        let result = try await migrationManager.migrate(storeAt: storeURL, options: options)
        
        // 验证结果
        XCTAssertEqual(result, .success)
        XCTAssertTrue(mockPlanner.needsMigrationCalled)
        XCTAssertFalse(mockExecutor.migrateCalled)
    }
    
    /// 测试创建备份
    func testCreateBackup() async throws {
        // 设置预期
        let storeURL = tempDirectory.appendingPathComponent("test.sqlite")
        let backupURL = tempDirectory.appendingPathComponent("backup/test.sqlite")
        mockBackupManager.createBackupResult = backupURL
        
        // 执行测试
        let result = try await migrationManager.createBackup(of: storeURL)
        
        // 验证结果
        XCTAssertEqual(result.path, backupURL.path)
        XCTAssertTrue(mockBackupManager.createBackupCalled)
    }
    
    /// 测试从备份恢复
    func testRestoreFromBackup() async throws {
        // 设置预期
        let storeURL = tempDirectory.appendingPathComponent("test.sqlite")
        let backupURL = tempDirectory.appendingPathComponent("backup/test.sqlite")
        mockBackupManager.restoreResult = true
        
        // 执行测试
        let result = try await migrationManager.restoreFromBackup(backupURL, to: storeURL)
        
        // 验证结果
        XCTAssertTrue(result)
        XCTAssertTrue(mockBackupManager.restoreCalled)
    }
    
    /// 测试状态发布
    func testStatePublishing() throws {
        // 设置预期
        let expectation = XCTestExpectation(description: "状态更新")
        let expectedState: MigrationState = .inProgress
        
        // 订阅状态
        migrationManager.statePublisher
            .dropFirst() // 跳过初始状态
            .sink { state in
                XCTAssertEqual(state, expectedState)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // 更新状态
        migrationManager.updateState(expectedState)
        
        // 等待期望
        wait(for: [expectation], timeout: 1.0)
    }
    
    /// 测试进度发布
    func testProgressPublishing() throws {
        // 设置预期
        let expectation = XCTestExpectation(description: "进度更新")
        let expectedProgress = Progress(totalUnitCount: 100)
        expectedProgress.completedUnitCount = 50
        
        // 订阅进度
        migrationManager.progressPublisher
            .compactMap { $0 }
            .sink { progress in
                XCTAssertEqual(progress.totalUnitCount, expectedProgress.totalUnitCount)
                XCTAssertEqual(progress.completedUnitCount, expectedProgress.completedUnitCount)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // 更新进度
        migrationManager.updateProgress(expectedProgress)
        
        // 等待期望
        wait(for: [expectation], timeout: 1.0)
    }
    
    /// 测试创建默认实例
    func testCreateDefault() {
        // 创建默认实例
        let defaultManager = EnhancedMigrationManager.createDefault()
        
        // 验证非空
        XCTAssertNotNil(defaultManager)
    }
}

// MARK: - Mock Classes

/// 模拟迁移规划器
class MockMigrationPlanner: MigrationPlannerProtocol {
    var needsMigrationResult = false
    var needsMigrationCalled = false
    var migrationPathResult: [ModelVersion] = []
    var migrationPathCalled = false
    
    func needsMigration(at storeURL: URL) async throws -> Bool {
        needsMigrationCalled = true
        return needsMigrationResult
    }
    
    func migrationPath(for storeURL: URL) async throws -> [ModelVersion] {
        migrationPathCalled = true
        return migrationPathResult
    }
}

/// 模拟迁移执行器
class MockMigrationExecutor: MigrationExecutorProtocol {
    var migrateResult: MigrationResult = .success
    var migrateCalled = false
    
    func migrate(
        storeAt storeURL: URL,
        withOptions options: MigrationOptions,
        progressHandler: @escaping (Progress) -> Void
    ) async throws -> MigrationResult {
        migrateCalled = true
        return migrateResult
    }
}

/// 模拟备份管理器
class MockBackupManager: BackupManagerProtocol {
    var createBackupResult: URL!
    var createBackupCalled = false
    var restoreResult = false
    var restoreCalled = false
    var removeOldBackupsResult = true
    var removeOldBackupsCalled = false
    
    func createBackup(of storeURL: URL) async throws -> URL {
        createBackupCalled = true
        return createBackupResult
    }
    
    func restoreFromBackup(_ backupURL: URL, to storeURL: URL) async throws -> Bool {
        restoreCalled = true
        return restoreResult
    }
    
    func removeOldBackups(keepingLast count: Int) async throws -> Bool {
        removeOldBackupsCalled = true
        return removeOldBackupsResult
    }
}

/// 模拟迁移进度报告器
class MockMigrationProgressReporter: MigrationProgressReporterProtocol {
    var progress = Progress(totalUnitCount: 100)
    
    func updateProgress(_ value: Double) {
        progress.completedUnitCount = Int64(value * 100)
    }
    
    func currentProgress() -> Progress {
        return progress
    }
}
#endif 