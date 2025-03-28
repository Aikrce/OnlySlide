@preconcurrency import CoreData
@preconcurrency import Foundation

/// Core Data 模型版本管理器
public final class CoreDataModelVersionManager: @unchecked Sendable {
    // MARK: - Properties
    
    @MainActor public static let shared = CoreDataModelVersionManager()
    private let modelName = "OnlySlide"
    
    /// 资源管理器
    internal let resourceManager: CoreDataResourceManager
    
    // MARK: - Initialization
    
    /// 初始化模型版本管理器
    /// - Parameter resourceManager: 资源管理器
    public init(resourceManager: CoreDataResourceManager = CoreDataResourceManager.shared) {
        self.resourceManager = resourceManager
    }
    
    /// 当前模型版本
    private var currentModel: NSManagedObjectModel? {
        return resourceManager.mergedObjectModel()
    }
    
    /// 所有可用的模型版本
    private var availableModels: [NSManagedObjectModel] {
        return resourceManager.allModels()
    }
    
    /// 获取所有可用的模型版本
    /// - Returns: 所有可用模型的版本信息
    public func availableModelVersions() -> [ModelVersion] {
        return availableModels.compactMap { model in
            ModelVersion(versionIdentifiers: model.versionIdentifiers)
        }.sorted()
    }
    
    /// 获取指定模型版本的模型
    /// - Parameter version: 模型版本
    /// - Returns: 对应版本的管理对象模型
    public func model(for version: ModelVersion) -> NSManagedObjectModel? {
        return availableModels.first { model in
            guard let modelVersion = ModelVersion(versionIdentifiers: model.versionIdentifiers) else {
                return false
            }
            return modelVersion.identifier == version.identifier
        }
    }
    
    /// 获取当前模型的版本
    /// - Returns: 当前模型版本
    public func currentModelVersion() -> ModelVersion? {
        guard let currentModel = currentModel else {
            return nil
        }
        return ModelVersion(versionIdentifiers: currentModel.versionIdentifiers)
    }
    
    // MARK: - Version Management
    
    /// 检查是否需要迁移
    /// - Parameter storeURL: 存储文件的 URL
    /// - Returns: 是否需要迁移
    public func requiresMigration(at storeURL: URL) throws -> Bool {
        guard let currentModel = currentModel else {
            throw CoreDataError.modelNotFound("无法加载当前数据模型")
        }
        
        // 获取存储元数据
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        
        // 检查兼容性
        return !currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
    }
    
    /// 获取源模型
    /// - Parameter metadata: 存储元数据
    /// - Returns: 兼容的源模型
    public func sourceModel(for metadata: [String: Any]) throws -> NSManagedObjectModel {
        guard let compatibleModel = availableModels.first(where: {
            $0.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }) else {
            throw CoreDataError.modelNotFound("找不到兼容的源数据模型")
        }
        return compatibleModel
    }
    
    /// 获取源模型版本
    /// - Parameter metadata: 存储元数据
    /// - Returns: 源模型版本
    public func sourceModelVersion(for metadata: [String: Any]) throws -> ModelVersion {
        let sourceModel = try sourceModel(for: metadata)
        guard let version = ModelVersion(versionIdentifiers: sourceModel.versionIdentifiers) else {
            throw CoreDataError.modelNotFound("无法确定源模型版本")
        }
        return version
    }
    
    /// 获取目标模型
    /// - Returns: 当前的目标模型
    public func destinationModel() throws -> NSManagedObjectModel {
        guard let model = currentModel else {
            throw CoreDataError.modelNotFound("无法加载目标数据模型")
        }
        return model
    }
    
    /// 获取目标模型版本
    /// - Returns: 目标模型版本
    public func destinationModelVersion() throws -> ModelVersion {
        guard let model = currentModel, 
              let version = ModelVersion(versionIdentifiers: model.versionIdentifiers) else {
            throw CoreDataError.modelNotFound("无法确定目标模型版本")
        }
        return version
    }
    
    /// 查找迁移路径
    /// - Parameters:
    ///   - sourceVersion: 源模型版本
    ///   - destinationVersion: 目标模型版本
    /// - Returns: 迁移路径（模型版本序列）
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
    
    /// 创建迁移映射
    /// - Parameters:
    ///   - sourceModel: 源模型
    ///   - destinationModel: 目标模型
    /// - Returns: 迁移映射
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
    
    /// 查找下一个模型版本
    /// - Parameters:
    ///   - sourceModel: 源模型
    ///   - destinationModel: 目标模型
    /// - Returns: 下一个要迁移到的模型
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
        // 使用资源管理器的搜索Bundles
        let bundles = resourceManager.searchBundles
        
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
            logger.info("使用标准API找到自定义映射模型")
            return mapping
        } catch {
            logger.debug("未找到自定义映射模型，将使用推断的映射模型: \(error.localizedDescription)")
            
            // 如果找不到自定义映射，尝试使用自定义映射模型查找器
            do {
                let finder = MappingModelFinder()
                if let mapping = try finder.findMappingModel(
                    from: sourceModel,
                    to: destinationModel,
                    in: bundles
                ) {
                    logger.info("使用自定义查找器找到映射模型")
                    return mapping
                }
            } catch {
                logger.warning("自定义映射模型查找器失败: \(error.localizedDescription)")
            }
            
            return nil
        }
    }
} 