import Foundation
import Logging

/// 日志服务
public final class LoggingService {
    // MARK: - Properties
    private let logger: Logger
    private let fileLogger: FileLogger?
    
    // MARK: - Initialization
    public init(
        label: String = "com.onlyslide.logger",
        logLevel: Logger.Level = .info,
        enableFileLogging: Bool = true
    ) {
        // 配置标准日志记录器
        logger = Logger(label: label)
        logger.logLevel = logLevel
        
        // 配置文件日志记录器
        if enableFileLogging {
            fileLogger = try? FileLogger(label: label)
        } else {
            fileLogger = nil
        }
    }
    
    // MARK: - Public Methods
    
    /// 记录调试日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - file: 源文件
    ///   - function: 函数
    ///   - line: 行号
    public func debug(_ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        logger.debug("\(message)", file: file, function: function, line: line)
        fileLogger?.log(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    /// 记录信息日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - file: 源文件
    ///   - function: 函数
    ///   - line: 行号
    public func info(_ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        logger.info("\(message)", file: file, function: function, line: line)
        fileLogger?.log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    /// 记录通知日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - file: 源文件
    ///   - function: 函数
    ///   - line: 行号
    public func notice(_ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        logger.notice("\(message)", file: file, function: function, line: line)
        fileLogger?.log(level: .notice, message: message, file: file, function: function, line: line)
    }
    
    /// 记录警告日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - file: 源文件
    ///   - function: 函数
    ///   - line: 行号
    public func warning(_ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        logger.warning("\(message)", file: file, function: function, line: line)
        fileLogger?.log(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    /// 记录错误日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - file: 源文件
    ///   - function: 函数
    ///   - line: 行号
    public func error(_ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        logger.error("\(message)", file: file, function: function, line: line)
        fileLogger?.log(level: .error, message: message, file: file, function: function, line: line)
    }
    
    /// 记录严重错误日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - file: 源文件
    ///   - function: 函数
    ///   - line: 行号
    public func critical(_ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        logger.critical("\(message)", file: file, function: function, line: line)
        fileLogger?.log(level: .critical, message: message, file: file, function: function, line: line)
    }
    
    /// 获取日志文件URL
    /// - Returns: 日志文件URL
    public func getLogFileURL() -> URL? {
        return fileLogger?.getLogFileURL()
    }
    
    /// 清除日志文件
    /// - Returns: 是否成功清除
    public func clearLogs() -> Bool {
        return fileLogger?.clearLogs() ?? false
    }
}

// MARK: - FileLogger

/// 文件日志记录器
fileprivate class FileLogger {
    // MARK: - Properties
    private let fileManager = FileManager.default
    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private let label: String
    private let logQueue = DispatchQueue(label: "com.onlyslide.filelogger", qos: .utility)
    
    // MARK: - Initialization
    init(label: String) throws {
        self.label = label
        
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // 获取日志目录
        let logDirectory = try getLogDirectory()
        
        // 创建日志文件名
        let fileName = "\(label)-\(getFormattedDate()).log"
        logFileURL = logDirectory.appendingPathComponent(fileName)
        
        // 确保日志文件存在
        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
        }
    }
    
    // MARK: - Public Methods
    func log(level: Logger.Level, message: String, file: String, function: String, line: UInt) {
        let logEntry = formatLogEntry(level: level, message: message, file: file, function: function, line: line)
        appendToLogFile(logEntry)
    }
    
    func getLogFileURL() -> URL {
        return logFileURL
    }
    
    func clearLogs() -> Bool {
        do {
            if fileManager.fileExists(atPath: logFileURL.path) {
                try fileManager.removeItem(at: logFileURL)
                return true
            }
            return false
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    private func getLogDirectory() throws -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logDirectory = documentsDirectory.appendingPathComponent("Logs", isDirectory: true)
        
        if !fileManager.fileExists(atPath: logDirectory.path) {
            try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        }
        
        return logDirectory
    }
    
    private func getFormattedDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: Date())
    }
    
    private func formatLogEntry(level: Logger.Level, message: String, file: String, function: String, line: UInt) -> String {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        
        return "[\(timestamp)] [\(label)] [\(level)] [\(fileName):\(line) \(function)] \(message)\n"
    }
    
    private func appendToLogFile(_ logEntry: String) {
        logQueue.async {
            if let data = logEntry.data(using: .utf8) {
                if let fileHandle = try? FileHandle(forWritingTo: self.logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            }
        }
    }
} 