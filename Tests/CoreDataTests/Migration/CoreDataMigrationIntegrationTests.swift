@preconcurrency import CoreData
import XCTest
@testable import CoreDataModule

@MainActor
final class CoreDataMigrationIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var tempDirectoryURL: URL!
    private var storeURL: URL!
    private var resourceManager: CoreDataResourceManager!
    private var backupManager: BackupManager!
    private var planner: MigrationPlanner!
    private var executor: MigrationExecutor!
    private var progressReporter: MigrationProgressReporter!
    private var migrationManager: CoreDataMigrationManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        // 创建临时目录
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreDataMigrationTests_\(UUID().uuidString)", isDirectory: true)
        
        try FileManager.default.createDirectory(
            at: tempDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // 创建测试存储 URL
        storeURL = tempDirectoryURL.appendingPathComponent("test_store.sqlite")
        
        // 创建测试资源管理器
        resourceManager = CoreDataResourceManager()
        
        // 创建测试备份管理器
        let backupConfig = BackupConfiguration(
            shouldCreateBackup: true,
            shouldRemoveOldBackups: true,
            maxBackupsToKeep: 3
        )
        backupManager = BackupManager(resourceManager: resourceManager, configuration: backupConfig)
        
        // 创建测试计划器
        let modelVersionManager = CoreDataModelVersionManager()
        planner = MigrationPlanner(resourceManager: resourceManager, modelVersionManager: modelVersionManager)
        
        // 创建测试执行器
        executor = MigrationExecutor(planner: planner)
        
        // 创建测试进度报告器
        progressReporter = MigrationProgressReporter()
        
        // 创建测试迁移管理器
        migrationManager = CoreDataMigrationManager(
            progressReporter: progressReporter,
            backupManager: backupManager,
            planner: planner,
            executor: executor
        )
    }
    
    override func tearDown() async throws {
        // 清理临时目录
        if FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        
        // 清理引用
        tempDirectoryURL = nil
        storeURL = nil
        resourceManager = nil
        backupManager = nil
        planner = nil
        executor = nil
        progressReporter = nil
        migrationManager = nil
    }
    
    // MARK: - Tests
    
    /// 测试创建并迁移存储
    func testCreateAndMigrateStore() async throws {
        // 1. 创建测试存储
        let testStore = try createTestStore(at: storeURL)
        XCTAssertNotNil(testStore, "应该成功创建测试存储")
        
        // 2. 检查迁移前状态
        XCTAssertEqual(migrationManager.getCurrentState(), .notStarted, "初始状态应该是 notStarted")
        XCTAssertNil(migrationManager.getCurrentProgress(), "初始进度应该为 nil")
        
        // 3. 模拟存储需要迁移
        let mockPlanner = MockMigrationPlanner(resourceManager: resourceManager, modelVersionManager: CoreDataModelVersionManager())
        mockPlanner.shouldRequireMigration = true
        
        let mockExecutor = MockMigrationExecutor(planner: mockPlanner)
        
        migrationManager = CoreDataMigrationManager(
            progressReporter: progressReporter,
            backupManager: backupManager,
            planner: mockPlanner,
            executor: mockExecutor
        )
        
        // 4. 执行迁移
        do {
            let needsMigration = try await migrationManager.checkAndMigrateStoreIfNeeded(at: storeURL)
            XCTAssertTrue(needsMigration, "应该需要迁移")
            XCTAssertEqual(migrationManager.getCurrentState(), .completed, "迁移完成后状态应该是 completed")
        } catch {
            XCTFail("迁移过程中发生错误: \(error)")
        }
    }
    
    /// 测试迁移不需要时的情况
    func testMigrationNotNeeded() async throws {
        // 1. 创建测试存储
        let testStore = try createTestStore(at: storeURL)
        XCTAssertNotNil(testStore, "应该成功创建测试存储")
        
        // 2. 模拟存储不需要迁移
        let mockPlanner = MockMigrationPlanner(resourceManager: resourceManager, modelVersionManager: CoreDataModelVersionManager())
        mockPlanner.shouldRequireMigration = false
        
        migrationManager = CoreDataMigrationManager(
            progressReporter: progressReporter,
            backupManager: backupManager,
            planner: mockPlanner,
            executor: executor
        )
        
        // 3. 执行迁移检查
        let needsMigration = try await migrationManager.checkAndMigrateStoreIfNeeded(at: storeURL)
        XCTAssertFalse(needsMigration, "不应该需要迁移")
        XCTAssertEqual(migrationManager.getCurrentState(), .completed, "状态应该是 completed，但结果是 notNeeded")
    }
    
    /// 测试迁移过程中的错误处理
    func testMigrationError() async throws {
        // 1. 创建测试存储
        let testStore = try createTestStore(at: storeURL)
        XCTAssertNotNil(testStore, "应该成功创建测试存储")
        
        // 2. 模拟存储需要迁移，但执行过程中会发生错误
        let mockPlanner = MockMigrationPlanner(resourceManager: resourceManager, modelVersionManager: CoreDataModelVersionManager())
        mockPlanner.shouldRequireMigration = true
        mockPlanner.shouldThrowError = true
        mockPlanner.errorToThrow = MigrationError.planCreationFailed("测试错误")
        
        migrationManager = CoreDataMigrationManager(
            progressReporter: progressReporter,
            backupManager: backupManager,
            planner: mockPlanner,
            executor: executor
        )
        
        // 3. 执行迁移
        do {
            _ = try await migrationManager.checkAndMigrateStoreIfNeeded(at: storeURL)
            XCTFail("应该抛出错误")
        } catch {
            XCTAssertEqual(migrationManager.getCurrentState(), .failed, "迁移失败后状态应该是 failed")
            XCTAssertTrue(error is MigrationError, "错误应该是 MigrationError 类型")
        }
    }
    
    /// 测试进度报告
    func testProgressReporting() async throws {
        // 1. 创建测试存储
        let testStore = try createTestStore(at: storeURL)
        XCTAssertNotNil(testStore, "应该成功创建测试存储")
        
        // 2. 模拟存储需要迁移，并且会报告进度
        let mockPlanner = MockMigrationPlanner(resourceManager: resourceManager, modelVersionManager: CoreDataModelVersionManager())
        mockPlanner.shouldRequireMigration = true
        
        let mockExecutor = MockMigrationExecutor(planner: mockPlanner)
        mockExecutor.shouldReportProgress = true
        
        migrationManager = CoreDataMigrationManager(
            progressReporter: progressReporter,
            backupManager: backupManager,
            planner: mockPlanner,
            executor: mockExecutor
        )
        
        // 3. 执行迁移
        do {
            let needsMigration = try await migrationManager.checkAndMigrateStoreIfNeeded(at: storeURL)
            XCTAssertTrue(needsMigration, "应该需要迁移")
            
            // 4. 验证进度报告
            XCTAssertNotNil(migrationManager.getCurrentProgress(), "应该有进度报告")
            XCTAssertEqual(migrationManager.getCurrentProgress()?.fraction, 1.0, "进度应该是 100%")
            XCTAssertEqual(migrationManager.getCurrentState(), .completed, "迁移完成后状态应该是 completed")
        } catch {
            XCTFail("迁移过程中发生错误: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// 创建测试存储
    private func createTestStore(at url: URL) throws -> NSPersistentStore? {
        // 使用空模型创建一个测试存储
        let model = NSManagedObjectModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        
        return try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: options
        )
    }
}

// MARK: - Mock Classes

class MockMigrationPlanner: MigrationPlanner {
    var shouldRequireMigration = false
    var shouldThrowError = false
    var errorToThrow: Error = MigrationError.unknown("未知错误")
    
    override func requiresMigration(at storeURL: URL) async throws -> Bool {
        if shouldThrowError {
            throw errorToThrow
        }
        return shouldRequireMigration
    }
    
    override func createMigrationPlan(for storeURL: URL) async throws -> MigrationPlan {
        if shouldThrowError {
            throw errorToThrow
        }
        
        // 创建一个测试迁移计划
        if shouldRequireMigration {
            let step = MigrationStep(
                sourceVersion: ModelVersion(major: 1, minor: 0, patch: 0),
                destinationVersion: ModelVersion(major: 1, minor: 1, patch: 0)
            )
            return MigrationPlan(steps: [step])
        } else {
            return MigrationPlan(steps: [])
        }
    }
}

class MockMigrationExecutor: MigrationExecutor {
    var shouldReportProgress = false
    
    override func executePlan(_ plan: MigrationPlan, progressHandler: ((MigrationProgress) -> Void)? = nil) async throws {
        // 模拟执行计划
        if shouldReportProgress && progressHandler != nil {
            // 报告 0% 进度
            let initialProgress = MigrationProgress(
                currentStep: 1,
                totalSteps: 1,
                description: "开始迁移",
                sourceVersion: ModelVersion(major: 1, minor: 0, patch: 0),
                destinationVersion: ModelVersion(major: 1, minor: 1, patch: 0),
                percentComplete: 0
            )
            progressHandler?(initialProgress)
            
            // 短暂延迟
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            // 报告 50% 进度
            let midProgress = MigrationProgress(
                currentStep: 1,
                totalSteps: 1,
                description: "迁移进行中",
                sourceVersion: ModelVersion(major: 1, minor: 0, patch: 0),
                destinationVersion: ModelVersion(major: 1, minor: 1, patch: 0),
                percentComplete: 50
            )
            progressHandler?(midProgress)
            
            // 短暂延迟
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            // 报告 100% 进度
            let finalProgress = MigrationProgress(
                currentStep: 1,
                totalSteps: 1,
                description: "迁移完成",
                sourceVersion: ModelVersion(major: 1, minor: 0, patch: 0),
                destinationVersion: ModelVersion(major: 1, minor: 1, patch: 0),
                percentComplete: 100
            )
            progressHandler?(finalProgress)
        }
    }
} 