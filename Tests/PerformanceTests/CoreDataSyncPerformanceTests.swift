import XCTest
import CoreDataModule

class CoreDataSyncPerformanceTests: XCTestCase {
    
    // 测试同步操作的性能
    func testSyncPerformance() async throws {
        measure {
            // 设置测试环境
            let expectation = self.expectation(description: "Sync performance")
            
            Task {
                do {
                    // 执行同步操作
                    await CoreDataSyncManager.shared.startSync()
                    expectation.fulfill()
                }
            }
            
            // 等待异步操作完成，最长等待10秒
            self.wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // 测试批量处理更改的性能
    func testBatchProcessingPerformance() async throws {
        // 创建模拟数据
        let context = CoreDataStack.shared.newBackgroundContext()
        var changeObjects: [NSManagedObject] = []
        
        // 在上下文中添加测试数据
        try await context.performAndWait {
            for i in 0..<100 {
                let entity = NSEntityDescription.entity(forEntityName: "SyncLog", in: context)!
                let changeObject = NSManagedObject(entity: entity, insertInto: context)
                changeObject.setValue("insert", forKey: "type")
                changeObject.setValue(false, forKey: "synced")
                changeObject.setValue(Date(), forKey: "createdAt")
                changeObjects.append(changeObject)
            }
            try context.save()
        }
        
        // 测试处理批量更改的性能
        measure {
            let expectation = self.expectation(description: "Batch processing performance")
            
            Task {
                do {
                    // 访问私有方法进行性能测试（仅用于测试目的）
                    // 注意：实际应用中可能需要修改访问级别或使用反射
                    try await CoreDataSyncManager.shared.processBatchChanges(changeObjects, in: context)
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to process batch changes: \(error)")
                }
            }
            
            self.wait(for: [expectation], timeout: 15.0)
        }
        
        // 清理测试数据
        try await context.performAndWait {
            for object in changeObjects {
                context.delete(object)
            }
            try context.save()
        }
    }
    
    // 测试模型加载性能
    func testModelLoadingPerformance() {
        measure {
            let expectation = self.expectation(description: "Model loading performance")
            
            Task {
                do {
                    // 测试模型加载性能
                    let models = try await CoreDataResourceManager.shared.allModels()
                    XCTAssertNotNil(models)
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to load models: \(error)")
                }
            }
            
            self.wait(for: [expectation], timeout: 5.0)
        }
    }
} 