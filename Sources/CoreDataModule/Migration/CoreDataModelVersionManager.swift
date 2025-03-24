import CoreData
import Foundation

/// Core Data 模型版本管理器
public final class CoreDataModelVersionManager {
    // MARK: - Properties
    
    public static let shared = CoreDataModelVersionManager()
    private let modelName = "OnlySlide"
    
    /// 当前模型版本
    private var currentModel: NSManagedObjectModel? {
        return NSManagedObjectModel.mergedModel(from: [Bundle.main])
    }
    
    /// 所有可用的模型版本
    private var availableModels: [NSManagedObjectModel] {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd") else {
            return []
        }
        
        let modelVersions = try? FileManager.default.contentsOfDirectory(
            at: modelURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        return modelVersions?.compactMap { url in
            guard url.pathExtension == "mom" else { return nil }
            return NSManagedObjectModel(contentsOf: url)
        } ?? []
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
        guard let inferredMapping = try? NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        ) else {
            throw CoreDataError.migrationFailed("无法创建数据迁移映射")
        }
        
        return inferredMapping
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
        // 从包含映射模型的bundle数组中查找
        let bundles = [Bundle.main]
        
        // 获取源模型和目标模型的版本
        guard let sourceVersion = ModelVersion(versionIdentifiers: sourceModel.versionIdentifiers),
              let destinationVersion = ModelVersion(versionIdentifiers: destinationModel.versionIdentifiers) else {
            return nil
        }
        
        // 尝试使用自定义名称查找映射模型
        let mappingName = "Mapping_\(sourceVersion.identifier)_to_\(destinationVersion.identifier)"
        
        for bundle in bundles {
            if let mappingPath = bundle.path(forResource: mappingName, ofType: "cdm"),
               let mapping = NSMappingModel(contentsOf: URL(fileURLWithPath: mappingPath)) {
                return mapping
            }
        }
        
        // 尝试使用标准API查找映射模型
        return try? NSMappingModel(
            from: bundles,
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        )
    }
} 