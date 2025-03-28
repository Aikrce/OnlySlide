import Foundation
import Combine
import CoreData
import os

/// 定义错误处理策略
public enum ErrorHandlingStrategy {
    /// 自动重试
    case retry(maxAttempts: Int, delay: TimeInterval)
    /// 备份和恢复
    case backupAndRestore
    /// 用户交互
    case userInteraction
    /// 仅记录
    case logOnly
    /// 默认策略
    case `default`
}

/// 定义错误严重程度
public enum ErrorSeverity: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    case fatal = 5
    
    public static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// 核心数据错误管理器
/// 提供集中的错误处理、记录和恢复机制
@MainActor
public final class CoreDataErrorManager: @unchecked Sendable {
    // MARK: - 单例
    
    /// 共享实例
    public static let shared = CoreDataErrorManager()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "ErrorManager")
    
    /// 错误处理器
    private let errorHandler = CoreDataErrorHandler.shared
    
    /// 错误发布者
    private let errorSubject = PassthroughSubject<(Error, String), Never>()
    
    /// 公开的错误发布者
    public var errorPublisher: AnyPublisher<(Error, String), Never> {
        return errorSubject.eraseToAnyPublisher()
    }
    
    /// 指示是否正在处理恢复过程的标志
    private var isRecovering = false
    
    /// 注册的错误处理策略
    private var errorStrategies: [String: ErrorHandlingStrategy] = [:]
    
    /// 错误计数器
    private var errorCounts: [String: Int] = [:]
    
    /// 错误时间戳
    private var errorTimestamps: [String: Date] = [:]
    
    /// 错误恢复策略提供者
    private let recoveryProvider = CoreDataRecoveryStrategies()
    
    // MARK: - 初始化
    
    private init() {
        setupDefaultStrategies()
    }
    
    // MARK: - 公共方法
    
    /// 处理错误
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误上下文描述
    ///   - file: 发生错误的文件
    ///   - line: 发生错误的行
    ///   - function: 发生错误的函数
    public func handle(_ error: Error, context: String, file: String = #file, line: Int = #line, function: String = #function) {
        // 创建错误ID
        let errorIdentifier = createErrorIdentifier(error: error, context: context)
        
        // 增加错误计数
        incrementErrorCount(for: errorIdentifier)
        
        // 记录错误
        logError(error, context: context, file: file, line: line, function: function)
        
        // 发布错误通知
        errorSubject.send((error, context))
        
        // 应用恢复策略
        applyRecoveryStrategy(for: error, context: context, errorIdentifier: errorIdentifier)
    }
    
    /// 处理错误并返回结果
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误上下文描述
    ///   - file: 发生错误的文件
    ///   - line: 发生错误的行
    ///   - function: 发生错误的函数
    /// - Returns: 处理后的错误对象
    public func handleAndReturn(_ error: Error, context: String, file: String = #file, line: Int = #line, function: String = #function) -> CoreDataError {
        // 处理错误
        handle(error, context: context, file: file, line: line, function: function)
        
        // 转换错误并返回
        return errorHandler.convert(error)
    }
    
    /// 处理错误并抛出
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误上下文描述
    ///   - file: 发生错误的文件
    ///   - line: 发生错误的行
    ///   - function: 发生错误的函数
    /// - Throws: 处理后的错误对象
    public func handleAndThrow(_ error: Error, context: String, file: String = #file, line: Int = #line, function: String = #function) throws {
        // 处理错误
        let convertedError = handleAndReturn(error, context: context, file: file, line: line, function: function)
        
        // 抛出错误
        throw convertedError
    }
    
    /// 注册错误处理策略
    /// - Parameters:
    ///   - strategy: 错误处理策略
    ///   - errorType: 错误类型
    ///   - context: 错误上下文描述
    public func registerStrategy(_ strategy: ErrorHandlingStrategy, for errorType: String, context: String? = nil) {
        let key = createStrategyKey(errorType: errorType, context: context)
        errorStrategies[key] = strategy
        logger.debug("已注册错误处理策略: \(strategy) 用于 \(key)")
    }
    
    /// 重置错误统计
    public func resetErrorStatistics() {
        errorCounts.removeAll()
        errorTimestamps.removeAll()
        logger.debug("已重置错误统计")
    }
    
    /// 获取错误严重程度
    /// - Parameter error: 错误对象
    /// - Returns: 错误严重程度
    public func getSeverity(for error: Error) -> ErrorSeverity {
        if let coreDataError = error as? CoreDataError {
            switch coreDataError {
            case .notFound, .fetchFailed:
                return .warning
            case .saveFailed, .updateFailed, .deleteFailed, .mergeConflict:
                return .error
            case .migrationFailed, .modelNotFound, .storeNotFound:
                return .critical
            case .validationFailed, .invalidManagedObject:
                return .warning
            case .unknown:
                return .error
            }
        } else if (error as NSError).domain == NSCocoaErrorDomain {
            return .error
        } else {
            return .warning
        }
    }
    
    /// 处理Core Data错误
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 上下文描述（例如"保存操作"）
    ///   - completion: 完成回调，传递是否成功恢复
    public func handleError(_ error: Error, context: String, completion: @escaping (Bool) -> Void) {
        // 将错误转换为CoreDataError类型
        let coreDataError: CoreDataError
        if let cde = error as? CoreDataError {
            coreDataError = cde
        } else if let nsError = error as? NSError {
            coreDataError = CoreDataError.from(nsError)
        } else {
            coreDataError = .unknown(error)
        }
        
        // 记录错误
        logger.error("\(context) 发生错误: \(coreDataError.errorDescription ?? "未知错误")")
        
        // 尝试获取恢复策略
        if let strategy = recoveryProvider.strategyFor(error: coreDataError) {
            // 执行恢复策略
            strategy.execute { success in
                if success {
                    self.logger.info("成功恢复 \(context) 的错误")
                } else {
                    self.logger.error("无法恢复 \(context) 的错误")
                }
                completion(success)
            }
        } else {
            logger.warning("没有找到 \(context) 错误的恢复策略")
            completion(false)
        }
    }
    
    /// 异步处理Core Data错误
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 上下文描述
    /// - Returns: 是否成功恢复
    public func handleError(_ error: Error, context: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            handleError(error, context: context) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// 记录错误但不尝试恢复
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 上下文描述
    public func logError(_ error: Error, context: String) {
        // 将错误转换为CoreDataError类型
        let coreDataError: CoreDataError
        if let cde = error as? CoreDataError {
            coreDataError = cde
        } else if let nsError = error as? NSError {
            coreDataError = CoreDataError.from(nsError)
        } else {
            coreDataError = .unknown(error)
        }
        
        // 记录错误
        logger.error("\(context) 发生错误: \(coreDataError.errorDescription ?? "未知错误")")
    }
    
    /// 创建并记录错误
    /// - Parameters:
    ///   - errorType: CoreDataError类型
    ///   - context: 上下文描述
    /// - Returns: 创建的错误
    public func createAndLogError(_ errorType: CoreDataError, context: String) -> CoreDataError {
        logger.error("\(context) 发生错误: \(errorType.errorDescription ?? "未知错误")")
        return errorType
    }
    
    // MARK: - 辅助方法
    
    /// 创建错误标识符
    private func createErrorIdentifier(error: Error, context: String) -> String {
        let errorTypeString: String
        if let coreDataError = error as? CoreDataError {
            errorTypeString = String(describing: type(of: coreDataError)) + "." + String(describing: coreDataError)
        } else {
            let nsError = error as NSError
            errorTypeString = nsError.domain + "." + String(nsError.code)
        }
        
        return "\(errorTypeString):\(context)"
    }
    
    /// 创建策略键
    private func createStrategyKey(errorType: String, context: String?) -> String {
        if let context = context {
            return "\(errorType):\(context)"
        } else {
            return errorType
        }
    }
    
    /// 增加错误计数
    private func incrementErrorCount(for identifier: String) {
        errorCounts[identifier] = (errorCounts[identifier] ?? 0) + 1
        errorTimestamps[identifier] = Date()
    }
    
    /// 获取错误计数
    private func getErrorCount(for identifier: String) -> Int {
        return errorCounts[identifier] ?? 0
    }
    
    /// 获取上次错误时间
    private func getLastErrorTime(for identifier: String) -> Date? {
        return errorTimestamps[identifier]
    }
    
    /// 记录错误
    private func logError(_ error: Error, context: String, file: String, line: Int, function: String) {
        let fileURL = URL(fileURLWithPath: file)
        let fileName = fileURL.lastPathComponent
        
        // 获取错误严重程度
        let severity = getSeverity(for: error)
        
        // 根据严重程度选择日志级别
        switch severity {
        case .debug:
            logger.debug("[\(context)] \(error.localizedDescription) (\(fileName):\(line), \(function))")
        case .info:
            logger.info("[\(context)] \(error.localizedDescription) (\(fileName):\(line), \(function))")
        case .warning:
            logger.warning("[\(context)] \(error.localizedDescription) (\(fileName):\(line), \(function))")
        case .error, .critical:
            logger.error("[\(context)] \(error.localizedDescription) (\(fileName):\(line), \(function))")
        case .fatal:
            logger.critical("[\(context)] \(error.localizedDescription) (\(fileName):\(line), \(function))")
        }
    }
    
    /// 应用恢复策略
    private func applyRecoveryStrategy(for error: Error, context: String, errorIdentifier: String) {
        // 防止恢复过程中递归处理错误
        guard !isRecovering else {
            logger.warning("错误恢复过程中发生新错误，跳过恢复策略: \(error.localizedDescription)")
            return
        }
        
        // 设置恢复标志
        isRecovering = true
        
        // 获取策略
        let strategy = getStrategy(for: error, context: context)
        
        // 应用策略
        switch strategy {
        case .retry(let maxAttempts, let delay):
            // 检查重试次数
            let count = getErrorCount(for: errorIdentifier)
            if count <= maxAttempts {
                logger.info("将在 \(delay) 秒后重试操作 (尝试 \(count)/\(maxAttempts))")
                
                // 延迟后重试
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    retryOperation(for: errorIdentifier)
                }
            } else {
                logger.warning("已达到最大重试次数 (\(maxAttempts))，不再重试")
            }
            
        case .backupAndRestore:
            // 实现备份和恢复逻辑
            performBackupAndRestore(for: error, context: context)
            
        case .userInteraction:
            // 通知用户界面请求用户交互
            // 例如通过发布者通知UI层显示错误对话框
            logger.info("请求用户交互以处理错误")
            
        case .logOnly:
            // 只记录错误，不做其他处理
            logger.info("仅记录错误，不执行恢复策略")
            
        case .default:
            // 默认策略
            applyDefaultRecoveryStrategy(for: error, context: context)
        }
        
        // 重置恢复标志
        isRecovering = false
    }
    
    /// 获取错误处理策略
    private func getStrategy(for error: Error, context: String) -> ErrorHandlingStrategy {
        // 尝试获取特定错误和上下文的策略
        let errorTypeString: String
        if let coreDataError = error as? CoreDataError {
            errorTypeString = String(describing: type(of: coreDataError)) + "." + String(describing: coreDataError)
        } else {
            let nsError = error as NSError
            errorTypeString = nsError.domain + "." + String(nsError.code)
        }
        
        // 尝试按优先级获取策略
        if let strategy = errorStrategies["\(errorTypeString):\(context)"] {
            return strategy
        } else if let strategy = errorStrategies[errorTypeString] {
            return strategy
        } else if let strategy = errorStrategies[context] {
            return strategy
        } else {
            return .default
        }
    }
    
    /// 设置默认错误处理策略
    private func setupDefaultStrategies() {
        // 默认重试策略 - 网络和临时错误
        registerStrategy(.retry(maxAttempts: 3, delay: 1.0), for: "NSURLErrorDomain")
        
        // 默认备份和恢复策略 - 数据损坏
        registerStrategy(.backupAndRestore, for: "CoreDataError.storeNotFound")
        registerStrategy(.backupAndRestore, for: "CoreDataError.migrationFailed")
        
        // 默认用户交互策略 - 验证错误
        registerStrategy(.userInteraction, for: "CoreDataError.validationFailed")
        
        // 默认只记录策略 - 非关键错误
        registerStrategy(.logOnly, for: "CoreDataError.notFound")
    }
    
    /// 应用默认恢复策略
    private func applyDefaultRecoveryStrategy(for error: Error, context: String) {
        if let coreDataError = error as? CoreDataError {
            switch coreDataError {
            case .notFound, .fetchFailed:
                // 对于获取失败，默认不执行特殊恢复
                logger.info("默认策略: 获取失败或对象未找到，不执行特殊恢复")
                
            case .saveFailed, .updateFailed:
                // 尝试重新加载上下文
                logger.info("默认策略: 保存或更新失败，尝试重新加载上下文")
                
            case .deleteFailed:
                // 为删除失败提供建议
                logger.info("默认策略: 删除失败，可能存在引用问题")
                
            case .migrationFailed, .modelNotFound, .storeNotFound:
                // 严重错误，需要用户干预
                logger.warning("默认策略: 数据迁移或存储问题，需要用户干预")
                
            case .mergeConflict:
                // 合并冲突策略
                logger.info("默认策略: 合并冲突，采用自动解决方案")
                
            case .validationFailed, .invalidManagedObject:
                // 数据验证错误
                logger.info("默认策略: 数据验证失败，提供修复建议")
                
            case .unknown:
                // 未知错误处理
                logger.warning("默认策略: 未知错误，记录并监控")
            }
        } else {
            // 非CoreDataError的处理
            logger.info("默认策略: 非CoreData错误，仅记录")
        }
    }
    
    /// 重试操作
    private func retryOperation(for errorIdentifier: String) {
        // 这里应该实现实际的重试逻辑
        // 通常需要保存失败的操作上下文，并在此处重新执行
        logger.info("重试操作: \(errorIdentifier)")
        
        // 实现示例：可以使用字典存储需要重试的闭包
        // retryOperations[errorIdentifier]?()
    }
    
    /// 执行备份和恢复
    private func performBackupAndRestore(for error: Error, context: String) {
        // 实现备份和恢复逻辑
        logger.info("执行备份和恢复流程")
        
        // 例如：调用CoreDataResourceManager的备份功能
        // CoreDataResourceManager.shared.backupStore()
        // 然后尝试恢复或重建
    }
} 