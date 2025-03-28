import Foundation

public enum LogLevel {
    case debug
    case info
    case warning
    case error
    
    var prefix: String {
        switch self {
        case .debug: return "🔍 DEBUG"
        case .info: return "ℹ️ INFO"
        case .warning: return "⚠️ WARNING"
        case .error: return "❌ ERROR"
        }
    }
}

public protocol Logging {
    func log(_ message: String, level: LogLevel, file: String, function: String, line: Int)
}

public extension Logging {
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
}

// 添加Sendable一致性
@available(macOS 10.15, iOS 13.0, *)
public final class OSLogger: Logging, @unchecked Sendable {
    // 使用actor isolation让shared属性并发安全
    @MainActor public static let shared = OSLogger()
    
    private let dateFormatter: DateFormatter
    private let lock = NSLock() // 添加锁以保护并发访问
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    public func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        // 使用锁保护dateFormatter的并发访问
        lock.lock()
        let timestamp = dateFormatter.string(from: Date())
        lock.unlock()
        
        let filename = (file as NSString).lastPathComponent
        let logMessage = "\(timestamp) [\(level.prefix)] [\(filename):\(line)] \(function): \(message)"
        
        #if DEBUG
        print(logMessage)
        #endif
        
        // TODO: 在这里添加文件日志记录逻辑
    }
}

// 便利访问
// 添加MainActor注解使其并发安全
@available(macOS 10.15, iOS 13.0, *)
@MainActor public let log = OSLogger.shared 