import Foundation
import CoreData
import os

/// 定义恢复结果
public enum RecoveryResult {
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

/// 验证恢复策略
/// 用于处理数据验证错误
final class ValidatorRecoveryStrategy: RecoveryStrategy {
    let name = "ValidatorRecovery"
    
    func canHandle(_ error: Error) -> Bool {
        if let coreDataError = error as? CoreDataError {
            switch coreDataError {
            case .validationFailed, .invalidManagedObject:
                return true
            default:
                break
            }
        }
        
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code >= NSValidationErrorMinimum && nsError.code <= NSValidationErrorMaximum
    }
    
    func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "Recovery")
        logger.info("尝试修复验证错误")
        
        // 验证错误通常需要用户交互来修复无效数据
        // 这里可以提供一些通用的修复建议
        logger.info("验证错误需要用户交互来修复")
        
        // 如果是特定类型的验证错误，可以尝试自动修复
        if let nsError = error as NSError, nsError.domain == NSCocoaErrorDomain {
            if let entity = nsError.userInfo["NSValidationErrorKey"] as? String,
               let value = nsError.userInfo["NSValidationErrorValue"] {
                logger.debug("验证错误详情 - 实体: \(entity), 值: \(value)")
                
                // 根据具体的验证错误类型执行不同的修复逻辑
                // 例如：对于特定属性的无效值，可以尝试设置默认值
            }
        }
        
        // 大多数验证错误需要用户交互
        return .requiresUserInteraction
    }
} 