import XCTest
import CoreData
@testable import Core

final class CoreDataTests: XCTestCase {
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
        let store = try context.persistentStoreCoordinator?.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )
        
        XCTAssertNotNil(store, "应该成功创建存储")
        
        // 测试迁移检查
        let requiresMigration = try manager.requiresMigration(at: storeURL)
        XCTAssertFalse(requiresMigration, "新创建的存储不应该需要迁移")
        
        // 清理
        try FileManager.default.removeItem(at: storeURL)
    }
    
    func testMigrationProgress() async throws {
        let manager = CoreDataMigrationManager.shared
        let storeURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.sqlite")
        
        var progressUpdates: [Double] = []
        
        // 执行迁移
        let success = try await manager.performMigration(at: storeURL) { progress in
            progressUpdates.append(progress.percentage)
        }
        
        XCTAssertTrue(success, "迁移应该成功完成")
        XCTAssertFalse(progressUpdates.isEmpty, "应该收到进度更新")
        
        // 清理
        try? FileManager.default.removeItem(at: storeURL)
    }
    
    // MARK: - Conflict Resolution Tests
    
    func testConflictResolution() async throws {
        let resolver = CoreDataConflictResolver(context: context)
        
        // 创建测试对象
        let document = Document(context: context)
        document.id = UUID()
        document.title = "本地版本"
        document.updatedAt = Date()
        
        // 创建服务器数据
        let serverData: [String: Any] = [
            "id": document.id!.uuidString,
            "title": "服务器版本",
            "updatedAt": Date().addingTimeInterval(3600) // 一小时后
        ]
        
        // 测试不同策略
        do {
            // 测试服务器优先策略
            let resolvedServer = try resolver.resolveConflict(
                localObject: document,
                serverObject: serverData
            )
            XCTAssertEqual(resolvedServer.title, "服务器版本")
            
            // 测试客户端优先策略
            let resolverClient = CoreDataConflictResolver(context: context, policy: .clientWins)
            let resolvedClient = try resolverClient.resolveConflict(
                localObject: document,
                serverObject: serverData
            )
            XCTAssertEqual(resolvedClient.title, "本地版本")
        } catch {
            XCTFail("冲突解决不应该失败: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testBatchInsertPerformance() throws {
        measure {
            let count = 1000
            let context = container.newBackgroundContext()
            
            context.performAndWait {
                for i in 0..<count {
                    let document = Document(context: context)
                    document.id = UUID()
                    document.title = "文档 \(i)"
                    document.content = "内容 \(i)"
                    document.createdAt = Date()
                    document.updatedAt = Date()
                }
                
                XCTAssertNoThrow(try context.save())
            }
        }
    }
    
    func testBatchFetchPerformance() throws {
        // 准备测试数据
        let context = container.newBackgroundContext()
        context.performAndWait {
            for i in 0..<1000 {
                let document = Document(context: context)
                document.id = UUID()
                document.title = "文档 \(i)"
            }
            try? context.save()
        }
        
        // 测试批量获取性能
        measure {
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            let results = try? context.fetch(fetchRequest)
            XCTAssertEqual(results?.count, 1000)
        }
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
    
    func testDocumentEntityCreation() {
        let document = Document(
            id: UUID(),
            title: "Test Document",
            content: "Test Content",
            createdAt: Date(),
            updatedAt: Date(),
            metadata: "Test Metadata",
            status: .draft,
            sourceURL: nil,
            type: .unknown,
            tags: [],
            user: nil,
            slides: []
        )
        
        let entity = DocumentEntity(context: context)
        entity.documentModel = document
        
        XCTAssertNoThrow(try context.save())
        
        let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        let results = try! context.fetch(fetchRequest)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, document.id)
        XCTAssertEqual(results.first?.title, document.title)
        XCTAssertEqual(results.first?.content, document.content)
    }
    
    func testDocumentEntityUpdate() {
        // Create initial document
        let document = Document(
            id: UUID(),
            title: "Test Document",
            content: "Test Content",
            createdAt: Date(),
            updatedAt: Date(),
            metadata: "Test Metadata",
            status: .draft,
            sourceURL: nil,
            type: .unknown,
            tags: [],
            user: nil,
            slides: []
        )
        
        let entity = DocumentEntity(context: context)
        entity.documentModel = document
        XCTAssertNoThrow(try context.save())
        
        // Update document
        var updatedDocument = document
        updatedDocument.title = "Updated Title"
        updatedDocument.content = "Updated Content"
        
        entity.documentModel = updatedDocument
        XCTAssertNoThrow(try context.save())
        
        // Verify update
        let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        let results = try! context.fetch(fetchRequest)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Updated Title")
        XCTAssertEqual(results.first?.content, "Updated Content")
    }
    
    func testDocumentEntityDeletion() {
        // Create document
        let document = Document(
            id: UUID(),
            title: "Test Document",
            content: "Test Content",
            createdAt: Date(),
            updatedAt: Date(),
            metadata: "Test Metadata",
            status: .draft,
            sourceURL: nil,
            type: .unknown,
            tags: [],
            user: nil,
            slides: []
        )
        
        let entity = DocumentEntity(context: context)
        entity.documentModel = document
        XCTAssertNoThrow(try context.save())
        
        // Delete document
        context.delete(entity)
        XCTAssertNoThrow(try context.save())
        
        // Verify deletion
        let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        let results = try! context.fetch(fetchRequest)
        
        XCTAssertEqual(results.count, 0)
    }
} 