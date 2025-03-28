import CoreData
import Foundation
import os

/// Core Data 模块内的错误
public enum CoreDataError: Error, LocalizedError {
    /// 存储错误
    case storeNotFound(String)
    case persistentStoreCoordinatorError(Error)
    case managedObjectContextError(Error)
    case objectNotFound(String)
    case saveError(Error)
    
    /// 同步错误
    case syncSetupError(String)
    case syncStartError(String)
    case syncStopError(String)
    case syncProcessError(String)
    case invalidSyncState(String)
    case networkUnavailable
    
    /// 数据转换错误
    case conversionError(String)
    case invalidData(String)
    
    /// 备份和恢复错误
    case backupFailed(Error)
    case backupDirectoryError(String)
    case invalidBackupFile
    case backupRestoreFailed(reason: String)
    
    /// 迁移错误
    case modelNotFound(String)
    case migrationFailed(String)
    case saveFailed(reason: String)
    case updateFailed(reason: String)
    case deleteFailed(reason: String)
    case mergeConflict(reason: String)
    case validationFailed(reason: String)
    case invalidManagedObject(reason: String)
    case notFound(String)
    
    /// 通用错误
    case unknown(Error)
    case custom(String)
    
    public var errorDescription: String? {
        switch self {
        /// 存储错误
        case .storeNotFound(let message):
            return "Core Data store not found: \(message)"
        case .persistentStoreCoordinatorError(let error):
            return "Persistent Store Coordinator error: \(error.localizedDescription)"
        case .managedObjectContextError(let error):
            return "Managed Object Context error: \(error.localizedDescription)"
        case .objectNotFound(let id):
            return "Object not found with ID: \(id)"
        case .saveError(let error):
            return "Save error: \(error.localizedDescription)"
            
        /// 同步错误
        case .syncSetupError(let message):
            return "Sync setup error: \(message)"
        case .syncStartError(let message):
            return "Sync start error: \(message)"
        case .syncStopError(let message):
            return "Sync stop error: \(message)"
        case .syncProcessError(let message):
            return "Sync process error: \(message)"
        case .invalidSyncState(let message):
            return "Invalid sync state: \(message)"
        case .networkUnavailable:
            return "Network is unavailable"
            
        /// 数据转换错误
        case .conversionError(let message):
            return "Conversion error: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
            
        /// 备份和恢复错误
        case .backupFailed(let error):
            return "Backup failed: \(error.localizedDescription)"
        case .backupDirectoryError(let message):
            return "Backup directory error: \(message)"
        case .invalidBackupFile:
            return "Invalid backup file"
        case .backupRestoreFailed(let reason):
            return "Backup restore failed: \(reason)"
            
        /// 迁移错误    
        case .modelNotFound(let message):
            return "Model not found: \(message)"
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        case .saveFailed(let reason):
            return "Save failed: \(reason)"
        case .updateFailed(let reason):
            return "Update failed: \(reason)"
        case .deleteFailed(let reason):
            return "Delete failed: \(reason)"
        case .mergeConflict(let reason):
            return "Merge conflict: \(reason)"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        case .invalidManagedObject(let reason):
            return "Invalid managed object: \(reason)"
        case .notFound(let message):
            return "Not found: \(message)"
            
        /// 通用错误
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        case .custom(let message):
            return message
        }
    }
    
    /// 从NSError创建CoreDataError实例
    /// - Parameter error: NSError对象
    /// - Returns: 对应的CoreDataError
    public static func from(_ error: NSError) -> CoreDataError {
        // 处理Core Data错误
        if error.domain == NSCocoaErrorDomain {
            switch error.code {
            case NSCoreDataError:
                return .unknown(error)
            case NSValidationErrorMinimum...NSValidationErrorMaximum:
                return .validationFailed(reason: error.localizedDescription)
            case NSManagedObjectValidationError:
                return .validationFailed(reason: error.localizedDescription)
            case NSManagedObjectConstraintValidationError:
                return .validationFailed(reason: "约束验证失败: \(error.localizedDescription)")
            case NSPersistentStoreError:
                return .persistentStoreCoordinatorError(error)
            case NSManagedObjectContextLockingError:
                return .managedObjectContextError(error)
            case NSPersistentStoreCoordinatorLockingError:
                return .persistentStoreCoordinatorError(error)
            case NSManagedObjectReferentialIntegrityError:
                return .invalidManagedObject(reason: "引用完整性错误: \(error.localizedDescription)")
            case NSManagedObjectExternalRelationshipError:
                return .invalidManagedObject(reason: "外部关系错误: \(error.localizedDescription)")
            case NSManagedObjectMergeError:
                return .mergeConflict(reason: error.localizedDescription)
            case NSManagedObjectConstraintMergeError:
                return .mergeConflict(reason: "约束合并错误: \(error.localizedDescription)")
            case NSPersistentStoreInvalidTypeError:
                return .persistentStoreCoordinatorError(error)
            case NSPersistentStoreTypeMismatchError:
                return .persistentStoreCoordinatorError(error)
            case NSPersistentStoreIncompatibleVersionHashError:
                return .migrationFailed("存储版本不兼容: \(error.localizedDescription)")
            case NSPersistentStoreIncompatibleSchemaError:
                return .migrationFailed("存储架构不兼容: \(error.localizedDescription)")
            case NSPersistentStoreOperationError:
                return .persistentStoreCoordinatorError(error)
            case NSPersistentStoreSaveError:
                return .saveFailed(reason: error.localizedDescription)
            case NSCoreDataError + 1:
                return .migrationFailed("迁移错误: \(error.localizedDescription)")
            default:
                return .unknown(error)
            }
        } else {
            // 处理其他错误
            return .unknown(error)
        }
    }
}

/// Core Data 错误处理器
public final class CoreDataErrorHandler: @unchecked Sendable {
    /// 单例
    @MainActor public static let shared = CoreDataErrorHandler()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "ErrorHandling")
    
    private init() {}
    
    /// 处理错误
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误上下文描述
    public func handle(_ error: Error, context: String) {
        // 判断错误类型
        if let coreDataError = error as? CoreDataError {
            logger.error("Core Data错误[\(context)]: \(coreDataError.errorDescription ?? "未知错误")")
        } else if let nsError = error as? NSError, nsError.domain == NSCocoaErrorDomain {
            // 将NSError转换为CoreDataError
            let coreDataError = CoreDataError.from(nsError)
            logger.error("Cocoa错误[\(context)]: \(coreDataError.errorDescription ?? "未知错误")")
        } else {
            logger.error("未知错误[\(context)]: \(error.localizedDescription)")
        }
    }
    
    /// 转换错误
    /// - Parameter error: 任意错误
    /// - Returns: 转换后的CoreDataError
    public func convert(_ error: Error) -> CoreDataError {
        if let coreDataError = error as? CoreDataError {
            return coreDataError
        } else if let nsError = error as? NSError {
            return CoreDataError.from(nsError)
        } else {
            return .unknown(error)
        }
    }
    
    /// 记录错误但不抛出
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误上下文描述
    public func logOnly(_ error: Error, context: String) {
        handle(error, context: context)
    }
    
    /// 记录错误并抛出
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误上下文描述
    /// - Throws: 转换后的CoreDataError
    public func logAndThrow(_ error: Error, context: String) throws {
        handle(error, context: context)
        throw convert(error)
    }
} 