import Foundation
import os.log

/// 核心日志记录类
/// 
/// 为CoreDataModule提供统一的日志接口
public enum CoreLogger {
    /// 系统Logger实例，用于记录日志
    private static let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "CoreLogger")
    
    /// 记录调试级别日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - category: 日志类别
    ///   - file: 源文件
    ///   - function: 函数名
    ///   - line: 行号
    public static func debug(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        let formattedMessage = formatMessage(message, category: category)
        logger.debug("\(formattedMessage, privacy: .public)")
    }
    
    /// 记录信息级别日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - category: 日志类别
    ///   - file: 源文件
    ///   - function: 函数名
    ///   - line: 行号
    public static func info(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        let formattedMessage = formatMessage(message, category: category)
        logger.info("\(formattedMessage, privacy: .public)")
    }
    
    /// 记录警告级别日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - category: 日志类别
    ///   - file: 源文件
    ///   - function: 函数名
    ///   - line: 行号
    public static func warning(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        let formattedMessage = formatMessage(message, category: category)
        logger.warning("\(formattedMessage, privacy: .public)")
    }
    
    /// 记录错误级别日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - category: 日志类别
    ///   - file: 源文件
    ///   - function: 函数名
    ///   - line: 行号
    public static func error(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        let formattedMessage = formatMessage(message, category: category)
        logger.error("\(formattedMessage, privacy: .public)")
    }
    
    /// 记录严重级别日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - category: 日志类别
    ///   - file: 源文件
    ///   - function: 函数名
    ///   - line: 行号
    public static func critical(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        let formattedMessage = formatMessage(message, category: category)
        logger.critical("\(formattedMessage, privacy: .public)")
    }
    
    /// 格式化日志消息，添加类别前缀
    /// - Parameters:
    ///   - message: 原始消息
    ///   - category: 类别
    /// - Returns: 格式化后的消息
    private static func formatMessage(_ message: String, category: String?) -> String {
        if let category = category {
            return "[\(category)] \(message)"
        }
        return message
    }
} 