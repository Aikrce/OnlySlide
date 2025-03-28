import XCTest
@testable import CoreDataModule

/// ModelVersionDefinition测试类
/// 用于测试模型版本定义的相关功能
class ModelVersionDefinitionTests: XCTestCase {
    
    // MARK: - Tests
    
    /// 测试创建模型版本定义
    func testModelVersionDefinition() {
        // 创建模型版本
        let v1 = ModelVersion(versionString: "V1_0_0")!
        let v2 = ModelVersion(versionString: "V2_0_0")!
        
        // 创建模型版本定义
        let definition1 = ModelVersionDefinition(version: v1)
        let definition2 = ModelVersionDefinition(version: v2, mappingBlock: { _ in
            // 模拟映射操作
            print("执行V2版本的映射")
        })
        
        // 验证版本
        XCTAssertEqual(definition1.version.major, 1, "版本定义1的主版本号应该是1")
        XCTAssertEqual(definition2.version.major, 2, "版本定义2的主版本号应该是2")
        
        // 验证映射块
        XCTAssertNil(definition1.mappingBlock, "版本定义1不应该有映射块")
        XCTAssertNotNil(definition2.mappingBlock, "版本定义2应该有映射块")
    }
    
    /// 测试模型版本定义注册表
    func testModelVersionDefinitionRegistry() {
        // 创建模型版本定义注册表
        let registry = ModelVersionDefinitionRegistry()
        
        // 创建并注册版本定义
        let v1 = ModelVersion(versionString: "V1_0_0")!
        let v2 = ModelVersion(versionString: "V2_0_0")!
        let v3 = ModelVersion(versionString: "V3_0_0")!
        
        registry.register(version: v1)
        registry.register(version: v2, mappingBlock: { _ in
            // 模拟映射操作
            print("执行V2版本的映射")
        })
        registry.register(version: v3)
        
        // 验证版本数量
        XCTAssertEqual(registry.definitions.count, 3, "应该注册了3个版本定义")
        
        // 验证版本定义顺序
        let sortedDefinitions = registry.sortedDefinitions()
        XCTAssertEqual(sortedDefinitions.count, 3, "排序后应该有3个版本定义")
        XCTAssertEqual(sortedDefinitions[0].version.major, 1, "第一个版本定义应该是V1")
        XCTAssertEqual(sortedDefinitions[1].version.major, 2, "第二个版本定义应该是V2")
        XCTAssertEqual(sortedDefinitions[2].version.major, 3, "第三个版本定义应该是V3")
        
        // 测试获取迁移路径
        let path = registry.migrationPath(from: v1, to: v3)
        XCTAssertEqual(path.count, 2, "从V1到V3的迁移路径应该包含2个步骤")
        XCTAssertEqual(path[0].sourceVersion.major, 1, "第一步的源版本应该是V1")
        XCTAssertEqual(path[0].destinationVersion.major, 2, "第一步的目标版本应该是V2")
        XCTAssertEqual(path[1].sourceVersion.major, 2, "第二步的源版本应该是V2")
        XCTAssertEqual(path[1].destinationVersion.major, 3, "第二步的目标版本应该是V3")
        
        // 测试获取最新版本
        let latestVersion = registry.latestVersion()
        XCTAssertEqual(latestVersion.major, 3, "最新版本应该是V3")
    }
    
    /// 测试当前版本和目标版本的判断
    func testCurrentAndDestinationVersions() {
        // 创建模型版本定义注册表
        let registry = ModelVersionDefinitionRegistry()
        
        // 注册版本
        let v1 = ModelVersion(versionString: "V1_0_0")!
        let v2 = ModelVersion(versionString: "V2_0_0")!
        
        registry.register(version: v1)
        registry.register(version: v2)
        
        // 设置当前版本
        registry.setCurrentVersion(v1)
        
        // 验证当前版本
        XCTAssertEqual(registry.currentVersion()?.major, 1, "当前版本应该是V1")
        
        // 验证目标版本
        XCTAssertEqual(registry.destinationVersion().major, 2, "目标版本应该是V2")
        
        // 测试需要迁移的判断
        XCTAssertTrue(registry.requiresMigration(), "从V1到V2应该需要迁移")
    }
    
    /// 测试相同版本间的迁移判断
    func testNoMigrationRequired() {
        // 创建模型版本定义注册表
        let registry = ModelVersionDefinitionRegistry()
        
        // 只注册一个版本
        let v1 = ModelVersion(versionString: "V1_0_0")!
        registry.register(version: v1)
        
        // 设置当前版本
        registry.setCurrentVersion(v1)
        
        // 验证迁移需求
        XCTAssertFalse(registry.requiresMigration(), "相同版本间不应该需要迁移")
        
        // 验证迁移路径
        let path = registry.migrationPath(from: v1, to: v1)
        XCTAssertTrue(path.isEmpty, "相同版本间的迁移路径应该为空")
    }
}

/// 模型版本定义结构体
struct ModelVersionDefinition {
    /// 版本信息
    let version: ModelVersion
    /// 映射块，用于自定义迁移逻辑
    let mappingBlock: ((NSMappingModel) -> Void)?
    
    /// 初始化模型版本定义
    /// - Parameters:
    ///   - version: 模型版本
    ///   - mappingBlock: 可选的映射块
    init(version: ModelVersion, mappingBlock: ((NSMappingModel) -> Void)? = nil) {
        self.version = version
        self.mappingBlock = mappingBlock
    }
}

/// 模型版本定义注册表类
class ModelVersionDefinitionRegistry {
    /// 所有注册的版本定义
    private(set) var definitions: [ModelVersionDefinition] = []
    /// 当前使用的版本
    private var _currentVersion: ModelVersion?
    
    /// 注册一个版本
    /// - Parameters:
    ///   - version: 模型版本
    ///   - mappingBlock: 可选的映射块
    func register(version: ModelVersion, mappingBlock: ((NSMappingModel) -> Void)? = nil) {
        let definition = ModelVersionDefinition(version: version, mappingBlock: mappingBlock)
        definitions.append(definition)
    }
    
    /// 设置当前版本
    /// - Parameter version: 当前使用的版本
    func setCurrentVersion(_ version: ModelVersion) {
        _currentVersion = version
    }
    
    /// 获取当前版本
    /// - Returns: 当前版本，如果未设置则返回nil
    func currentVersion() -> ModelVersion? {
        return _currentVersion
    }
    
    /// 获取目标版本（通常是最新版本）
    /// - Returns: 目标版本
    func destinationVersion() -> ModelVersion {
        return sortedDefinitions().last!.version
    }
    
    /// 获取最新版本
    /// - Returns: 最新的注册版本
    func latestVersion() -> ModelVersion {
        return destinationVersion()
    }
    
    /// 是否需要迁移
    /// - Returns: 当前版本是否需要迁移到目标版本
    func requiresMigration() -> Bool {
        guard let current = currentVersion() else {
            // 如果未设置当前版本，假设需要迁移
            return true
        }
        
        let destination = destinationVersion()
        return current.identifier != destination.identifier
    }
    
    /// 按版本排序的定义列表
    /// - Returns: 排序后的模型版本定义列表
    func sortedDefinitions() -> [ModelVersionDefinition] {
        return definitions.sorted { $0.version < $1.version }
    }
    
    /// 计算迁移路径
    /// - Parameters:
    ///   - source: 源版本
    ///   - destination: 目标版本
    /// - Returns: 迁移步骤列表
    func migrationPath(from source: ModelVersion, to destination: ModelVersion) -> [MigrationStep] {
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
        var steps: [MigrationStep] = []
        
        for i in sourceIndex..<destIndex {
            let sourceVersion = sortedDefs[i].version
            let destVersion = sortedDefs[i + 1].version
            
            let step = MigrationStep(
                sourceVersion: sourceVersion,
                destinationVersion: destVersion,
                mappingBlock: sortedDefs[i + 1].mappingBlock
            )
            
            steps.append(step)
        }
        
        return steps
    }
}

/// 迁移步骤结构体
struct MigrationStep {
    /// 源版本
    let sourceVersion: ModelVersion
    /// 目标版本
    let destinationVersion: ModelVersion
    /// 可选的映射块
    let mappingBlock: ((NSMappingModel) -> Void)?
    
    /// 初始化迁移步骤
    /// - Parameters:
    ///   - sourceVersion: 源版本
    ///   - destinationVersion: 目标版本
    ///   - mappingBlock: 映射块（可选）
    init(
        sourceVersion: ModelVersion,
        destinationVersion: ModelVersion,
        mappingBlock: ((NSMappingModel) -> Void)? = nil
    ) {
        self.sourceVersion = sourceVersion
        self.destinationVersion = destinationVersion
        self.mappingBlock = mappingBlock
    }
} 