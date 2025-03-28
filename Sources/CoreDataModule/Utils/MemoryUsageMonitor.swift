import Foundation
import os.log
@preconcurrency import Darwin

/// 内存使用监控工具
public struct MemoryUsageMonitor {
    
    /// 用于保护对 mach_task_self_ 的访问的锁
    private static let taskSelfLock = NSLock()
    
    /// 当前任务端口的并发安全访问器
    @inline(__always) // 强制内联，避免函数调用开销
    internal static func safeTaskSelf() -> mach_port_t {
        // 使用锁保护对 mach_task_self_ 的访问
        taskSelfLock.lock()
        defer { taskSelfLock.unlock() }
        // 使用正确的方式访问
        return mach_task_self_
    }
    
    /// 获取当前内存使用量（字节）
    public static func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: MemoryLayout<mach_task_basic_info>.size/MemoryLayout<integer_t>.size) {
                // 使用安全的访问方法获取任务端口
                task_info(safeTaskSelf(),
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            CoreLogger.error("获取内存使用信息失败: \(kerr)", category: "Performance")
            return 0
        }
    }
    
    /// 格式化内存使用量为人类可读格式
    /// - Parameter bytes: 内存字节数
    /// - Returns: 格式化后的字符串（如：10.5 MB）
    public static func formatMemoryUsage(_ bytes: UInt64) -> String {
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
    
    /// 记录指定操作的内存使用情况
    /// - Parameters:
    ///   - operation: 操作名称
    ///   - category: 日志类别
    public static func logMemoryUsage(operation: String, category: String = "Memory") {
        let usage = currentMemoryUsage()
        CoreLogger.info("内存使用: \(operation) - \(formatMemoryUsage(usage))", category: category)
    }
    
    /// 内存使用情况摘要
    /// - Returns: 内存使用信息字符串
    public static func memoryUsageSummary() -> String {
        let usage = currentMemoryUsage()
        return "当前内存使用: \(formatMemoryUsage(usage))"
    }
    
    /// 在操作前后监控内存使用变化
    /// - Parameters:
    ///   - operationName: 操作名称
    ///   - operation: 要执行的操作闭包
    public static func trackMemoryUsage<T>(for operationName: String, operation: () throws -> T) rethrows -> T {
        let beforeUsage = currentMemoryUsage()
        CoreLogger.info("开始 \(operationName) - 初始内存: \(formatMemoryUsage(beforeUsage))", category: "MemoryTracking")
        
        let result = try operation()
        
        let afterUsage = currentMemoryUsage()
        let difference = Int64(afterUsage) - Int64(beforeUsage)
        let differenceFormatted = ByteCountFormatter.string(fromByteCount: difference, countStyle: .memory)
        let arrow = difference >= 0 ? "↑" : "↓"
        
        CoreLogger.info("完成 \(operationName) - 当前内存: \(formatMemoryUsage(afterUsage)) (\(arrow) \(differenceFormatted))", category: "MemoryTracking")
        
        return result
    }
    
    /// 异步版本的内存使用追踪
    /// - Parameters:
    ///   - operationName: 操作名称
    ///   - operation: 要执行的异步操作闭包
    public static func trackMemoryUsage<T: Sendable>(for operationName: String, operation: @Sendable () async throws -> T) async rethrows -> T {
        let beforeUsage = currentMemoryUsage()
        CoreLogger.info("开始 \(operationName) - 初始内存: \(formatMemoryUsage(beforeUsage))", category: "MemoryTracking")
        
        let result = try await operation()
        
        let afterUsage = currentMemoryUsage()
        let difference = Int64(afterUsage) - Int64(beforeUsage)
        let differenceFormatted = ByteCountFormatter.string(fromByteCount: difference, countStyle: .memory)
        let arrow = difference >= 0 ? "↑" : "↓"
        
        CoreLogger.info("完成 \(operationName) - 当前内存: \(formatMemoryUsage(afterUsage)) (\(arrow) \(differenceFormatted))", category: "MemoryTracking")
        
        return result
    }
} 