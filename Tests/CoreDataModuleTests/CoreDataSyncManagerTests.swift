import XCTest
@testable import CoreDataModule

final class CoreDataSyncManagerTests: XCTestCase {
    
    var syncManager: CoreDataSyncManager!
    
    override func setUp() async throws {
        try await super.setUp()
        // 初始化测试环境
        syncManager = CoreDataSyncManager.shared
    }
    
    override func tearDown() async throws {
        // 清理测试环境
        await syncManager.stopSync()
        try await super.tearDown()
    }
    
    func testStateChanges() async throws {
        // 测试同步状态变化
        let expectation = XCTestExpectation(description: "State changes")
        
        // 订阅状态变化
        let publisher = await syncManager.syncState
        var receivedStates: [CoreDataSyncState] = []
        
        let cancellable = publisher.sink { state in
            receivedStates.append(state)
            if receivedStates.count >= 2 { // 至少捕获空闲和同步中两种状态
                expectation.fulfill()
            }
        }
        
        // 触发同步
        await syncManager.startSync()
        
        // 等待状态变化
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // 验证状态变化
        XCTAssertTrue(receivedStates.contains(.idle), "应该包含空闲状态")
        XCTAssertTrue(receivedStates.contains(where: { 
            if case .syncing = $0 { return true }
            return false
        }), "应该包含同步中状态")
        
        cancellable.cancel()
    }
    
    func testStopSync() async throws {
        // 启动同步
        await syncManager.startSync()
        
        // 停止同步
        await syncManager.stopSync()
        
        // 验证同步已停止
        let statePublisher = await syncManager.syncState
        var currentState: CoreDataSyncState?
        
        let expectation = XCTestExpectation(description: "Get current state")
        let cancellable = statePublisher.sink { state in
            currentState = state
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        XCTAssertEqual(currentState, .idle, "停止后状态应该是空闲")
        cancellable.cancel()
    }
    
    func testSyncErrorHandling() async throws {
        // 模拟同步错误
        // 注意：这需要一种方法来触发同步错误
        // 在实际实现中可能需要模拟网络错误或其他失败情况
        
        // 等待同步完成
        let expectation = XCTestExpectation(description: "Sync error handling")
        
        var receivedError: Error?
        let publisher = await syncManager.syncState
        let cancellable = publisher.sink { state in
            if case .error(let error) = state {
                receivedError = error
                expectation.fulfill()
            }
        }
        
        // 在这里触发同步错误（需要实现方法来模拟错误）
        // 例如：injectTestError()
        
        // 等待错误状态
        await fulfillment(of: [expectation], timeout: 5.0, enforceOrder: true)
        
        // 验证错误处理
        XCTAssertNotNil(receivedError, "应该接收到同步错误")
        
        cancellable.cancel()
    }
}

// MARK: - 测试助手

extension CoreDataSyncManagerTests {
    // 这里可以添加测试所需的辅助方法
} 