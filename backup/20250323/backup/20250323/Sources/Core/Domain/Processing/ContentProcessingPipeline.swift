import Foundation
import Logging

public protocol ContentProcessor {
    func process(_ content: String) async throws -> String
}

/// 内容处理管道
public final class ContentProcessingPipeline {
    // MARK: - Properties
    
    private var processors: [ContentProcessor] = []
    private let logger = Logger(label: "com.onlyslide.processing.pipeline")
    
    public init() {}
    
    // MARK: - Pipeline Management
    
    /// 添加处理器
    /// - Parameter processor: 处理器
    public func addProcessor(_ processor: ContentProcessor) {
        processors.append(processor)
    }
    
    /// 处理内容
    /// - Parameter content: 要处理的内容
    /// - Returns: 处理后的内容
    public func process(_ content: String) async throws -> String {
        var processedContent = content
        
        for (index, processor) in processors.enumerated() {
            do {
                processedContent = try await processor.process(processedContent)
                logger.info("完成处理步骤 \(index + 1)/\(processors.count)")
            } catch {
                logger.error("处理步骤 \(index + 1) 失败: \(error)")
                throw ContentProcessingError.processorFailed(index: index, error: error)
            }
        }
        
        return processedContent
    }
    
    /// 重置处理管道
    public func reset() {
        processors.removeAll()
    }
}

// MARK: - Errors

public enum ContentProcessingError: Error {
    case processorFailed(index: Int, error: Error)
    case invalidContent
    case processingTimeout
} 