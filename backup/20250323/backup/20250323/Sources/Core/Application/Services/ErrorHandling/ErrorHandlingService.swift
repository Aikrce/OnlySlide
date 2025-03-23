import Foundation
import Logging

/// 错误处理服务
public final class ErrorHandlingService {
    // MARK: - Properties
    private let logger = Logger(label: "com.onlyslide.errorhandling")
    
    // MARK: - Initialization
    public init() {
        logger.info("初始化错误处理服务")
    }
    
    // MARK: - Public Methods
    /// 处理错误
    /// - Parameters:
    ///   - error: 错误
    ///   - source: 错误来源
    ///   - action: 错误发生时的操作
    ///   - shouldPropagate: 是否应该传播错误
    /// - Returns: 是否成功处理错误
    public func handleError(_ error: Error, source: String, action: String, shouldPropagate: Bool = true) -> Bool {
        logger.error("处理错误: \(error.localizedDescription), 来源: \(source), 操作: \(action)")
        
        // 1. 记录错误
        logError(error, source: source, action: action)
        
        // 2. 分析错误是否可恢复
        let isRecoverable = analyzeRecoverability(error)
        
        // 3. 尝试恢复
        if isRecoverable {
            attemptRecovery(error, source: source, action: action)
        }
        
        // 4. 如果需要，传播错误
        if shouldPropagate {
            propagateError(error, source: source, action: action)
        }
        
        return isRecoverable
    }
    
    /// 记录错误
    /// - Parameters:
    ///   - error: 错误
    ///   - source: 错误来源
    ///   - action: 错误发生时的操作
    public func logError(_ error: Error, source: String, action: String) {
        let errorDetails = """
        错误类型: \(type(of: error))
        错误描述: \(error.localizedDescription)
        错误来源: \(source)
        操作: \(action)
        时间: \(Date())
        """
        
        logger.error("\(errorDetails)")
        
        // 这里可以添加更复杂的日志记录逻辑，如保存到文件、发送到服务器等
    }
    
    // MARK: - Private Methods
    /// 分析错误是否可恢复
    /// - Parameter error: 错误
    /// - Returns: 是否可恢复
    private func analyzeRecoverability(_ error: Error) -> Bool {
        // 根据错误类型判断是否可恢复
        if let appError = error as? AppError {
            switch appError {
            case .networkError, .temporaryFailure:
                return true
            case .authenticationError, .validationError, .dataError:
                return true
            case .criticalError, .systemError:
                return false
            }
        }
        
        // 默认不可恢复
        return false
    }
    
    /// 尝试恢复
    /// - Parameters:
    ///   - error: 错误
    ///   - source: 错误来源
    ///   - action: 错误发生时的操作
    private func attemptRecovery(_ error: Error, source: String, action: String) {
        logger.info("尝试从错误恢复: \(error.localizedDescription)")
        
        if let appError = error as? AppError {
            switch appError {
            case .networkError:
                // 网络错误恢复策略
                logger.info("应用网络恢复策略")
                
            case .temporaryFailure:
                // 临时失败恢复策略
                logger.info("应用临时失败恢复策略")
                
            case .authenticationError:
                // 身份验证错误恢复策略
                logger.info("应用身份验证恢复策略")
                
            case .validationError:
                // 验证错误恢复策略
                logger.info("应用验证恢复策略")
                
            case .dataError:
                // 数据错误恢复策略
                logger.info("应用数据恢复策略")
                
            default:
                logger.warning("没有为此错误类型定义恢复策略: \(appError)")
            }
        } else {
            logger.warning("未知错误类型，无法应用特定恢复策略")
        }
    }
    
    /// 传播错误
    /// - Parameters:
    ///   - error: 错误
    ///   - source: 错误来源
    ///   - action: 错误发生时的操作
    private func propagateError(_ error: Error, source: String, action: String) {
        logger.info("传播错误: \(error.localizedDescription), 来源: \(source), 操作: \(action)")
        
        // 在实际应用中，这里可能会将错误发送到UI层显示，或通知其他系统组件
        // 例如，可以使用通知中心发布错误通知
        let errorInfo: [String: Any] = [
            "error": error,
            "source": source,
            "action": action,
            "timestamp": Date()
        ]
        
        NotificationCenter.default.post(
            name: .errorOccurred,
            object: nil,
            userInfo: errorInfo
        )
    }
}

// MARK: - Notification Names
public extension Notification.Name {
    /// 错误发生通知
    static let errorOccurred = Notification.Name("com.onlyslide.errorOccurred")
}

// MARK: - 应用错误类型
public enum AppError: Error {
    case networkError(String)
    case authenticationError(String)
    case validationError(String)
    case dataError(String)
    case temporaryFailure(String)
    case systemError(String)
    case criticalError(String)
}

// MARK: - LocalizedError
extension AppError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "网络错误: \(message)"
        case .authenticationError(let message):
            return "身份验证错误: \(message)"
        case .validationError(let message):
            return "验证错误: \(message)"
        case .dataError(let message):
            return "数据错误: \(message)"
        case .temporaryFailure(let message):
            return "临时失败: \(message)"
        case .systemError(let message):
            return "系统错误: \(message)"
        case .criticalError(let message):
            return "严重错误: \(message)"
        }
    }
} 