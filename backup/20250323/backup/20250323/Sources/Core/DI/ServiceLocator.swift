import Foundation
import Logging

/// 服务定位器
public final class ServiceLocator {
    // MARK: - Properties
    private static var instance: ServiceLocator?
    private let logger = Logger(label: "com.onlyslide.servicelocator")
    private var services: [String: Any] = [:]
    
    // MARK: - Initialization
    private init() {
        logger.info("初始化服务定位器")
    }
    
    // MARK: - Public Methods
    public static func shared() -> ServiceLocator {
        if instance == nil {
            instance = ServiceLocator()
        }
        return instance!
    }
    
    public func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
        logger.info("注册服务: \(key)")
    }
    
    public func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return services[key] as? T
    }
    
    // MARK: - Setup Methods
    public func setupServices() throws {
        logger.info("设置服务")
        
        // 配置存储服务
        setupStorageServices()
        
        // 配置AI服务
        setupAIServices()
        
        // 配置业务服务
        setupBusinessServices()
    }
    
    private func setupStorageServices() {
        logger.info("设置存储服务")
        
        // 文档存储
        let documentStorage = FileDocumentStorage()
        register(documentStorage, for: DocumentStorage.self)
    }
    
    private func setupAIServices() {
        logger.info("设置AI服务")
        
        // AI模型工厂
        let aiModelFactory = DefaultAIModelFactory()
        register(aiModelFactory, for: AIModelFactory.self)
        
        // 内容处理流水线
        let contentProcessor = ContentProcessingPipeline()
        register(contentProcessor, for: ContentProcessingPipeline.self)
    }
    
    private func setupBusinessServices() {
        logger.info("设置业务服务")
        
        // 获取依赖
        guard let documentStorage = resolve(DocumentStorage.self),
              let aiModelFactory = resolve(AIModelFactory.self),
              let contentProcessor = resolve(ContentProcessingPipeline.self) else {
            logger.error("无法解析所需依赖")
            return
        }
        
        // 缓存管理器
        let cacheManager = DefaultCacheManager()
        register(cacheManager, for: CacheManager.self)
        
        // 文档存储库
        let documentRepository = DefaultDocumentRepository(documentStorage: documentStorage)
        register(documentRepository, for: IDocumentRepository.self)
        
        // 创建文档处理用例
        let processDocumentUseCase = ProcessDocumentUseCaseImpl(
            documentRepository: documentRepository,
            aiModelFactory: aiModelFactory,
            contentProcessor: contentProcessor
        )
        register(processDocumentUseCase, for: IProcessDocumentUseCase.self)
    }
}

// 简单的文件文档存储实现
fileprivate class FileDocumentStorage: DocumentStorage {
    private let logger = Logger(label: "com.onlyslide.filedocumentstorage")
    
    func fetchDocument(withID id: UUID) async throws -> Document? {
        logger.debug("获取文档: \(id)")
        return nil // 桩实现
    }
    
    func fetchAllDocuments() async throws -> [Document] {
        logger.debug("获取所有文档")
        return [] // 桩实现
    }
    
    func saveDocument(_ document: Document) async throws -> Document {
        logger.debug("保存文档: \(document.id)")
        return document // 桩实现
    }
    
    func updateDocument(_ document: Document) async throws -> Document {
        logger.debug("更新文档: \(document.id)")
        return document // 桩实现
    }
    
    func deleteDocument(withID id: UUID) async throws {
        logger.debug("删除文档: \(id)")
        // 桩实现
    }
}

// 简单的文档存储库实现
fileprivate class DefaultDocumentRepository: IDocumentRepository {
    private let documentStorage: DocumentStorage
    private let logger = Logger(label: "com.onlyslide.documentrepository")
    
    init(documentStorage: DocumentStorage) {
        self.documentStorage = documentStorage
    }
    
    func find(byID id: UUID) async throws -> Document? {
        return try await documentStorage.fetchDocument(withID: id)
    }
    
    func findAll() async throws -> [Document] {
        return try await documentStorage.fetchAllDocuments()
    }
    
    func save(_ document: Document) async throws -> Document {
        return try await documentStorage.saveDocument(document)
    }
    
    func update(_ document: Document) async throws -> Document {
        return try await documentStorage.updateDocument(document)
    }
    
    func delete(byID id: UUID) async throws {
        try await documentStorage.deleteDocument(withID: id)
    }
}

// 简单的AI模型工厂实现
fileprivate class DefaultAIModelFactory: AIModelFactory {
    private var models: [String: AIModel] = [:]
    
    func register(model: AIModel, for name: String) {
        models[name] = model
    }
    
    func getModel(named name: String) -> AIModel? {
        return models[name]
    }
}

// MARK: - Service Registration
extension ServiceLocator {
    /// 注册核心服务
    func registerCoreServices() throws {
        // 配置管理器
        let configManager = try FileConfigurationManager.createDefault()
        register(configManager, for: ConfigurationManager.self)
        
        // 缓存管理器
        let cacheManager = try CompositeCacheManager.createDefault()
        register(cacheManager, for: CacheManager.self)
        
        // 文档存储
        let documentStorage = try RealmDocumentStorage()
        register(documentStorage, for: DocumentStorage.self)
    }
    
    /// 注册AI服务
    func registerAIServices() throws {
        // 获取配置
        guard let configManager: ConfigurationManager = resolve(),
              let config = try? configManager.getConfiguration() else {
            throw ServiceError.missingDependency
        }
        
        // 创建AI模型工厂
        let aiModelFactory = AIModelFactory(
            selectedModel: config.aiConfig.selectedModel,
            apiKeys: config.aiConfig.apiKeys
        )
        register(aiModelFactory, for: AIModelFactory.self)
    }
    
    /// 注册文档处理服务
    func registerDocumentServices() throws {
        // 获取依赖
        guard let documentStorage: DocumentStorage = resolve(),
              let cacheManager: CacheManager = resolve(),
              let configManager: ConfigurationManager = resolve() else {
            throw ServiceError.missingDependency
        }
        
        // 创建文档处理管道
        let processingPipeline = ContentProcessingPipeline()
        register(processingPipeline, for: ContentProcessingPipeline.self)
        
        // 创建文档处理用例
        let processDocumentUseCase = ProcessDocumentUseCaseImpl(
            documentStorage: documentStorage,
            cacheManager: cacheManager,
            configManager: configManager
        )
        register(processDocumentUseCase, for: ProcessDocumentUseCase.self)
    }
}

// MARK: - Service Resolution
extension ServiceLocator {
    /// 获取服务
    func getService<T>() throws -> T {
        guard let service: T = resolve() else {
            throw ServiceError.serviceNotFound
        }
        return service
    }
}

// MARK: - Errors
enum ServiceError: Error {
    case serviceNotFound
    case missingDependency
    case invalidConfiguration
} 