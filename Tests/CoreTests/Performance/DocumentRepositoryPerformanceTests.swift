import XCTest
import CoreData
@testable import Core

final class DocumentRepositoryPerformanceTests: XCTestCase {
    // MARK: - Properties
    
    private var repository: CoreDataDocumentRepository!
    private var coreDataManager: CoreDataManager!
    private var cachingEnabled = true
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 使用内存数据库以避免测试对物理存储的影响
        let persistentContainer = setupInMemoryPersistentContainer()
        coreDataManager = CoreDataManager(container: persistentContainer)
        
        // 创建自定义缓存配置（缩短过期时间以便测试）
        let cacheConfig = CacheConfig(
            enableAutomaticPurge: true,
            purgeInterval: 60, // 1分钟清理一次
            defaultExpirationTime: 60, // 1分钟过期
            maxCacheItems: 10000
        )
        
        let documentCache = DocumentCache(config: cacheConfig)
        
        // 创建测试用的仓库实例
        repository = CoreDataDocumentRepository(
            coreDataManager: coreDataManager,
            syncManager: CoreDataSyncManager.shared,
            conflictResolver: CoreDataConflictResolver.shared,
            documentCache: documentCache
        )
    }
    
    override func tearDown() async throws {
        repository = nil
        coreDataManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Performance Tests
    
    /// 测试批量创建文档的性能
    func testBatchCreationPerformance() async throws {
        // 创建测试数据
        let sampleCount = 100
        let documentsToCreate = try createSampleDocuments(count: sampleCount)
        
        // 测试批量创建性能
        measure {
            let expectation = XCTestExpectation(description: "Batch create documents")
            
            Task {
                do {
                    let created = try await repository.createDocuments(documentsToCreate)
                    XCTAssertEqual(created.count, sampleCount, "应该创建指定数量的文档")
                    expectation.fulfill()
                } catch {
                    XCTFail("批量创建失败：\(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    /// 测试单个创建文档的性能（作为对照）
    func testIndividualCreationPerformance() async throws {
        // 创建测试数据
        let sampleCount = 100
        let documentsToCreate = try createSampleDocuments(count: sampleCount)
        
        // 测试单个创建性能
        measure {
            let expectation = XCTestExpectation(description: "Create documents individually")
            
            Task {
                do {
                    for document in documentsToCreate {
                        _ = try await repository.createDocument(document)
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("单个创建失败：\(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    /// 测试缓存查询性能
    func testCachedQueryPerformance() async throws {
        // 创建测试数据并预热缓存
        let sampleCount = 100
        let documentsToCreate = try createSampleDocuments(count: sampleCount)
        let createdDocuments = try await repository.createDocuments(documentsToCreate)
        
        // 提取ID以供测试
        let documentIds = createdDocuments.map { $0.id }
        
        // 测试缓存查询性能
        measure {
            let expectation = XCTestExpectation(description: "Query documents with cache")
            
            Task {
                do {
                    // 第一次查询（预热缓存）
                    for id in documentIds {
                        _ = try await repository.getDocument(id: id)
                    }
                    
                    // 第二次查询（应该使用缓存）
                    for id in documentIds {
                        _ = try await repository.getDocument(id: id)
                    }
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("缓存查询失败：\(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    /// 测试缓存搜索性能
    func testCachedSearchPerformance() async throws {
        // 创建测试数据并预热缓存
        let sampleCount = 100
        var documentsToCreate = try createSampleDocuments(count: sampleCount)
        
        // 添加标签以便测试标签搜索
        for i in 0..<documentsToCreate.count {
            let tags = ["performance", "test", "tag\(i % 5)"]
            documentsToCreate[i].tags = tags
        }
        
        _ = try await repository.createDocuments(documentsToCreate)
        
        // 测试缓存搜索性能
        measure {
            let expectation = XCTestExpectation(description: "Search documents with cache")
            
            Task {
                do {
                    // 搜索标签（第一次，预热缓存）
                    let query1 = DocumentSearchQuery(text: "#performance", sortBy: .updatedAt)
                    let results1 = try await repository.searchDocuments(query: query1)
                    XCTAssertGreaterThan(results1.count, 0, "应该找到包含标签的文档")
                    
                    // 再次搜索标签（应该使用缓存）
                    let query2 = DocumentSearchQuery(text: "#performance", sortBy: .updatedAt)
                    let results2 = try await repository.searchDocuments(query: query2)
                    XCTAssertEqual(results1.count, results2.count, "两次搜索结果应该一致")
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("缓存搜索失败：\(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    /// 测试批量更新性能
    func testBatchUpdatePerformance() async throws {
        // 创建测试数据
        let sampleCount = 100
        let documentsToCreate = try createSampleDocuments(count: sampleCount)
        let createdDocuments = try await repository.createDocuments(documentsToCreate)
        
        // 修改测试数据
        var updatedDocuments = createdDocuments
        for i in 0..<updatedDocuments.count {
            updatedDocuments[i].title = "Updated \(i)"
            updatedDocuments[i].content = "Updated content \(i)"
        }
        
        // 测试批量更新性能
        measure {
            let expectation = XCTestExpectation(description: "Batch update documents")
            
            Task {
                do {
                    let updated = try await repository.updateDocuments(updatedDocuments)
                    XCTAssertEqual(updated.count, sampleCount, "应该更新指定数量的文档")
                    expectation.fulfill()
                } catch {
                    XCTFail("批量更新失败：\(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    /// 测试批量删除性能
    func testBatchDeletePerformance() async throws {
        // 创建测试数据
        let sampleCount = 100
        let documentsToCreate = try createSampleDocuments(count: sampleCount)
        let createdDocuments = try await repository.createDocuments(documentsToCreate)
        
        // 提取ID以供删除
        let documentIds = createdDocuments.map { $0.id }
        
        // 测试批量删除性能
        measure {
            let expectation = XCTestExpectation(description: "Batch delete documents")
            
            Task {
                do {
                    try await repository.deleteDocuments(ids: documentIds)
                    
                    // 验证是否删除成功
                    let allDocs = try await repository.getAllDocuments()
                    XCTAssertEqual(allDocs.count, 0, "所有文档应该已被删除")
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("批量删除失败：\(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Helper Methods
    
    /// 创建用于测试的内存存储容器
    private func setupInMemoryPersistentContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "OnlySlide")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("无法加载测试内存存储: \(error)")
            }
        }
        
        return container
    }
    
    /// 创建指定数量的测试文档
    private func createSampleDocuments(count: Int) throws -> [Document] {
        var documents: [Document] = []
        
        for i in 0..<count {
            let document = Document(
                id: UUID(),
                title: "Test Document \(i)",
                content: "This is the content of test document \(i)",
                createdAt: Date(),
                updatedAt: Date(),
                metadata: "test metadata",
                status: .draft,
                sourceURL: URL(string: "https://example.com/doc\(i)"),
                type: .presentation,
                tags: ["test", "performance"],
                user: nil,
                slides: []
            )
            documents.append(document)
        }
        
        return documents
    }
} 