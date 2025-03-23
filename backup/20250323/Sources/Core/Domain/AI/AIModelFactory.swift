import Foundation

/// AI模型工厂接口
public protocol AIModelFactory {
    /// 注册AI模型
    /// - Parameters:
    ///   - model: AI模型实例
    ///   - type: 模型类型
    func register(_ model: AIModel, for type: AIModelType)
    
    /// 获取AI模型
    /// - Parameter type: 模型类型
    /// - Returns: AI模型实例
    func getModel(for type: AIModelType) -> AIModel?
    
    /// 移除AI模型
    /// - Parameter type: 模型类型
    func removeModel(for type: AIModelType)
    
    /// 更新AI模型
    /// - Parameters:
    ///   - model: 新的AI模型实例
    ///   - type: 模型类型
    func updateModel(_ model: AIModel, for type: AIModelType)
    
    /// 获取所有已注册的AI模型类型
    /// - Returns: 模型类型数组
    func getRegisteredModelTypes() -> [AIModelType]
    
    /// 检查指定类型的模型是否已注册
    /// - Parameter type: 模型类型
    /// - Returns: 是否已注册
    func isModelRegistered(for type: AIModelType) -> Bool
    
    /// 获取模型的配置信息
    /// - Parameter type: 模型类型
    /// - Returns: 配置信息字典
    func getModelConfiguration(for type: AIModelType) -> [String: Any]?
    
    /// 更新模型的配置信息
    /// - Parameters:
    ///   - configuration: 新的配置信息
    ///   - type: 模型类型
    func updateModelConfiguration(_ configuration: [String: Any], for type: AIModelType)
}

/// AI模型接口
public protocol AIModel {
    /// 模型名称
    var name: String { get }
    
    /// API密钥
    var apiKey: String? { get }
    
    /// 生成文本
    /// - Parameters:
    ///   - prompt: 提示文本
    ///   - options: 生成选项
    /// - Returns: 生成的文本
    func generateText(prompt: String, options: [String: Any]?) async throws -> String
    
    /// 生成图像
    /// - Parameters:
    ///   - prompt: 提示文本
    ///   - options: 生成选项
    /// - Returns: 生成的图像数据
    func generateImage(prompt: String, options: [String: Any]?) async throws -> Data
    
    /// 分析图像
    /// - Parameters:
    ///   - imageData: 图像数据
    ///   - options: 分析选项
    /// - Returns: 分析结果
    func analyzeImage(imageData: Data, options: [String: Any]?) async throws -> [String: Any]
    
    /// 处理文档
    /// - Parameter content: 文档内容
    /// - Returns: 处理后的文档内容
    func processDocument(_ content: String) async throws -> String
    
    /// 提取问题
    /// - Parameter content: 文档内容
    /// - Returns: 提取的问题列表
    func extractQuestions(from content: String) async throws -> [Question]
}

public class DefaultAIModelFactory: AIModelFactory {
    public static let shared = DefaultAIModelFactory()
    
    private var models: [AIModelType: AIModel] = [:]
    private var configurations: [AIModelType: [String: Any]] = [:]
    
    private init() {}
    
    public func register(_ model: AIModel, for type: AIModelType) {
        models[type] = model
    }
    
    public func getModel(for type: AIModelType) -> AIModel? {
        return models[type]
    }
    
    public func removeModel(for type: AIModelType) {
        models.removeValue(forKey: type)
        configurations.removeValue(forKey: type)
    }
    
    public func updateModel(_ model: AIModel, for type: AIModelType) {
        models[type] = model
    }
    
    public func getRegisteredModelTypes() -> [AIModelType] {
        return Array(models.keys)
    }
    
    public func isModelRegistered(for type: AIModelType) -> Bool {
        return models[type] != nil
    }
    
    public func getModelConfiguration(for type: AIModelType) -> [String: Any]? {
        return configurations[type]
    }
    
    public func updateModelConfiguration(_ configuration: [String: Any], for type: AIModelType) {
        configurations[type] = configuration
    }
} 