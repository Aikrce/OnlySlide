import CoreData
import Foundation

/// 模型版本定义结构体
public struct ModelVersionDefinition: Sendable {
    /// 版本信息
    public let version: ModelVersion
    /// 映射块，用于自定义迁移逻辑
    public let mappingBlock: (@Sendable (NSMappingModel) -> Void)?
    
    /// 初始化模型版本定义
    /// - Parameters:
    ///   - version: 模型版本
    ///   - mappingBlock: 可选的映射块
    public init(version: ModelVersion, mappingBlock: (@Sendable (NSMappingModel) -> Void)? = nil) {
        self.version = version
        self.mappingBlock = mappingBlock
    }
}

/// 模型版本定义注册表类
@MainActor
public final class ModelVersionDefinitionRegistry {
    /// 单例对象
    public static let shared = ModelVersionDefinitionRegistry()
    
    /// 所有注册的版本定义
    private(set) var definitions: [ModelVersionDefinition] = []
    /// 当前使用的版本
    private var _currentVersion: ModelVersion?
    
    /// 私有初始化方法，确保单例模式
    private init() {}
    
    /// 注册一个版本
    /// - Parameters:
    ///   - version: 模型版本
    ///   - mappingBlock: 可选的映射块
    public func register(version: ModelVersion, mappingBlock: (@Sendable (NSMappingModel) -> Void)? = nil) {
        let definition = ModelVersionDefinition(version: version, mappingBlock: mappingBlock)
        definitions.append(definition)
    }
    
    /// 设置当前版本
    /// - Parameter version: 当前使用的版本
    public func setCurrentVersion(_ version: ModelVersion) {
        _currentVersion = version
    }
    
    /// 获取当前版本
    /// - Returns: 当前版本，如果未设置则返回nil
    public func currentVersion() -> ModelVersion? {
        return _currentVersion
    }
    
    /// 获取目标版本（通常是最新版本）
    /// - Returns: 目标版本
    public func destinationVersion() -> ModelVersion {
        guard let lastDefinition = sortedDefinitions().last else {
            fatalError("没有注册的模型版本")
        }
        return lastDefinition.version
    }
    
    /// 获取最新版本
    /// - Returns: 最新的注册版本
    public func latestVersion() -> ModelVersion {
        return destinationVersion()
    }
    
    /// 是否需要迁移
    /// - Returns: 当前版本是否需要迁移到目标版本
    public func requiresMigration() -> Bool {
        guard let current = currentVersion() else {
            // 如果未设置当前版本，假设需要迁移
            return true
        }
        
        let destination = destinationVersion()
        return current.identifier != destination.identifier
    }
    
    /// 按版本排序的定义列表
    /// - Returns: 排序后的模型版本定义列表
    public func sortedDefinitions() -> [ModelVersionDefinition] {
        return definitions.sorted { $0.version < $1.version }
    }
    
    /// 计算迁移路径
    /// - Parameters:
    ///   - source: 源版本
    ///   - destination: 目标版本
    /// - Returns: 迁移步骤列表
    public func migrationPath(from source: ModelVersion, to destination: ModelVersion) -> [MigrationStepDefinition] {
        // 如果源版本和目标版本相同，返回空数组
        if source.identifier == destination.identifier {
            return []
        }
        
        // 如果源版本大于目标版本，返回空数组（不支持降级）
        if source > destination {
            return []
        }
        
        // 获取排序后的定义
        let sortedDefs = sortedDefinitions()
        
        // 查找源版本和目标版本的索引
        guard let sourceIndex = sortedDefs.firstIndex(where: { $0.version.identifier == source.identifier }),
              let destIndex = sortedDefs.firstIndex(where: { $0.version.identifier == destination.identifier }),
              sourceIndex < destIndex else {
            return []
        }
        
        // 创建迁移步骤
        var steps: [MigrationStepDefinition] = []
        
        for i in sourceIndex..<destIndex {
            let sourceVersion = sortedDefs[i].version
            let destVersion = sortedDefs[i + 1].version
            
            let step = MigrationStepDefinition(
                sourceVersion: sourceVersion,
                destinationVersion: destVersion,
                mappingBlock: sortedDefs[i + 1].mappingBlock
            )
            
            steps.append(step)
        }
        
        return steps
    }
    
    /// 获取迁移定义
    /// - Parameter version: 目标版本
    /// - Returns: 对应版本的定义
    public func definition(for version: ModelVersion) -> ModelVersionDefinition? {
        return definitions.first { $0.version.identifier == version.identifier }
    }
    
    /// 检查指定版本是否已注册
    /// - Parameter version: 要检查的版本
    /// - Returns: 是否已经注册
    public func isVersionRegistered(_ version: ModelVersion) -> Bool {
        return definitions.contains { $0.version.identifier == version.identifier }
    }
    
    /// 清除所有注册的版本定义（主要用于测试）
    public func clearAllDefinitions() {
        definitions.removeAll()
        _currentVersion = nil
    }
}

/// 迁移步骤定义结构体
public struct MigrationStepDefinition: Sendable {
    /// 源版本
    public let sourceVersion: ModelVersion
    /// 目标版本
    public let destinationVersion: ModelVersion
    /// 可选的映射块
    public let mappingBlock: (@Sendable (NSMappingModel) -> Void)?
    
    /// 初始化迁移步骤定义
    /// - Parameters:
    ///   - sourceVersion: 源版本
    ///   - destinationVersion: 目标版本
    ///   - mappingBlock: 映射块（可选）
    public init(
        sourceVersion: ModelVersion,
        destinationVersion: ModelVersion,
        mappingBlock: (@Sendable (NSMappingModel) -> Void)? = nil
    ) {
        self.sourceVersion = sourceVersion
        self.destinationVersion = destinationVersion
        self.mappingBlock = mappingBlock
    }
}