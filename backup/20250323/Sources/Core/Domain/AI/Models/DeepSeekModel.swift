import Foundation

public class DeepSeekModel: AIModel {
    public let name = "deepseek"
    public let apiKey: String?
    
    private let baseURL = "https://api.deepseek.com/v1"
    private let defaultModel = "deepseek-chat"
    
    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }
    
    public func generateText(prompt: String) async throws -> String {
        guard let apiKey = self.apiKey ?? AIModelFactory.shared.getAPIKey(for: name) else {
            throw AIError.missingAPIKey
        }
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": defaultModel,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.requestFailed
        }
        
        let result = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
        return result.choices.first?.message.content ?? ""
    }
    
    public func generateImage(prompt: String) async throws -> Data {
        throw AIError.unsupportedOperation
    }
    
    public func analyzeImage(_ image: Data) async throws -> String {
        throw AIError.unsupportedOperation
    }
    
    public func processDocument(_ content: String) async throws -> String {
        let prompt = """
        Please process the following document content and improve its structure and clarity:
        
        \(content)
        """
        return try await generateText(prompt: prompt)
    }
    
    public func extractQuestions(from content: String) async throws -> [Question] {
        let prompt = """
        Please extract key questions from the following content. Format the output as a JSON array of questions, where each question has:
        - content: the question text
        - type: one of [factual, analytical, conceptual, application, synthesis, evaluation]
        
        Content:
        \(content)
        """
        
        let response = try await generateText(prompt: prompt)
        let data = response.data(using: .utf8) ?? Data()
        let questions = try JSONDecoder().decode([Question].self, from: data)
        return questions
    }
}

private struct DeepSeekResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

extension AIError {
    static let unsupportedOperation = AIError.custom("Operation not supported by this model")
    
    static func custom(_ message: String) -> AIError {
        return .init(message: message)
    }
    
    private init(message: String) {
        self = .requestFailed
        self._message = message
    }
    
    private var _message: String?
    
    public var errorDescription: String? {
        return _message ?? super.errorDescription
    }
} 