import Foundation
import Core

// MARK: - HTML Cleanup

public struct HTMLCleanupProcessor: ContentProcessor {
    public init() {}
    
    public func process(_ content: String) async throws -> String {
        // 移除HTML标签
        var cleanContent = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // 解码HTML实体
        cleanContent = cleanContent.replacingOccurrences(of: "&nbsp;", with: " ")
        cleanContent = cleanContent.replacingOccurrences(of: "&amp;", with: "&")
        cleanContent = cleanContent.replacingOccurrences(of: "&lt;", with: "<")
        cleanContent = cleanContent.replacingOccurrences(of: "&gt;", with: ">")
        
        // 移除多余空白
        cleanContent = cleanContent.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return cleanContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Text Normalization

public struct TextNormalizationProcessor: ContentProcessor {
    public init() {}
    
    public func process(_ content: String) async throws -> String {
        // 统一换行符
        var normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")
        
        // 移除连续空行
        normalized = normalized.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        // 规范化标点符号
        normalized = normalized.replacingOccurrences(of: "。。。", with: "...")
        normalized = normalized.replacingOccurrences(of: "？？", with: "?")
        normalized = normalized.replacingOccurrences(of: "！！", with: "!")
        
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Content Segmentation

public struct ContentSegmentationProcessor: ContentProcessor {
    public init() {}
    
    public func process(_ content: String) async throws -> String {
        var segments: [String] = []
        let lines = content.components(separatedBy: "\n")
        var currentSegment: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 空行表示段落分隔
            if trimmed.isEmpty {
                if !currentSegment.isEmpty {
                    segments.append(currentSegment.joined(separator: "\n"))
                    currentSegment.removeAll()
                }
            } else {
                currentSegment.append(trimmed)
            }
        }
        
        // 处理最后一个段落
        if !currentSegment.isEmpty {
            segments.append(currentSegment.joined(separator: "\n"))
        }
        
        return segments.joined(separator: "\n\n")
    }
}

// MARK: - Key Info Extraction

public struct KeyInfoExtractionProcessor: ContentProcessor {
    public init() {}
    
    public func process(_ content: String) async throws -> String {
        var processedContent = content
        
        // 提取问题
        let questionPattern = "(问题|题目|Question)[：:](.*?)(?=\\n|$)"
        if let regex = try? NSRegularExpression(pattern: questionPattern, options: .caseInsensitive) {
            let range = NSRange(processedContent.startIndex..., in: processedContent)
            processedContent = regex.stringByReplacingMatches(
                in: processedContent,
                options: [],
                range: range,
                withTemplate: "【问题】$2"
            )
        }
        
        // 提取答案
        let answerPattern = "(答案|解答|Answer)[：:](.*?)(?=\\n|$)"
        if let regex = try? NSRegularExpression(pattern: answerPattern, options: .caseInsensitive) {
            let range = NSRange(processedContent.startIndex..., in: processedContent)
            processedContent = regex.stringByReplacingMatches(
                in: processedContent,
                options: [],
                range: range,
                withTemplate: "【答案】$2"
            )
        }
        
        return processedContent
    }
}

// MARK: - Factory

public extension ContentProcessingPipeline {
    /// 创建默认的处理管道
    static func createDefault() -> ContentProcessingPipeline {
        let pipeline = ContentProcessingPipeline()
        
        // 添加默认处理器
        pipeline.addProcessor(HTMLCleanupProcessor())
        pipeline.addProcessor(TextNormalizationProcessor())
        pipeline.addProcessor(ContentSegmentationProcessor())
        pipeline.addProcessor(KeyInfoExtractionProcessor())
        
        return pipeline
    }
} 