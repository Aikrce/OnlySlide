import Foundation
import os.signpost
import os.log

public final class PerformanceMonitor {
    // MARK: - Properties
    
    public static let shared = PerformanceMonitor()
    
    private let logger = Logger(label: "com.onlyslide.monitoring.performance")
    private let osLog = OSLog(subsystem: "com.onlyslide.monitoring", category: "performance")
    private var metrics: [String: [TimeInterval]] = [:]
    private var thresholds: [String: TimeInterval] = [:]
    private var startTimes: [String: DispatchTime] = [:]
    
    private init() {}
    
    // MARK: - Monitoring Methods
    
    /// 开始测量操作耗时
    /// - Parameter operation: 操作名称
    /// - Returns: 操作标识符
    @discardableResult
    public func startMeasuring(_ operation: String) -> OSSignpostID {
        let signpostID = OSSignpostID(log: osLog)
        os_signpost(.begin, log: osLog, name: "operation", signpostID: signpostID, "%{public}s", operation)
        startTimes[operation] = DispatchTime.now()
        return signpostID
    }
    
    /// 停止测量操作耗时
    /// - Parameters:
    ///   - operation: 操作名称
    ///   - signpostID: 操作标识符
    public func stopMeasuring(_ operation: String, signpostID: OSSignpostID) {
        guard let startTime = startTimes[operation] else { return }
        
        let endTime = DispatchTime.now()
        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        
        metrics[operation, default: []].append(duration)
        startTimes.removeValue(forKey: operation)
        
        os_signpost(.end, log: osLog, name: "operation", signpostID: signpostID, "%{public}s: %.3f seconds", operation, duration)
        
        // 检查是否超过阈值
        if let threshold = thresholds[operation], duration > threshold {
            os_log("Performance warning: %{public}s took %.3f seconds (threshold: %.3f)", log: osLog, type: .error,
                   operation, duration, threshold)
        }
    }
    
    /// 设置操作的性能阈值
    /// - Parameters:
    ///   - threshold: 阈值（秒）
    ///   - operation: 操作名称
    public func setThreshold(_ threshold: TimeInterval, for operation: String) {
        thresholds[operation] = threshold
    }
    
    /// 获取操作的平均耗时
    /// - Parameter operation: 操作名称
    /// - Returns: 平均耗时（秒）
    public func getAverageTime(for operation: String) -> TimeInterval? {
        guard let times = metrics[operation], !times.isEmpty else { return nil }
        return times.reduce(0, +) / Double(times.count)
    }
    
    /// 重置所有性能指标
    public func reset() {
        metrics.removeAll()
        startTimes.removeAll()
    }
    
    /// 生成性能报告
    /// - Returns: 性能报告字符串
    public func generateReport() -> String {
        var report = "Performance Report\n"
        report += "=================\n\n"
        
        for (operation, times) in metrics {
            guard !times.isEmpty else { continue }
            
            let average = times.reduce(0, +) / Double(times.count)
            let min = times.min() ?? 0
            let max = times.max() ?? 0
            
            report += "Operation: \(operation)\n"
            report += "  Average: \(String(format: "%.3f", average)) seconds\n"
            report += "  Min: \(String(format: "%.3f", min)) seconds\n"
            report += "  Max: \(String(format: "%.3f", max)) seconds\n"
            report += "  Samples: \(times.count)\n"
            
            if let threshold = thresholds[operation] {
                let exceedCount = times.filter { $0 > threshold }.count
                report += "  Threshold Exceeded: \(exceedCount) times\n"
            }
            
            report += "\n"
        }
        
        return report
    }
    
    // MARK: - Memory Monitoring
    
    /// 获取当前内存使用情况
    /// - Returns: 内存使用信息字典
    public func getMemoryUsage() -> [String: Int64] {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            return [:]
        }
        
        return [
            "residentMemory": Int64(info.resident_size),
            "virtualMemory": Int64(info.virtual_size)
        ]
    }
    
    /// 监控闭包执行期间的性能
    /// - Parameters:
    ///   - name: 操作名称
    ///   - block: 要执行的闭包
    public func measure<T>(_ name: String, block: () throws -> T) rethrows -> T {
        let signpostID = startMeasuring(name)
        defer { stopMeasuring(name, signpostID: signpostID) }
        return try block()
    }
    
    /// 异步监控闭包执行期间的性能
    /// - Parameters:
    ///   - name: 操作名称
    ///   - block: 要执行的异步闭包
    public func measureAsync<T>(_ name: String, block: () async throws -> T) async rethrows -> T {
        let signpostID = startMeasuring(name)
        defer { stopMeasuring(name, signpostID: signpostID) }
        return try await block()
    }
} 