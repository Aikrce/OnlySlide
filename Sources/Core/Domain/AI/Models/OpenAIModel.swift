import Foundation

public class OpenAIModel: AIModel {
    public let name = "openai"
    public let apiKey: String?
    
    private let baseURL = "https://api.openai.com/v1"
    private let defaultModel = "gpt-4"
    private let imageModel = "dall-e-3"
    
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
        
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return result.choices.first?.message.content ?? ""
    }
    
    public func generateImage(prompt: String) async throws -> Data {
        guard let apiKey = self.apiKey ?? AIModelFactory.shared.getAPIKey(for: name) else {
            throw AIError.missingAPIKey
        }
        
        let url = URL(string: "\(baseURL)/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": imageModel,
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.requestFailed
        }
        
        let result = try JSONDecoder().decode(OpenAIImageResponse.self, from: data)
        guard let imageURL = URL(string: result.data.first?.url ?? "") else {
            throw AIError.invalidResponse
        }
        
        let (imageData, _) = try await URLSession.shared.data(from: imageURL)
        return imageData
    }
    
    public func analyzeImage(_ image: Data) async throws -> String {
        guard let apiKey = self.apiKey ?? AIModelFactory.shared.getAPIKey(for: name) else {
            throw AIError.missingAPIKey
        }
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let base64Image = image.base64EncodedString()
        let body: [String: Any] = [
            "model": "gpt-4-vision-preview",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Analyze this image and describe its content."
                        ]
                    ]
                ]
            ],
            "max_tokens": 300
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.requestFailed
        }
        
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return result.choices.first?.message.content ?? ""
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

private struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct OpenAIImageResponse: Codable {
    struct ImageData: Codable {
        let url: String
    }
    let data: [ImageData]
}

public enum AIError: LocalizedError {
    case missingAPIKey
    case requestFailed
    case invalidResponse
    
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing API key"
        case .requestFailed:
            return "Request failed"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
} 