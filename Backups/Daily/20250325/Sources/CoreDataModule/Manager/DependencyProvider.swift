import Foundation
import CoreData
import Combine

// MARK: - Provider Protocol

/// 依赖提供者协议
public protocol Provider {
    /// 获取特定类型的依赖
    func resolve<T>() -> T
    
    /// 获取可选类型的依赖
    func optional<T>() -> T?
    
    /// 注册依赖
    func register<T>(factory: @escaping () -> T)
    
    /// 注册共享实例的依赖
    func registerShared<T>(factory: @escaping () -> T)
    
    /// 注册特定类型的依赖
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    
    /// 注册特定类型的共享依赖
    func registerShared<T>(_ type: T.Type, factory: @escaping () -> T)
}

// MARK: - Factory Protocol

/// 工厂协议
public protocol Factory {
    /// 创建实例
    associatedtype Instance
    
    /// 创建实例的方法
    func create() -> Instance
}

// MARK: - Dependencies Registry

/// 依赖注册表
@MainActor
public final class DependencyRegistry: Provider {
    // MARK: - Dependency Container
    
    private class DependencyContainer {
        var factory: () -> Any
        var instance: Any?
        let isShared: Bool
        
        init(factory: @escaping () -> Any, isShared: Bool) {
            self.factory = factory
            self.isShared = isShared
        }
        
        func resolve() -> Any {
            if isShared {
                if let instance = instance {
                    return instance
                } else {
                    let newInstance = factory()
                    instance = newInstance
                    return newInstance
                }
            } else {
                return factory()
            }
        }
    }
    
    // MARK: - Properties
    
    /// 共享实例
    public static let shared = DependencyRegistry()
    
    /// 注册的依赖
    private var containers = [String: DependencyContainer]()
    
    // MARK: - Initialization
    
    /// 初始化依赖注册表
    public init() {
        registerDefaults()
    }
    
    // MARK: - Provider Implementation
    
    public func resolve<T>() -> T {
        let key = String(describing: T.self)
        
        guard let container = containers[key] else {
            fatalError("No registration for \(key)")
        }
        
        guard let result = container.resolve() as? T else {
            fatalError("Failed to resolve \(key)")
        }
        
        return result
    }
    
    public func optional<T>() -> T? {
        let key = String(describing: T.self)
        
        guard let container = containers[key] else {
            return nil
        }
        
        return container.resolve() as? T
    }
    
    public func register<T>(factory: @escaping () -> T) {
        let key = String(describing: T.self)
        containers[key] = DependencyContainer(factory: { factory() }, isShared: false)
    }
    
    public func registerShared<T>(factory: @escaping () -> T) {
        let key = String(describing: T.self)
        containers[key] = DependencyContainer(factory: { factory() }, isShared: true)
    }
    
    // 新增：注册特定类型的依赖
    public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        containers[key] = DependencyContainer(factory: { factory() }, isShared: false)
    }
    
    // 新增：注册特定类型的共享依赖
    public func registerShared<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        containers[key] = DependencyContainer(factory: { factory() }, isShared: true)
    }
    
    // MARK: - Register Factory
    
    /// 注册工厂
    public func register<F: Factory>(factory: F) {
        let key = String(describing: F.Instance.self)
        containers[key] = DependencyContainer(factory: { factory.create() }, isShared: false)
    }
    
    /// 注册共享工厂
    public func registerShared<F: Factory>(factory: F) {
        let key = String(describing: F.Instance.self)
        containers[key] = DependencyContainer(factory: { factory.create() }, isShared: true)
    }
    
    // MARK: - Default Registration
    
    private func registerDefaults() {
        // 注册核心组件
        registerShared { CoreDataManager.shared }
        registerShared { CoreDataStack.shared }
        registerShared { CoreDataResourceManager.shared }
        registerShared { CoreDataModelVersionManager.shared }
        registerShared { CoreDataMigrationManager.shared }
        registerShared { CoreDataErrorManager.shared }
        registerShared { CoreDataRecoveryExecutor.shared }
        
        // 注册优化版本的组件
        registerShared { EnhancedMigrationManager.createDefault() }
        registerShared { EnhancedErrorHandler.createDefault() }
        registerShared { EnhancedRecoveryService.createDefault() }
        registerShared { EnhancedModelVersionManager.createDefault() }
        
        // 注册协议实现
        registerShared(ModelVersionManaging.self) { EnhancedModelVersionManager.createDefault() }
        registerShared(ErrorHandlingService.self) { EnhancedErrorHandler.createDefault() }
        registerShared(RecoveryService.self) { EnhancedRecoveryService.createDefault() }
        
        // 注册错误处理系统
        registerShared(ErrorHandlerFactory.self) { ErrorHandlerFactory() }
        registerShared(EnhancedErrorHandler.self) { resolve(ErrorHandlerFactory.self).createErrorHandler() }
        registerShared(EnhancedRecoveryService.self) { resolve(ErrorHandlerFactory.self).createRecoveryService() }
        
        // 注册迁移系统
        registerShared(MigrationManagerFactory.self) { MigrationManagerFactory() }
        registerShared(EnhancedMigrationManager.self) { resolve(MigrationManagerFactory.self).createMigrationManager() }
        
        // 注册模型版本管理
        registerShared(ModelVersionManagerFactory.self) { ModelVersionManagerFactory() }
        registerShared(ModelVersionManaging.self) { resolve(ModelVersionManagerFactory.self).createModelVersionManager() }
        
        // 注册同步系统
        registerShared(SyncManagerFactory.self) { SyncManagerFactory() }
        registerShared(EnhancedSyncManager.self) { resolve(SyncManagerFactory.self).createSyncManager() }
    }
    
    // MARK: - Reset
    
    /// 重置注册表
    public func reset() {
        containers.removeAll()
        registerDefaults()
    }
    
    // MARK: - Register Factories
    
    /// 注册所有工厂
    public func registerFactories() {
        // 注册模型版本管理器工厂
        registerShared(ModelVersionManagerFactory())
        
        // 注册错误处理器工厂
        registerShared(ErrorHandlerFactory())
        
        // 注册恢复服务工厂
        registerShared(RecoveryServiceFactory())
        
        // 注册迁移管理器工厂
        registerShared(MigrationManagerFactory())
    }
}

// MARK: - Convenience Provider Functions

/// 获取依赖
@MainActor
public func resolve<T>() -> T {
    return DependencyRegistry.shared.resolve()
}

/// 获取可选依赖
@MainActor
public func optional<T>() -> T? {
    return DependencyRegistry.shared.optional()
}

/// 注册依赖
@MainActor
public func register<T>(factory: @escaping () -> T) {
    DependencyRegistry.shared.register(factory: factory)
}

/// 注册共享依赖
@MainActor
public func registerShared<T>(factory: @escaping () -> T) {
    DependencyRegistry.shared.registerShared(factory: factory)
}

// MARK: - Factory Implementations

/// 迁移管理器工厂
public struct MigrationManagerFactory: Factory {
    public typealias Instance = EnhancedMigrationManager
    
    public func create() -> EnhancedMigrationManager {
        return EnhancedMigrationManager.createDefault()
    }
}

/// 错误处理器工厂
public struct ErrorHandlerFactory: Factory {
    public typealias Instance = EnhancedErrorHandler
    
    public func create() -> EnhancedErrorHandler {
        return EnhancedErrorHandler.createDefault()
    }
}

/// 恢复服务工厂
public struct RecoveryServiceFactory: Factory {
    public typealias Instance = EnhancedRecoveryService
    
    public func create() -> EnhancedRecoveryService {
        return EnhancedRecoveryService.createDefault()
    }
}

/// 模型版本管理器工厂
public struct ModelVersionManagerFactory: Factory {
    public typealias Instance = EnhancedModelVersionManager
    
    public func create() -> EnhancedModelVersionManager {
        return EnhancedModelVersionManager.createDefault()
    }
}

/// 同步管理器工厂
public struct SyncManagerFactory: Factory {
    /// 创建同步服务
    public func createSyncService() -> SyncServiceProtocol {
        // 实际项目中可能需要添加更多配置
        return DefaultSyncService()
    }
    
    /// 创建存储访问
    public func createStoreAccess() -> StoreAccessProtocol {
        return DefaultStoreAccess()
    }
    
    /// 创建进度报告器
    public func createProgressReporter() -> SyncProgressReporterProtocol {
        return DefaultSyncProgressReporter()
    }
    
    /// 创建同步管理器
    public func createSyncManager() -> EnhancedSyncManager {
        return EnhancedSyncManager(
            syncService: createSyncService(),
            storeAccess: createStoreAccess(),
            progressReporter: createProgressReporter()
        )
    }
}

// MARK: - Usage Example

/// 示例：基于依赖注入的错误处理服务
public struct ErrorHandlingService {
    /// 错误处理器
    private let errorHandler: EnhancedErrorHandler
    
    /// 恢复服务
    private let recoveryService: EnhancedRecoveryService
    
    /// 初始化错误处理服务
    public init(
        errorHandler: EnhancedErrorHandler = resolve(),
        recoveryService: EnhancedRecoveryService = resolve()
    ) {
        self.errorHandler = errorHandler
        self.recoveryService = recoveryService
    }
    
    /// 处理错误
    public func handle(_ error: Error, context: String) {
        errorHandler.handle(error, context: context)
    }
    
    /// 尝试恢复错误
    public func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        return await recoveryService.attemptRecovery(from: error, context: context)
    }
}

/// 示例：基于依赖注入的迁移服务
public struct MigrationService {
    /// 迁移管理器
    private let migrationManager: EnhancedMigrationManager
    
    /// 模型版本管理器
    private let versionManager: ModelVersionManaging
    
    /// 初始化迁移服务
    public init(
        migrationManager: EnhancedMigrationManager = resolve(),
        versionManager: ModelVersionManaging = resolve()
    ) {
        self.migrationManager = migrationManager
        self.versionManager = versionManager
    }
    
    /// 执行迁移
    public func migrate(storeAt url: URL, options: MigrationOptions = .default) async throws -> MigrationResult {
        return try await migrationManager.migrate(storeAt: url, options: options)
    }
    
    /// 检查是否需要迁移
    public func needsMigration(at url: URL) async throws -> Bool {
        return try await migrationManager.needsMigration(at: url)
    }
    
    /// 获取迁移路径
    public func getMigrationPath(for url: URL) async throws -> [ModelVersion] {
        // 获取存储元数据
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: url, options: nil)
        
        // 获取源版本和目标版本
        let sourceVersion = try versionManager.sourceModelVersion(for: metadata)
        let destinationVersion = try versionManager.destinationModelVersion()
        
        // 计算迁移路径
        return versionManager.migrationPath(from: sourceVersion, to: destinationVersion)
    }
} 