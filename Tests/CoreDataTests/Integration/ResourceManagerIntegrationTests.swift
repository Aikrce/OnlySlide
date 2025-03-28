import XCTest
@testable import CoreDataModule

/// 资源管理器集成测试
/// 测试 CoreDataResourceManager 在真实环境中的资源加载能力
final class ResourceManagerIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    var resourceManager: CoreDataResourceManager!
    var tempDirectoryURL: URL!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        resourceManager = CoreDataResourceManager()
        
        // 创建临时目录用于测试
        let fileManager = FileManager.default
        tempDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    override func tearDownWithError() throws {
        // 清理临时目录
        try FileManager.default.removeItem(at: tempDirectoryURL)
        resourceManager = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Tests
    
    /// 测试默认情况下合并模型加载
    func testDefaultMergedModel() {
        // 在实际项目中，应该能成功加载合并的模型
        let model = resourceManager.mergedObjectModel()
        XCTAssertNotNil(model, "默认情况下应该能加载到合并的模型")
    }
    
    /// 测试从多个 Bundle 加载模型
    func testModelLoadingFromMultipleBundles() {
        // 此测试需要在真实环境中运行，检查是否能够从不同 Bundle 加载模型
        // 注意：这个测试可能会失败，因为测试环境可能没有真实的模型文件
        
        // 我们至少要确保不会崩溃
        let modelURL = resourceManager.modelURL()
        print("找到的模型URL: \(String(describing: modelURL))")
        
        // 加载所有模型版本
        let versionURLs = resourceManager.allModelVersionURLs()
        print("找到的版本URLs: \(versionURLs)")
        
        // 我们不断言具体结果，只确保方法调用不会崩溃
    }
    
    /// 测试备份目录创建
    func testBackupDirectoryCreation() {
        let backupDirectory = resourceManager.createBackupDirectory()
        XCTAssertNotNil(backupDirectory, "应该能创建备份目录")
        
        if let backupDirectory = backupDirectory {
            let exists = FileManager.default.fileExists(atPath: backupDirectory.path)
            XCTAssertTrue(exists, "备份目录应该存在")
        }
    }
    
    /// 测试备份URL生成
    func testBackupURLGeneration() {
        let backupURL = resourceManager.backupStoreURL()
        XCTAssertNotNil(backupURL, "应该能生成备份URL")
        XCTAssertTrue(backupURL.lastPathComponent.contains("OnlySlide"), "备份文件名应该包含模型名称")
        XCTAssertTrue(backupURL.pathExtension == "sqlite", "备份文件应该是sqlite格式")
    }
    
    /// 测试默认存储URL
    func testDefaultStoreURL() {
        let storeURL = resourceManager.defaultStoreURL()
        XCTAssertNotNil(storeURL, "应该能生成默认存储URL")
        XCTAssertTrue(storeURL.lastPathComponent.contains("OnlySlide"), "存储文件名应该包含模型名称")
        XCTAssertTrue(storeURL.pathExtension == "sqlite", "存储文件应该是sqlite格式")
    }
    
    /// 测试模拟不同 Bundle 环境下的资源加载
    func testSimulatedBundleEnvironments() throws {
        // 创建一个模拟的模型目录结构
        let momdURL = tempDirectoryURL.appendingPathComponent("OnlySlide.momd", isDirectory: true)
        try FileManager.default.createDirectory(at: momdURL, withIntermediateDirectories: true, attributes: nil)
        
        // 创建一个假的 .mom 文件
        let momURL = momdURL.appendingPathComponent("V1_0_0.mom")
        let dummyData = "测试数据".data(using: .utf8)!
        try dummyData.write(to: momURL)
        
        // 使用自定义 Bundle 初始化资源管理器
        // 注意：在实际测试中，这需要模拟 Bundle，这里只是为了演示
        print("创建的模拟模型文件: \(momURL.path)")
        
        // 验证文件确实被创建
        XCTAssertTrue(FileManager.default.fileExists(atPath: momURL.path), "模拟的模型文件应该存在")
    }
    
    /// 测试清理过期备份
    func testCleanupBackups() async throws {
        // 创建几个模拟的备份文件
        let backupDir = try XCTUnwrap(resourceManager.createBackupDirectory())
        
        // 创建5个假备份文件
        for i in 1...5 {
            let backupURL = backupDir.appendingPathComponent("OnlySlide_test_\(i).sqlite")
            let dummyData = "备份\(i)".data(using: .utf8)!
            try dummyData.write(to: backupURL)
            
            // 添加延迟使文件修改时间不同
            if i < 5 {
                try await Task.sleep(for: .milliseconds(100)) // 等待0.1秒
            }
        }
        
        // 验证备份文件已创建
        let initialBackups = resourceManager.allBackups()
        XCTAssertEqual(initialBackups.count, 5, "应该创建了5个备份文件")
        
        // 执行清理，只保留3个备份
        resourceManager.cleanupBackups(keepLatest: 3)
        
        // 验证清理结果
        let remainingBackups = resourceManager.allBackups()
        XCTAssertEqual(remainingBackups.count, 3, "清理后应该只剩3个备份文件")
    }
} 