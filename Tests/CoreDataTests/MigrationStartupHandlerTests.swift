import XCTest
import CoreData
@testable import CoreDataModule

final class MigrationStartupHandlerTests: XCTestCase {
    
    private var handler: MigrationStartupHandler!
    private var migrationManager: CoreDataMigrationManager!
    private var versionManager: CoreDataModelVersionManager!
    private var tempURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 创建用于测试的临时存储URL
        let tempDir = FileManager.default.temporaryDirectory
        tempURL = tempDir.appendingPathComponent("test_store.sqlite")
        
        // 如果文件存在，先删除它
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.removeItem(at: tempURL)
        }
        
        // 创建测试用的版本管理器
        versionManager = CoreDataModelVersionManager()
        
        // 创建测试用的迁移管理器
        migrationManager = CoreDataMigrationManager(versionManager: versionManager)
        
        // 创建测试用的启动处理器
        handler = MigrationStartupHandler(
            migrationManager: migrationManager,
            versionManager: versionManager
        )
    }
    
    override func tearDownWithError() throws {
        // 清理临时文件
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.removeItem(at: tempURL)
        }
        
        handler = nil
        migrationManager = nil
        versionManager = nil
        tempURL = nil
        
        try super.tearDownWithError()
    }
    
    func testGetStoreURL() {
        // 测试获取存储URL的静态方法
        let fileName = "test_store.sqlite"
        let url = MigrationStartupHandler.getStoreURL(fileName: fileName)
        
        // 检查生成的URL是否有效
        XCTAssertNotNil(url, "应该能生成有效的存储URL")
        XCTAssertTrue(url.lastPathComponent == fileName, "文件名应该匹配")
    }
    
    func testCheckAndMigrateStoreWhenNoMigrationNeeded() {
        // 测试当不需要迁移时的行为
        var progressUpdates = 0
        
        handler.checkAndMigrateStoreIfNeeded(at: tempURL) { progress in
            progressUpdates += 1
        }
        
        // 检查状态
        let status = handler.getMigrationStatus()
        XCTAssertEqual(status, .completed, "没有实际存储时，状态应为已完成")
        XCTAssertEqual(progressUpdates, 0, "不需要迁移时不应有进度更新")
    }
} 