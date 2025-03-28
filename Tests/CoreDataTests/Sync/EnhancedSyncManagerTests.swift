import XCTest
import Combine
@testable import CoreDataModule

class EnhancedSyncManagerTests: XCTestCase {
    
    // MARK: - 测试对象
    
    private var syncManager: EnhancedSyncManager!
    private var mockSyncService: MockSyncService!
    private var mockStoreAccess: MockStoreAccess!
    private var mockProgressReporter: MockProgressReporter!
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - 测试生命周期
    
    override func setUp() {
        super.setUp()
        mockSyncService = MockSyncService()
        mockStoreAccess = MockStoreAccess()
        mockProgressReporter = MockProgressReporter()
        
        syncManager = EnhancedSyncManager(
            syncService: mockSyncService,
            storeAccess: mockStoreAccess,
            progressReporter: mockProgressReporter
        )
    }
    
    override func tearDown() {
        syncManager = nil
        mockSyncService = nil
        mockStoreAccess = nil
        mockProgressReporter = nil
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - 测试同步功能
    
    func testInitialization() {
        XCTAssertNotNil(syncManager)
    }
    
    func testDownloadSync() async throws {
        let expectation = XCTestExpectation(description: "下载同步完成")
        
        // 设置测试数据
        let testData: [String: Any] = ["key": "value"]
        mockSyncService.fetchResult = testData
        
        // 订阅状态更新
        syncManager.statePublisher
            .dropFirst() // 跳过初始的 .idle 状态
            .sink { state in
                if case .completed = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 执行下载同步
        let options = SyncOptions(direction: .download)
        let result = try await syncManager.sync(with: options)
        
        XCTAssertTrue(result)
        XCTAssertTrue(mockSyncService.fetchCalled)
        XCTAssertFalse(mockSyncService.uploadCalled)
        XCTAssertTrue(mockStoreAccess.writeCalled)
        XCTAssertEqual(mockStoreAccess.lastWrittenData as? [String: String], testData as? [String: String])
        
        // 确保状态更新为 completed
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testUploadSync() async throws {
        let expectation = XCTestExpectation(description: "上传同步完成")
        
        // 设置测试数据
        let testData: [String: Any] = ["localKey": "localValue"]
        mockStoreAccess.readResult = testData
        mockSyncService.uploadResult = true
        
        // 订阅状态更新
        syncManager.statePublisher
            .dropFirst() // 跳过初始的 .idle 状态
            .sink { state in
                if case .completed = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 执行上传同步
        let options = SyncOptions(direction: .upload)
        let result = try await syncManager.sync(with: options)
        
        XCTAssertTrue(result)
        XCTAssertFalse(mockSyncService.fetchCalled)
        XCTAssertTrue(mockSyncService.uploadCalled)
        XCTAssertTrue(mockStoreAccess.readCalled)
        XCTAssertEqual(mockSyncService.lastUploadedData as? [String: String], testData as? [String: String])
        
        // 确保状态更新为 completed
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testBidirectionalSync() async throws {
        let expectation = XCTestExpectation(description: "双向同步完成")
        
        // 设置测试数据
        let localData: [String: Any] = ["localKey": "localValue"]
        let remoteData: [String: Any] = ["remoteKey": "remoteValue"]
        let mergedData: [String: Any] = ["mergedKey": "mergedValue"]
        
        mockStoreAccess.readResult = localData
        mockSyncService.fetchResult = remoteData
        mockSyncService.resolveResult = mergedData
        mockStoreAccess.hasChangesResult = true
        
        // 订阅状态更新
        syncManager.statePublisher
            .dropFirst() // 跳过初始的 .idle 状态
            .sink { state in
                if case .completed = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 执行双向同步
        let options = SyncOptions(direction: .bidirectional, autoMergeStrategy: .mergeFields)
        let result = try await syncManager.sync(with: options)
        
        XCTAssertTrue(result)
        XCTAssertTrue(mockSyncService.fetchCalled)
        XCTAssertTrue(mockSyncService.uploadCalled)
        XCTAssertTrue(mockSyncService.resolveCalled)
        XCTAssertTrue(mockStoreAccess.readCalled)
        XCTAssertTrue(mockStoreAccess.writeCalled)
        XCTAssertEqual(mockSyncService.lastResolveLocalData as? [String: String], localData as? [String: String])
        XCTAssertEqual(mockSyncService.lastResolveRemoteData as? [String: String], remoteData as? [String: String])
        XCTAssertEqual(mockSyncService.lastResolveStrategy, .mergeFields)
        
        // 确保状态更新为 completed
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testBidirectionalSyncWithNoChanges() async throws {
        // 设置测试数据
        let localData: [String: Any] = ["key": "value"]
        let remoteData: [String: Any] = ["key": "value"]
        
        mockStoreAccess.readResult = localData
        mockSyncService.fetchResult = remoteData
        mockStoreAccess.hasChangesResult = false // 数据没有变化
        
        // 执行双向同步
        let options = SyncOptions(direction: .bidirectional)
        let result = try await syncManager.sync(with: options)
        
        XCTAssertTrue(result)
        XCTAssertTrue(mockSyncService.fetchCalled)
        XCTAssertTrue(mockStoreAccess.readCalled)
        XCTAssertFalse(mockSyncService.resolveCalled) // 不应该调用解决冲突
        XCTAssertFalse(mockStoreAccess.writeCalled) // 不应该写入数据
        XCTAssertFalse(mockSyncService.uploadCalled) // 不应该上传数据
    }
    
    func testMultipleSyncCalls() async throws {
        // 设置第一次同步的任务
        let firstSyncTask = Task {
            return try await syncManager.sync()
        }
        
        // 立即尝试启动第二次同步
        let secondSyncTask = Task {
            return try await syncManager.sync()
        }
        
        // 等待两个任务完成
        let firstResult = try await firstSyncTask.value
        let secondResult = try await secondSyncTask.value
        
        // 第一次同步应成功，第二次应失败（因为第一次正在进行）
        XCTAssertTrue(firstResult)
        XCTAssertFalse(secondResult)
    }
    
    func testSyncFailureHandling() async {
        let expectation = XCTestExpectation(description: "同步失败处理")
        
        // 设置测试错误
        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "测试错误"])
        mockSyncService.shouldThrowError = true
        mockSyncService.errorToThrow = testError
        
        // 订阅状态更新
        syncManager.statePublisher
            .dropFirst() // 跳过初始的 .idle 状态
            .sink { state in
                if case .failed(let error) = state {
                    let nsError = error as NSError
                    XCTAssertEqual(nsError.domain, testError.domain)
                    XCTAssertEqual(nsError.code, testError.code)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 执行同步并期望失败
        do {
            _ = try await syncManager.sync()
            XCTFail("同步应该失败")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, testError.domain)
            XCTAssertEqual(nsError.code, testError.code)
        }
        
        // 确保状态更新为 failed
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testProgressReporting() async throws {
        let progressExpectation = XCTestExpectation(description: "进度更新")
        progressExpectation.expectedFulfillmentCount = 3 // 期望至少3次进度更新
        
        var progressValues: [Double] = []
        
        // 订阅进度更新
        syncManager.progressPublisher
            .dropFirst() // 跳过初始的 0.0 进度
            .sink { progress in
                progressValues.append(progress)
                progressExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // 执行同步
        let result = try await syncManager.sync()
        
        XCTAssertTrue(result)
        
        // 等待进度更新
        await fulfillment(of: [progressExpectation], timeout: 1.0)
        
        // 验证进度值
        XCTAssertFalse(progressValues.isEmpty)
        
        // 检查进度是递增的
        var lastProgress = 0.0
        for progress in progressValues {
            XCTAssertGreaterThanOrEqual(progress, lastProgress)
            lastProgress = progress
        }
        
        // 最终进度应为1.0
        XCTAssertEqual(progressValues.last, 1.0)
    }
    
    func testStateReporting() async throws {
        let stateExpectation = XCTestExpectation(description: "状态更新")
        stateExpectation.expectedFulfillmentCount = 3 // 期望至少3次状态更新
        
        var states: [SyncState] = []
        
        // 订阅状态更新
        syncManager.statePublisher
            .dropFirst() // 跳过初始的 .idle 状态
            .sink { state in
                states.append(state)
                stateExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // 执行同步
        let result = try await syncManager.sync()
        
        XCTAssertTrue(result)
        
        // 等待状态更新
        await fulfillment(of: [stateExpectation], timeout: 1.0)
        
        // 验证状态转换
        XCTAssertFalse(states.isEmpty)
        XCTAssertEqual(states.first, .preparing)
        
        // 状态应该最终为 .completed
        XCTAssertEqual(states.last, .completed)
    }
    
    func testLastSyncTimeTracking() async throws {
        XCTAssertNil(syncManager.lastSyncTime())
        
        // 执行同步
        let result = try await syncManager.sync()
        
        XCTAssertTrue(result)
        
        // 验证最后同步时间已设置
        XCTAssertNotNil(syncManager.lastSyncTime())
        
        // 最后同步时间应该是最近的
        if let lastSyncTime = syncManager.lastSyncTime() {
            let now = Date()
            let timeDifference = now.timeIntervalSince(lastSyncTime)
            XCTAssertLessThan(timeDifference, 5.0) // 时间差应小于5秒
        }
    }
}

// MARK: - 模拟对象

class MockSyncService: SyncServiceProtocol {
    var fetchCalled = false
    var uploadCalled = false
    var resolveCalled = false
    
    var fetchResult: [String: Any] = [:]
    var uploadResult = false
    var resolveResult: [String: Any] = [:]
    
    var lastUploadedData: [String: Any] = [:]
    var lastResolveLocalData: [String: Any] = [:]
    var lastResolveRemoteData: [String: Any] = [:]
    var lastResolveStrategy: AutoMergeStrategy = .serverWins
    
    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "MockSyncService", code: 1, userInfo: nil)
    
    func fetchDataFromServer() async throws -> [String: Any] {
        fetchCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return fetchResult
    }
    
    func uploadDataToServer(_ data: [String: Any]) async throws -> Bool {
        uploadCalled = true
        lastUploadedData = data
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return uploadResult
    }
    
    func resolveConflicts(local: [String: Any], remote: [String: Any], strategy: AutoMergeStrategy) async throws -> [String: Any] {
        resolveCalled = true
        lastResolveLocalData = local
        lastResolveRemoteData = remote
        lastResolveStrategy = strategy
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return resolveResult
    }
}

class MockStoreAccess: StoreAccessProtocol {
    var readCalled = false
    var writeCalled = false
    var hasChangesCalled = false
    
    var readResult: [String: Any] = [:]
    var writeResult = true
    var hasChangesResult = true
    
    var lastWrittenData: [String: Any] = [:]
    
    func readDataFromStore() async throws -> [String: Any] {
        readCalled = true
        return readResult
    }
    
    func writeDataToStore(_ data: [String: Any]) async throws -> Bool {
        writeCalled = true
        lastWrittenData = data
        return writeResult
    }
    
    func hasChanges(_ newData: [String: Any], comparedTo oldData: [String: Any]) -> Bool {
        hasChangesCalled = true
        return hasChangesResult
    }
}

class MockProgressReporter: SyncProgressReporterProtocol {
    var reportedStates: [SyncState] = []
    var reportedProgresses: [Double] = []
    var currentStateValue: SyncState = .idle
    var currentProgressValue: Double = 0.0
    
    func reportState(_ state: SyncState) {
        reportedStates.append(state)
        currentStateValue = state
    }
    
    func reportProgress(_ progress: Double) {
        reportedProgresses.append(progress)
        currentProgressValue = progress
    }
    
    func currentState() -> SyncState {
        return currentStateValue
    }
    
    func currentProgress() -> Double {
        return currentProgressValue
    }
} 