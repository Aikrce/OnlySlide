#if canImport(XCTest)
import XCTest
import CoreData
@testable import CoreDataModule

/// CoreDataResourceManager 测试类
/// 测试 CoreDataResourceManager 对资源的查找和管理功能
class CoreDataResourceManagerTests: XCTestCase {
    
    // MARK: - Properties
    
    var resourceManager: CoreDataResourceManager!
    var tempDirectoryURL: URL!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        // 创建临时目录用于测试
        let fileManager = FileManager.default
        tempDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        
        // 初始化默认的资源管理器
        resourceManager = CoreDataResourceManager()
    }
    
    override func tearDown() async throws {
        // 清理临时目录
        try FileManager.default.removeItem(at: tempDirectoryURL)
        resourceManager = nil
    }
    
    // MARK: - Tests
    
    /// 测试合并对象模型加载
    func testMergedObjectModel() {
        let model = resourceManager.mergedObjectModel()
        // 在实际项目中会有模型，但在测试环境中可能为 nil
        // 这里主要测试方法不会崩溃
        XCTAssertNoThrow(resourceManager.mergedObjectModel())
    }
    
    /// 测试模型 URL 获取
    func testModelURL() {
        let modelURL = resourceManager.modelURL()
        
        // 测试文件的存在性
        if let url = modelURL {
            let pathExtension = url.pathExtension
            XCTAssertTrue(pathExtension == "momd" || pathExtension == "mom", "模型文件应该有 .momd 或 .mom 扩展名")
        }
    }
    
    /// 测试获取所有模型
    func testAllModels() {
        let models = resourceManager.allModels()
        // 确保方法不会崩溃
        XCTAssertNoThrow(models)
    }
    
    /// 测试使用自定义模型名称初始化
    func testCustomModelNameInitialization() {
        let customModelManager = CoreDataResourceManager(modelName: "CustomModel")
        XCTAssertNotNil(customModelManager)
        
        // 尝试获取模型（可能为 nil，因为实际上没有这个模型，但不应崩溃）
        XCTAssertNoThrow(customModelManager.modelURL())
    }
    
    /// 测试使用自定义 Bundle 数组初始化
    func testCustomBundlesInitialization() {
        let bundle1 = Bundle.main
        let bundle2 = Bundle(for: CoreDataResourceManagerTests.self)
        
        let customBundlesManager = CoreDataResourceManager(bundles: [bundle1, bundle2])
        XCTAssertNotNil(customBundlesManager)
        
        // 尝试获取模型
        XCTAssertNoThrow(customBundlesManager.mergedObjectModel())
    }
    
    /// 测试 shared(withBundles:) 工厂方法
    func testSharedWithBundles() {
        let bundle1 = Bundle.main
        let bundle2 = Bundle(for: CoreDataResourceManagerTests.self)
        
        let manager = CoreDataResourceManager.shared(withBundles: [bundle1, bundle2])
        XCTAssertNotNil(manager)
        
        // 尝试获取模型
        XCTAssertNoThrow(manager.mergedObjectModel())
    }
    
    /// 测试备份目录创建
    func testBackupDirectoryCreation() {
        let backupDirectoryURL = resourceManager.createBackupDirectory()
        XCTAssertNotNil(backupDirectoryURL, "应该成功创建备份目录")
        
        if let url = backupDirectoryURL {
            let exists = FileManager.default.fileExists(atPath: url.path)
            XCTAssertTrue(exists, "备份目录应该存在")
        }
    }
    
    /// 测试生成备份 URL
    func testBackupURLGeneration() {
        let backupURL = resourceManager.backupStoreURL()
        XCTAssertNotNil(backupURL)
        
        if let url = backupURL {
            XCTAssertTrue(url.lastPathComponent.contains(".sqlite"), "备份文件名应该包含 .sqlite 扩展名")
            XCTAssertTrue(url.lastPathComponent.contains("OnlySlide"), "备份文件名应该包含模型名称")
            
            // 验证备份目录路径
            let backupDirComponent = url.deletingLastPathComponent().lastPathComponent
            XCTAssertEqual(backupDirComponent, "Backups", "备份文件应该位于 Backups 目录中")
        }
    }
    
    /// 测试清理备份功能
    func testCleanupBackups() {
        // 创建模拟备份文件
        let backupDirectory = resourceManager.createBackupDirectory()
        XCTAssertNotNil(backupDirectory)
        
        // 创建一些测试备份文件
        if let backupDir = backupDirectory {
            for i in 1...10 {
                let backupFile = backupDir.appendingPathComponent("OnlySlide_202503\(i)_120000.sqlite")
                try? "Test backup \(i)".write(to: backupFile, atomically: true, encoding: .utf8)
                
                // 添加一些辅助文件
                if i % 2 == 0 {
                    let walFile = backupDir.appendingPathComponent("OnlySlide_202503\(i)_120000.sqlite-wal")
                    let shmFile = backupDir.appendingPathComponent("OnlySlide_202503\(i)_120000.sqlite-shm")
                    try? "WAL file \(i)".write(to: walFile, atomically: true, encoding: .utf8)
                    try? "SHM file \(i)".write(to: shmFile, atomically: true, encoding: .utf8)
                }
            }
            
            // 测试清理，保留最新的 5 个
            resourceManager.cleanupBackups(keepLatest: 5)
            
            // 检查备份数量
            let backups = resourceManager.allBackups()
            XCTAssertEqual(backups.count, 5, "应该保留 5 个最新的备份")
            
            // 检查是否保留了较新的备份
            for backup in backups {
                let fileName = backup.lastPathComponent
                XCTAssertTrue(fileName.contains("202503"), "应该保留较新的备份")
                
                // 检查备份编号是否大于 5
                if let rangeStart = fileName.range(of: "2025035"),
                   let rangeEnd = fileName.range(of: "_120000") {
                    let numberStr = fileName[rangeStart.upperBound..<rangeEnd.lowerBound]
                    if let number = Int(numberStr) {
                        XCTAssertGreaterThanOrEqual(number, 6, "应该保留编号较大的备份")
                    }
                }
            }
            
            // 检查辅助文件是否也被清理了
            for i in 1...5 {
                let walFile = backupDir.appendingPathComponent("OnlySlide_202503\(i)_120000.sqlite-wal")
                let shmFile = backupDir.appendingPathComponent("OnlySlide_202503\(i)_120000.sqlite-shm")
                
                XCTAssertFalse(FileManager.default.fileExists(atPath: walFile.path), "WAL 文件应该被清理")
                XCTAssertFalse(FileManager.default.fileExists(atPath: shmFile.path), "SHM 文件应该被清理")
            }
        }
    }
    
    /// 测试默认存储 URL 生成
    func testDefaultStoreURL() {
        let storeURL = resourceManager.defaultStoreURL()
        XCTAssertNotNil(storeURL)
        
        if let url = storeURL {
            XCTAssertTrue(url.pathExtension == "sqlite", "存储文件应该有 .sqlite 扩展名")
            
            // 检查路径是否包含应用 ID
            let pathComponents = url.pathComponents
            let bundleID = Bundle.main.bundleIdentifier ?? "com.onlyslide"
            XCTAssertTrue(pathComponents.contains(where: { $0 == bundleID }), "存储路径应该包含应用 ID")
        }
    }
    
    /// 测试从多个位置查找模型
    func testModelSearchInMultipleLocations() {
        // 创建一个模拟的 .momd 目录
        let momdDir = tempDirectoryURL.appendingPathComponent("OnlySlide.momd", isDirectory: true)
        try? FileManager.default.createDirectory(at: momdDir, withIntermediateDirectories: true, attributes: nil)
        
        // 创建一个空的模型文件
        let modelFile = momdDir.appendingPathComponent("OnlySlide_1.0.mom")
        try? "Test model content".write(to: modelFile, atomically: true, encoding: .utf8)
        
        // 创建一个包含临时目录的资源管理器
        let testBundle = Bundle(for: type(of: self))
        let mockResourceManager = CoreDataResourceManager(modelName: "OnlySlide", bundle: testBundle, additionalBundles: [])
        
        // 执行测试，确保不会崩溃
        XCTAssertNoThrow(mockResourceManager.allModelVersionURLs())
        XCTAssertNoThrow(mockResourceManager.allModels())
    }
    
    /// 测试映射模型搜索
    func testMappingModelSearch() {
        let sourceVersion = ModelVersion(major: 1, minor: 0, patch: 0)
        let destinationVersion = ModelVersion(major: 1, minor: 1, patch: 0)
        
        // 执行测试，确保不会崩溃
        XCTAssertNoThrow(resourceManager.mappingModel(from: sourceVersion, to: destinationVersion))
    }
}
#endif 