import Foundation
import CoreData

/// 负责规划迁移过程
@MainActor public final class MigrationPlanner: @unchecked Sendable {
    // MARK: - Properties
    
    /// 资源管理器
    private let resourceManager: CoreDataResourceManager
    
    /// 模型版本管理器
    private let modelVersionManager: CoreDataModelVersionManager
    
    // MARK: - Initialization
    
    /// 初始化迁移计划器
    /// - Parameters:
    ///   - resourceManager: 资源管理器
    ///   - modelVersionManager: 模型版本管理器
    public init(
        resourceManager: CoreDataResourceManager = .shared,
        modelVersionManager: CoreDataModelVersionManager = .shared
    ) {
        self.resourceManager = resourceManager
        self.modelVersionManager = modelVersionManager
    }
    
    // MARK: - Public Methods
    
    /// 检查是否需要迁移
    /// - Parameter storeURL: 存储 URL
    /// - Returns: 是否需要迁移
    public func requiresMigration(at storeURL: URL) async throws -> Bool {
        // 如果文件不存在，不需要迁移
        if !FileManager.default.fileExists(atPath: storeURL.path) {
            return false
        }
        
        return try modelVersionManager.requiresMigration(at: storeURL)
    }
    
    /// 创建迁移计划
    /// - Parameter storeURL: 存储 URL
    /// - Returns: 迁移计划
    public func createMigrationPlan(for storeURL: URL) async throws -> MigrationPlan {
        // 获取存储元数据
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        
        // 获取源版本和目标版本
        let sourceVersion = try modelVersionManager.sourceModelVersion(for: metadata)
        let destinationVersion = try modelVersionManager.destinationModelVersion()
        
        // 如果源版本和目标版本相同，则不需要迁移
        if sourceVersion.identifier == destinationVersion.identifier {
            return MigrationPlan(
                sourceVersion: sourceVersion,
                destinationVersion: destinationVersion,
                steps: [],
                storeURL: storeURL
            )
        }
        
        // 计算迁移路径
        let migrationPath = modelVersionManager.migrationPath(from: sourceVersion, to: destinationVersion)
        
        // 创建迁移步骤
        var steps: [MigrationStep] = []
        
        for (index, version) in migrationPath.enumerated() {
            let step = MigrationStep(
                index: index + 1,
                sourceVersion: index == 0 ? sourceVersion : migrationPath[index - 1],
                destinationVersion: version
            )
            steps.append(step)
        }
        
        return MigrationPlan(
            sourceVersion: sourceVersion,
            destinationVersion: destinationVersion,
            steps: steps,
            storeURL: storeURL
        )
    }
    
    /// 获取迁移步骤的源模型
    /// - Parameter step: 迁移步骤
    /// - Returns: 源模型
    public func sourceModel(for step: MigrationStep) throws -> NSManagedObjectModel {
        guard let model = modelVersionManager.model(for: step.sourceVersion) else {
            throw MigrationError.modelNotFound(description: "找不到版本 \(step.sourceVersion.description) 的模型")
        }
        return model
    }
    
    /// 获取迁移步骤的目标模型
    /// - Parameter step: 迁移步骤
    /// - Returns: 目标模型
    public func destinationModel(for step: MigrationStep) throws -> NSManagedObjectModel {
        guard let model = modelVersionManager.model(for: step.destinationVersion) else {
            throw MigrationError.modelNotFound(description: "找不到版本 \(step.destinationVersion.description) 的模型")
        }
        return model
    }
    
    /// 获取迁移步骤的映射模型
    /// - Parameter step: 迁移步骤
    /// - Returns: 映射模型
    public func mappingModel(for step: MigrationStep) throws -> NSMappingModel {
        let sourceModel = try self.sourceModel(for: step)
        let destinationModel = try self.destinationModel(for: step)
        
        return try modelVersionManager.migrationMapping(
            from: sourceModel,
            to: destinationModel
        )
    }
} 