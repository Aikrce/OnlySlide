import CoreData
import Foundation
import os

/// Core Data 错误枚举
public enum CoreDataError: LocalizedError, Equatable {
    /// 未找到对象
    case notFound(String? = nil)
    
    /// 获取失败
    case fetchFailed(Error?)
    
    /// 保存失败
    case saveFailed(Error?)
    
    /// 更新失败
    case updateFailed(Error?)
    
    /// 删除失败
    case deleteFailed(Error?)
    
    /// 迁移失败
    case migrationFailed(String)
    
    /// 模型未找到
    case modelNotFound(String)
    
    /// 存储未找到
    case storeNotFound(String)
    
    /// 合并冲突
    case mergeConflict(Error?)
    
    /// 验证失败
    case validationFailed(String)
    
    /// 无效的托管对象
    case invalidManagedObject(String)
    
    /// 未知错误
    case unknown(Error?)
    
    /// 本地化描述
    public var errorDescription: String? {
        switch self {
        case .notFound(let entity):
            return entity != nil ? "未找到\(entity!)" : "未找到对象"
        case .fetchFailed(let error):
            return "获取数据失败: \(error?.localizedDescription ?? "未知错误")"
        case .saveFailed(let error):
            return "保存数据失败: \(error?.localizedDescription ?? "未知错误")"
        case .updateFailed(let error):
            return "更新数据失败: \(error?.localizedDescription ?? "未知错误")"
        case .deleteFailed(let error):
            return "删除数据失败: \(error?.localizedDescription ?? "未知错误")"
        case .migrationFailed(let message):
            return "数据迁移失败: \(message)"
        case .modelNotFound(let message):
            return "模型未找到: \(message)"
        case .storeNotFound(let message):
            return "存储未找到: \(message)"
        case .mergeConflict(let error):
            return "合并冲突: \(error?.localizedDescription ?? "未知错误")"
        case .validationFailed(let message):
            return "数据验证失败: \(message)"
        case .invalidManagedObject(let message):
            return "无效的托管对象: \(message)"
        case .unknown(let error):
            return "未知错误: \(error?.localizedDescription ?? "未知错误")"
        }
    }
    
    /// 恢复建议
    public var recoverySuggestion: String? {
        switch self {
        case .notFound:
            return "请检查输入的标识符是否正确"
        case .fetchFailed:
            return "请检查网络连接和数据库状态"
        case .saveFailed, .updateFailed:
            return "请检查数据是否有效并重试"
        case .deleteFailed:
            return "请确保对象未被其他对象引用"
        case .migrationFailed:
            return "请尝试重新启动应用程序"
        case .modelNotFound:
            return "请检查数据模型是否存在并正确配置"
        case .storeNotFound:
            return "请检查数据存储路径是否正确"
        case .mergeConflict:
            return "请选择保留本地版本或远程版本"
        case .validationFailed:
            return "请检查输入数据是否符合要求"
        case .invalidManagedObject:
            return "请检查对象数据格式是否正确"
        case .unknown:
            return "请重新启动应用程序并联系支持团队"
        }
    }
    
    /// 实现Equatable协议，以便于测试
    public static func == (lhs: CoreDataError, rhs: CoreDataError) -> Bool {
        switch (lhs, rhs) {
        case (.notFound(let lhsMessage), .notFound(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.fetchFailed, .fetchFailed),
             (.saveFailed, .saveFailed),
             (.updateFailed, .updateFailed),
             (.deleteFailed, .deleteFailed),
             (.mergeConflict, .mergeConflict),
             (.unknown, .unknown):
            return true
        case (.migrationFailed(let lhsMessage), .migrationFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.modelNotFound(let lhsMessage), .modelNotFound(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.storeNotFound(let lhsMessage), .storeNotFound(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.validationFailed(let lhsMessage), .validationFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.invalidManagedObject(let lhsMessage), .invalidManagedObject(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    /// 从NSError转换为CoreDataError
    public static func from(_ error: NSError) -> CoreDataError {
        switch error.domain {
        case NSCocoaErrorDomain:
            return fromCocoaError(error)
        default:
            return .unknown(error)
        }
    }
    
    /// 从Cocoa错误转换为CoreDataError
    private static func fromCocoaError(_ error: NSError) -> CoreDataError {
        // CoreData错误常量
        let NSValidationErrorMinimum = 1550
        let NSValidationErrorMaximum = 1569
        let NSPersistentStoreErrorMinimum = 134000
        let NSPersistentStoreErrorMaximum = 134099
        let NSManagedObjectConstraintErrorMinimum = 133000
        let NSManagedObjectConstraintErrorMaximum = 133099
        let NSCoreDataErrorMinimum = 1550
        let NSCoreDataErrorMaximum = 1599
        
        // 根据错误码确定错误类型
        switch error.code {
        case NSValidationErrorMinimum...NSValidationErrorMaximum:
            // 验证错误
            let entity = error.userInfo["NSValidationErrorKey"] as? String ?? "未知实体"
            let value = error.userInfo["NSValidationErrorValue"] ?? "未知值"
            return .validationFailed("实体: \(entity), 值: \(value), 错误: \(error.localizedDescription)")
            
        case NSPersistentStoreErrorMinimum...NSPersistentStoreErrorMaximum:
            // 持久化存储错误
            if error.code == NSPersistentStoreIncompatibleVersionHashError {
                return .migrationFailed("存储版本不兼容: \(error.localizedDescription)")
            } else if error.code == NSPersistentStoreOpenError {
                return .storeNotFound("无法打开存储: \(error.localizedDescription)")
            } else if error.code == NSPersistentStoreSaveError {
                return .saveFailed(error)
            } else {
                return .saveFailed(error)
            }
            
        case NSManagedObjectConstraintErrorMinimum...NSManagedObjectConstraintErrorMaximum:
            // 约束错误
            return .saveFailed(error)
            
        case NSCoreDataErrorMinimum...NSCoreDataErrorMaximum:
            // 其他CoreData错误
            if error.code == NSManagedObjectValidationError {
                return .validationFailed(error.localizedDescription)
            } else if error.code == NSManagedObjectContextLockingError {
                return .saveFailed(error)
            } else if error.code == NSPersistentStoreCoordinatorLockingError {
                return .saveFailed(error)
            } else if error.code == NSManagedObjectMergeError {
                return .mergeConflict(error)
            } else if error.code == NSManagedObjectReferentialIntegrityError {
                return .deleteFailed(error)
            } else if error.code == NSMigrationError {
                return .migrationFailed(error.localizedDescription)
            } else if error.code == NSMigrationMissingSourceModelError {
                return .modelNotFound("源模型未找到: \(error.localizedDescription)")
            } else if error.code == NSMigrationMissingMappingModelError {
                return .modelNotFound("映射模型未找到: \(error.localizedDescription)")
            } else {
                return .unknown(error)
            }
            
        default:
            // 尝试根据错误域进一步分类
            if error.domain == NSCocoaErrorDomain {
                // 常见的Cocoa错误
                if error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError {
                    return .storeNotFound("文件不存在: \(error.localizedDescription)")
                } else if error.code == NSFileReadUnknownError || error.code == NSFileWriteUnknownError {
                    return .saveFailed(error)
                }
            }
            
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