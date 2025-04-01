import Foundation
import os.log

/// 日志工具类
@available(*, deprecated, message: "请使用Sources/Logging/Logger.swift中的统一日志系统代替")
final class CommonLogger {
    private let logger: OSLog
    
    init(label: String) {
        self.logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.onlyslide", category: label)
        print("警告: CommonLogger已被弃用，请使用Logging模块中的Logger")
    }
    
    func info(_ message: String) {
        os_log(.info, log: logger, "%{public}@", message)
    }
    
    func error(_ message: String) {
        os_log(.error, log: logger, "%{public}@", message)
    }
    
    func debug(_ message: String) {
        os_log(.debug, log: logger, "%{public}@", message)
    }
} 