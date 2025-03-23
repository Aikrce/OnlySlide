import Foundation
import os

public final class Logger {
    // MARK: - Properties
    
    private let logger: os.Logger
    private let subsystem: String
    
    // MARK: - Initialization
    
    public init(label: String, subsystem: String = "com.onlyslide") {
        self.subsystem = subsystem
        self.logger = os.Logger(subsystem: subsystem, category: label)
    }
    
    // MARK: - Logging Methods
    
    public func trace(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.trace("\(message) [\(sourceInfo(file: file, function: function, line: line))]")
    }
    
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.debug("\(message) [\(sourceInfo(file: file, function: function, line: line))]")
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.info("\(message) [\(sourceInfo(file: file, function: function, line: line))]")
    }
    
    public func notice(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.notice("\(message) [\(sourceInfo(file: file, function: function, line: line))]")
    }
    
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.warning("\(message) [\(sourceInfo(file: file, function: function, line: line))]")
    }
    
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.error("\(message) [\(sourceInfo(file: file, function: function, line: line))]")
    }
    
    public func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.critical("\(message) [\(sourceInfo(file: file, function: function, line: line))]")
    }
    
    public func fault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.fault("\(message) [\(sourceInfo(file: file, function: function, line: line))]")
    }
    
    // MARK: - Private Methods
    
    private func sourceInfo(file: String, function: String, line: Int) -> String {
        let filename = (file as NSString).lastPathComponent
        return "\(filename):\(line) \(function)"
    }
} 