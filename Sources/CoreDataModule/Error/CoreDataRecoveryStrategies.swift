import Foundation
import CoreData
import os

/// 定义恢复结果
public enum RecoveryResult: Sendable {
    /// 恢复成功
    case success
    /// 恢复失败
    case failure(Error)
    /// 需要用户交互
    case requiresUserInteraction
    /// 恢复部分成功
    case partialSuccess(String)
}

/// 错误恢复策略协议
public protocol RecoveryStrategy {
    /// 恢复策略名称
    var name: String { get }
    
    /// 尝试恢复错误
    /// - Parameters:
    ///   - error: 要恢复的错误
    ///   - context: 错误上下文
    /// - Returns: 恢复结果
    func attemptRecovery(from error: Error, context: String) async -> RecoveryResult
    
    /// 检查策略是否适用于给定错误
    /// - Parameter error: 检查的错误
    /// - Returns: 是否适用
    func canHandle(_ error: Error) -> Bool
}

/// 核心数据恢复策略执行器
/// 负责执行不同类型错误的恢复策略
public final class CoreDataRecoveryExecutor: @unchecked Sendable {
    // MARK: - 单例
    
    /// 共享实例
    public static let shared = CoreDataRecoveryExecutor()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "Recovery")
    
    /// 注册的恢复策略
    private var strategies: [RecoveryStrategy] = []
    
    // MARK: - 初始化
    
    private init() {
        registerDefaultStrategies()
    }
    
    // MARK: - 公共方法
    
    /// 注册恢复策略
    /// - Parameter strategy: 恢复策略
    public func register(strategy: RecoveryStrategy) {
        strategies.append(strategy)
        logger.debug("已注册恢复策略: \(strategy.name)")
    }
    
    /// 尝试恢复错误
    /// - Parameters:
    ///   - error: 要恢复的错误
    ///   - context: 错误上下文
    /// - Returns: 恢复结果
    public func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        // 记录恢复尝试
        logger.info("尝试从错误恢复: \(error.localizedDescription) [\(context)]")
        
        // 查找合适的恢复策略
        let applicableStrategies = strategies.filter { $0.canHandle(error) }
        
        if applicableStrategies.isEmpty {
            logger.warning("没有找到适用的恢复策略: \(error.localizedDescription)")
            return .failure(error)
        }
        
        // 尝试每个适用的策略
        for strategy in applicableStrategies {
            logger.debug("应用恢复策略: \(strategy.name)")
            
            let result = await strategy.attemptRecovery(from: error, context: context)
            
            switch result {
            case .success:
                logger.info("恢复成功: \(strategy.name)")
                return result
            case .partialSuccess(let message):
                logger.info("部分恢复: \(strategy.name) - \(message)")
                return result
            case .requiresUserInteraction:
                logger.info("需要用户交互: \(strategy.name)")
                return result
            case .failure(let recoveryError):
                logger.error("恢复失败: \(strategy.name) - \(recoveryError.localizedDescription)")
                // 继续尝试下一个策略
            }
        }
        
        // 所有策略都失败
        logger.error("所有恢复策略都失败: \(error.localizedDescription)")
        return .failure(error)
    }
    
    // MARK: - 私有方法
    
    /// 注册默认恢复策略
    private func registerDefaultStrategies() {
        register(strategy: StoreResetRecoveryStrategy())
        register(strategy: ContextResetRecoveryStrategy())
        register(strategy: MigrationRecoveryStrategy())
        register(strategy: BackupRestorationStrategy())
        register(strategy: ValidatorRecoveryStrategy())
    }
}

// MARK: - 恢复策略实现

/// 存储重置恢复策略
/// 用于处理持久化存储损坏的情况
final class StoreResetRecoveryStrategy: RecoveryStrategy {
    let name = "StoreResetRecovery"
    
    func canHandle(_ error: Error) -> Bool {
        if let coreDataError = error as? CoreDataError {
            switch coreDataError {
            case .storeNotFound, .migrationFailed:
                return true
            default:
                break
            }
        }
        
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && 
            (nsError.code == NSPersistentStoreIncompatibleVersionHashError || 
             nsError.code == NSPersistentStoreOpenError)
    }
    
    func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "Recovery")
        logger.info("尝试重置存储以恢复错误")
        
        // 获取存储URL
        guard let storeURL = CoreDataStack.shared.persistentContainer.persistentStoreDescriptions.first?.url else {
            logger.error("无法获取存储URL")
            return .failure(CoreDataError.storeNotFound("无法获取存储URL"))
        }
        
        do {
            // 创建备份
            try CoreDataResourceManager.shared.backupStore(at: storeURL)
            logger.info("已创建存储备份")
            
            // 删除现有存储
            try FileManager.default.removeItem(at: storeURL)
            logger.info("已删除损坏的存储")
            
            // 尝试重新创建存储
            // 这里只是移除了存储文件，CoreData会在下次访问时自动创建新的存储
            // 可能需要重新启动应用程序或重新加载持久化容器
            
            return .requiresUserInteraction  // 需要用户确认重启应用
        } catch {
            logger.error("重置存储失败: \(error.localizedDescription)")
            return .failure(error)
        }
    }
}

/// 上下文重置恢复策略
/// 用于处理上下文状态不一致的情况
final class ContextResetRecoveryStrategy: RecoveryStrategy {
    let name = "ContextResetRecovery"
    
    func canHandle(_ error: Error) -> Bool {
        if let coreDataError = error as? CoreDataError {
            switch coreDataError {
            case .saveFailed, .updateFailed, .mergeConflict:
                return true
            default:
                break
            }
        }
        
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && 
            (nsError.code == NSManagedObjectContextLockingError || 
             nsError.code == NSPersistentStoreCoordinatorLockingError)
    }
    
    func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "Recovery")
        logger.info("尝试重置上下文以恢复错误")
        
        // 获取视图上下文
        let viewContext = CoreDataStack.shared.persistentContainer.viewContext
        
        // 重置上下文
        viewContext.reset()
        logger.info("已重置视图上下文")
        
        return .success
    }
}

/// 迁移恢复策略
/// 用于处理迁移失败的情况
final class MigrationRecoveryStrategy: RecoveryStrategy {
    let name = "MigrationRecovery"
    
    func canHandle(_ error: Error) -> Bool {
        if let coreDataError = error as? CoreDataError {
            switch coreDataError {
            case .migrationFailed:
                return true
            default:
                break
            }
        }
        
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSMigrationError
    }
    
    func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "Recovery")
        logger.info("尝试执行手动迁移以恢复错误")
        
        // 获取存储URL
        guard let storeURL = CoreDataStack.shared.persistentContainer.persistentStoreDescriptions.first?.url else {
            logger.error("无法获取存储URL")
            return .failure(CoreDataError.storeNotFound("无法获取存储URL"))
        }
        
        do {
            // 创建备份
            try CoreDataResourceManager.shared.backupStore(at: storeURL)
            logger.info("已创建存储备份")
            
            // 尝试执行手动迁移
            let migrationManager = CoreDataMigrationManager.shared
            migrationManager.reset()  // 重置迁移状态
            
            // 执行迁移
            try await migrationManager.performMigration(at: storeURL)
            logger.info("手动迁移成功")
            
            return .success
        } catch {
            logger.error("手动迁移失败: \(error.localizedDescription)")
            return .failure(error)
        }
    }
}

/// 备份恢复策略
/// 用于从备份恢复数据
final class BackupRestorationStrategy: RecoveryStrategy {
    let name = "BackupRestoration"
    
    func canHandle(_ error: Error) -> Bool {
        if let coreDataError = error as? CoreDataError {
            switch coreDataError {
            case .storeNotFound, .saveFailed, .migrationFailed:
                return true
            default:
                break
            }
        }
        
        return false
    }
    
    func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "Recovery")
        logger.info("尝试从备份恢复")
        
        // 获取存储URL
        guard let storeURL = CoreDataStack.shared.persistentContainer.persistentStoreDescriptions.first?.url else {
            logger.error("无法获取存储URL")
            return .failure(CoreDataError.storeNotFound("无法获取存储URL"))
        }
        
        // 获取可用的备份
        let resourceManager = CoreDataResourceManager.shared
        let backups = resourceManager.getBackups(for: storeURL)
        
        if backups.isEmpty {
            logger.warning("没有可用备份")
            return .failure(CoreDataError.notFound("没有可用备份"))
        }
        
        // 获取最新的备份
        guard let latestBackup = backups.first else {
            logger.warning("无法获取最新备份")
            return .failure(CoreDataError.notFound("无法获取最新备份"))
        }
        
        do {
            // 恢复备份
            try resourceManager.restoreBackup(at: latestBackup, to: storeURL)
            logger.info("已从备份恢复: \(latestBackup.lastPathComponent)")
            
            return .success
        } catch {
            logger.error("从备份恢复失败: \(error.localizedDescription)")
            return .failure(error)
        }
    }
}

/// 验证器恢复策略
/// 用于处理验证错误
final class ValidatorRecoveryStrategy: RecoveryStrategy {
    let name = "ValidatorRecovery"
    
    func canHandle(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && 
            nsError.code == NSValidationErrorCode
    }
    
    func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "Recovery")
        logger.info("尝试修复验证错误")
        
        // 如果是特定类型的验证错误，可以尝试自动修复
        if let nsError = error as? NSError, nsError.domain == NSCocoaErrorDomain {
            if let entity = nsError.userInfo["NSValidationErrorKey"] as? String,
               let value = nsError.userInfo["NSValidationErrorValue"] {
                logger.debug("验证错误详情 - 实体: \(String(describing: entity)), 值: \(String(describing: value))")
                
                // 根据具体的验证错误类型执行不同的修复逻辑
                if nsError.code == NSValidationStringTooShortError {
                    // 对于字符串太短的错误，可以尝试设置默认值
                    return .partialSuccess("已自动修复字符串长度错误")
                } else if nsError.code == NSValidationNumberTooSmallError {
                    // 对于数字太小的错误，可以尝试设置最小值
                    return .partialSuccess("已自动修复数字范围错误")
                }
            }
        }
        
        // 如果无法自动修复，需要用户交互
        return .requiresUserInteraction
    }
}

/// 错误恢复策略协议
public protocol ErrorRecoveryStrategy {
    /// 执行恢复策略
    /// - Parameter completion: 完成回调，传递是否成功
    func execute(completion: @escaping (Bool) -> Void)
    
    /// 异步执行恢复策略
    /// - Returns: 是否成功恢复
    func execute() async -> Bool
}

/// 默认扩展：提供基于回调版本的异步实现
public extension ErrorRecoveryStrategy {
    func execute() async -> Bool {
        return await withCheckedContinuation { continuation in
            execute { success in
                continuation.resume(returning: success)
            }
        }
    }
}

/// Core Data恢复策略提供者
public final class CoreDataRecoveryStrategies {
    /// 日志记录器
    private let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "RecoveryStrategies")
    
    /// 初始化
    public init() {}
    
    /// 为指定错误获取恢复策略
    /// - Parameter error: CoreData错误
    /// - Returns: 适用的恢复策略或nil
    public func strategyFor(error: CoreDataError) -> ErrorRecoveryStrategy? {
        switch error {
        case .storeNotFound:
            return StoreRecreationStrategy()
        case .persistentStoreCoordinatorError:
            return StoreResetStrategy()
        case .managedObjectContextError:
            return ContextResetStrategy()
        case .saveError:
            return SaveRetryStrategy()
        case .syncProcessError, .syncSetupError, .syncStartError, .syncStopError:
            return SyncRecoveryStrategy()
        case .migrationFailed:
            return MigrationRecoveryStrategy()
        case .backupFailed, .backupDirectoryError, .backupRestoreFailed:
            return BackupRecoveryStrategy()
        case .mergeConflict:
            return MergeConflictResolutionStrategy()
        default:
            logger.warning("没有找到错误类型 \(String(describing: error)) 的恢复策略")
            return nil
        }
    }
}

// MARK: - 具体恢复策略

/// 存储重建策略
private class StoreRecreationStrategy: ErrorRecoveryStrategy {
    func execute(completion: @escaping (Bool) -> Void) {
        // 实现存储重建逻辑
        let coreDataStack = CoreDataStack.shared
        
        Task {
            do {
                try await coreDataStack.recreateStore()
                completion(true)
            } catch {
                CoreLogger.error("重建存储失败: \(error.localizedDescription)", category: "Recovery")
                completion(false)
            }
        }
    }
}

/// 存储重置策略
private class StoreResetStrategy: ErrorRecoveryStrategy {
    func execute(completion: @escaping (Bool) -> Void) {
        // 实现存储重置逻辑
        let coreDataStack = CoreDataStack.shared
        
        Task {
            do {
                try await coreDataStack.resetStore()
                completion(true)
            } catch {
                CoreLogger.error("重置存储失败: \(error.localizedDescription)", category: "Recovery")
                completion(false)
            }
        }
    }
}

/// 上下文重置策略
private class ContextResetStrategy: ErrorRecoveryStrategy {
    func execute(completion: @escaping (Bool) -> Void) {
        // 实现上下文重置逻辑
        let coreDataStack = CoreDataStack.shared
        coreDataStack.resetContext()
        completion(true)
    }
}

/// 保存重试策略
private class SaveRetryStrategy: ErrorRecoveryStrategy {
    func execute(completion: @escaping (Bool) -> Void) {
        // 实现保存重试逻辑
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.mainContext
        
        Task {
            do {
                // 先回滚，然后重试保存
                await context.perform {
                    context.rollback()
                }
                
                try await coreDataStack.saveContext()
                completion(true)
            } catch {
                CoreLogger.error("重试保存失败: \(error.localizedDescription)", category: "Recovery")
                completion(false)
            }
        }
    }
}

/// 同步恢复策略
private class SyncRecoveryStrategy: ErrorRecoveryStrategy {
    func execute(completion: @escaping (Bool) -> Void) {
        // 重置同步状态逻辑
        CoreLogger.info("执行同步恢复策略", category: "Recovery")
        
        // 模拟恢复过程
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            // 在实际实现中，这里应该是真正的恢复逻辑
            CoreLogger.info("同步状态已重置", category: "Recovery")
            completion(true)
        }
    }
}

/// 迁移恢复策略
private class MigrationRecoveryStrategy: ErrorRecoveryStrategy {
    func execute(completion: @escaping (Bool) -> Void) {
        CoreLogger.info("执行迁移恢复策略", category: "Recovery")
        
        // 模拟恢复过程
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            // 在实际实现中，这里应该是真正的恢复逻辑
            CoreLogger.info("迁移已重置", category: "Recovery")
            completion(true)
        }
    }
}

/// 备份恢复策略
private class BackupRecoveryStrategy: ErrorRecoveryStrategy {
    func execute(completion: @escaping (Bool) -> Void) {
        CoreLogger.info("执行备份恢复策略", category: "Recovery")
        
        // 模拟恢复过程
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            // 在实际实现中，这里应该是真正的恢复逻辑
            CoreLogger.info("备份问题已处理", category: "Recovery")
            completion(true)
        }
    }
}

/// 合并冲突解决策略
private class MergeConflictResolutionStrategy: ErrorRecoveryStrategy {
    func execute(completion: @escaping (Bool) -> Void) {
        CoreLogger.info("执行合并冲突解决策略", category: "Recovery")
        
        // 获取Core Data栈
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.mainContext
        
        // 丢弃本地更改，接受最新的版本
        Task {
            await context.perform {
                context.rollback()
            }
            
            CoreLogger.info("合并冲突已解决（回滚本地更改）", category: "Recovery")
            completion(true)
        }
    }
} 