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
    
    // MARK: - Version Management
    
    /// 检查是否需要迁移
    /// - Parameter storeURL: 存储文件的 URL
    /// - Returns: 是否需要迁移
    public func requiresMigration(at storeURL: URL) throws -> Bool {
        guard let currentModel = currentModel else {
            throw AppError.configurationError("无法加载当前数据模型")
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
            throw AppError.configurationError("找不到兼容的源数据模型")
        }
        return compatibleModel
    }
    
    /// 获取目标模型
    /// - Returns: 当前的目标模型
    public func destinationModel() throws -> NSManagedObjectModel {
        guard let model = currentModel else {
            throw AppError.configurationError("无法加载目标数据模型")
        }
        return model
    }
    
    /// 创建迁移计划
    /// - Parameters:
    ///   - sourceModel: 源模型
    ///   - destinationModel: 目标模型
    /// - Returns: 迁移计划
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
            throw AppError.configurationError("无法创建数据迁移映射")
        }
        
        return inferredMapping
    }
    
    // MARK: - Private Methods
    
    /// 获取自定义映射模型
    private func customMappingModel(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel
    ) -> NSMappingModel? {
        return try? NSMappingModel(
            from: [Bundle.main],
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        )
    }
    
    /// 获取模型版本标识符
    private func modelVersionIdentifier(for model: NSManagedObjectModel) -> String? {
        return model.versionIdentifiers.first as? String
    }
} 