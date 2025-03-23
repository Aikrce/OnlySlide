import Foundation
import os.log

/// 日志工具类
final class Logger {
    private let logger: OSLog
    
    init(label: String) {
        self.logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.onlyslide", category: label)
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