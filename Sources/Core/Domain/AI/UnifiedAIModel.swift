import Foundation

/// 统一的 AI 模型接口
/// 合并了项目中存在的两个不同 AIModel 协议定义
public protocol UnifiedAIModel {
    // 从 AIModel.swift
    var id: String { get }
    var name: String { get }
    var type: AIModelType { get }
    var version: String { get }
    var configuration: [String: Any] { get set }
    
    // 从 AIModelFactory.swift 中的 AIModel
    var apiKey: String? { get }
    
    // 核心方法
    func process(_ input: String) async throws -> String
    func process(_ input: Data) async throws -> Data
    func process(_ input: URL) async throws -> URL
    
    func validate(_ input: String) throws -> Bool
    func validate(_ input: Data) throws -> Bool
    func validate(_ input: URL) throws -> Bool
    
    func configure(with configuration: [String: Any]) throws
    func reset() throws
    
    // 特定任务方法
    func generateText(prompt: String, options: [String: Any]?) async throws -> String
    func generateImage(prompt: String, options: [String: Any]?) async throws -> Data
    func analyzeImage(imageData: Data, options: [String: Any]?) async throws -> [String: Any]
    func processDocument(_ content: String) async throws -> String
    func extractQuestions(from content: String) async throws -> [Question]
}

// MARK: - 默认实现

public extension UnifiedAIModel {
    // 默认实现，以便现有代码可以适配新接口
    func process(_ input: Data) async throws -> Data {
        throw AIModelError.unsupportedOperation
    }
    
    func process(_ input: URL) async throws -> URL {
        throw AIModelError.unsupportedOperation
    }
    
    func validate(_ input: String) throws -> Bool {
        return true
    }
    
    func validate(_ input: Data) throws -> Bool {
        throw AIModelError.unsupportedOperation
    }
    
    func validate(_ input: URL) throws -> Bool {
        throw AIModelError.unsupportedOperation
    }
    
    func reset() throws {
        var config = configuration
        config = [:]
        configure(with: config)
    }
    
    // AIModelFactory.swift 中 AIModel 接口方法的默认实现
    func generateText(prompt: String, options: [String: Any]?) async throws -> String {
        return try await process(prompt)
    }
    
    func generateImage(prompt: String, options: [String: Any]?) async throws -> Data {
        throw AIModelError.unsupportedOperation
    }
    
    func analyzeImage(imageData: Data, options: [String: Any]?) async throws -> [String: Any] {
        throw AIModelError.unsupportedOperation
    }
    
    func processDocument(_ content: String) async throws -> String {
        return try await process(content)
    }
    
    func extractQuestions(from content: String) async throws -> [Question] {
        throw AIModelError.unsupportedOperation
    }
}

// MARK: - Errors

public enum AIModelError: LocalizedError {
    case invalidConfiguration
    case processingFailed
    case unsupportedOperation
    case invalidInput
    case modelNotFound
    case unauthorized
    case networkError
    case rateLimitExceeded
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid model configuration"
        case .processingFailed:
            return "Failed to process input"
        case .unsupportedOperation:
            return "Operation not supported by this model"
        case .invalidInput:
            return "Invalid input provided"
        case .modelNotFound:
            return "AI model not found"
        case .unauthorized:
            return "Unauthorized access to AI model"
        case .networkError:
            return "Network error occurred"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        }
    }
} 