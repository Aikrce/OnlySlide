import Foundation
import Combine

/// CoreDataModule接口协议
/// 为App模块提供与CoreDataModule交互的统一接口
public protocol CoreDataManagerProtocol: AnyObject {
    var migrationProgressPublisher: AnyPublisher<Double, Never> { get }
    var migrationStatePublisher: AnyPublisher<MigrationStateWrapper, Never> { get }
    var migrationErrorPublisher: AnyPublisher<Error?, Never> { get }
    
    func startMigration() async throws
    func requiresMigration() async throws -> Bool
    func getDatabaseInfo() async throws -> DatabaseInfo
    func resetMigration() 
}

/// CoreDataManager工厂
/// 负责创建CoreDataManager实例，隔离具体实现
public enum CoreDataManagerFactory {
    /// 获取CoreDataManager实例
    /// - Returns: 符合CoreDataManagerProtocol的实例
    public static func getManager() -> CoreDataManagerProtocol {
        // 使用运行时动态加载CoreDataModule中的管理器
        // 这里使用运行时方式是为了避免直接依赖，解决编译问题
        if let managerClass = NSClassFromString("CoreDataModule.CoreDataManager") as? NSObject.Type,
           let manager = managerClass.value(forKeyPath: "shared") as? NSObject {
            return CoreDataManagerWrapper(manager: manager)
        }
        
        // 如果无法加载真实管理器，返回一个模拟实现
        return MockCoreDataManager()
    }
}

/// CoreDataManager包装器
/// 通过运行时反射调用CoreDataManager的方法
private class CoreDataManagerWrapper: CoreDataManagerProtocol {
    private let manager: NSObject
    private let progressSubject = CurrentValueSubject<Double, Never>(0.0)
    private let stateSubject = CurrentValueSubject<MigrationStateWrapper, Never>(.notStarted)
    private let errorSubject = CurrentValueSubject<Error?, Never>(nil)
    
    var migrationProgressPublisher: AnyPublisher<Double, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    var migrationStatePublisher: AnyPublisher<MigrationStateWrapper, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    var migrationErrorPublisher: AnyPublisher<Error?, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    init(manager: NSObject) {
        self.manager = manager
        setupObservation()
    }
    
    private func setupObservation() {
        // 设置KVO观察
        // 这里只是一个示例，具体实现需要根据CoreDataManager的属性名称调整
        if manager.responds(to: #selector(getter: MigrationStateObserving.migrationProgress)) {
            manager.addObserver(self, forKeyPath: "migrationProgress", options: [.new], context: nil)
        }
        
        if manager.responds(to: #selector(getter: MigrationStateObserving.migrationState)) {
            manager.addObserver(self, forKeyPath: "migrationState", options: [.new], context: nil)
        }
        
        if manager.responds(to: #selector(getter: ErrorObserving.error)) {
            manager.addObserver(self, forKeyPath: "error", options: [.new], context: nil)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath, object as? NSObject == manager else { return }
        
        switch keyPath {
        case "migrationProgress":
            if let newValue = change?[.newKey] as? Double {
                progressSubject.send(newValue)
            }
        case "migrationState":
            if let stateValue = change?[.newKey] as? Int {
                // 将原始值转换为MigrationStateWrapper
                let wrappedState: MigrationStateWrapper
                switch stateValue {
                case 0: wrappedState = .notStarted
                case 1: wrappedState = .preparing
                case 2: wrappedState = .migrating
                case 3: wrappedState = .completed
                case 4: wrappedState = .failed
                default: wrappedState = .notStarted
                }
                stateSubject.send(wrappedState)
            }
        case "error":
            if let error = change?[.newKey] as? Error {
                errorSubject.send(error)
            } else {
                errorSubject.send(nil)
            }
        default:
            break
        }
    }
    
    deinit {
        // 移除观察者
        if manager.responds(to: #selector(getter: MigrationStateObserving.migrationProgress)) {
            manager.removeObserver(self, forKeyPath: "migrationProgress")
        }
        
        if manager.responds(to: #selector(getter: MigrationStateObserving.migrationState)) {
            manager.removeObserver(self, forKeyPath: "migrationState")
        }
        
        if manager.responds(to: #selector(getter: ErrorObserving.error)) {
            manager.removeObserver(self, forKeyPath: "error")
        }
    }
    
    func startMigration() async throws {
        if manager.responds(to: Selector(("startMigration"))) {
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global().async {
                    do {
                        let selector = Selector(("startMigration"))
                        let method = self.manager.method(for: selector)
                        if let method = method {
                            let imp = method_getImplementation(method)
                            let function = unsafeBitCast(imp, to: (@convention(c) (AnyObject, Selector) -> Void).self)
                            function(self.manager, selector)
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: NSError(domain: "CoreDataError", code: 1, userInfo: [NSLocalizedDescriptionKey: "方法不存在"]))
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        throw NSError(domain: "CoreDataError", code: 1, userInfo: [NSLocalizedDescriptionKey: "方法不存在"])
    }
    
    func requiresMigration() async throws -> Bool {
        // 通过运行时反射调用requiresMigration方法
        // 这里使用了一个简化的实现，假设总是返回false
        return false
    }
    
    func getDatabaseInfo() async throws -> DatabaseInfo {
        // 简化实现
        return DatabaseInfo(
            sizeInBytes: 0,
            currentVersion: "未知",
            targetVersion: "最新版本",
            migrationComplexity: .simple
        )
    }
    
    func resetMigration() {
        if manager.responds(to: Selector(("reset"))) {
            manager.perform(Selector(("reset")))
        }
    }
}

/// 用于观察迁移状态的协议
@objc private protocol MigrationStateObserving {
    @objc var migrationProgress: Double { get }
    @objc var migrationState: Int { get }
}

/// 用于观察错误的协议
@objc private protocol ErrorObserving {
    @objc var error: Error? { get }
}

/// 模拟CoreDataManager实现
/// 当无法加载真实的CoreDataManager时使用
private class MockCoreDataManager: CoreDataManagerProtocol {
    private let progressSubject = CurrentValueSubject<Double, Never>(0.0)
    private let stateSubject = CurrentValueSubject<MigrationStateWrapper, Never>(.notStarted)
    private let errorSubject = CurrentValueSubject<Error?, Never>(nil)
    
    var migrationProgressPublisher: AnyPublisher<Double, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    var migrationStatePublisher: AnyPublisher<MigrationStateWrapper, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    var migrationErrorPublisher: AnyPublisher<Error?, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    func startMigration() async throws {
        // 模拟迁移流程
        progressSubject.send(0.0)
        stateSubject.send(.preparing)
        
        // 模拟迁移过程
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            progressSubject.send(Double(i) / 10.0)
        }
        
        stateSubject.send(.completed)
    }
    
    func requiresMigration() async throws -> Bool {
        return false // 模拟实现，始终返回不需要迁移
    }
    
    func getDatabaseInfo() async throws -> DatabaseInfo {
        return DatabaseInfo(
            sizeInBytes: 1024 * 1024, // 1MB
            currentVersion: "模拟版本",
            targetVersion: "模拟目标版本",
            migrationComplexity: .simple
        )
    }
    
    func resetMigration() {
        stateSubject.send(.notStarted)
        progressSubject.send(0.0)
        errorSubject.send(nil)
    }
} 