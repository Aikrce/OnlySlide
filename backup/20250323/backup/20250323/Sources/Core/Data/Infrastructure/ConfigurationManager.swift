import Foundation

/// 应用配置
struct AppConfiguration: Codable {
    /// AI模型配置
    struct AIConfig: Codable {
        var selectedModel: String
        var apiKeys: [String: String]
        var maxTokens: Int
        var temperature: Double
    }
    
    /// 缓存配置
    struct CacheConfig: Codable {
        var memoryCacheSize: Int
        var diskCacheSize: Int
        var defaultExpirationInterval: TimeInterval
    }
    
    /// 文档处理配置
    struct ProcessingConfig: Codable {
        var maxDocumentSize: Int
        var supportedFileTypes: [String]
        var processingTimeout: TimeInterval
    }
    
    var aiConfig: AIConfig
    var cacheConfig: CacheConfig
    var processingConfig: ProcessingConfig
}

/// 配置管理器协议
protocol ConfigurationManager {
    /// 获取配置
    func getConfiguration() throws -> AppConfiguration
    
    /// 更新配置
    func updateConfiguration(_ configuration: AppConfiguration) throws
    
    /// 重置为默认配置
    func resetToDefault() throws
}

/// 文件配置管理器
final class FileConfigurationManager: ConfigurationManager {
    // MARK: - Properties
    private let fileManager = FileManager.default
    private let configURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    init() throws {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let appDirectory = applicationSupport.appendingPathComponent("OnlySlide", isDirectory: true)
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        self.configURL = appDirectory.appendingPathComponent("config.json")
        
        // 如果配置文件不存在，创建默认配置
        if !fileManager.fileExists(atPath: configURL.path) {
            try resetToDefault()
        }
    }
    
    // MARK: - ConfigurationManager
    func getConfiguration() throws -> AppConfiguration {
        let data = try Data(contentsOf: configURL)
        return try decoder.decode(AppConfiguration.self, from: data)
    }
    
    func updateConfiguration(_ configuration: AppConfiguration) throws {
        let data = try encoder.encode(configuration)
        try data.write(to: configURL)
    }
    
    func resetToDefault() throws {
        let defaultConfig = AppConfiguration(
            aiConfig: .init(
                selectedModel: "deepseek",
                apiKeys: [:],
                maxTokens: 2048,
                temperature: 0.7
            ),
            cacheConfig: .init(
                memoryCacheSize: 50 * 1024 * 1024, // 50MB
                diskCacheSize: 500 * 1024 * 1024,  // 500MB
                defaultExpirationInterval: 86400    // 24小时
            ),
            processingConfig: .init(
                maxDocumentSize: 10 * 1024 * 1024, // 10MB
                supportedFileTypes: ["txt", "md", "doc", "docx", "pdf"],
                processingTimeout: 300              // 5分钟
            )
        )
        
        try updateConfiguration(defaultConfig)
    }
}

// MARK: - Factory
extension FileConfigurationManager {
    /// 创建默认的配置管理器
    static func createDefault() throws -> ConfigurationManager {
        return try FileConfigurationManager()
    }
} 