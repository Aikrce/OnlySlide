import Foundation
import os.log

/// 依赖注入容器 - 管理应用程序的所有依赖
public final class DependencyContainer {
    // MARK: - Singleton
    static let shared = DependencyContainer()
    
    // MARK: - Properties
    private var factories: [String: () -> Any] = [:]
    private let logger = os.Logger(subsystem: "com.onlyslide", category: "dependency")
    
    // MARK: - Initialization
    public init() {
        logger.info("初始化依赖注入容器")
    }
    
    // MARK: - Registration
    /// 注册依赖
    public func register<T>(_ instance: T, for type: T.Type) {
        let key = String(describing: type)
        factories[key] = { instance }
        logger.debug("已注册实例: \(key)")
    }
    
    /// 注册工厂闭包
    public func register<T>(_ factory: @escaping () -> T, for type: T.Type) {
        let key = String(describing: type)
        factories[key] = factory
        logger.debug("已注册工厂: \(key)")
    }
    
    // MARK: - Resolution
    /// 解析依赖
    public func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        guard let factory = factories[key] else {
            logger.error("无法解析依赖: \(key)")
            return nil
        }
        
        logger.debug("解析依赖: \(key)")
        return factory() as? T
    }
    
    // MARK: - Default Registrations
    /// 注册默认依赖
    public func registerDefaults() {
        logger.info("注册默认依赖...")
        
        // 日志服务
        register(LoggingService(), for: LoggingService.self)
        
        // 错误处理服务
        register(ErrorHandlingService(), for: ErrorHandlingService.self)
        
        // 缓存管理
        register({ CompositeCacheManager.createDefault() }, for: UnifiedCacheManager.self)
        
        logger.info("默认依赖注册完成")
    }
}

// MARK: - Service Access
extension DependencyContainer {
    // 便捷访问方法
    var aiModelFactory: AIModelFactory {
        guard let factory = resolve(AIModelFactory.self) else {
            fatalError("AIModelFactory not registered")
        }
        return factory
    }
    
    var contentProcessor: ContentProcessingPipeline {
        guard let processor = resolve(ContentProcessingPipeline.self) else {
            fatalError("ContentProcessingPipeline not registered")
        }
        return processor
    }
    
    var performanceMonitor: PerformanceMonitor {
        guard let monitor = resolve(PerformanceMonitor.self) else {
            fatalError("PerformanceMonitor not registered")
        }
        return monitor
    }
} 