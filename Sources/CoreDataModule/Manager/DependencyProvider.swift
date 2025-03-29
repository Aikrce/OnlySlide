import Foundation
import CoreData
import Combine
import os

// MARK: - Provider Protocol

/// 依赖提供者接口
@preconcurrency
public protocol Provider: Sendable {
    /// 获取特定类型的依赖
    func resolve<T: Sendable>() async -> T
    
    /// 获取可选类型的依赖
    func optional<T: Sendable>() async -> T?
    
    /// 注册依赖
    func register<T: Sendable>(factory: @escaping @Sendable () async -> T) async
    
    /// 注册共享实例的依赖
    func registerShared<T: Sendable>(factory: @escaping @Sendable () async -> T) async
    
    /// 注册特定类型的依赖
    func register<T: Sendable>(_ type: T.Type, factory: @escaping @Sendable () async -> T) async
    
    /// 注册特定类型的共享依赖
    func registerShared<T: Sendable>(_ type: T.Type, factory: @escaping @Sendable () async -> T) async
}

// MARK: - Platform Specifics

/// 平台特定功能提供
public protocol PlatformSpecificProvider: Sendable {
    /// 平台名称
    var platformName: String { get }
    
    /// 平台特定的初始化
    func initialize() async
    
    /// 创建平台特定的错误处理服务
    func createErrorHandlingService() async -> CrossPlatformErrorHandling
    
    /// 平台特定资源清理
    func cleanup() async
}

// MARK: - macOS 平台提供者
public struct MacOSPlatformProvider: PlatformSpecificProvider {
    public var platformName: String { "macOS" }
    
    public init() {}
    
    public func initialize() async {
        // macOS 特定初始化
        print("初始化 macOS 平台特定功能")
    }
    
    public func createErrorHandlingService() async -> CrossPlatformErrorHandling {
        return CrossPlatformErrorHandlingService(
            subsystem: "com.onlyslide.macos",
            category: "errorhandling",
            maxHistoryEntries: 200
        )
    }
    
    public func cleanup() async {
        // macOS 特定清理
        print("清理 macOS 平台特定资源")
    }
}

// MARK: - iOS 平台提供者
public struct IOSPlatformProvider: PlatformSpecificProvider {
    public var platformName: String { "iOS" }
    
    public init() {}
    
    public func initialize() async {
        // iOS 特定初始化
        print("初始化 iOS 平台特定功能")
    }
    
    public func createErrorHandlingService() async -> CrossPlatformErrorHandling {
        return CrossPlatformErrorHandlingService(
            subsystem: "com.onlyslide.ios",
            category: "errorhandling",
            maxHistoryEntries: 100
        )
    }
    
    public func cleanup() async {
        // iOS 特定清理
        print("清理 iOS 平台特定资源")
    }
}

// MARK: - 平台检测

/// 获取当前平台提供者
public func getCurrentPlatformProvider() -> PlatformSpecificProvider {
    #if os(macOS)
    return MacOSPlatformProvider()
    #elseif os(iOS)
    return IOSPlatformProvider()
    #elseif os(watchOS)
    // watchOS平台实现
    fatalError("watchOS平台暂不支持")
    #elseif os(tvOS)
    // tvOS平台实现
    fatalError("tvOS平台暂不支持")
    #else
    // 其他平台实现
    fatalError("当前平台暂不支持")
    #endif
}

// MARK: - Dependencies Registry

/// 依赖注册表
public actor DependencyRegistry: Provider {
    // MARK: - Dependency Container
    
    private final class DependencyContainer: @unchecked Sendable {
        let factory: @Sendable () async -> Any
        private(set) var instance: Any?
        let isShared: Bool
        private let lock = NSLock()
        
        init(factory: @escaping @Sendable () async -> Any, isShared: Bool) {
            self.factory = factory
            self.isShared = isShared
        }
        
        func resolve() async -> Any {
            // 如果非共享实例，直接创建新实例
            if !isShared {
                return await factory()
            }
            
            // 使用锁保护共享实例的访问
            lock.lock()
            defer { lock.unlock() }
            
            if let instance = instance {
                return instance
            } else {
                let newInstance = await factory()
                instance = newInstance
                return newInstance
            }
        }
    }
    
    // MARK: - Properties
    
    /// 共享实例
    public static let shared = DependencyRegistry()
    
    /// 注册的依赖
    private var containers = [String: DependencyContainer]()
    private var sharedInstances = [String: Any]()
    
    /// 平台提供者
    private let platformProvider: PlatformSpecificProvider
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "DependencyRegistry")
    
    // MARK: - Initialization
    
    /// 初始化依赖注册表
    public init(platformProvider: PlatformSpecificProvider? = nil) {
        self.platformProvider = platformProvider ?? getCurrentPlatformProvider()
        Task {
            await registerDefaults()
        }
    }
    
    // MARK: - Provider Implementation
    
    public func resolve<T>() async -> T {
        let key = String(describing: T.self)
        
        guard let container = containers[key] else {
            fatalError("依赖未注册: \(key)")
        }
        
        guard let result = await container.resolve() as? T else {
            fatalError("无法解析依赖: \(key)")
        }
        
        return result
    }
    
    public func optional<T>() async -> T? {
        let key = String(describing: T.self)
        
        guard let container = containers[key] else {
            return nil
        }
        
        return await container.resolve() as? T
    }
    
    public func register<T>(factory: @escaping @Sendable () async -> T) async {
        let key = String(describing: T.self)
        containers[key] = DependencyContainer(factory: { await factory() } as @Sendable () async -> Any, isShared: false)
    }
    
    public func registerShared<T>(factory: @escaping @Sendable () async -> T) async {
        let key = String(describing: T.self)
        containers[key] = DependencyContainer(factory: { await factory() } as @Sendable () async -> Any, isShared: true)
    }
    
    public func register<T>(_ type: T.Type, factory: @escaping @Sendable () async -> T) async {
        let key = String(describing: type)
        containers[key] = DependencyContainer(factory: { await factory() } as @Sendable () async -> Any, isShared: false)
    }
    
    public func registerShared<T>(_ type: T.Type, factory: @escaping @Sendable () async -> T) async {
        let key = String(describing: type)
        containers[key] = DependencyContainer(factory: { await factory() } as @Sendable () async -> Any, isShared: true)
    }
    
    // MARK: - Default Registration
    
    private func registerDefaults() async {
        logger.info("正在注册\(platformProvider.platformName)平台的默认依赖")
        
        // 初始化平台特定功能
        await platformProvider.initialize()
        
        // 注册组件
        await registerCoreComponents()
        await registerFactories()
        await registerDependencies()
        
        logger.info("已完成依赖注册")
    }
    
    private func registerCoreComponents() async {
        // 注册核心组件
        await registerShared(factory: { CoreDataManager.shared })
        await registerShared(factory: { CoreDataStack.shared })
        await registerShared(factory: { await CoreDataResourceManager.shared })
        await registerShared(factory: { CoreDataModelVersionManager.shared })
        await registerShared(factory: { CoreDataMigrationManager.shared })
        await registerShared(factory: { CoreDataErrorManager.shared })
        await registerShared(factory: { CoreDataRecoveryExecutor.shared })
    }
    
    // MARK: - Register Dependencies
    
    private func registerDependencies() async {
        // 注册平台特定的错误处理服务
        await registerShared(CrossPlatformErrorHandling.self, factory: {
            await self.platformProvider.createErrorHandlingService()
        })
        
        // 注册增强的迁移管理器
        await registerShared(factory: {
            await EnhancedMigrationManager.createDefault()
        })
        
        // 注册同步管理器
        await registerShared(factory: {
            await createSyncManager()
        })
        
        // 注册资源管理器
        await registerShared(ResourceProviding.self, factory: {
            return await CoreDataResourceManager.shared
        })
    }
    
    // MARK: - Reset
    
    /// 重置注册表
    public func reset() async {
        // 清理平台特定资源
        await platformProvider.cleanup()
        
        // 清理依赖
        containers.removeAll()
        sharedInstances.removeAll()
        
        // 重新注册默认依赖
        await registerDefaults()
    }
    
    // MARK: - Register Factories
    
    /// 注册所有工厂
    public func registerFactories() async {
        // 注册模型版本管理器工厂
        await registerShared(factory: { ModelVersionManagerFactory() })
        
        // 注册错误处理器工厂
        await registerShared(factory: { ErrorHandlerFactory() })
        
        // 注册恢复服务工厂
        await registerShared(factory: { RecoveryServiceFactory() })
        
        // 注册迁移管理器工厂
        await registerShared(factory: { MigrationManagerFactory() })
        
        // 注册同步工厂
        await registerShared(factory: { SyncManagerFactory() })
    }
    
    // MARK: - Factory Helper Methods
    
    /// 创建同步管理器
    private func createSyncManager() async -> EnhancedSyncManager {
        // 获取依赖组件
        let coreDataManager: CoreDataManager = await resolve()
        let errorHandler: CrossPlatformErrorHandling = await resolve()
        
        // 创建同步服务和进度报告器
        let syncService = DefaultSyncService()
        let progressReporter = SyncProgressReporter()
        
        // 在主actor上获取上下文
        let context = await MainActor.run { coreDataManager.viewContext }
        
        // 创建并返回同步管理器
        return EnhancedSyncManager(
            context: context,
            syncService: syncService,
            progressReporter: progressReporter
        )
    }
}

// MARK: - Convenience Provider Functions

/// 获取依赖
public func resolve<T>() async -> T {
    return await CoreDataModule.DependencyRegistry.shared.resolve()
}

/// 明确指定类型的依赖解析
public func resolve<T>(_ type: T.Type) async -> T {
    return await CoreDataModule.DependencyRegistry.shared.resolve()
}

/// 获取可选依赖
public func optional<T>() async -> T? {
    return await CoreDataModule.DependencyRegistry.shared.optional()
}

/// 注册依赖
public func register<T: Sendable>(factory: @escaping @Sendable () async -> T) async {
    await CoreDataModule.DependencyRegistry.shared.register(factory: factory)
}

/// 注册共享依赖
public func registerShared<T: Sendable>(factory: @escaping @Sendable () async -> T) async {
    await CoreDataModule.DependencyRegistry.shared.registerShared(factory: factory)
}

// MARK: - Factory Implementations

/// 迁移管理器工厂
public struct MigrationManagerFactory: Factory {
    public typealias Instance = EnhancedMigrationManager
    
    @MainActor
    public func create() async -> EnhancedMigrationManager {
        return EnhancedMigrationManager.createDefault()
    }
}

/// 错误处理器工厂
public struct ErrorHandlerFactory: Factory {
    public typealias Instance = EnhancedErrorHandler
    
    @MainActor
    public func create() async -> EnhancedErrorHandler {
        return EnhancedErrorHandler.createDefault()
    }
}

/// 恢复服务工厂
public struct RecoveryServiceFactory: Factory {
    public typealias Instance = EnhancedRecoveryService
    
    @MainActor
    public func create() async -> EnhancedRecoveryService {
        return EnhancedRecoveryService.createDefault()
    }
}

/// 模型版本管理器工厂
public struct ModelVersionManagerFactory: Factory {
    public typealias Instance = EnhancedModelVersionManager
    
    @MainActor
    public func create() async -> EnhancedModelVersionManager {
        // 创建默认实例，不传递额外参数
        return EnhancedModelVersionManager.createDefault()
    }
}

/// 同步管理器工厂
@MainActor 
public class SyncManagerFactory: Factory {
    public typealias Instance = EnhancedSyncManager
    
    /// 初始化工厂
    public init() {}
    
    /// 创建同步服务
    @MainActor
    private func createSyncService() async -> DefaultSyncService {
        let service = DefaultSyncService()
        return service
    }
    
    /// 创建进度报告器
    @MainActor
    private func createProgressReporter() -> SyncProgressReporterProtocol {
        return SyncProgressReporter()
    }
    
    /// 创建同步管理器
    @MainActor
    public func create() async -> EnhancedSyncManager {
        // 获取主上下文
        let context = CoreDataStack.shared.mainContext
        
        // 创建同步服务和进度报告器
        let syncService = await createSyncService()
        let progressReporter = createProgressReporter()
        
        // 创建同步管理器
        return EnhancedSyncManager(
            context: context,
            syncService: syncService,
            progressReporter: progressReporter
        )
    }
}

// MARK: - Usage Example

/// 示例：基于依赖注入的错误处理服务
@MainActor
public final class ErrorHandlingService: Sendable {
    /// 错误处理器
    private let errorHandler: EnhancedErrorHandler
    
    /// 恢复服务
    private let recoveryService: EnhancedRecoveryService
    
    /// 初始化错误处理服务
    public init(
        errorHandler: EnhancedErrorHandler,
        recoveryService: EnhancedRecoveryService
    ) {
        self.errorHandler = errorHandler
        self.recoveryService = recoveryService
    }
    
    /// 使用依赖注入系统创建默认实例
    public static func createDefault() async -> ErrorHandlingService {
        // 尝试异步解析依赖
        let errorHandler: ErrorHandlerFactory
        let recoveryService: RecoveryServiceFactory
        
        do {
            errorHandler = await resolve(ErrorHandlerFactory.self)
            recoveryService = await resolve(RecoveryServiceFactory.self)
        } catch {
            print("解析依赖失败: \(error)")
            return ErrorHandlingService(
                errorHandler: EnhancedErrorHandler(),
                recoveryService: EnhancedRecoveryService()
            )
        }
        
        // 尝试异步创建依赖
        do {
            let handlerInstance = try await errorHandler.create()
            let recoveryInstance = try await recoveryService.create()
            
            return ErrorHandlingService(
                errorHandler: handlerInstance,
                recoveryService: recoveryInstance
            )
        } catch {
            print("创建依赖实例失败: \(error)")
            return ErrorHandlingService(
                errorHandler: EnhancedErrorHandler(),
                recoveryService: EnhancedRecoveryService()
            )
        }
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
@MainActor
public final class MigrationService: Sendable {
    /// 迁移管理器
    private let migrationManager: EnhancedMigrationManager
    
    /// 模型版本管理器
    private let versionManager: ModelVersionManaging
    
    /// 初始化迁移服务
    public init(
        migrationManager: EnhancedMigrationManager,
        versionManager: ModelVersionManaging
    ) {
        self.migrationManager = migrationManager
        self.versionManager = versionManager
    }
    
    /// 使用依赖注入系统创建默认实例
    public static func createDefault() async -> MigrationService {
        do {
            // 使用async/await模式创建依赖
            let migrationFactory = try await CoreDataModule.resolveFactory(MigrationManagerFactory.self)
            let versionFactory = try await CoreDataModule.resolveFactory(ModelVersionManagerFactory.self)
            
            return MigrationService(
                migrationManager: migrationFactory,
                versionManager: versionFactory
            )
        } catch {
            print("创建默认迁移服务失败: \(error)")
            
            // 创建基本版本的资源提供者
            let resourceProvider = CoreDataResourceManager.shared
            
            // 创建基本实例
            let migration = EnhancedMigrationManager()
            let version = EnhancedModelVersionManager(resourceProvider: resourceProvider)
            
            return MigrationService(
                migrationManager: migration,
                versionManager: version
            )
        }
    }
    
    /// 执行迁移
    public func migrate(storeAt url: URL, options: MigrationOptions = .default) async throws -> MigrationResult {
        let enhancedResult = try await migrationManager.migrate(storeAt: url, options: options)
        
        // 获取当前元数据以确定源版本
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: url, options: nil)
        let sourceVersion = try await versionManager.sourceModelVersion(for: metadata)
        let destinationVersion = try await versionManager.destinationModelVersion()
        let startTime = Date()
        
        // 将EnhancedMigrationResult转换为MigrationResult
        switch enhancedResult {
        case .success:
            return .success(
                sourceVersion: sourceVersion,
                destinationVersion: destinationVersion,
                startTime: startTime
            )
        case .failure(let error):
            throw error
        case .cancelled:
            throw NSError(domain: "MigrationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Migration was cancelled"])
        }
    }
    
    /// 检查是否需要迁移
    public func needsMigration(at url: URL) async throws -> Bool {
        return try await migrationManager.needsMigration(at: url)
    }
    
    /// 获取迁移路径
    public func getMigrationPath(for url: URL) async throws -> [ModelVersion] {
        // 获取存储元数据
        let _ = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: url, options: nil)
        
        // 获取源版本和目标版本
        let sourceVersion = try await versionManager.sourceModelVersion(for: metadata)
        let destinationVersion = try await versionManager.destinationModelVersion()
        
        // 计算迁移路径
        return await versionManager.migrationPath(from: sourceVersion, to: destinationVersion)
    }
} 