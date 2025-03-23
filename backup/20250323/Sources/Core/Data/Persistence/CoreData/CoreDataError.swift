import Foundation

/// Core Data 错误类型
public enum CoreDataError: LocalizedError {
    case migrationFailed(String)
    case modelNotFound(String)
    case storeNotFound(String)
    case invalidStore(String)
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case updateFailed(String)
    case notFound(String)
    case invalidManagedObject(String)
    
    public var errorDescription: String? {
        switch self {
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        case .modelNotFound(let message):
            return "Model not found: \(message)"
        case .storeNotFound(let message):
            return "Store not found: \(message)"
        case .invalidStore(let message):
            return "Invalid store: \(message)"
        case .saveFailed(let message):
            return "Save failed: \(message)"
        case .fetchFailed(let message):
            return "Fetch failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        case .updateFailed(let message):
            return "Update failed: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        case .invalidManagedObject(let message):
            return "Invalid managed object: \(message)"
        }
    }
}

/// Core Data 错误处理器
final class CoreDataErrorHandler {
    static let shared = CoreDataErrorHandler()
    
    private init() {}
    
    /// 处理 Core Data 错误
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误发生的上下文描述
    func handle(_ error: Error, context: String) {
        let nsError = error as NSError
        
        // 根据错误类型进行处理
        switch nsError.domain {
        case NSCocoaErrorDomain:
            handleCocoaError(nsError, context: context)
        case NSCoreDataErrorDomain:
            handleCoreDataError(nsError, context: context)
        default:
            handleGenericError(nsError, context: context)
        }
        
        // 记录错误
        logError(error, context: context)
    }
    
    // MARK: - Private Methods
    
    private func handleCocoaError(_ error: NSError, context: String) {
        switch error.code {
        case NSValidationErrorMinimum...NSValidationErrorMaximum:
            // 处理验证错误
            handleValidationError(error, context: context)
        case NSManagedObjectConstraintValidationError:
            // 处理约束验证错误
            handleConstraintError(error, context: context)
        default:
            // 处理其他 Cocoa 错误
            handleGenericError(error, context: context)
        }
    }
    
    private func handleCoreDataError(_ error: NSError, context: String) {
        switch error.code {
        case NSPersistentStoreIncompatibleVersionHashError:
            // 处理存储版本不兼容错误
            handleMigrationError(error, context: context)
        case NSManagedObjectContextLockingError:
            // 处理上下文锁定错误
            handleLockingError(error, context: context)
        case NSPersistentStoreOperationError:
            // 处理持久化存储操作错误
            handleStoreOperationError(error, context: context)
        default:
            // 处理其他 Core Data 错误
            handleGenericError(error, context: context)
        }
    }
    
    private func handleValidationError(_ error: NSError, context: String) {
        // 实现验证错误的具体处理逻辑
        print("验证错误: \(error.localizedDescription), 上下文: \(context)")
    }
    
    private func handleConstraintError(_ error: NSError, context: String) {
        // 实现约束错误的具体处理逻辑
        print("约束错误: \(error.localizedDescription), 上下文: \(context)")
    }
    
    private func handleMigrationError(_ error: NSError, context: String) {
        // 实现迁移错误的具体处理逻辑
        print("迁移错误: \(error.localizedDescription), 上下文: \(context)")
    }
    
    private func handleLockingError(_ error: NSError, context: String) {
        // 实现锁定错误的具体处理逻辑
        print("锁定错误: \(error.localizedDescription), 上下文: \(context)")
    }
    
    private func handleStoreOperationError(_ error: NSError, context: String) {
        // 实现存储操作错误的具体处理逻辑
        print("存储操作错误: \(error.localizedDescription), 上下文: \(context)")
    }
    
    private func handleGenericError(_ error: NSError, context: String) {
        // 实现通用错误的具体处理逻辑
        print("通用错误: \(error.localizedDescription), 上下文: \(context)")
    }
    
    private func logError(_ error: Error, context: String) {
        // 实现错误日志记录逻辑
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        print("[\(timestamp)] 错误: \(error.localizedDescription), 上下文: \(context)")
    }
} 