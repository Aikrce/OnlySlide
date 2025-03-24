import XCTest
import CoreData
@testable import Core

final class OriginalCoreDataTests: XCTestCase {
    // MARK: - Properties
    
    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        container = setupInMemoryPersistentContainer()
        context = container.viewContext
    }
    
    override func tearDown() async throws {
        context = nil
        container = nil
        try await super.tearDown()
    }
    
    // MARK: - Migration Tests
    
    func testModelVersionManagement() async throws {
        let manager = CoreDataModelVersionManager.shared
        
        // 创建测试存储
        let storeURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.sqlite")
        
        // 删除可能存在的测试文件
        try? FileManager.default.removeItem(at: storeURL)
        
        // 确保模型版本正确
        let modelVersions = manager.availableVersions
        XCTAssertGreaterThan(modelVersions.count, 0, "应该至少有一个模型版本")
    }
    
    // MARK: - Core Data Stack Tests
    
    func testCoreDataStack() throws {
        // 测试创建托管对象上下文
        let stack = CoreDataStack.shared
        XCTAssertNotNil(stack.viewContext, "视图上下文不应为nil")
        
        // 测试创建后台上下文
        let backgroundContext = stack.newBackgroundContext()
        XCTAssertNotNil(backgroundContext, "后台上下文不应为nil")
        XCTAssertNotEqual(backgroundContext, stack.viewContext, "后台上下文应与视图上下文不同")
    }
    
    func testSaveContext() async throws {
        // 测试保存上下文
        let stack = CoreDataStack(inMemory: true)
        
        // 在上下文中创建一个对象
        let entity = NSEntityDescription.entity(forEntityName: "Document", in: stack.viewContext)!
        let document = NSManagedObject(entity: entity, insertInto: stack.viewContext)
        document.setValue("Test Document", forKey: "title")
        
        // 保存上下文
        try stack.saveContext()
        
        // 验证保存成功
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Document")
        let results = try stack.viewContext.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1, "应该有一个保存的文档")
        XCTAssertEqual(results.first?.value(forKey: "title") as? String, "Test Document", "标题应该正确")
    }
    
    // MARK: - CRUD Tests
    
    func testCreateAndFetchDocument() async throws {
        // 测试创建和获取文档
        let manager = CoreDataManager()
        let context = manager.mainContext
        
        // 创建文档
        let document = try createTestDocument(in: context, title: "Test Document", content: "Test Content")
        
        // 保存上下文
        try context.save()
        
        // 获取文档
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Document")
        fetchRequest.predicate = NSPredicate(format: "id == %@", document.value(forKey: "id") as! String)
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1, "应该能获取到创建的文档")
        
        let fetchedDocument = results.first!
        XCTAssertEqual(fetchedDocument.value(forKey: "title") as? String, "Test Document", "标题应该匹配")
        XCTAssertEqual(fetchedDocument.value(forKey: "content") as? String, "Test Content", "内容应该匹配")
    }
    
    func testUpdateDocument() async throws {
        // 测试更新文档
        let manager = CoreDataManager()
        let context = manager.mainContext
        
        // 创建文档
        let document = try createTestDocument(in: context, title: "Original Title", content: "Original Content")
        try context.save()
        
        // 更新文档
        document.setValue("Updated Title", forKey: "title")
        document.setValue("Updated Content", forKey: "content")
        try context.save()
        
        // 获取并验证更新
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Document")
        fetchRequest.predicate = NSPredicate(format: "id == %@", document.value(forKey: "id") as! String)
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1, "应该能获取到更新的文档")
        
        let updatedDocument = results.first!
        XCTAssertEqual(updatedDocument.value(forKey: "title") as? String, "Updated Title", "更新后的标题应该匹配")
        XCTAssertEqual(updatedDocument.value(forKey: "content") as? String, "Updated Content", "更新后的内容应该匹配")
    }
    
    func testDeleteDocument() async throws {
        // 测试删除文档
        let manager = CoreDataManager()
        let context = manager.mainContext
        
        // 创建文档
        let document = try createTestDocument(in: context, title: "Test Document", content: "Test Content")
        try context.save()
        
        // 删除文档
        context.delete(document)
        try context.save()
        
        // 验证删除
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Document")
        fetchRequest.predicate = NSPredicate(format: "id == %@", document.value(forKey: "id") as! String)
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 0, "删除后应该无法获取到文档")
    }
    
    // MARK: - Sync Tests
    
    func testSyncStateTransitions() async throws {
        // 测试同步状态转换
        let idleState = SyncState.idle
        let syncingState = SyncState.syncing
        let completedState = SyncState.completed
        let errorState = SyncState.error(AppError.networkError("Test Error"))
        
        // 测试相等性
        XCTAssertEqual(idleState, .idle)
        XCTAssertEqual(syncingState, .syncing)
        XCTAssertEqual(completedState, .completed)
        XCTAssertNotEqual(idleState, syncingState)
        
        // 测试错误状态相等性
        let sameErrorState = SyncState.error(AppError.networkError("Test Error"))
        let differentErrorState = SyncState.error(AppError.networkError("Different Error"))
        
        XCTAssertEqual(errorState, sameErrorState)
        XCTAssertNotEqual(errorState, differentErrorState)
    }
    
    func testConflictResolution() async throws {
        // 测试冲突解决
        let resolver = CoreDataConflictResolver.shared
        
        // 创建测试对象
        let document = try createTestDocument(in: context, title: "Local Title", content: "Local Content")
        
        // 创建模拟服务器数据
        let serverData: [String: Any] = [
            "id": document.value(forKey: "id") as! String,
            "title": "Server Title",
            "content": "Server Content",
            "updatedAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)) // 1小时后
        ]
        
        // 设置本地更新时间
        document.setValue(Date(), forKey: "updatedAt")
        
        // 测试不同的冲突解决策略
        
        // 1. 本地优先
        resolver.setDefaultStrategy(.localWins)
        let localResult = try resolver.resolveConflict(
            localObject: document,
            serverData: serverData,
            strategy: .localWins,
            context: context
        )
        XCTAssertEqual(localResult.value(forKey: "title") as? String, "Local Title", "本地优先策略应保留本地值")
        
        // 2. 服务器优先
        resolver.setDefaultStrategy(.serverWins)
        let serverResult = try resolver.resolveConflict(
            localObject: document,
            serverData: serverData,
            strategy: .serverWins,
            context: context
        )
        XCTAssertEqual(serverResult.value(forKey: "title") as? String, "Server Title", "服务器优先策略应使用服务器值")
        
        // 3. 最近优先（服务器数据更新）
        resolver.setDefaultStrategy(.mostRecent)
        document.setValue("Local Title", forKey: "title") // 恢复本地值
        let recentResult = try resolver.resolveConflict(
            localObject: document,
            serverData: serverData,
            strategy: .mostRecent,
            context: context
        )
        XCTAssertEqual(recentResult.value(forKey: "title") as? String, "Server Title", "最近优先策略应使用最近更新的值")
    }
    
    // MARK: - Error Handling Tests
    
    func testCoreDataErrorTypes() {
        // 测试 Core Data 错误类型
        let migrationError = CoreDataError.migrationFailed("Test Migration Error")
        let fetchError = CoreDataError.fetchFailed("Test Fetch Error")
        let saveError = CoreDataError.saveFailed("Test Save Error")
        
        XCTAssertEqual(migrationError.errorDescription, "Migration failed: Test Migration Error")
        XCTAssertEqual(fetchError.errorDescription, "Fetch failed: Test Fetch Error")
        XCTAssertEqual(saveError.errorDescription, "Save failed: Test Save Error")
    }
    
    func testErrorHandling() async throws {
        // 测试错误处理
        let errorHandler = ErrorHandlingService()
        
        // 测试可恢复错误
        let recoverableError = AppError.networkError("测试网络错误")
        let recoverableResult = errorHandler.handleError(recoverableError, source: "CoreDataTests", action: "testErrorHandling")
        XCTAssertTrue(recoverableResult, "网络错误应该被识别为可恢复")
        
        // 测试不可恢复错误
        let unrecoverableError = AppError.criticalError("测试严重错误")
        let unrecoverableResult = errorHandler.handleError(unrecoverableError, source: "CoreDataTests", action: "testErrorHandling")
        XCTAssertFalse(unrecoverableResult, "严重错误应该被识别为不可恢复")
    }
    
    // MARK: - Helper Methods
    
    private func setupInMemoryPersistentContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "OnlySlide")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("无法加载内存存储: \(error)")
            }
        }
        
        return container
    }
    
    private func createTestDocument(in context: NSManagedObjectContext, title: String, content: String) throws -> NSManagedObject {
        let entity = NSEntityDescription.entity(forEntityName: "Document", in: context)!
        let document = NSManagedObject(entity: entity, insertInto: context)
        
        // 设置属性
        document.setValue(UUID().uuidString, forKey: "id")
        document.setValue(title, forKey: "title")
        document.setValue(content, forKey: "content")
        document.setValue(Date(), forKey: "createdAt")
        document.setValue(Date(), forKey: "updatedAt")
        document.setValue(Date(), forKey: "lastSyncedAt")
        
        return document
    }
} 