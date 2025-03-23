import XCTest
import CoreData
@testable import Core
@testable import Features

final class DataLayerIntegrationTests: XCTestCase {
    // MARK: - Properties
    
    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!
    private var documentRepository: DocumentRepository!
    private var syncManager: CoreDataSyncManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        container = setupTestContainer()
        context = container.viewContext
        documentRepository = DocumentRepository(context: context)
        syncManager = CoreDataSyncManager(context: context)
    }
    
    override func tearDown() async throws {
        documentRepository = nil
        syncManager = nil
        context = nil
        container = nil
        try await super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testDocumentCreationAndSync() async throws {
        // 创建文档
        let document = try await documentRepository.create(
            title: "测试文档",
            content: "测试内容",
            type: .text
        )
        
        // 验证文档创建
        XCTAssertNotNil(document.id)
        XCTAssertEqual(document.title, "测试文档")
        
        // 同步到服务器
        let syncExpectation = expectation(description: "同步完成")
        
        Task {
            do {
                try await syncManager.sync()
                syncExpectation.fulfill()
            } catch {
                XCTFail("同步失败: \(error)")
            }
        }
        
        await fulfillment(of: [syncExpectation], timeout: 5.0)
        
        // 验证同步状态
        let syncState = await syncManager.syncState
        XCTAssertEqual(syncState, .completed)
    }
    
    func testDocumentUpdateAndConflictResolution() async throws {
        // 创建初始文档
        let document = try await documentRepository.create(
            title: "原始标题",
            content: "原始内容",
            type: .text
        )
        
        // 模拟服务器更新
        let serverData: [String: Any] = [
            "id": document.id!.uuidString,
            "title": "服务器标题",
            "content": "服务器内容",
            "updatedAt": Date().addingTimeInterval(3600)
        ]
        
        // 本地更新
        document.title = "本地标题"
        document.content = "本地内容"
        try context.save()
        
        // 解决冲突
        let resolver = CoreDataConflictResolver(context: context)
        let resolved = try resolver.resolveConflict(
            localObject: document,
            serverObject: serverData
        )
        
        // 验证冲突解决结果
        XCTAssertEqual(resolved.title, "服务器标题")
        XCTAssertEqual(resolved.content, "服务器内容")
    }
    
    func testFullSyncFlow() async throws {
        // 准备测试数据
        let documentsCount = 10
        var documents: [Document] = []
        
        // 创建多个文档
        for i in 0..<documentsCount {
            let doc = try await documentRepository.create(
                title: "文档 \(i)",
                content: "内容 \(i)",
                type: .text
            )
            documents.append(doc)
        }
        
        // 执行完整同步流程
        let syncExpectation = expectation(description: "完整同步流程")
        
        Task {
            do {
                // 执行同步
                try await syncManager.sync()
                
                // 验证所有文档状态
                let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
                let syncedDocs = try context.fetch(fetchRequest)
                
                XCTAssertEqual(syncedDocs.count, documentsCount)
                
                // 验证每个文档的同步状态
                for doc in syncedDocs {
                    XCTAssertNotNil(doc.updatedAt)
                    XCTAssertEqual(doc.processingStatus, .completed)
                }
                
                syncExpectation.fulfill()
            } catch {
                XCTFail("同步流程失败: \(error)")
            }
        }
        
        await fulfillment(of: [syncExpectation], timeout: 10.0)
    }
    
    func testDocumentPersistence() throws {
        let context = container.viewContext
        
        // Create a document
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
        
        // Save the document
        let entity = DocumentEntity(context: context)
        entity.documentModel = document
        try context.save()
        
        // Fetch the document
        let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", document.id as CVarArg)
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1)
        
        let fetchedDocument = results.first!.documentModel
        XCTAssertEqual(fetchedDocument.id, document.id)
        XCTAssertEqual(fetchedDocument.title, document.title)
        XCTAssertEqual(fetchedDocument.content, document.content)
    }
    
    // MARK: - Helper Methods
    
    private func setupTestContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "OnlySlide")
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        let expectation = expectation(description: "加载持久化存储")
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("加载测试存储失败: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        return container
    }
} 