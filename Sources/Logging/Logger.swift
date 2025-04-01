import Foundation
import os.log

/// 日志级别
public enum LogLevel: String, Comparable {
    case debug = "DEBUG"
    case info = "INFO"
    case notice = "NOTICE"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    case none = "NONE"
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        let order: [LogLevel] = [.debug, .info, .notice, .warning, .error, .critical, .none]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
    
    var prefix: String {
        switch self {
        case .debug: return "🔍 DEBUG"
        case .info: return "ℹ️ INFO"
        case .notice: return "📢 NOTICE"
        case .warning: return "⚠️ WARNING"
        case .error: return "❌ ERROR"
        case .critical: return "🚨 CRITICAL"
        case .none: return ""
        }
    }
    
    // 转换为标准OSLogType
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .notice: return .info // OS.log没有notice级别
        case .warning: return .default // OS.log使用.default作为warning
        case .error: return .error
        case .critical: return .fault
        case .none: return .default
        }
    }
}

/// 日志目标接口
public protocol LogHandler {
    /// 记录日志
    func log(level: LogLevel, message: String, metadata: [String: String]?)
    
    /// 获取日志级别
    var logLevel: LogLevel { get set }
}

/// 控制台日志处理器
public class ConsoleLogHandler: LogHandler {
    public var logLevel: LogLevel = .info
    private let includeMetadata: Bool
    
    public init(logLevel: LogLevel = .info, includeMetadata: Bool = true) {
        self.logLevel = logLevel
        self.includeMetadata = includeMetadata
    }
    
    public func log(level: LogLevel, message: String, metadata: [String: String]?) {
        guard level >= logLevel else { return }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var logMessage = "\(timestamp) [\(level.prefix)] \(message)"
        
        if includeMetadata, let metadata = metadata, !metadata.isEmpty {
            let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            logMessage += " [\(metadataString)]"
        }
        
        print(logMessage)
    }
}

/// OSLog处理器
public class OSLogHandler: LogHandler {
    public var logLevel: LogLevel = .info
    private let logger: OSLog
    
    public init(subsystem: String, category: String, logLevel: LogLevel = .info) {
        self.logger = OSLog(subsystem: subsystem, category: category)
        self.logLevel = logLevel
    }
    
    public func log(level: LogLevel, message: String, metadata: [String: String]?) {
        guard level >= logLevel else { return }
        
        var logMessage = message
        if let metadata = metadata, !metadata.isEmpty {
            let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            logMessage += " [\(metadataString)]"
        }
        
        os_log(level.osLogType, log: logger, "%{public}@", logMessage)
    }
}

/// 文件日志处理器
public class FileLogHandler: LogHandler {
    public var logLevel: LogLevel = .info
    private let logFileURL: URL
    private let dateFormatter = ISO8601DateFormatter()
    private let logQueue = DispatchQueue(label: "com.onlyslide.filelogger", qos: .utility)
    private let fileManager = FileManager.default
    private let maxFileSize: Int
    private let maxLogFiles: Int
    
    public init(directory: URL? = nil, filename: String? = nil, logLevel: LogLevel = .info, maxFileSize: Int = 10 * 1024 * 1024, maxLogFiles: Int = 5) throws {
        self.logLevel = logLevel
        self.maxFileSize = maxFileSize
        self.maxLogFiles = maxLogFiles
        
        // 确定日志目录
        let logDirectory: URL
        if let directory = directory {
            logDirectory = directory
        } else {
            logDirectory = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Logs", isDirectory: true)
        }
        
        // 创建日志目录
        if !fileManager.fileExists(atPath: logDirectory.path) {
            try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        }
        
        // 确定日志文件名
        let logFilename = filename ?? "onlyslide-\(Date().timeIntervalSince1970).log"
        logFileURL = logDirectory.appendingPathComponent(logFilename)
        
        // 创建日志文件
        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
        }
        
        // 清理旧日志文件
        cleanupOldLogFiles(in: logDirectory)
    }
    
    public func log(level: LogLevel, message: String, metadata: [String: String]?) {
        guard level >= logLevel else { return }
        
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = self.dateFormatter.string(from: Date())
            var logMessage = "\(timestamp) [\(level.rawValue)] \(message)"
            
            if let metadata = metadata, !metadata.isEmpty {
                let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
                logMessage += " [\(metadataString)]"
            }
            logMessage += "\n"
            
            do {
                let fileHandle = try FileHandle(forWritingTo: self.logFileURL)
                defer { fileHandle.closeFile() }
                
                fileHandle.seekToEndOfFile()
                if let data = logMessage.data(using: .utf8) {
                    fileHandle.write(data)
                }
                
                // 检查文件大小并在必要时滚动日志
                let fileSize = try? FileManager.default.attributesOfItem(atPath: self.logFileURL.path)[.size] as? Int ?? 0
                if let size = fileSize, size > self.maxFileSize {
                    self.rotateLogFile()
                }
            } catch {
                print("Error writing to log file: \(error)")
            }
        }
    }
    
    // 获取日志文件URL
    public func getLogFileURL() -> URL {
        return logFileURL
    }
    
    // 清除日志文件
    public func clearLogs() -> Bool {
        do {
            if fileManager.fileExists(atPath: logFileURL.path) {
                try fileManager.removeItem(at: logFileURL)
                try "".write(to: logFileURL, atomically: true, encoding: .utf8)
                return true
            }
            return false
        } catch {
            print("Error clearing logs: \(error)")
            return false
        }
    }
    
    // 滚动日志文件（创建新的日志文件）
    private func rotateLogFile() {
        let rotatedURL = logFileURL.deletingLastPathComponent()
            .appendingPathComponent("\(logFileURL.deletingPathExtension().lastPathComponent)-\(Date().timeIntervalSince1970)\(logFileURL.pathExtension)")
        
        do {
            try fileManager.moveItem(at: logFileURL, to: rotatedURL)
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
            cleanupOldLogFiles(in: logFileURL.deletingLastPathComponent())
        } catch {
            print("Error rotating log file: \(error)")
        }
    }
    
    // 清理旧日志文件，保留最新的maxLogFiles个文件
    private func cleanupOldLogFiles(in directory: URL) {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
                .filter { $0.pathExtension == "log" }
                .sorted { (url1, url2) -> Bool in
                    let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    return date1! > date2!
                }
            
            if fileURLs.count > maxLogFiles {
                for fileURL in fileURLs.suffix(from: maxLogFiles) {
                    try fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print("Error cleaning up old log files: \(error)")
        }
    }
}

/// 日志记录接口
public protocol Logging {
    /// 添加日志处理器
    func addHandler(_ handler: LogHandler)
    
    /// 移除日志处理器
    func removeHandler(_ handler: LogHandler)
    
    /// 记录日志消息
    func log(_ message: String, level: LogLevel, metadata: [String: String]?, file: String, function: String, line: Int)
    
    /// 设置全局最低日志级别
    func setGlobalLogLevel(_ level: LogLevel)
}

public extension Logging {
    func debug(_ message: String, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, metadata: metadata, file: file, function: function, line: line)
    }
    
    func info(_ message: String, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, metadata: metadata, file: file, function: function, line: line)
    }
    
    func notice(_ message: String, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .notice, metadata: metadata, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, metadata: metadata, file: file, function: function, line: line)
    }
    
    func error(_ message: String, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, metadata: metadata, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, metadata: metadata, file: file, function: function, line: line)
    }
}

// 添加Sendable一致性
public final class Logger: Logging, @unchecked Sendable {
    // MARK: - Properties
    private var handlers: [LogHandler] = []
    private var globalLogLevel: LogLevel = .info
    private let lock = NSLock() // 添加锁以保护并发访问
    
    // MARK: - Singleton
    public static let shared = Logger()
    
    // MARK: - 构造函数
    public init() {
        // 默认添加控制台日志处理器
        addHandler(ConsoleLogHandler())
    }
    
    // 添加指定子系统和类别的初始化方法
    public convenience init(subsystem: String, category: String) {
        self.init()
        addHandler(OSLogHandler(subsystem: subsystem, category: category))
    }
    
    // MARK: - Logging Protocol Implementation
    public func addHandler(_ handler: LogHandler) {
        lock.lock()
        defer { lock.unlock() }
        handlers.append(handler)
    }
    
    public func removeHandler(_ handler: LogHandler) {
        lock.lock()
        defer { lock.unlock() }
        // 这里我们通过内存地址进行简单比较，更复杂的实现可能需要给LogHandler加上id属性
        handlers.removeAll { $0 as AnyObject === handler as AnyObject }
    }
    
    public func log(_ message: String, level: LogLevel, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        guard level >= globalLogLevel else { return }
        
        var fullMetadata = metadata ?? [:]
        
        // 添加源代码信息
        let filename = (file as NSString).lastPathComponent
        fullMetadata["file"] = filename
        fullMetadata["function"] = function
        fullMetadata["line"] = String(line)
        
        lock.lock()
        let handlersSnapshot = handlers
        lock.unlock()
        
        // 向所有处理器发送日志
        for handler in handlersSnapshot {
            handler.log(level: level, message: message, metadata: fullMetadata)
        }
    }
    
    public func setGlobalLogLevel(_ level: LogLevel) {
        lock.lock()
        defer { lock.unlock() }
        globalLogLevel = level
    }
    
    // MARK: - 便利方法
    
    // 启用文件日志
    public func enableFileLogging(directory: URL? = nil, filename: String? = nil) {
        do {
            let fileHandler = try FileLogHandler(directory: directory, filename: filename)
            addHandler(fileHandler)
        } catch {
            print("Failed to enable file logging: \(error)")
        }
    }
    
    // 设置所有处理器的日志级别
    public func setAllHandlersLogLevel(_ level: LogLevel) {
        lock.lock()
        defer { lock.unlock() }
        for handler in handlers {
            handler.logLevel = level
        }
    }
}

// 便利访问
public let log = Logger.shared 