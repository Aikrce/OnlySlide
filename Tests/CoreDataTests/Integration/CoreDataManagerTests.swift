import XCTest
import CoreData
import Combine
@testable import CoreDataModule

class CoreDataManagerTests: XCTestCase {
    // MARK: - Properties
    
    private var manager: CoreDataManager!
    private var testContext: NSManagedObjectContext!
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // 获取CoreDataManager实例
        manager = CoreDataManager.shared
        
        // 创建内存测试上下文，避免影响实际数据库
        testContext = createInMemoryTestContext()
    }
    
    override func tearDown() {
        // 清理测试上下文中的所有对象
        clearAllObjects()
        
        cancellables.removeAll()
        testContext = nil
        
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    func testContextCreation() {
        // 测试主上下文获取
        let mainContext = manager.mainContext
        XCTAssertNotNil(mainContext)
        
        // 测试后台上下文创建
        let backgroundContext = manager.newBackgroundContext()
        XCTAssertNotNil(backgroundContext)
        XCTAssertNotEqual(mainContext, backgroundContext)
    }
    
    func testSaveContext() {
        // 准备测试数据
        let context = testContext
        
        // 创建测试对象
        let testEntity = NSEntityDescription.insertNewObject(
            forEntityName: "TestEntity",
            into: context
        )
        testEntity.setValue("testID", forKey: "id")
        testEntity.setValue("测试名称", forKey: "name")
        
        // 测试保存
        XCTAssertNoThrow(try manager.saveContext(context))
        
        // 验证保存是否成功
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TestEntity")
        fetchRequest.predicate = NSPredicate(format: "id = %@", "testID")
        
        do {
            let results = try context.fetch(fetchRequest)
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual(results.first?.value(forKey: "name") as? String, "测试名称")
        } catch {
            XCTFail("获取保存的对象失败: \(error)")
        }
    }
    
    func testAsyncSaveContext() {
        // 准备测试数据
        let context = testContext
        
        // 创建测试对象
        let testEntity = NSEntityDescription.insertNewObject(
            forEntityName: "TestEntity",
            into: context
        )
        testEntity.setValue("asyncID", forKey: "id")
        testEntity.setValue("异步测试", forKey: "name")
        
        // 创建期望
        let expectation = self.expectation(description: "Async save completed")
        
        // 异步保存
        manager.saveContextAsync(context) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // 验证保存是否成功
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TestEntity")
        fetchRequest.predicate = NSPredicate(format: "id = %@", "asyncID")
        
        do {
            let results = try context.fetch(fetchRequest)
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual(results.first?.value(forKey: "name") as? String, "异步测试")
        } catch {
            XCTFail("获取保存的对象失败: \(error)")
        }
    }
    
    func testFetchOperation() {
        // 准备测试数据
        let context = testContext
        
        // 创建多个测试对象
        for i in 1...5 {
            let testEntity = NSEntityDescription.insertNewObject(
                forEntityName: "TestEntity",
                into: context
            )
            testEntity.setValue("fetch\(i)", forKey: "id")
            testEntity.setValue("获取测试\(i)", forKey: "name")
        }
        
        // 保存对象
        try? manager.saveContext(context)
        
        // 测试获取操作
        do {
            let results: [NSManagedObject] = try manager.fetch(
                entityName: "TestEntity",
                predicate: NSPredicate(format: "id BEGINSWITH %@", "fetch"),
                sortDescriptors: [NSSortDescriptor(key: "id", ascending: true)],
                context: context
            )
            
            // 验证结果
            XCTAssertEqual(results.count, 5)
            for i in 0..<5 {
                XCTAssertEqual(results[i].value(forKey: "id") as? String, "fetch\(i+1)")
            }
        } catch {
            XCTFail("获取操作失败: \(error)")
        }
    }
    
    func testAsyncFetchOperation() {
        // 准备测试数据
        let context = testContext
        
        // 创建多个测试对象
        for i in 1...3 {
            let testEntity = NSEntityDescription.insertNewObject(
                forEntityName: "TestEntity",
                into: context
            )
            testEntity.setValue("asyncFetch\(i)", forKey: "id")
            testEntity.setValue("异步获取测试\(i)", forKey: "name")
        }
        
        // 保存对象
        try? manager.saveContext(context)
        
        // 创建期望
        let expectation = self.expectation(description: "Async fetch completed")
        
        // 测试异步获取
        manager.fetchAsync(
            entityName: "TestEntity",
            predicate: NSPredicate(format: "id BEGINSWITH %@", "asyncFetch"),
            sortDescriptors: [NSSortDescriptor(key: "id", ascending: true)],
            context: context
        ) { (result: Result<[NSManagedObject], Error>) in
            switch result {
            case .success(let results):
                // 验证结果
                XCTAssertEqual(results.count, 3)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("异步获取失败: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDeleteOperation() {
        // 准备测试数据
        let context = testContext
        
        // 创建测试对象
        let testEntity = NSEntityDescription.insertNewObject(
            forEntityName: "TestEntity",
            into: context
        )
        testEntity.setValue("deleteID", forKey: "id")
        testEntity.setValue("删除测试", forKey: "name")
        
        // 保存对象
        try? manager.saveContext(context)
        
        // 测试删除
        do {
            try manager.delete(testEntity, context: context)
            
            // 验证对象是否被删除
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TestEntity")
            fetchRequest.predicate = NSPredicate(format: "id = %@", "deleteID")
            let results = try context.fetch(fetchRequest)
            
            XCTAssertEqual(results.count, 0)
        } catch {
            XCTFail("删除操作失败: \(error)")
        }
    }
    
    func testBatchDeleteOperation() {
        // 准备测试数据
        let context = testContext
        
        // 创建多个测试对象
        for i in 1...5 {
            let testEntity = NSEntityDescription.insertNewObject(
                forEntityName: "TestEntity",
                into: context
            )
            testEntity.setValue("batchDelete\(i)", forKey: "id")
            testEntity.setValue("批量删除测试\(i)", forKey: "name")
        }
        
        // 保存对象
        try? manager.saveContext(context)
        
        // 测试批量删除
        do {
            try manager.batchDelete(
                entityName: "TestEntity",
                predicate: NSPredicate(format: "id BEGINSWITH %@", "batchDelete"),
                context: context
            )
            
            // 验证对象是否被删除
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TestEntity")
            fetchRequest.predicate = NSPredicate(format: "id BEGINSWITH %@", "batchDelete")
            let results = try context.fetch(fetchRequest)
            
            XCTAssertEqual(results.count, 0)
        } catch {
            XCTFail("批量删除操作失败: \(error)")
        }
    }
    
    func testExistsOperation() {
        // 准备测试数据
        let context = testContext
        
        // 创建测试对象
        let testEntity = NSEntityDescription.insertNewObject(
            forEntityName: "TestEntity",
            into: context
        )
        testEntity.setValue("existsID", forKey: "id")
        testEntity.setValue("存在测试", forKey: "name")
        
        // 保存对象
        try? manager.saveContext(context)
        
        // 测试exists操作
        do {
            // 测试存在的对象
            let exists = try manager.exists(
                entityName: "TestEntity",
                predicate: NSPredicate(format: "id = %@", "existsID"),
                context: context
            )
            XCTAssertTrue(exists)
            
            // 测试不存在的对象
            let notExists = try manager.exists(
                entityName: "TestEntity",
                predicate: NSPredicate(format: "id = %@", "nonExistentID"),
                context: context
            )
            XCTAssertFalse(notExists)
        } catch {
            XCTFail("存在性检查失败: \(error)")
        }
    }
    
    func testCountOperation() {
        // 准备测试数据
        let context = testContext
        
        // 创建多个测试对象
        for i in 1...7 {
            let testEntity = NSEntityDescription.insertNewObject(
                forEntityName: "TestEntity",
                into: context
            )
            testEntity.setValue("count\(i)", forKey: "id")
            testEntity.setValue("计数测试\(i)", forKey: "name")
        }
        
        // 保存对象
        try? manager.saveContext(context)
        
        // 测试count操作
        do {
            // 测试全部计数
            let totalCount = try manager.count(
                entityName: "TestEntity",
                context: context
            )
            
            // 测试条件计数
            let filteredCount = try manager.count(
                entityName: "TestEntity",
                predicate: NSPredicate(format: "id BEGINSWITH %@", "count"),
                context: context
            )
            
            // 验证计数结果
            XCTAssertEqual(filteredCount, 7)
            
            // 注意：totalCount可能包含之前测试创建的其他对象
            XCTAssertGreaterThanOrEqual(totalCount, filteredCount)
        } catch {
            XCTFail("计数操作失败: \(error)")
        }
    }
    
    func testErrorHandlingAndErrorPublisher() {
        // 创建期望
        let errorPublishedExpectation = expectation(description: "Error published")
        
        // 订阅错误通知
        manager.errorPublisher
            .sink { error, context in
                // 验证接收到的错误
                XCTAssertEqual(context, "测试错误处理")
                errorPublishedExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // 创建测试错误
        let testError = NSError(domain: "测试域", code: 123, userInfo: [NSLocalizedDescriptionKey: "测试错误"])
        
        // 测试错误处理
        manager.handleError(testError, context: "测试错误处理")
        
        // 等待错误发布
        wait(for: [errorPublishedExpectation], timeout: 1.0)
    }
    
    func testSafeFetchOperation() async {
        // 准备测试数据
        let context = testContext
        
        // 创建测试对象
        let testEntity = NSEntityDescription.insertNewObject(
            forEntityName: "TestEntity",
            into: context
        )
        testEntity.setValue("safeFetch", forKey: "id")
        testEntity.setValue("安全获取测试", forKey: "name")
        
        // 保存对象
        try? manager.saveContext(context)
        
        // 创建安全获取请求
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TestEntity")
        fetchRequest.predicate = NSPredicate(format: "id = %@", "safeFetch")
        
        // 测试安全获取
        do {
            let results = try await manager.safeFetch(fetchRequest, in: context)
            
            // 验证结果
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual(results.first?.value(forKey: "name") as? String, "安全获取测试")
        } catch {
            XCTFail("安全获取操作失败: \(error)")
        }
    }
    
    func testSafeSaveOperation() async {
        // 准备测试数据
        let context = testContext
        
        // 创建测试对象
        let testEntity = NSEntityDescription.insertNewObject(
            forEntityName: "TestEntity",
            into: context
        )
        testEntity.setValue("safeSave", forKey: "id")
        testEntity.setValue("安全保存测试", forKey: "name")
        
        // 测试安全保存
        do {
            try await manager.safeSave(context: context)
            
            // 验证保存结果
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TestEntity")
            fetchRequest.predicate = NSPredicate(format: "id = %@", "safeSave")
            let results = try context.fetch(fetchRequest)
            
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual(results.first?.value(forKey: "name") as? String, "安全保存测试")
        } catch {
            XCTFail("安全保存操作失败: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createInMemoryTestContext() -> NSManagedObjectContext {
        // 创建测试模型
        let model = createTestModel()
        
        // 创建持久化存储协调器，使用内存存储
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try? coordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil,
            options: nil
        )
        
        // 创建测试上下文
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }
    
    private func createTestModel() -> NSManagedObjectModel {
        // 创建测试模型
        let model = NSManagedObjectModel()
        
        // 创建测试实体
        let entity = NSEntityDescription()
        entity.name = "TestEntity"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        
        // 创建属性
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .stringAttributeType
        idAttribute.isOptional = false
        
        let nameAttribute = NSAttributeDescription()
        nameAttribute.name = "name"
        nameAttribute.attributeType = .stringAttributeType
        nameAttribute.isOptional = true
        
        // 设置实体属性
        entity.properties = [idAttribute, nameAttribute]
        
        // 添加实体到模型
        model.entities = [entity]
        
        return model
    }
    
    private func clearAllObjects() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TestEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        try? testContext.execute(deleteRequest)
        try? testContext.save()
    }
} 