import CoreData
import os.log

/// Core Data 性能监控管理器
final class CoreDataPerformanceMonitor {
    // MARK: - Properties
    
    static let shared = CoreDataPerformanceMonitor()
    
    private let logger = OSLog(subsystem: "com.onlyslide.coredata", category: "Performance")
    private var fetchMetrics: [String: TimeInterval] = [:]
    private var saveMetrics: [String: TimeInterval] = [:]
    
    private init() {}
    
    // MARK: - Monitoring
    
    /// 监控获取请求性能
    /// - Parameters:
    ///   - entityName: 实体名称
    ///   - operation: 获取操作闭包
    /// - Returns: 操作结果
    func monitorFetch<T>(entityName: String, operation: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let end = CFAbsoluteTimeGetCurrent()
        
        // 记录性能指标
        let duration = end - start
        fetchMetrics[entityName, default: 0] += duration
        
        // 记录日志
        os_log("获取操作耗时 %.3f 秒 (实体: %@)", log: logger, type: .debug, duration, entityName)
        
        return result
    }
    
    /// 监控保存操作性能
    /// - Parameters:
    ///   - context: 托管对象上下文
    ///   - operation: 保存操作闭包
    func monitorSave(context: NSManagedObjectContext, operation: () throws -> Void) rethrows {
        let start = CFAbsoluteTimeGetCurrent()
        try operation()
        let end = CFAbsoluteTimeGetCurrent()
        
        // 记录性能指标
        let duration = end - start
        let contextName = context.name ?? "Unknown"
        saveMetrics[contextName, default: 0] += duration
        
        // 记录日志
        os_log("保存操作耗时 %.3f 秒 (上下文: %@)", log: logger, type: .debug, duration, contextName)
    }
    
    // MARK: - Cache Management
    
    /// 配置获取请求缓存
    /// - Parameter fetchRequest: 获取请求
    func configureFetchRequestCache<T>(_ fetchRequest: NSFetchRequest<T>) {
        // 设置批量获取
        fetchRequest.fetchBatchSize = 100
        
        // 设置结果类型
        fetchRequest.resultType = .managedObjectResultType
        
        // 启用预取
        if let relationships = fetchRequest.entity?.relationshipsByName.keys {
            fetchRequest.relationshipKeyPathsForPrefetching = Array(relationships)
        }
    }
    
    /// 配置获取请求以优化内存使用
    /// - Parameter fetchRequest: 获取请求
    func configureFetchRequestForMemory<T>(_ fetchRequest: NSFetchRequest<T>) {
        // 设置刷新策略
        fetchRequest.returnsObjectsAsFaults = false
        
        // 设置结果类型为字典
        fetchRequest.resultType = .dictionaryResultType
        
        // 设置批量获取
        fetchRequest.fetchBatchSize = 20
    }
    
    // MARK: - Performance Analysis
    
    /// 获取性能报告
    /// - Returns: 性能报告字符串
    func getPerformanceReport() -> String {
        var report = "Core Data 性能报告\n"
        report += "==================\n\n"
        
        // 获取操作性能
        report += "获取操作性能:\n"
        for (entity, duration) in fetchMetrics {
            report += "- \(entity): \(String(format: "%.3f", duration))秒\n"
        }
        
        report += "\n保存操作性能:\n"
        for (context, duration) in saveMetrics {
            report += "- \(context): \(String(format: "%.3f", duration))秒\n"
        }
        
        return report
    }
    
    /// 重置性能指标
    func resetMetrics() {
        fetchMetrics.removeAll()
        saveMetrics.removeAll()
    }
    
    // MARK: - Query Optimization
    
    /// 优化获取请求
    /// - Parameter fetchRequest: 获取请求
    func optimizeFetchRequest<T>(_ fetchRequest: NSFetchRequest<T>) {
        // 配置批量获取
        configureFetchRequestCache(fetchRequest)
        
        // 添加索引支持的排序描述符
        if let sortDescriptors = fetchRequest.sortDescriptors {
            fetchRequest.sortDescriptors = optimizeSortDescriptors(sortDescriptors)
        }
        
        // 优化谓词
        if let predicate = fetchRequest.predicate {
            fetchRequest.predicate = optimizePredicate(predicate)
        }
    }
    
    /// 优化排序描述符
    private func optimizeSortDescriptors(_ sortDescriptors: [NSSortDescriptor]) -> [NSSortDescriptor] {
        // 这里可以根据实际需求优化排序描述符
        return sortDescriptors
    }
    
    /// 优化谓词
    private func optimizePredicate(_ predicate: NSPredicate) -> NSPredicate {
        // 这里可以根据实际需求优化谓词
        return predicate
    }
    
    // MARK: - Memory Management
    
    /// 优化内存使用
    /// - Parameter context: 托管对象上下文
    func optimizeMemoryUsage(for context: NSManagedObjectContext) {
        // 刷新对象
        context.refreshAllObjects()
        
        // 重置上下文
        context.reset()
        
        // 触发垃圾回收
        autoreleasepool {
            context.performAndWait {
                // 执行一些内存密集型操作
            }
        }
    }
} 