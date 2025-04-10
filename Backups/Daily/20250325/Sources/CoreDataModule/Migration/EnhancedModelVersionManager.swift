import CoreData
import Foundation
import Combine
import os

// MARK: - 模型版本管理协议

/// 模型版本管理协议
public protocol ModelVersionManaging: Sendable {
    /// 获取所有可用的模型版本
    func availableModelVersions() -> [ModelVersion]
    
    /// 获取指定模型版本的模型
    func model(for version: ModelVersion) -> NSManagedObjectModel?
    
    /// 获取当前模型的版本
    func currentModelVersion() -> ModelVersion?
    
    /// 检查是否需要迁移
    func requiresMigration(at storeURL: URL) throws -> Bool
    
    /// 获取源模型
    func sourceModel(for metadata: [String: Any]) throws -> NSManagedObjectModel
    
    /// 获取源模型版本
    func sourceModelVersion(for metadata: [String: Any]) throws -> ModelVersion
    
    /// 获取目标模型
    func destinationModel() throws -> NSManagedObjectModel
    
    /// 获取目标模型版本
    func destinationModelVersion() throws -> ModelVersion
    
    /// 查找迁移路径
    func migrationPath(from sourceVersion: ModelVersion, to destinationVersion: ModelVersion) -> [ModelVersion]
    
    /// 创建迁移映射
    func migrationMapping(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel
    ) throws -> NSMappingModel
    
    /// 查找下一个模型版本
    func findNextModel(
        after sourceModel: NSManagedObjectModel,
        towards destinationModel: NSManagedObjectModel
    ) throws -> NSManagedObjectModel?
}

/// 资源提供协议
public protocol ResourceProviding: Sendable {
    /// 合并的对象模型
    func mergedObjectModel() -> NSManagedObjectModel?
    
    /// 所有可用的模型
    func allModels() -> [NSManagedObjectModel]
    
    /// 搜索包
    var searchBundles: [Bundle] { get }
}

// MARK: - 增强型模型版本管理器

/// 增强的 Core Data 模型版本管理器
public struct EnhancedModelVersionManager: ModelVersionManaging {
    // MARK: - Properties
    
    /// 日志记录器
    private let logger: Logger
    
    /// 资源提供者
    private let resourceProvider: ResourceProviding
    
    /// 模型名称
    private let modelName: String
    
    // MARK: - Initialization
    
    /// 初始化模型版本管理器
    /// - Parameters:
    ///   - resourceProvider: 资源提供者
    ///   - modelName: 模型名称
    ///   - logger: 日志记录器
    public init(
        resourceProvider: ResourceProviding,
        modelName: String = "OnlySlide",
        logger: Logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "ModelVersionManager")
    ) {
        self.resourceProvider = resourceProvider
        self.modelName = modelName
        self.logger = logger
    }
    
    /// 创建默认的模型版本管理器
    /// - Returns: 配置好的模型版本管理器
    public static func createDefault() -> EnhancedModelVersionManager {
        return EnhancedModelVersionManager(resourceProvider: CoreDataResourceManager.shared)
    }
    
    /// 当前模型版本
    private var currentModel: NSManagedObjectModel? {
        return resourceProvider.mergedObjectModel()
    }
    
    /// 所有可用的模型版本
    private var availableModels: [NSManagedObjectModel] {
        return resourceProvider.allModels()
    }
    
    // MARK: - ModelVersionManaging Implementation
    
    public func availableModelVersions() -> [ModelVersion] {
        return availableModels.compactMap { model in
            ModelVersion(versionIdentifiers: model.versionIdentifiers)
        }.sorted()
    }
    
    public func model(for version: ModelVersion) -> NSManagedObjectModel? {
        return availableModels.first { model in
            guard let modelVersion = ModelVersion(versionIdentifiers: model.versionIdentifiers) else {
                return false
            }
            return modelVersion.identifier == version.identifier
        }
    }
    
    public func currentModelVersion() -> ModelVersion? {
        guard let currentModel = currentModel else {
            return nil
        }
        return ModelVersion(versionIdentifiers: currentModel.versionIdentifiers)
    }
    
    public func requiresMigration(at storeURL: URL) throws -> Bool {
        guard let currentModel = currentModel else {
            throw CoreDataError.modelNotFound("无法加载当前数据模型")
        }
        
        do {
            // 获取存储元数据
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
            
            // 检查兼容性
            return !currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        } catch {
            // 优化错误处理
            if (error as NSError).domain == NSCocoaErrorDomain && 
               (error as NSError).code == NSFileReadNoSuchFileError {
                // 文件不存在的情况下，不需要迁移
                logger.notice("存储文件不存在: \(storeURL.path)")
                return false
            }
            throw error
        }
    }
    
    public func sourceModel(for metadata: [String: Any]) throws -> NSManagedObjectModel {
        guard let compatibleModel = availableModels.first(where: {
            $0.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }) else {
            throw CoreDataError.modelNotFound("找不到兼容的源数据模型")
        }
        return compatibleModel
    }
    
    public func sourceModelVersion(for metadata: [String: Any]) throws -> ModelVersion {
        let sourceModel = try sourceModel(for: metadata)
        guard let version = ModelVersion(versionIdentifiers: sourceModel.versionIdentifiers) else {
            throw CoreDataError.modelNotFound("无法确定源模型版本")
        }
        return version
    }
    
    public func destinationModel() throws -> NSManagedObjectModel {
        guard let model = currentModel else {
            throw CoreDataError.modelNotFound("无法加载目标数据模型")
        }
        return model
    }
    
    public func destinationModelVersion() throws -> ModelVersion {
        guard let model = currentModel, 
              let version = ModelVersion(versionIdentifiers: model.versionIdentifiers) else {
            throw CoreDataError.modelNotFound("无法确定目标模型版本")
        }
        return version
    }
    
    public func migrationPath(from sourceVersion: ModelVersion, to destinationVersion: ModelVersion) -> [ModelVersion] {
        // 如果源版本和目标版本相同，返回空数组
        if sourceVersion.identifier == destinationVersion.identifier {
            return []
        }
        
        // 如果源版本大于目标版本，返回空数组
        if sourceVersion > destinationVersion {
            return []
        }
        
        // 计算版本序列
        return ModelVersion.sequence(from: sourceVersion, to: destinationVersion)
    }
    
    public func migrationMapping(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel
    ) throws -> NSMappingModel {
        // 尝试获取自定义映射模型
        if let customMapping = customMappingModel(from: sourceModel, to: destinationModel) {
            return customMapping
        }
        
        // 尝试推断映射模型
        do {
            let inferredMapping = try NSMappingModel.inferredMappingModel(
                forSourceModel: sourceModel,
                destinationModel: destinationModel
            )
            return inferredMapping
        } catch {
            throw CoreDataError.migrationFailed("无法创建数据迁移映射: \(error.localizedDescription)")
        }
    }
    
    public func findNextModel(
        after sourceModel: NSManagedObjectModel,
        towards destinationModel: NSManagedObjectModel
    ) throws -> NSManagedObjectModel? {
        // 获取源模型和目标模型的版本
        guard let sourceVersion = ModelVersion(versionIdentifiers: sourceModel.versionIdentifiers),
              let destinationVersion = ModelVersion(versionIdentifiers: destinationModel.versionIdentifiers) else {
            throw CoreDataError.migrationFailed("无法确定模型版本")
        }
        
        // 如果源版本和目标版本相同，不需要迁移
        if sourceVersion.identifier == destinationVersion.identifier {
            return nil
        }
        
        // 计算迁移路径
        let migrationPath = self.migrationPath(from: sourceVersion, to: destinationVersion)
        
        // 如果迁移路径为空，无法确定下一个模型
        if migrationPath.isEmpty {
            return nil
        }
        
        // 获取下一个版本的模型
        let nextVersion = migrationPath[0]
        return model(for: nextVersion)
    }
    
    // MARK: - Private Methods
    
    /// 获取自定义映射模型
    private func customMappingModel(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel
    ) -> NSMappingModel? {
        // 使用资源提供者的搜索Bundles
        let bundles = resourceProvider.searchBundles
        
        // 获取源模型和目标模型的版本
        guard let sourceVersion = ModelVersion(versionIdentifiers: sourceModel.versionIdentifiers),
              let destinationVersion = ModelVersion(versionIdentifiers: destinationModel.versionIdentifiers) else {
            logger.warning("无法确定迁移模型版本，无法使用自定义映射")
            return nil
        }
        
        // 记录正在查找的映射模型
        logger.debug("查找自定义映射模型: 从 \(sourceVersion.identifier) 到 \(destinationVersion.identifier)")
        
        // 构建各种可能的映射名称格式
        let mappingNames = [
            "Mapping_\(sourceVersion.identifier)_to_\(destinationVersion.identifier)",
            "\(sourceVersion.identifier)_to_\(destinationVersion.identifier)",
            "\(sourceVersion.identifier)To\(destinationVersion.identifier)",
            "\(sourceVersion.identifier)-\(destinationVersion.identifier)"
        ]
        
        // 查找各种可能的映射文件扩展名
        let extensions = ["cdm", "xcmappingmodel"]
        
        // 尝试所有组合
        for bundle in bundles {
            for name in mappingNames {
                for ext in extensions {
                    if let mappingPath = bundle.path(forResource: name, ofType: ext),
                       let mapping = NSMappingModel(contentsOf: URL(fileURLWithPath: mappingPath)) {
                        logger.info("找到自定义映射模型: \(mappingPath)")
                        return mapping
                    }
                }
            }
        }
        
        // 如果没有找到特定命名的映射模型，尝试使用标准API
        do {
            let mapping = try NSMappingModel(
                from: bundles,
                forSourceModel: sourceModel,
                destinationModel: destinationModel
            )
            logger.info("使用系统API找到自定义映射模型")
            return mapping
        } catch {
            logger.notice("找不到自定义映射模型，将使用推断映射: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - CoreDataResourceManager + ResourceProviding

/// 使现有的资源管理器符合资源提供协议
extension CoreDataResourceManager: ResourceProviding {
    // 已经实现了所需方法，只需要符合协议即可
}

// MARK: - DependencyRegistry Extension

/// 依赖注册表扩展，注册模型版本管理器
extension DependencyRegistry {
    /// 注册工厂
    public func registerFactories() {
        // 注册模型版本管理器
        registerShared(ModelVersionManagerFactory())
        
        // 注册其他工厂...
    }
}

/// 模型版本管理器工厂
public struct ModelVersionManagerFactory: Factory {
    public typealias Instance = EnhancedModelVersionManager
    
    public func create() -> EnhancedModelVersionManager {
        return EnhancedModelVersionManager.createDefault()
    }
}

// MARK: - 兼容层

/// 将新的基于值类型的实现与现有API集成
@MainActor
public struct ModelVersionManagerAdapter: Sendable {
    /// 共享实例
    public static let shared = ModelVersionManagerAdapter()
    
    /// 内部使用的增强管理器
    private let enhancedManager: EnhancedModelVersionManager
    
    /// 初始化适配器
    /// - Parameter manager: 增强型模型版本管理器
    public init(manager: EnhancedModelVersionManager = EnhancedModelVersionManager.createDefault()) {
        self.enhancedManager = manager
    }
    
    /// 代理方法调用
    /// - Returns: 增强管理器
    public func manager() -> EnhancedModelVersionManager {
        return enhancedManager
    }
    
    /// 在旧代码中使用新实现的兼容函数
    public func compatibleAvailableModelVersions() -> [String] {
        return enhancedManager.availableModelVersions().map { $0.identifier }
    }
    
    /// 兼容方法：检查是否需要迁移
    public func compatibleRequiresMigration(at storeURL: URL) throws -> Bool {
        do {
            return try enhancedManager.requiresMigration(at: storeURL)
        } catch {
            // 保持与旧API相同的错误处理方式
            print("Error checking migration requirement: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 兼容方法：获取源模型
    public func compatibleSourceModel(for metadata: [String: Any]) throws -> NSManagedObjectModel {
        return try enhancedManager.sourceModel(for: metadata)
    }
    
    /// 兼容方法：获取源模型版本
    public func compatibleSourceModelVersion(for metadata: [String: Any]) throws -> String {
        return try enhancedManager.sourceModelVersion(for: metadata).identifier
    }
    
    /// 兼容方法：获取目标模型
    public func compatibleDestinationModel() throws -> NSManagedObjectModel {
        return try enhancedManager.destinationModel()
    }
    
    /// 兼容方法：获取目标模型版本
    public func compatibleDestinationModelVersion() throws -> String {
        return try enhancedManager.destinationModelVersion().identifier
    }
}

/// 全局访问函数（进一步减少对类的依赖）
@MainActor
public func getModelVersionManager() -> EnhancedModelVersionManager {
    return ModelVersionManagerAdapter.shared.manager()
} 