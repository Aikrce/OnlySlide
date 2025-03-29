import Foundation
import os

/// 缓存监控工具类
///
/// 用于监控和分析缓存性能和使用情况
@MainActor public final class CacheMonitor {
    // MARK: - 单例
    
    /// 共享实例
    public static let shared = CacheMonitor()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "CacheMonitor")
    
    // MARK: - 统计信息
    
    /// 模型缓存命中次数
    private var modelCacheHits: Int = 0
    
    /// 模型缓存未命中次数
    private var modelCacheMisses: Int = 0
    
    /// 实体缓存命中次数
    private var entityCacheHits: Int = 0
    
    /// 实体缓存未命中次数
    private var entityCacheMisses: Int = 0
    
    /// 查询缓存命中次数
    private var queryCacheHits: Int = 0
    
    /// 查询缓存未命中次数
    private var queryCacheMisses: Int = 0
    
    /// 检查点时间信息
    private var checkpoints: [String: Date] = [:]
    
    /// 操作耗时记录
    private var operationTimings: [String: [TimeInterval]] = [:]
    
    /// 上次缓存清理时间
    private var lastCleanupTime: Date = Date()
    
    /// 定时清理任务 - 使用可选值包装而非直接存储 Timer
    /// 这里我们不直接存储 Timer，而是存储一个表示是否有活跃计时器的布尔值
    private var hasActiveCleanupTimer: Bool = false
    
    /// 是否启用详细日志
    public var verboseLogging: Bool = false
    
    // MARK: - 初始化
    
    private init() {
        // 启动定时清理检查
        startCleanupTimer()
    }
    
    deinit {
        // 在 deinit 中不再需要引用 Timer
        // 注意：在 deinit 中不能调用 actor 隔离的方法，所以我们只更新标志
        hasActiveCleanupTimer = false
        // 任何需要停止的 Timer 应该在其他地方停止，例如在应用程序退出前
    }
    
    // MARK: - 缓存命中统计
    
    /// 记录模型缓存命中
    public func recordModelCacheHit() {
        modelCacheHits += 1
        if verboseLogging {
            logger.debug("模型缓存命中")
        }
    }
    
    /// 记录模型缓存未命中
    public func recordModelCacheMiss() {
        modelCacheMisses += 1
        if verboseLogging {
            logger.debug("模型缓存未命中")
        }
    }
    
    /// 记录实体缓存命中
    public func recordEntityCacheHit() {
        entityCacheHits += 1
        if verboseLogging {
            logger.debug("实体缓存命中")
        }
    }
    
    /// 记录实体缓存未命中
    public func recordEntityCacheMiss() {
        entityCacheMisses += 1
        if verboseLogging {
            logger.debug("实体缓存未命中")
        }
    }
    
    /// 记录查询缓存命中
    public func recordQueryCacheHit() {
        queryCacheHits += 1
        if verboseLogging {
            logger.debug("查询缓存命中")
        }
    }
    
    /// 记录查询缓存未命中
    public func recordQueryCacheMiss() {
        queryCacheMisses += 1
        if verboseLogging {
            logger.debug("查询缓存未命中")
        }
    }
    
    // MARK: - 性能监控
    
    /// 设置检查点
    /// - Parameter name: 检查点名称
    public func setCheckpoint(name: String) {
        checkpoints[name] = Date()
    }
    
    /// 获取从检查点到现在的时间
    /// - Parameter name: 检查点名称
    /// - Returns: 时间间隔（秒）
    public func timeIntervalSinceCheckpoint(name: String) -> TimeInterval? {
        guard let checkpointTime = checkpoints[name] else {
            return nil
        }
        
        return Date().timeIntervalSince(checkpointTime)
    }
    
    /// 记录操作耗时
    /// - Parameters:
    ///   - operation: 操作名称
    ///   - time: 耗时（秒）
    public func recordOperationTime(operation: String, time: TimeInterval) {
        if operationTimings[operation] == nil {
            operationTimings[operation] = []
        }
        
        operationTimings[operation]?.append(time)
        
        if verboseLogging {
            logger.debug("操作 \(operation) 耗时: \(time) 秒")
        }
    }
    
    /// 测量操作耗时
    /// - Parameters:
    ///   - operation: 操作名称
    ///   - work: 要执行的操作
    public func measure<T>(operation: String, work: () -> T) -> T {
        let startTime = Date()
        let result = work()
        let timeInterval = Date().timeIntervalSince(startTime)
        
        recordOperationTime(operation: operation, time: timeInterval)
        
        return result
    }
    
    /// 测量异步操作耗时
    /// - Parameters:
    ///   - operation: 操作名称
    ///   - work: 要执行的异步操作
    public func measure<T: Sendable>(operation: String, work: () async throws -> T) async rethrows -> T {
        let startTime = Date()
        let result = try await work()
        let timeInterval = Date().timeIntervalSince(startTime)
        
        recordOperationTime(operation: operation, time: timeInterval)
        
        return result
    }
    
    // MARK: - 缓存维护
    
    /// 启动定时清理检查器
    private func startCleanupTimer() {
        stopCleanupTimer() // 确保先停止已有计时器
        
        Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                if let strongSelf = self {
                    await strongSelf.checkCacheCleanupNeeded()
                }
            }
        }
        hasActiveCleanupTimer = true
    }
    
    /// 停止定时清理
    private func stopCleanupTimer() {
        // 由于我们不再直接引用 Timer，这里不需要调用 invalidate
        // 但在实际应用中，你可能需要一个方法来跟踪和停止计时器
        hasActiveCleanupTimer = false
    }
    
    /// 检查是否需要清理缓存
    public func checkCacheCleanupNeeded() async {
        // 如果距离上次清理超过2小时
        if Date().timeIntervalSince(lastCleanupTime) > 2 * 60 * 60 {
            // 清理过期缓存
            let resourceManager = CoreDataResourceManager.shared
            await resourceManager.cleanupExpiredCache()
            
            let coreDataStack = CoreDataStack.shared
            await coreDataStack.cleanupExpiredCache()
            
            lastCleanupTime = Date()
            logger.info("已执行定期缓存清理")
        }
    }
    
    /// 手动触发缓存清理
    public func triggerCacheCleanup() async {
        let resourceManager = CoreDataResourceManager.shared
        await resourceManager.cleanupExpiredCache()
        
        let coreDataStack = CoreDataStack.shared
        await coreDataStack.cleanupExpiredCache()
        
        lastCleanupTime = Date()
        logger.info("已执行手动缓存清理")
    }
    
    // MARK: - 统计报告
    
    /// 获取缓存命中率摘要
    /// - Returns: 统计信息字符串
    public func cacheHitRateSummary() -> String {
        // 模型缓存命中率
        let modelTotal = modelCacheHits + modelCacheMisses
        let modelHitRate = modelTotal > 0 ? Double(modelCacheHits) / Double(modelTotal) * 100 : 0
        
        // 实体缓存命中率
        let entityTotal = entityCacheHits + entityCacheMisses
        let entityHitRate = entityTotal > 0 ? Double(entityCacheHits) / Double(entityTotal) * 100 : 0
        
        // 查询缓存命中率
        let queryTotal = queryCacheHits + queryCacheMisses
        let queryHitRate = queryTotal > 0 ? Double(queryCacheHits) / Double(queryTotal) * 100 : 0
        
        // 总命中率
        let totalHits = modelCacheHits + entityCacheHits + queryCacheHits
        let totalMisses = modelCacheMisses + entityCacheMisses + queryCacheMisses
        let totalRequests = totalHits + totalMisses
        let overallHitRate = totalRequests > 0 ? Double(totalHits) / Double(totalRequests) * 100 : 0
        
        return """
        缓存命中率统计:
        - 模型缓存: \(String(format: "%.1f", modelHitRate))% (命中: \(modelCacheHits), 未命中: \(modelCacheMisses))
        - 实体缓存: \(String(format: "%.1f", entityHitRate))% (命中: \(entityCacheHits), 未命中: \(entityCacheMisses))
        - 查询缓存: \(String(format: "%.1f", queryHitRate))% (命中: \(queryCacheHits), 未命中: \(queryCacheMisses))
        - 总体命中率: \(String(format: "%.1f", overallHitRate))%
        """
    }
    
    /// 获取操作性能摘要
    /// - Returns: 统计信息字符串
    public func operationPerformanceSummary() -> String {
        var summary = "操作性能统计:\n"
        
        for (operation, timings) in operationTimings {
            guard !timings.isEmpty else { continue }
            
            // 计算平均值、最小值和最大值
            let average = timings.reduce(0, +) / Double(timings.count)
            let min = timings.min() ?? 0
            let max = timings.max() ?? 0
            
            summary += "- \(operation): 平均 \(String(format: "%.3f", average))秒, 最小 \(String(format: "%.3f", min))秒, 最大 \(String(format: "%.3f", max))秒, 样本数 \(timings.count)\n"
        }
        
        return summary
    }
    
    /// 获取完整的性能报告
    /// - Returns: 完整报告字符串
    public func fullPerformanceReport() async -> String {
        // 不使用可能导致跨Actor边界传递的字典类型，而是直接获取基本值
        let resourceManager = CoreDataResourceManager.shared
        let resourceStats = try? await resourceManager.getStatistics()
        
        let resourceHits = resourceStats?.hits ?? 0
        let resourceMisses = resourceStats?.misses ?? 0
        let resourceHitRate = resourceStats?.hitRate ?? 0.0
        
        let coreDataStack = CoreDataStack.shared
        let stackStats = try? await coreDataStack.getStatistics()
        
        let stackHits = stackStats?.hits ?? 0
        let stackMisses = stackStats?.misses ?? 0
        let stackHitRate = stackStats?.hitRate ?? 0.0
        
        let report = """
        ===== 缓存性能报告 =====
        
        === 资源管理器缓存 ===
        命中: \(resourceHits), 未命中: \(resourceMisses), 命中率: \(String(format: "%.1f", resourceHitRate * 100))%
        
        === Core Data 栈缓存 ===
        命中: \(stackHits), 未命中: \(stackMisses), 命中率: \(String(format: "%.1f", stackHitRate * 100))%
        
        === 内存使用 ===
        当前: \(MemoryUsageMonitor.formatMemoryUsage(MemoryUsageMonitor.currentMemoryUsage()))
        
        === 缓存命中统计 ===
        模型缓存命中: \(modelCacheHits), 未命中: \(modelCacheMisses), 命中率: \(modelCacheRate() * 100)%
        实体缓存命中: \(entityCacheHits), 未命中: \(entityCacheMisses), 命中率: \(entityCacheRate() * 100)%
        查询缓存命中: \(queryCacheHits), 未命中: \(queryCacheMisses), 命中率: \(queryCacheRate() * 100)%
        
        === 操作耗时（平均，秒） ===
        \(formattedTimings())
        
        ===== 报告结束 =====
        """
        
        return report
    }
    
    /// 记录性能报告
    public func logPerformanceReport() async {
        let report = await fullPerformanceReport()
        logger.info("\(report)")
    }
    
    /// 重置统计信息
    public func resetStatistics() {
        modelCacheHits = 0
        modelCacheMisses = 0
        entityCacheHits = 0
        entityCacheMisses = 0
        queryCacheHits = 0
        queryCacheMisses = 0
        checkpoints.removeAll()
        operationTimings.removeAll()
        
        logger.info("已重置缓存监控统计信息")
    }
    
    /// 计算模型缓存命中率
    private func modelCacheRate() -> Double {
        let total = modelCacheHits + modelCacheMisses
        return total > 0 ? Double(modelCacheHits) / Double(total) : 0.0
    }
    
    /// 计算实体缓存命中率
    private func entityCacheRate() -> Double {
        let total = entityCacheHits + entityCacheMisses
        return total > 0 ? Double(entityCacheHits) / Double(total) : 0.0
    }
    
    /// 计算查询缓存命中率
    private func queryCacheRate() -> Double {
        let total = queryCacheHits + queryCacheMisses
        return total > 0 ? Double(queryCacheHits) / Double(total) : 0.0
    }
    
    /// 格式化操作耗时统计
    private func formattedTimings() -> String {
        var result = ""
        for (operation, timings) in operationTimings {
            guard !timings.isEmpty else { continue }
            let average = timings.reduce(0, +) / Double(timings.count)
            result += "\(operation): \(String(format: "%.4f", average))\n"
        }
        return result.isEmpty ? "暂无统计" : result
    }
} 