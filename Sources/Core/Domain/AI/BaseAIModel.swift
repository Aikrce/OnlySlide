open class BaseAIModel: AIModel {
    // MARK: - Properties
    
    public let id: String
    public let name: String
    public let type: AIModelType
    public let version: String
    public var configuration: [String: Any]
    
    // MARK: - Initialization
    
    public init(
        id: String,
        name: String,
        type: AIModelType,
        version: String,
        configuration: [String: Any] = [:]
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.version = version
        self.configuration = configuration
    }
    
    // MARK: - AIModel Protocol Methods
    
    open func process(_ input: String) async throws -> String {
        throw AIModelError.unsupportedOperation
    }
    
    open func process(_ input: Data) async throws -> Data {
        throw AIModelError.unsupportedOperation
    }
    
    open func process(_ input: URL) async throws -> URL {
        throw AIModelError.unsupportedOperation
    }
    
    open func validate(_ input: String) throws -> Bool {
        return true
    }
    
    open func validate(_ input: Data) throws -> Bool {
        throw AIModelError.unsupportedOperation
    }
    
    open func validate(_ input: URL) throws -> Bool {
        throw AIModelError.unsupportedOperation
    }
    
    open func configure(with configuration: [String: Any]) throws {
        self.configuration = configuration
    }
    
    open func reset() throws {
        configuration = [:]
    }
    
    // MARK: - Protected Methods
    
    internal func validateConfiguration() throws {
        // 子类可以重写此方法以实现特定的配置验证
        guard !configuration.isEmpty else {
            throw AIModelError.invalidConfiguration
        }
    }
    
    internal func validateAPIKey() throws {
        guard let apiKey = configuration["apiKey"] as? String,
              !apiKey.isEmpty else {
            throw AIModelError.unauthorized
        }
    }
    
    internal func validateEndpoint() throws {
        guard let endpoint = configuration["endpoint"] as? String,
              !endpoint.isEmpty else {
            throw AIModelError.invalidConfiguration
        }
    }
} 