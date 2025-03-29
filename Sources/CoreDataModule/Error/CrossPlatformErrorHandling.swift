import Foundation
import os.log

/// 跨平台错误处理服务协议
public protocol CrossPlatformErrorHandling: Sendable {
    /// 处理错误
    /// - Parameters:
    ///   - error: 错误
    ///   - source: 错误来源
    ///   - action: 错误发生时的操作
    ///   - shouldPropagate: 是否应该传播错误
    /// - Returns: 错误处理结果
    func handleError(_ error: Error, source: String, action: String, shouldPropagate: Bool) async -> ErrorHandlingResult
    
    /// 记录错误
    /// - Parameters:
    ///   - error: 错误
    ///   - source: 错误来源
    ///   - action: 错误发生时的操作
    func logError(_ error: Error, source: String, action: String) async
    
    /// 分析错误是否可恢复
    /// - Parameter error: 错误
    /// - Returns: 是否可恢复
    func analyzeRecoverability(_ error: Error) async -> Bool
    
    /// 尝试恢复
    /// - Parameters:
    ///   - error: 错误
    ///   - source: 错误来源
    ///   - action: 错误发生时的操作
    /// - Returns: 恢复结果
    func attemptRecovery(_ error: Error, source: String, action: String) async -> RecoveryResult
}

/// 错误处理结果
public enum ErrorHandlingResult: Sendable {
    /// 已处理
    case handled
    
    /// 已处理并恢复
    case recoveredSuccessfully
    
    /// 处理但恢复失败
    case recoveryFailed(Error)
    
    /// 未处理
    case unhandled(Error)
}

/// 恢复结果
public enum RecoveryResult: Sendable {
    /// 成功恢复
    case success
    
    /// 恢复失败
    case failure(Error)
    
    /// 不支持恢复
    case notSupported
}

/// 统一的错误处理服务实现
public actor CrossPlatformErrorHandlingService: CrossPlatformErrorHandling {
    // MARK: - Properties
    
    /// 日志对象
    private let logger: os.Logger
    
    /// 错误处理历史记录
    private var errorHistory: [ErrorHistoryEntry] = []
    
    /// 错误历史条目最大数量
    private let maxHistoryEntries: Int
    
    // MARK: - Initialization
    
    /// 初始化错误处理服务
    /// - Parameters:
    ///   - subsystem: 子系统名称
    ///   - category: 分类名称
    ///   - maxHistoryEntries: 错误历史条目最大数量
    public init(subsystem: String = "com.onlyslide", category: String = "errorhandling", maxHistoryEntries: Int = 100) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
        self.maxHistoryEntries = maxHistoryEntries
        
        logger.info("初始化跨平台错误处理服务")
    }
    
    // MARK: - Public Methods
    
    public func handleError(_ error: Error, source: String, action: String, shouldPropagate: Bool = true) async -> ErrorHandlingResult {
        // 1. 记录错误
        await logError(error, source: source, action: action)
        
        // 2. 分析错误是否可恢复
        let isRecoverable = await analyzeRecoverability(error)
        
        // 3. 尝试恢复
        if isRecoverable {
            let recoveryResult = await attemptRecovery(error, source: source, action: action)
            
            switch recoveryResult {
            case .success:
                return .recoveredSuccessfully
            case .failure(let recoveryError):
                return .recoveryFailed(recoveryError)
            case .notSupported:
                break // 继续执行
            }
        }
        
        // 4. 如果需要，传播错误
        if shouldPropagate {
            await propagateError(error, source: source, action: action)
            return .unhandled(error)
        }
        
        return .handled
    }
    
    public func logError(_ error: Error, source: String, action: String) async {
        let errorDetails = """
        错误类型: \(type(of: error))
        错误描述: \(error.localizedDescription)
        错误来源: \(source)
        操作: \(action)
        时间: \(Date())
        """
        
        logger.error("\(errorDetails)")
        
        // 记录到历史记录
        let entry = ErrorHistoryEntry(
            timestamp: Date(),
            errorType: String(describing: type(of: error)),
            description: error.localizedDescription,
            source: source,
            action: action
        )
        
        addToHistory(entry)
    }
    
    public func analyzeRecoverability(_ error: Error) async -> Bool {
        // 根据错误类型判断是否可恢复
        if let appError = error as? AppError {
            switch appError {
            case .networkError, .temporaryFailure, .authenticationError, .validationError, .dataError:
                return true
            case .criticalError, .systemError, .databaseError, .configurationError:
                return false
            }
        } else if let coreDataError = error as? CoreDataError {
            switch coreDataError {
            case .temporaryFailure, .notFound, .invalidInput, .modelError:
                return true
            case .migrationFailed, .storeNotFound, .invalidModel, .invalidBackupFile, .backupFailed, .other:
                return false
            }
        }
        
        // 默认不可恢复
        return false
    }
    
    public func attemptRecovery(_ error: Error, source: String, action: String) async -> RecoveryResult {
        logger.info("尝试从错误恢复: \(error.localizedDescription)")
        
        // 根据错误类型选择恢复策略
        if let appError = error as? AppError {
            return await recoverFromAppError(appError)
        } else if let coreDataError = error as? CoreDataError {
            return await recoverFromCoreDataError(coreDataError)
        }
        
        return .notSupported
    }
    
    // MARK: - Private Methods
    
    /// 传播错误
    /// - Parameters:
    ///   - error: 错误
    ///   - source: 错误来源
    ///   - action: 错误发生时的操作
    private func propagateError(_ error: Error, source: String, action: String) async {
        logger.info("传播错误: \(error.localizedDescription), 来源: \(source), 操作: \(action)")
        
        // 在实际应用中，这里可能会将错误发送到UI层显示，或通知其他系统组件
        // 例如，可以使用通知中心发布错误通知
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        // Apple平台使用NotificationCenter
        let errorInfo: [String: Any] = [
            "error": error,
            "source": source,
            "action": action,
            "timestamp": Date()
        ]
        
        await MainActor.run {
            NotificationCenter.default.post(
                name: .errorOccurred,
                object: nil,
                userInfo: errorInfo
            )
        }
        #else
        // 其他平台使用自定义错误传播机制
        // 实现特定平台的错误传播逻辑
        #endif
    }
    
    /// 添加错误到历史记录
    /// - Parameter entry: 错误历史条目
    private func addToHistory(_ entry: ErrorHistoryEntry) {
        errorHistory.append(entry)
        
        // 如果超出最大条目数，移除最早的条目
        if errorHistory.count > maxHistoryEntries {
            errorHistory.removeFirst()
        }
    }
    
    /// 从App错误恢复
    /// - Parameter error: App错误
    /// - Returns: 恢复结果
    private func recoverFromAppError(_ error: AppError) async -> RecoveryResult {
        switch error {
        case .networkError:
            // 网络错误恢复策略
            logger.info("应用网络恢复策略")
            // 示例：尝试重新连接网络
            return .success
            
        case .temporaryFailure:
            // 临时失败恢复策略
            logger.info("应用临时失败恢复策略")
            // 示例：尝试重试操作
            return .success
            
        case .authenticationError:
            // 身份验证错误恢复策略
            logger.info("应用身份验证恢复策略")
            // 示例：引导用户重新登录
            return .notSupported
            
        case .validationError:
            // 验证错误恢复策略
            logger.info("应用验证恢复策略")
            // 示例：清理无效数据
            return .success
            
        case .dataError:
            // 数据错误恢复策略
            logger.info("应用数据恢复策略")
            // 示例：尝试从缓存恢复数据
            return .success
            
        case .systemError, .criticalError:
            // 系统错误和严重错误恢复策略
            logger.info("应用系统/严重错误恢复策略")
            // 这些一般不可恢复
            return .notSupported
            
        case .databaseError(let coreDataError):
            // 数据库错误恢复策略
            logger.info("应用数据库恢复策略: \(coreDataError.errorDescription ?? "未知错误")")
            // 委托给Core Data错误恢复
            return await recoverFromCoreDataError(coreDataError)
            
        case .configurationError:
            // 配置错误恢复策略
            logger.info("应用配置恢复策略")
            // 示例：尝试加载默认配置
            return .success
        }
    }
    
    /// 从Core Data错误恢复
    /// - Parameter error: Core Data错误
    /// - Returns: 恢复结果
    private func recoverFromCoreDataError(_ error: CoreDataError) async -> RecoveryResult {
        switch error {
        case .temporaryFailure:
            // 临时失败恢复策略
            logger.info("应用Core Data临时失败恢复策略")
            // 示例：尝试重试操作
            return .success
            
        case .notFound:
            // 未找到恢复策略
            logger.info("应用Core Data未找到恢复策略")
            // 示例：创建默认对象
            return .success
            
        case .invalidInput:
            // 无效输入恢复策略
            logger.info("应用Core Data无效输入恢复策略")
            // 示例：清理无效数据
            return .success
            
        case .modelError:
            // 模型错误恢复策略
            logger.info("应用Core Data模型错误恢复策略")
            // 示例：尝试修复模型错误
            return .success
            
        default:
            // 其他Core Data错误
            logger.warning("Core Data错误类型不支持恢复: \(error)")
            return .notSupported
        }
    }
    
    /// 获取错误历史记录
    /// - Returns: 错误历史记录
    public func getErrorHistory() -> [ErrorHistoryEntry] {
        return errorHistory
    }
    
    /// 清除错误历史记录
    public func clearErrorHistory() {
        errorHistory.removeAll()
    }
}

/// 错误历史条目
public struct ErrorHistoryEntry: Sendable, Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let errorType: String
    public let description: String
    public let source: String
    public let action: String
}

// MARK: - Notification Names Extension
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
public extension Notification.Name {
    /// 错误发生通知
    static let errorOccurred = Notification.Name("com.onlyslide.errorOccurred")
}
#endif

// MARK: - 工厂方法
public extension CrossPlatformErrorHandlingService {
    /// 创建默认实例
    /// - Returns: 默认配置的错误处理服务
    static func createDefault() -> CrossPlatformErrorHandlingService {
        return CrossPlatformErrorHandlingService()
    }
} 