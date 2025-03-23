import XCTest
import CoreData
@testable import Core
@testable import Features

final class DataLayerPerformanceTests: XCTestCase {
    // MARK: - Properties
    
    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!
    private var documentRepository: DocumentRepository!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        container = setupTestContainer()
        context = container.viewContext
        documentRepository = DocumentRepository(context: context)
    }
    
    override func tearDown() async throws {
        documentRepository = nil
        context = nil
        container = nil
        try await super.tearDown()
    }
    
    // MARK: - Performance Tests
    
    func testBatchInsertPerformance() throws {
        let batchSizes = [100, 1000, 10000]
        
        for size in batchSizes {
            measure {
                let context = container.newBackgroundContext()
                
                context.performAndWait {
                    for i in 0..<size {
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
    }
    
    func testBatchFetchPerformance() throws {
        // 准备测试数据
        let context = container.newBackgroundContext()
        let documentsCount = 10000
        
        context.performAndWait {
            for i in 0..<documentsCount {
                let document = Document(context: context)
                document.id = UUID()
                document.title = "文档 \(i)"
                document.content = "内容 \(i)"
            }
            try? context.save()
        }
        
        // 测试不同批量大小的获取性能
        let batchSizes = [50, 100, 500]
        
        for batchSize in batchSizes {
            measure {
                let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
                fetchRequest.fetchBatchSize = batchSize
                
                let results = try? context.fetch(fetchRequest)
                XCTAssertEqual(results?.count, documentsCount)
            }
        }
    }
    
    func testSearchPerformance() throws {
        // 准备测试数据
        let context = container.newBackgroundContext()
        let documentsCount = 10000
        
        context.performAndWait {
            for i in 0..<documentsCount {
                let document = Document(context: context)
                document.id = UUID()
                document.title = "文档 \(i)"
                document.content = "这是一个测试文档，包含一些关键词：性能测试 \(i)"
                document.tags = ["测试", "性能", "文档"]
            }
            try? context.save()
        }
        
        // 测试搜索性能
        measure {
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "content CONTAINS[cd] %@ OR title CONTAINS[cd] %@",
                "性能测试",
                "文档"
            )
            
            let results = try? context.fetch(fetchRequest)
            XCTAssertNotNil(results)
            XCTAssertGreaterThan(results?.count ?? 0, 0)
        }
    }
    
    func testRelationshipFetchPerformance() throws {
        // 准备测试数据
        let context = container.newBackgroundContext()
        let documentsCount = 1000
        
        context.performAndWait {
            for i in 0..<documentsCount {
                let document = Document(context: context)
                document.id = UUID()
                document.title = "文档 \(i)"
                
                // 创建关联的幻灯片
                for j in 0..<5 {
                    let slide = Slide(context: context)
                    slide.id = UUID()
                    slide.title = "幻灯片 \(j)"
                    slide.content = "幻灯片内容 \(j)"
                    slide.document = document
                }
            }
            try? context.save()
        }
        
        // 测试关系获取性能
        measure {
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.relationshipKeyPathsForPrefetching = ["slides"]
            
            let results = try? context.fetch(fetchRequest)
            XCTAssertEqual(results?.count, documentsCount)
            
            // 验证关系数据
            for document in results ?? [] {
                XCTAssertEqual(document.slides?.count, 5)
            }
        }
    }
    
    func testSortingPerformance() throws {
        // 准备测试数据
        let context = container.newBackgroundContext()
        let documentsCount = 10000
        
        context.performAndWait {
            for _ in 0..<documentsCount {
                let document = Document(context: context)
                document.id = UUID()
                document.title = "文档 \(Int.random(in: 0..<1000))"
                document.createdAt = Date().addingTimeInterval(Double.random(in: -86400...86400))
            }
            try? context.save()
        }
        
        // 测试不同排序方式的性能
        let sortDescriptors: [[NSSortDescriptor]] = [
            [NSSortDescriptor(key: "title", ascending: true)],
            [NSSortDescriptor(key: "createdAt", ascending: false)],
            [
                NSSortDescriptor(key: "title", ascending: true),
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
        ]
        
        for descriptors in sortDescriptors {
            measure {
                let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
                fetchRequest.sortDescriptors = descriptors
                
                let results = try? context.fetch(fetchRequest)
                XCTAssertEqual(results?.count, documentsCount)
            }
        }
    }
    
    func testBulkDocumentCreation() {
        measure {
            for _ in 0..<1000 {
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
            }
            
            XCTAssertNoThrow(try context.save())
        }
    }
    
    func testBulkDocumentFetch() {
        // Setup: Create 1000 documents
        for _ in 0..<1000 {
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
        }
        XCTAssertNoThrow(try context.save())
        
        // Measure fetch performance
        measure {
            let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
            XCTAssertNoThrow(try context.fetch(fetchRequest))
        }
    }
    
    func testBulkDocumentUpdate() {
        // Setup: Create 1000 documents
        var documents: [DocumentEntity] = []
        for _ in 0..<1000 {
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
            documents.append(entity)
        }
        XCTAssertNoThrow(try context.save())
        
        // Measure update performance
        measure {
            for entity in documents {
                var document = entity.documentModel
                document.title = "Updated Title"
                document.content = "Updated Content"
                entity.documentModel = document
            }
            XCTAssertNoThrow(try context.save())
        }
    }
    
    func testBulkDocumentDelete() {
        // Setup: Create 1000 documents
        for _ in 0..<1000 {
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
        }
        XCTAssertNoThrow(try context.save())
        
        // Measure delete performance
        measure {
            let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
            let documents = try! context.fetch(fetchRequest)
            for document in documents {
                context.delete(document)
            }
            XCTAssertNoThrow(try context.save())
        }
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