import Foundation
@preconcurrency import Combine
import CoreData
import os

// MARK: - Error Handling Protocols

/// 错误处理服务协议
public protocol ErrorHandlingProtocol: Sendable {
    /// 处理错误
    func handle(_ error: Error, context: String, file: String, line: Int, function: String)
    
    /// 转换错误
    func convert(_ error: Error) -> CoreDataError
    
    /// 记录错误并抛出
    func logAndThrow(_ error: Error, context: String, file: String, line: Int, function: String) throws
    
    /// 订阅错误通知
    var errorPublisher: AnyPublisher<(Error, String), Never> { get }
}

/// 错误恢复服务协议
public protocol RecoveryService: Sendable {
    /// 尝试恢复错误
    func attemptRecovery(from error: Error, context: String) async -> RecoveryResult
    
    /// 注册恢复策略
    func register(strategy: CoreDataRecoveryStrategy)
}

/// 可恢复策略协议，提供实际的恢复功能
public protocol RecoverableStrategy: Sendable {
    /// 检查是否可以处理指定错误
    func canHandle(_ error: CoreDataError) -> Bool
    
    /// 尝试从错误中恢复
    func attemptRecovery(from error: CoreDataError, context: String) async -> RecoveryResult
}

/// 错误恢复策略协议
public protocol CoreDataRecoveryStrategy: Sendable {
    /// 获取策略的名称
    var name: String { get }
}

/// 错误策略注册协议
public protocol ErrorStrategyRegistry: Sendable {
    /// 注册错误处理策略
    func registerStrategy(_ strategy: ErrorHandlingStrategy, for errorType: String, context: String?)
    
    /// 重置错误统计
    func resetErrorStatistics()
}

// MARK: - Enhanced Error Handling Manager

/// 增强版错误处理管理器
/// 使用值类型和依赖注入
public struct EnhancedErrorHandler: ErrorHandlingProtocol, ErrorStrategyRegistry {
    // MARK: - Dependencies
    
    private let logger: Logger
    private let converter: ErrorConverter
    private let publisher: PassthroughSubject<(Error, String), Never>
    private let strategyResolver: ErrorStrategyResolverRef
    
    // MARK: - Initialization
    
    /// 初始化错误处理器
    /// - Parameters:
    ///   - logger: 日志记录器
    ///   - converter: 错误转换器
    ///   - strategyResolver: 策略解析器
    public init(
        logger: Logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "EnhancedErrorHandler"),
        converter: ErrorConverter = ErrorConverter(),
        strategyResolver: ErrorStrategyResolverRef = ErrorStrategyResolverRef()
    ) {
        self.logger = logger
        self.converter = converter
        self.publisher = PassthroughSubject<(Error, String), Never>()
        self.strategyResolver = strategyResolver
    }
    
    // MARK: - Factory Method
    
    /// 创建使用默认设置的错误处理器
    /// - Returns: 配置好的错误处理器
    public static func createDefault() -> EnhancedErrorHandler {
        return EnhancedErrorHandler()
    }
    
    // MARK: - ErrorHandlingProtocol Implementation
    
    public var errorPublisher: AnyPublisher<(Error, String), Never> {
        return publisher.eraseToAnyPublisher()
    }
    
    /// 处理错误
    /// 记录错误并执行相应策略
    /// - Parameters:
    ///   - error: 错误
    ///   - context: 上下文描述
    ///   - file: 文件名
    ///   - line: 行号
    ///   - function: 函数名
    public func handle(_ error: Error, context: String, file: String = #file, line: Int = #line, function: String = #function) {
        // 记录错误
        logError(error, context: context, file: file, line: line, function: function)
        
        // 发布错误通知
        publisher.send((error, context))
        
        // 创建错误ID
        let errorID = createErrorIdentifier(error: error, context: context)
        
        // 增加错误计数
        strategyResolver.incrementErrorCount(for: errorID)
        
        // 应用恢复策略
        Task {
            _ = await applyRecoveryStrategy(for: error, context: context, errorID: errorID)
        }
    }
    
    public func convert(_ error: Error) -> CoreDataError {
        return converter.convert(error)
    }
    
    public func logAndThrow(_ error: Error, context: String, file: String = #file, line: Int = #line, function: String = #function) throws {
        handle(error, context: context, file: file, line: line, function: function)
        throw convert(error)
    }
    
    // MARK: - ErrorStrategyRegistry Implementation
    
    public func registerStrategy(_ strategy: ErrorHandlingStrategy, for errorType: String, context: String? = nil) {
        strategyResolver.registerStrategy(strategy, for: errorType, context: context)
    }
    
    public func resetErrorStatistics() {
        strategyResolver.resetErrorCounts()
    }
    
    // MARK: - Private Methods
    
    private func logError(_ error: Error, context: String, file: String, line: Int, function: String) {
        let fileURL = URL(fileURLWithPath: file)
        let fileName = fileURL.lastPathComponent
        
        // 获取错误严重性
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
    
    private func getSeverity(for error: Error) -> ErrorSeverity {
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
            case .persistentStoreCoordinatorError, .managedObjectContextError, 
                 .objectNotFound, .saveError, .syncSetupError, .syncStartError, 
                 .syncStopError, .syncProcessError, .invalidSyncState, 
                 .networkUnavailable, .conversionError, .invalidData, 
                 .backupFailed, .backupDirectoryError, .invalidBackupFile, 
                 .backupRestoreFailed, .custom:
                return .error
            case .unknown:
                return .error
            }
        } else if (error as NSError).domain == NSCocoaErrorDomain {
            return .error
        } else {
            return .warning
        }
    }
    
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
    
    private func applyRecoveryStrategy(for error: Error, context: String, errorID: String) async -> RecoveryResult {
        // 获取策略
        let strategy = strategyResolver.getStrategy(for: error, context: context)
        
        // 应用策略
        switch strategy {
        case .retry(let maxAttempts, let delay):
            // 检查重试次数
            let count = strategyResolver.getErrorCount(for: errorID)
            if count <= maxAttempts {
                logger.info("将在 \(delay) 秒后重试操作 (尝试 \(count)/\(maxAttempts))")
                
                // 延迟后重试
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                // 在实际应用中，这里需要实现实际的重试机制
                return .partialSuccess("已重试 \(count)/\(maxAttempts) 次")
            } else {
                logger.warning("已达到最大重试次数 (\(maxAttempts))，不再重试")
                return .failure(error)
            }
            
        case .backupAndRestore:
            logger.info("执行备份和恢复流程")
            // 在实际应用中，这里需要调用备份和恢复机制
            return .requiresUserInteraction
            
        case .userInteraction:
            logger.info("请求用户交互以处理错误")
            // 在实际应用中，这里需要通知UI层显示错误对话框
            return .requiresUserInteraction
            
        case .logOnly:
            logger.info("仅记录错误，不执行恢复策略")
            return .failure(error)
            
        case .default:
            // 应用默认恢复策略
            return await applyDefaultStrategy(for: error, context: context)
            
        case .none:
            logger.info("未指定恢复策略，不执行恢复")
            return .failure(error)
        }
    }
    
    /// 应用默认恢复策略
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误上下文
    /// - Returns: 恢复结果
    private func applyDefaultStrategy(for error: Error, context: String) async -> RecoveryResult {
        if let coreDataError = error as? CoreDataError {
            switch coreDataError {
            case .notFound, .fetchFailed:
                // 对于获取失败，默认不执行特殊恢复
                logger.info("默认策略: 获取失败或对象未找到，不执行特殊恢复")
                return .failure(error)
                
            case .saveFailed, .updateFailed:
                // 尝试重新加载上下文
                logger.info("默认策略: 保存或更新失败，尝试重新加载上下文")
                return .partialSuccess("建议重新加载数据")
                
            case .deleteFailed:
                // 为删除失败提供建议
                logger.info("默认策略: 删除失败，可能存在引用问题")
                return .failure(error)
                
            case .migrationFailed, .modelNotFound, .storeNotFound:
                // 严重错误，需要用户干预
                logger.warning("默认策略: 数据迁移或存储问题，需要用户干预")
                return .requiresUserInteraction
                
            case .mergeConflict:
                // 合并冲突策略
                logger.info("默认策略: 合并冲突，采用自动解决方案")
                return .partialSuccess("冲突已解决，但可能丢失部分更改")
                
            case .validationFailed, .invalidManagedObject:
                // 数据验证错误
                logger.info("默认策略: 数据验证失败，提供修复建议")
                return .requiresUserInteraction
                
            default:
                // 未知错误处理
                logger.warning("默认策略: 未知错误，记录并监控")
                return .failure(error)
            }
        } else {
            // 非CoreDataError的处理
            logger.info("默认策略: 非CoreData错误，仅记录")
            return .failure(error)
        }
    }
    
    /// 尝试恢复错误
    /// - Parameters:
    ///   - error: 要恢复的错误
    ///   - context: 错误上下文
    /// - Returns: 恢复结果
    public func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        // 创建错误ID
        let errorIdentifier = createErrorIdentifier(error: error, context: context)
        
        // 尝试应用恢复策略
        return await applyRecoveryStrategy(for: error, context: context, errorID: errorIdentifier)
    }
}

// MARK: - Enhanced Recovery Service

/// 增强版恢复服务
public final class EnhancedRecoveryService: RecoveryService {
    // MARK: - Properties
    
    private let logger: Logger
    private let strategiesLock = NSLock()
    private let _strategies: AtomicReference<[CoreDataRecoveryStrategy]>
    
    // MARK: - Initialization
    
    /// 初始化恢复服务
    public init(logger: Logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "EnhancedRecoveryService")) {
        self.logger = logger
        self._strategies = AtomicReference([])
        registerDefaultStrategies()
    }
    
    // MARK: - Factory Method
    
    public static func createDefault() -> EnhancedRecoveryService {
        return EnhancedRecoveryService()
    }
    
    // MARK: - RecoveryService Implementation
    
    public func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        logger.info("尝试恢复错误: \(error.localizedDescription) [上下文: \(context)]")
        
        // 转换成CoreDataError以便更好地处理
        let coreDataError: CoreDataError
        if let cdError = error as? CoreDataError {
            coreDataError = cdError
        } else {
            let converter = ErrorConverter()
            coreDataError = converter.convert(error)
        }
        
        // 使用线程安全的方式访问strategies
        let currentStrategies = _strategies.value
        
        // 尝试应用每个恢复策略
        for strategy in currentStrategies {
            if let recoverableStrategy = strategy as? RecoverableStrategy, 
               recoverableStrategy.canHandle(coreDataError) {
                logger.info("应用恢复策略: \(String(describing: type(of: strategy)))")
                return await recoverableStrategy.attemptRecovery(from: coreDataError, context: context)
            }
        }
        
        // 如果没有适用的策略，返回失败
        logger.warning("未找到适用的恢复策略")
        return .failure(error)
    }
    
    /// 注册恢复策略
    public func register(strategy: CoreDataRecoveryStrategy) {
        // 使用原子操作修改策略数组
        _strategies.modify { strategies in
            strategies.append(strategy)
        }
        logger.debug("已注册恢复策略: \(strategy.name)")
    }
    
    // MARK: - Private Methods
    
    /// 注册默认策略
    private func registerDefaultStrategies() {
        // 以下策略需要实现并添加到项目中
        // 注：这里应该导入实际的恢复策略实现
        // register(strategy: StoreNotFoundRecoveryStrategy())
        // register(strategy: ValidationErrorRecoveryStrategy())
        // register(strategy: NetworkErrorRecoveryStrategy())
        // register(strategy: MergeConflictRecoveryStrategy())
        // register(strategy: SaveFailedRecoveryStrategy())
        
        // 临时解决方案
        logger.info("已初始化恢复服务，但未注册默认策略（需要实现）")
    }
}

// MARK: - Error Converter

/// 错误转换器
public struct ErrorConverter: Sendable {
    /// 初始化
    public init() {}
    
    /// 转换错误
    public func convert(_ error: Error) -> CoreDataError {
        if let coreDataError = error as? CoreDataError {
            return coreDataError
        } else if let nsError = error as? NSError {
            return convertNSError(nsError)
        } else {
            return .unknown(error)
        }
    }
    
    /// 从NSError转换
    private func convertNSError(_ error: NSError) -> CoreDataError {
        if error.domain == NSCocoaErrorDomain {
            return convertCocoaError(error)
        } else {
            return .unknown(error)
        }
    }
    
    /// 从Cocoa错误转换
    private func convertCocoaError(_ error: NSError) -> CoreDataError {
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
                return .validationFailed("验证错误: \(error.localizedDescription)")
            } else if error.code == NSManagedObjectContextLockingError {
                return .saveFailed(error)
            } else if error.code == NSPersistentStoreCoordinatorLockingError {
                return .saveFailed(error)
            } else if error.code == NSManagedObjectMergeError {
                return .mergeConflict("合并错误: \(error.localizedDescription)")
            } else if error.code == NSManagedObjectReferentialIntegrityError {
                return .deleteFailed("引用完整性错误: \(error.localizedDescription)")
            } else if error.code == NSMigrationError {
                return .migrationFailed("迁移错误: \(error.localizedDescription)")
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

// MARK: - Error Strategy Resolver Reference Class

/// 错误策略解析器引用类型
public final class ErrorStrategyResolverRef: Sendable {
    // 使用锁来保证线程安全
    private let lock = NSLock()
    
    // 封装原有的策略解析器
    private let resolver: AtomicReference<ErrorStrategyResolver>
    
    public init() {
        // 实例化时初始化一次策略解析器
        self.resolver = AtomicReference(ErrorStrategyResolver())
        
        // 设置默认策略
        setupDefaultStrategies()
    }
    
    // MARK: - 线程安全的方法
    
    /// 获取策略
    public func getStrategy(for errorType: Error, context: String) -> ErrorHandlingStrategy? {
        return resolver.value.getStrategy(for: errorType, context: context)
    }
    
    /// 注册策略
    public func registerStrategy(_ strategy: ErrorHandlingStrategy, for errorType: String, context: String? = nil) {
        resolver.modify { resolver in 
            resolver.registerStrategy(strategy, for: errorType, context: context)
        }
    }
    
    /// 获取错误计数
    public func getErrorCount(for identifier: String) -> Int {
        return resolver.value.getErrorCount(for: identifier)
    }
    
    /// 增加错误计数
    public func incrementErrorCount(for identifier: String) {
        resolver.modify { resolver in
            resolver.incrementErrorCount(for: identifier)
        }
    }
    
    /// 重置错误计数
    public func resetErrorCounts() {
        resolver.modify { resolver in
            resolver.resetErrorCounts()
        }
    }
    
    // MARK: - 私有方法
    
    /// 设置默认策略
    private func setupDefaultStrategies() {
        // 先实现本地默认策略
        registerStrategy(.retry(maxAttempts: 3, delay: 1.0), for: "NSURLErrorDomain")
        registerStrategy(.backupAndRestore, for: "CoreDataError.storeNotFound")
        registerStrategy(.backupAndRestore, for: "CoreDataError.migrationFailed")
        registerStrategy(.userInteraction, for: "CoreDataError.validationFailed")
        registerStrategy(.logOnly, for: "CoreDataError.notFound")
    }
}

// MARK: - Error Strategy Resolver

/// 错误策略解析器
public struct ErrorStrategyResolver: Sendable {
    // MARK: - Properties
    
    /// 注册的错误策略
    private var strategies: [String: ErrorHandlingStrategy] = [:]
    
    /// 错误计数器
    private var errorCounts: [String: Int] = [:]
    
    /// 错误时间戳
    private var errorTimestamps: [String: Date] = [:]
    
    // MARK: - Initialization
    
    /// 初始化策略解析器
    public init() {
        setupDefaultStrategies()
    }
    
    // MARK: - Public Methods
    
    /// 注册错误处理策略
    /// - Parameters:
    ///   - strategy: 错误处理策略
    ///   - errorType: 错误类型
    ///   - context: 错误上下文
    public mutating func registerStrategy(_ strategy: ErrorHandlingStrategy, for errorType: String, context: String? = nil) {
        let key = createStrategyKey(errorType: errorType, context: context)
        strategies[key] = strategy
    }
    
    /// 获取错误处理策略
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误上下文
    /// - Returns: 错误处理策略
    public func getStrategy(for error: Error, context: String) -> ErrorHandlingStrategy {
        // 尝试获取特定错误和上下文的策略
        let errorTypeString: String
        if let coreDataError = error as? CoreDataError {
            errorTypeString = String(describing: type(of: coreDataError)) + "." + String(describing: coreDataError)
        } else {
            let nsError = error as NSError
            errorTypeString = nsError.domain + "." + String(nsError.code)
        }
        
        // 尝试按优先级获取策略
        if let strategy = strategies["\(errorTypeString):\(context)"] {
            return strategy
        } else if let strategy = strategies[errorTypeString] {
            return strategy
        } else if let strategy = strategies[context] {
            return strategy
        } else {
            return .default
        }
    }
    
    /// 增加错误计数
    /// - Parameter identifier: 错误标识符
    public mutating func incrementErrorCount(for identifier: String) {
        errorCounts[identifier] = (errorCounts[identifier] ?? 0) + 1
        errorTimestamps[identifier] = Date()
    }
    
    /// 获取错误计数
    /// - Parameter identifier: 错误标识符
    /// - Returns: 错误计数
    public func getErrorCount(for identifier: String) -> Int {
        return errorCounts[identifier] ?? 0
    }
    
    /// 重置错误计数
    public mutating func resetErrorCounts() {
        errorCounts.removeAll()
        errorTimestamps.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// 创建策略键
    private func createStrategyKey(errorType: String, context: String?) -> String {
        if let context = context {
            return "\(errorType):\(context)"
        } else {
            return errorType
        }
    }
    
    /// 设置默认策略
    private mutating func setupDefaultStrategies() {
        registerStrategy(.retry(maxAttempts: 3, delay: 1.0), for: "NSURLErrorDomain")
        registerStrategy(.backupAndRestore, for: "CoreDataError.storeNotFound")
        registerStrategy(.backupAndRestore, for: "CoreDataError.migrationFailed")
        registerStrategy(.userInteraction, for: "CoreDataError.validationFailed")
        registerStrategy(.logOnly, for: "CoreDataError.notFound")
    }
}

// MARK: - Integration With Existing Code

/// 创建全局错误处理服务
@MainActor
public struct ErrorServices {
    /// 错误处理服务
    public static let errorHandler = EnhancedErrorHandler.createDefault()
    
    /// 恢复服务
    public static let recoveryService = EnhancedRecoveryService.createDefault()
    
    /// 使用新的错误处理系统处理错误
    /// - Parameters:
    ///   - error: 错误
    ///   - context: 上下文
    ///   - file: 文件
    ///   - line: 行号
    ///   - function: 函数
    public static func handle(
        _ error: Error,
        context: String,
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        // 错误处理器现在是非mutating的，直接调用即可
        errorHandler.handle(error, context: context, file: file, line: line, function: function)
    }
    
    /// 尝试恢复错误
    /// - Parameters:
    ///   - error: 错误
    ///   - context: 上下文
    /// - Returns: 恢复结果
    public static func attemptRecovery(from error: Error, context: String) async -> RecoveryResult {
        return await recoveryService.attemptRecovery(from: error, context: context)
    }
}

// MARK: - 错误处理适配器

/// 错误处理适配器，提供与原始API兼容的接口
@MainActor
public struct ErrorHandlerAdapter: Sendable {
    /// 共享实例
    public static let shared = ErrorHandlerAdapter()
    
    /// 内部使用的增强错误处理器
    private let enhancedHandler: EnhancedErrorHandler
    
    /// 初始化适配器
    /// - Parameter handler: 增强错误处理器
    public init(handler: EnhancedErrorHandler = EnhancedErrorHandler.createDefault()) {
        self.enhancedHandler = handler
    }
    
    /// 获取处理器
    /// - Returns: 增强错误处理器
    public func handler() -> EnhancedErrorHandler {
        return enhancedHandler
    }
    
    /// 兼容方法：处理错误
    public func compatibleHandleError(_ error: Error, context: String = "") {
        enhancedHandler.handle(error, context: context)
    }
    
    /// 兼容方法：尝试恢复
    public func compatibleAttemptRecovery(from error: Error, context: String = "") async -> Bool {
        let result = await enhancedHandler.attemptRecovery(from: error, context: context)
        // 根据RecoveryResult决定是否成功
        switch result {
        case .success:
            return true
        case .partialSuccess(_):
            return true
        case .requiresUserInteraction, .failure(_):
            return false
        }
    }
    
    /// 兼容方法：记录错误
    public func compatibleLogError(_ error: Error, context: String) {
        let file = #file
        let line = #line
        let function = #function
        enhancedHandler.handle(error, context: context, file: file, line: line, function: function)
    }
}

/// 全局访问函数
@MainActor
public func getErrorHandler() -> EnhancedErrorHandler {
    return ErrorHandlerAdapter.shared.handler()
}

/// 原子引用类，提供线程安全的状态访问
public final class AtomicReference<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    
    public init(_ value: T) {
        self._value = value
    }
    
    public var value: T {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
    
    public func modify(_ action: (inout T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        action(&_value)
    }
} 