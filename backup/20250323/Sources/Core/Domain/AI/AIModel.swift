public protocol AIModel {
    // MARK: - Properties
    
    var id: String { get }
    var name: String { get }
    var type: AIModelType { get }
    var version: String { get }
    var configuration: [String: Any] { get set }
    
    // MARK: - Methods
    
    func process(_ input: String) async throws -> String
    func process(_ input: Data) async throws -> Data
    func process(_ input: URL) async throws -> URL
    
    func validate(_ input: String) throws -> Bool
    func validate(_ input: Data) throws -> Bool
    func validate(_ input: URL) throws -> Bool
    
    func configure(with configuration: [String: Any]) throws
    func reset() throws
}

// MARK: - Default Implementations

public extension AIModel {
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
        configuration = [:]
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