import Foundation

public protocol NetworkClient {
    func get<T: Decodable>(_ endpoint: String, headers: [String: String]?) async throws -> T
    func post<T: Decodable>(_ endpoint: String, parameters: [String: Any], headers: [String: String]?) async throws -> T
    func put<T: Decodable>(_ endpoint: String, parameters: [String: Any], headers: [String: String]?) async throws -> T
    func delete(_ endpoint: String, headers: [String: String]?) async throws
}

public enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case rateLimitExceeded
    case serverError
    case decodingError
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized request"
        case .notFound:
            return "Resource not found"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .serverError:
            return "Server error occurred"
        case .decodingError:
            return "Failed to decode response"
        case .networkError:
            return "Network error occurred"
        }
    }
} 