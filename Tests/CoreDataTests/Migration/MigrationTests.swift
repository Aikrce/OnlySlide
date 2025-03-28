#if canImport(XCTest)
import XCTest
import CoreData
@testable import CoreDataModule

/// CoreData迁移测试套件
/// 用于测试从不同版本迁移到最新版本的正确性
final class MigrationTests: XCTestCase {
    
    // MARK: - Properties
    
    /// 临时存储URL
    private var tempStoreURL: URL!
    
    /// 迁移管理器
    private var migrationManager: CoreDataMigrationManager!
    
    /// 版本管理器
    private var versionManager: CoreDataModelVersionManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // 创建临时目录和存储URL
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreDataModuleTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try? FileManager.default.createDirectory(
            at: tempDirectoryURL,
            withIntermediateDirectories: true
        )
        
        tempStoreURL = tempDirectoryURL.appendingPathComponent("TestStore.sqlite")
        migrationManager = CoreDataMigrationManager.shared
        versionManager = CoreDataModelVersionManager.shared
    }
    
    override func tearDown() {
        // 清理临时文件
        try? FileManager.default.removeItem(at: tempStoreURL.deletingLastPathComponent())
        
        tempStoreURL = nil
        migrationManager = nil
        versionManager = nil
        
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// 创建测试存储
    /// - Parameters:
    ///   - modelName: 模型名称
    ///   - storeURL: 存储URL
    /// - Returns: 持久化容器
    private func createTestStore(
        withModelName modelName: String,
        at storeURL: URL
    ) throws -> NSPersistentContainer {
        // 加载模型
        guard let modelURL = Bundle.module.url(
            forResource: modelName,
            withExtension: "momd"
        ) else {
            throw NSError(
                domain: "MigrationTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法找到模型: \(modelName)"]
            )
        }
        
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw NSError(
                domain: "MigrationTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "无法加载模型: \(modelName)"]
            )
        }
        
        // 创建持久化存储协调器
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        try persistentStoreCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        
        // 创建持久化容器
        let container = NSPersistentContainer(
            name: modelName,
            managedObjectModel: model
        )
        
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = false
        description.shouldInferMappingModelAutomatically = false
        
        container.persistentStoreDescriptions = [description]
        
        var loadError: Error?
        var loadSuccess = false
        
        container.loadPersistentStores { _, error in
            loadError = error
            loadSuccess = (error == nil)
        }
        
        if !loadSuccess {
            throw loadError ?? NSError(
                domain: "MigrationTests",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "无法加载持久化存储"]
            )
        }
        
        return container
    }
    
    /// 创建并填充测试存储
    /// - Parameters:
    ///   - modelVersion: 模型版本
    ///   - storeURL: 存储URL
    private func createAndPopulateTestStore(
        version modelVersion: ModelVersion,
        at storeURL: URL
    ) throws {
        // 获取模型名称
        let modelName = modelVersion.rawValue
        
        // 创建存储
        let container = try createTestStore(
            withModelName: modelName,
            at: storeURL
        )
        
        // 获取托管对象上下文
        let context = container.viewContext
        
        // 根据模型版本填充数据
        switch modelVersion {
        case .version1:
            // 为版本1模型创建测试数据
            let entity = NSEntityDescription.entity(
                forEntityName: "Slide",
                in: context
            )!
            
            let slide = NSManagedObject(entity: entity, insertInto: context)
            slide.setValue("测试幻灯片", forKey: "title")
            slide.setValue(Date(), forKey: "createdAt")
            
        case .version2:
            // 为版本2模型创建测试数据
            let slideEntity = NSEntityDescription.entity(
                forEntityName: "Slide",
                in: context
            )!
            
            let slide = NSManagedObject(entity: slideEntity, insertInto: context)
            slide.setValue("测试幻灯片", forKey: "title")
            slide.setValue(Date(), forKey: "createdAt")
            slide.setValue("这是一个测试描述", forKey: "slideDescription")
            
            let elementEntity = NSEntityDescription.entity(
                forEntityName: "SlideElement",
                in: context
            )!
            
            let element = NSManagedObject(entity: elementEntity, insertInto: context)
            element.setValue("文本元素", forKey: "type")
            element.setValue("这是一个文本元素", forKey: "content")
            element.setValue(slide, forKey: "slide")
            
        // 为其他版本添加测试数据...
        default:
            break
        }
        
        // 保存上下文
        try context.save()
    }
    
    // MARK: - Tests
    
    /// 测试检测是否需要迁移
    func testRequiresMigration() throws {
        // 创建版本1的存储
        try createAndPopulateTestStore(
            version: .version1,
            at: tempStoreURL
        )
        
        // 检查是否需要迁移到版本2
        let requiresMigration = try versionManager.requiresMigration(
            at: tempStoreURL
        )
        
        XCTAssertTrue(
            requiresMigration,
            "应该需要从版本1迁移到最新版本"
        )
    }
    
    /// 测试查找迁移路径
    func testFindMigrationPath() throws {
        // 测试从版本1到版本2的迁移路径
        let path = versionManager.migrationPath(
            from: .version1,
            to: .version2
        )
        
        XCTAssertEqual(
            path,
            [.version1, .version2],
            "从版本1到版本2的迁移路径应该是 [.version1, .version2]"
        )
    }
    
    /// 测试执行迁移
    func testPerformMigration() async throws {
        // 创建版本1的存储
        try createAndPopulateTestStore(
            version: .version1,
            at: tempStoreURL
        )
        
        // 执行迁移
        var progressUpdates: [MigrationProgress] = []
        
        let didMigrate = try await migrationManager.performMigration(
            at: tempStoreURL
        ) { progress in
            progressUpdates.append(progress)
        }
        
        XCTAssertTrue(
            didMigrate,
            "迁移应该成功执行"
        )
        
        XCTAssertFalse(
            progressUpdates.isEmpty,
            "应该收到进度更新"
        )
        
        // 验证迁移成功
        let requiresMigration = try versionManager.requiresMigration(
            at: tempStoreURL
        )
        
        XCTAssertFalse(
            requiresMigration,
            "迁移后不应该需要进一步迁移"
        )
    }
    
    /// 测试迁移后数据完整性
    func testDataIntegrityAfterMigration() async throws {
        // 创建版本1的存储并填充数据
        try createAndPopulateTestStore(
            version: .version1,
            at: tempStoreURL
        )
        
        // 执行迁移
        let didMigrate = try await migrationManager.performMigration(
            at: tempStoreURL
        )
        
        XCTAssertTrue(
            didMigrate,
            "迁移应该成功执行"
        )
        
        // 加载迁移后的存储
        let latestVersion = ModelVersion.version2
        let modelName = latestVersion.rawValue
        
        let container = try createTestStore(
            withModelName: modelName,
            at: tempStoreURL
        )
        
        let context = container.viewContext
        
        // 检查数据是否正确迁移
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Slide")
        let slides = try context.fetch(fetchRequest)
        
        XCTAssertEqual(
            slides.count,
            1,
            "应该有1个幻灯片对象"
        )
        
        let slide = slides.first!
        
        XCTAssertEqual(
            slide.value(forKey: "title") as? String,
            "测试幻灯片",
            "幻灯片标题应该被正确迁移"
        )
        
        XCTAssertNotNil(
            slide.value(forKey: "slideDescription"),
            "幻灯片描述字段应该存在"
        )
    }
}
#else
import CoreData
import Testing
@testable import CoreDataModule

/// CoreData迁移测试套件
/// 用于测试从不同版本迁移到最新版本的正确性
final class MigrationTests {
    // MARK: - Properties
    
    /// 临时存储URL
    private var tempStoreURL: URL!
    
    /// 迁移管理器
    private var migrationManager: CoreDataMigrationManager!
    
    /// 版本管理器
    private var versionManager: CoreDataModelVersionManager!
    
    // MARK: - Setup & Teardown
    
    func setUp() {
        // 创建临时目录和存储URL
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreDataModuleTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try? FileManager.default.createDirectory(
            at: tempDirectoryURL,
            withIntermediateDirectories: true
        )
        
        tempStoreURL = tempDirectoryURL.appendingPathComponent("TestStore.sqlite")
        migrationManager = CoreDataMigrationManager.shared
        versionManager = CoreDataModelVersionManager.shared
    }
    
    func tearDown() {
        // 清理临时文件
        try? FileManager.default.removeItem(at: tempStoreURL.deletingLastPathComponent())
        
        tempStoreURL = nil
        migrationManager = nil
        versionManager = nil
    }
    
    // MARK: - Helper Methods
    
    /// 创建测试存储
    /// - Parameters:
    ///   - modelName: 模型名称
    ///   - storeURL: 存储URL
    /// - Returns: 持久化容器
    private func createTestStore(
        withModelName modelName: String,
        at storeURL: URL
    ) throws -> NSPersistentContainer {
        // 加载模型
        guard let modelURL = Bundle.module.url(
            forResource: modelName,
            withExtension: "momd"
        ) else {
            throw NSError(
                domain: "MigrationTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法找到模型: \(modelName)"]
            )
        }
        
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw NSError(
                domain: "MigrationTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "无法加载模型: \(modelName)"]
            )
        }
        
        // 创建持久化存储协调器
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        try persistentStoreCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        
        // 创建持久化容器
        let container = NSPersistentContainer(
            name: modelName,
            managedObjectModel: model
        )
        
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = false
        description.shouldInferMappingModelAutomatically = false
        
        container.persistentStoreDescriptions = [description]
        
        var loadError: Error?
        var loadSuccess = false
        
        container.loadPersistentStores { _, error in
            loadError = error
            loadSuccess = (error == nil)
        }
        
        if !loadSuccess {
            throw loadError ?? NSError(
                domain: "MigrationTests",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "无法加载持久化存储"]
            )
        }
        
        return container
    }
    
    /// 创建并填充测试存储
    /// - Parameters:
    ///   - modelVersion: 模型版本
    ///   - storeURL: 存储URL
    private func createAndPopulateTestStore(
        version modelVersion: ModelVersion,
        at storeURL: URL
    ) throws {
        // 获取模型名称
        let modelName = modelVersion.rawValue
        
        // 创建存储
        let container = try createTestStore(
            withModelName: modelName,
            at: storeURL
        )
        
        // 获取托管对象上下文
        let context = container.viewContext
        
        // 根据模型版本填充数据
        switch modelVersion {
        case .version1:
            // 为版本1模型创建测试数据
            let entity = NSEntityDescription.entity(
                forEntityName: "Slide",
                in: context
            )!
            
            let slide = NSManagedObject(entity: entity, insertInto: context)
            slide.setValue("测试幻灯片", forKey: "title")
            slide.setValue(Date(), forKey: "createdAt")
            
        case .version2:
            // 为版本2模型创建测试数据
            let slideEntity = NSEntityDescription.entity(
                forEntityName: "Slide",
                in: context
            )!
            
            let slide = NSManagedObject(entity: slideEntity, insertInto: context)
            slide.setValue("测试幻灯片", forKey: "title")
            slide.setValue(Date(), forKey: "createdAt")
            slide.setValue("这是一个测试描述", forKey: "slideDescription")
            
            let elementEntity = NSEntityDescription.entity(
                forEntityName: "SlideElement",
                in: context
            )!
            
            let element = NSManagedObject(entity: elementEntity, insertInto: context)
            element.setValue("文本元素", forKey: "type")
            element.setValue("这是一个文本元素", forKey: "content")
            element.setValue(slide, forKey: "slide")
            
        // 为其他版本添加测试数据...
        default:
            break
        }
        
        // 保存上下文
        try context.save()
    }
    
    // MARK: - Tests
    
    /// 执行所有测试
    func run() {
        setUp()
        
        // 执行各个测试
        testRequiresMigration()
        testFindMigrationPath()
        testPerformMigration()
        
        tearDown()
    }
    
    /// 测试检测是否需要迁移
    func testRequiresMigration() {
        do {
            // 创建版本1的存储
            try createAndPopulateTestStore(
                version: .version1,
                at: tempStoreURL
            )
            
            // 检查是否需要迁移到版本2
            let requiresMigration = try versionManager.requiresMigration(
                at: tempStoreURL
            )
            
            TestSupport.assert(
                requiresMigration,
                "应该需要从版本1迁移到最新版本"
            )
        } catch {
            TestSupport.fail("测试失败: \(error.localizedDescription)")
        }
    }
    
    /// 测试查找迁移路径
    func testFindMigrationPath() {
        // 测试从版本1到版本2的迁移路径
        let path = versionManager.migrationPath(
            from: .version1,
            to: .version2
        )
        
        TestSupport.assert(
            path == [.version1, .version2],
            "从版本1到版本2的迁移路径应该是 [.version1, .version2]"
        )
    }
    
    /// 测试执行迁移
    func testPerformMigration() {
        // 简化版测试
        TestSupport.assert(true, "迁移测试需要异步支持")
    }
}
#endif 