import Foundation

/// AI模型接口
protocol AIModelInterface {
    /// 分析内容
    /// - Parameter text: 要分析的文本
    /// - Returns: 分析结果
    func analyzeContent(text: String) async throws -> String
    
    /// 提取问题
    /// - Parameter text: 源文本
    /// - Returns: 提取的问题列表
    func extractQuestions(text: String) async throws -> [Question]
    
    /// 生成幻灯片
    /// - Parameter text: 源文本
    /// - Returns: 生成的幻灯片内容
    func generateSlides(text: String) async throws -> String
}

/// AI模型工厂
final class AIModelFactory {
    private let selectedModel: String
    private let apiKeys: [String: String]
    
    init(selectedModel: String, apiKeys: [String: String]) {
        self.selectedModel = selectedModel
        self.apiKeys = apiKeys
    }
    
    func getModel(for type: String) -> AIModelInterface? {
        switch type {
        case "deepseek":
            return DeepSeekModel(apiKey: apiKeys["deepseek"])
        case "openai":
            return OpenAIModel(apiKey: apiKeys["openai"])
        default:
            return nil
        }
    }
} 