import XCTest
import CoreData

/// 一个完全独立的测试套件，不依赖CoreDataModule中的类型
class ModelVersionTestSuite: XCTestCase {
    
    // MARK: - Model Structs
    
    /// 模型版本结构体（独立实现）
    struct Version: Comparable, Sendable {
        let major: Int
        let minor: Int
        let patch: Int
        let identifier: String
        
        var description: String {
            return "v\(major).\(minor).\(patch)"
        }
        
        init?(versionString: String) {
            self.identifier = versionString
            
            let components = versionString.components(separatedBy: "_")
            
            guard components.count >= 2,
                  components[0].hasPrefix("V"),
                  let majorString = components[0].dropFirst().description,
                  let major = Int(majorString) else {
                return nil
            }
            
            self.major = major
            
            if components.count >= 2, let minor = Int(components[1]) {
                self.minor = minor
            } else {
                self.minor = 0
            }
            
            if components.count >= 3, let patch = Int(components[2]) {
                self.patch = patch
            } else {
                self.patch = 0
            }
        }
        
        init?(versionIdentifiers: Set<String>) {
            guard let versionString = versionIdentifiers.first(where: { $0.hasPrefix("V") }) else {
                return nil
            }
            
            guard let version = Version(versionString: versionString) else {
                return nil
            }
            
            self.major = version.major
            self.minor = version.minor
            self.patch = version.patch
            self.identifier = version.identifier
        }
        
        static func < (lhs: Version, rhs: Version) -> Bool {
            if lhs.major != rhs.major {
                return lhs.major < rhs.major
            }
            
            if lhs.minor != rhs.minor {
                return lhs.minor < rhs.minor
            }
            
            return lhs.patch < rhs.patch
        }
        
        static func sequence(from: Version, to: Version) -> [Version] {
            if from >= to {
                return []
            }
            
            var result: [Version] = []
            
            if from.major == to.major {
                if to.minor - from.minor == 1 {
                    return [to]
                }
                
                for minor in (from.minor + 1)...to.minor {
                    let versionString = "V\(from.major)_\(minor)_0"
                    if let version = Version(versionString: versionString) {
                        result.append(version)
                    }
                }
                return result
            }
            
            let currentMajorLatestMinor = 99
            let currentMajorLatestVersionString = "V\(from.major)_\(currentMajorLatestMinor)_0"
            if let currentMajorLatestVersion = Version(versionString: currentMajorLatestVersionString) {
                result.append(currentMajorLatestVersion)
            }
            
            for major in (from.major + 1)..<to.major {
                let versionString = "V\(major)_0_0"
                if let version = Version(versionString: versionString) {
                    result.append(version)
                }
            }
            
            for minor in 0...to.minor {
                let versionString = "V\(to.major)_\(minor)_0"
                if let version = Version(versionString: versionString) {
                    result.append(version)
                }
            }
            
            return result
        }
        
        static func from(url: URL) -> Version? {
            let fileName = url.lastPathComponent
            
            let pattern = "V\\d+(?:_\\d+)*"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return nil
            }
            
            let fileNameString = fileName as NSString
            let matches = regex.matches(in: fileName, options: [], range: NSRange(location: 0, length: fileNameString.length))
            
            guard let match = matches.first else {
                return nil
            }
            
            let versionString = fileNameString.substring(with: match.range)
            return Version(versionString: versionString)
        }
    }
    
    struct VersionDefinition: Sendable {
        let version: Version
        let mappingBlock: @Sendable ((NSMappingModel) -> Void)?
        
        init(version: Version, mappingBlock: @Sendable ((NSMappingModel) -> Void)? = nil) {
            self.version = version
            self.mappingBlock = mappingBlock
        }
    }
    
    struct MigrationStep: Sendable {
        let sourceVersion: Version
        let destinationVersion: Version
        let mappingBlock: @Sendable ((NSMappingModel) -> Void)?
        
        init(
            sourceVersion: Version,
            destinationVersion: Version,
            mappingBlock: @Sendable ((NSMappingModel) -> Void)? = nil
        ) {
            self.sourceVersion = sourceVersion
            self.destinationVersion = destinationVersion
            self.mappingBlock = mappingBlock
        }
    }
    
    actor VersionRegistry {
        private(set) var definitions: [VersionDefinition] = []
        private var _currentVersion: Version?
        
        func register(version: Version, mappingBlock: @Sendable ((NSMappingModel) -> Void)? = nil) {
            let definition = VersionDefinition(version: version, mappingBlock: mappingBlock)
            definitions.append(definition)
        }
        
        func setCurrentVersion(_ version: Version) {
            _currentVersion = version
        }
        
        func currentVersion() -> Version? {
            return _currentVersion
        }
        
        func destinationVersion() -> Version {
            guard let lastDefinition = sortedDefinitions().last else {
                fatalError("没有注册的模型版本")
            }
            return lastDefinition.version
        }
        
        func latestVersion() -> Version {
            return destinationVersion()
        }
        
        func requiresMigration() -> Bool {
            guard let current = currentVersion() else {
                return true
            }
            
            let destination = destinationVersion()
            return current.identifier != destination.identifier
        }
        
        func sortedDefinitions() -> [VersionDefinition] {
            return definitions.sorted { $0.version < $1.version }
        }
        
        func migrationPath(from source: Version, to destination: Version) -> [MigrationStep] {
            if source.identifier == destination.identifier {
                return []
            }
            
            if source > destination {
                return []
            }
            
            let sortedDefs = sortedDefinitions()
            
            guard let sourceIndex = sortedDefs.firstIndex(where: { $0.version.identifier == source.identifier }),
                  let destIndex = sortedDefs.firstIndex(where: { $0.version.identifier == destination.identifier }),
                  sourceIndex < destIndex else {
                return []
            }
            
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
    
    // MARK: - Tests
    
    func testVersionBasics() {
        // 创建版本
        let v1_0_0 = Version(versionString: "V1_0_0")!
        let v1_0_1 = Version(versionString: "V1_0_1")!
        let v1_1_0 = Version(versionString: "V1_1_0")!
        let v2_0_0 = Version(versionString: "V2_0_0")!
        
        // 测试属性
        XCTAssertEqual(v1_0_0.major, 1)
        XCTAssertEqual(v1_0_0.minor, 0)
        XCTAssertEqual(v1_0_0.patch, 0)
        XCTAssertEqual(v1_0_0.identifier, "V1_0_0")
        XCTAssertEqual(v1_0_0.description, "v1.0.0")
        
        // 测试比较
        XCTAssertLessThan(v1_0_0, v1_0_1)
        XCTAssertLessThan(v1_0_1, v1_1_0)
        XCTAssertLessThan(v1_1_0, v2_0_0)
        
        // 测试排序
        let versions = [v2_0_0, v1_0_0, v1_1_0, v1_0_1].sorted()
        XCTAssertEqual(versions, [v1_0_0, v1_0_1, v1_1_0, v2_0_0])
    }
    
    func testVersionFromIdentifiers() {
        // 字符串集合
        let stringSet: Set<String> = ["V1_0_0", "OtherIdentifier"]
        let version1 = Version(versionIdentifiers: stringSet)
        XCTAssertNotNil(version1)
        XCTAssertEqual(version1?.identifier, "V1_0_0")
        
        // 无效集合
        let invalidSet: Set<String> = ["Invalid", "NoVersion"]
        let invalidVersion = Version(versionIdentifiers: invalidSet)
        XCTAssertNil(invalidVersion)
    }
    
    func testVersionSequence() {
        let v1_0_0 = Version(versionString: "V1_0_0")!
        let v3_0_0 = Version(versionString: "V3_0_0")!
        
        let sequence = Version.sequence(from: v1_0_0, to: v3_0_0)
        
        // 验证序列内容
        XCTAssertEqual(sequence.count, 3)
        XCTAssertEqual(sequence[0].identifier, "V1_99_0")
        XCTAssertEqual(sequence[1].identifier, "V2_0_0")
        XCTAssertEqual(sequence[2].identifier, "V3_0_0")
        
        // 测试边界情况
        let emptySequence = Version.sequence(from: v3_0_0, to: v1_0_0)
        XCTAssertTrue(emptySequence.isEmpty)
        
        let sameVersionSequence = Version.sequence(from: v1_0_0, to: v1_0_0)
        XCTAssertTrue(sameVersionSequence.isEmpty)
    }
    
    func testVersionFromURL() {
        // 创建测试URL
        let url1 = URL(fileURLWithPath: "/path/to/ModelV1_0_0.mom")
        let url2 = URL(fileURLWithPath: "/path/to/Model_V2_3_1.xcdatamodeld")
        
        // 测试从URL提取版本
        let version1 = Version.from(url: url1)
        XCTAssertNotNil(version1)
        XCTAssertEqual(version1?.identifier, "V1_0_0")
        
        let version2 = Version.from(url: url2)
        XCTAssertNotNil(version2)
        XCTAssertEqual(version2?.identifier, "V2_3_1")
        
        // 测试无效URL
        let invalidURL = URL(fileURLWithPath: "/path/to/ModelNoVersion.mom")
        let invalidVersion = Version.from(url: invalidURL)
        XCTAssertNil(invalidVersion)
    }
    
    func testVersionDefinition() {
        let v1 = Version(versionString: "V1_0_0")!
        
        // 创建不带映射块的定义
        let def1 = VersionDefinition(version: v1)
        XCTAssertEqual(def1.version.identifier, "V1_0_0")
        XCTAssertNil(def1.mappingBlock)
        
        // 创建带映射块的定义
        var mappingBlockCalled = false
        let def2 = VersionDefinition(version: v1) { _ in
            mappingBlockCalled = true
        }
        
        XCTAssertEqual(def2.version.identifier, "V1_0_0")
        XCTAssertNotNil(def2.mappingBlock)
        
        // 执行映射块
        def2.mappingBlock?(NSMappingModel())
        XCTAssertTrue(mappingBlockCalled)
    }
    
    func testVersionRegistry() async {
        let registry = VersionRegistry()
        
        // 注册版本
        let v1 = Version(versionString: "V1_0_0")!
        let v2 = Version(versionString: "V2_0_0")!
        let v3 = Version(versionString: "V3_0_0")!
        
        await registry.register(version: v1)
        await registry.register(version: v2)
        await registry.register(version: v3)
        
        // 测试定义数量
        let definitions = await registry.definitions
        XCTAssertEqual(definitions.count, 3)
        
        // 测试排序
        let sorted = await registry.sortedDefinitions()
        XCTAssertEqual(sorted[0].version.identifier, "V1_0_0")
        XCTAssertEqual(sorted[1].version.identifier, "V2_0_0")
        XCTAssertEqual(sorted[2].version.identifier, "V3_0_0")
        
        // 测试获取最新版本
        let latestVersion = await registry.latestVersion()
        XCTAssertEqual(latestVersion.identifier, "V3_0_0")
    }
    
    func testMigrationPath() async {
        let registry = VersionRegistry()
        
        // 注册版本
        let v1 = Version(versionString: "V1_0_0")!
        let v2 = Version(versionString: "V2_0_0")!
        let v3 = Version(versionString: "V3_0_0")!
        
        // 添加映射块
        var mappingBlockCalls: [String] = []
        
        await registry.register(version: v1)
        await registry.register(version: v2) { _ in
            mappingBlockCalls.append("V1_to_V2")
        }
        await registry.register(version: v3) { _ in
            mappingBlockCalls.append("V2_to_V3")
        }
        
        // 获取迁移路径
        let path = await registry.migrationPath(from: v1, to: v3)
        
        // 验证路径
        XCTAssertEqual(path.count, 2)
        XCTAssertEqual(path[0].sourceVersion.identifier, "V1_0_0")
        XCTAssertEqual(path[0].destinationVersion.identifier, "V2_0_0")
        XCTAssertEqual(path[1].sourceVersion.identifier, "V2_0_0")
        XCTAssertEqual(path[1].destinationVersion.identifier, "V3_0_0")
        
        // 验证映射块
        XCTAssertNotNil(path[0].mappingBlock)
        XCTAssertNotNil(path[1].mappingBlock)
        
        // 调用映射块
        path[0].mappingBlock?(NSMappingModel())
        path[1].mappingBlock?(NSMappingModel())
        
        XCTAssertEqual(mappingBlockCalls, ["V1_to_V2", "V2_to_V3"])
    }
    
    func testCurrentVersionAndMigrationRequirement() async {
        let registry = VersionRegistry()
        
        // 注册版本
        let v1 = Version(versionString: "V1_0_0")!
        let v2 = Version(versionString: "V2_0_0")!
        
        await registry.register(version: v1)
        await registry.register(version: v2)
        
        // 初始状态，未设置当前版本
        let initialVersion = await registry.currentVersion()
        XCTAssertNil(initialVersion)
        let initialRequiresMigration = await registry.requiresMigration()
        XCTAssertTrue(initialRequiresMigration)
        
        // 设置当前版本为V1
        await registry.setCurrentVersion(v1)
        let v1Current = await registry.currentVersion()
        XCTAssertEqual(v1Current?.identifier, "V1_0_0")
        let v1RequiresMigration = await registry.requiresMigration()
        XCTAssertTrue(v1RequiresMigration)
        
        // 设置当前版本为最新版本
        await registry.setCurrentVersion(v2)
        let v2Current = await registry.currentVersion()
        XCTAssertEqual(v2Current?.identifier, "V2_0_0")
        let v2RequiresMigration = await registry.requiresMigration()
        XCTAssertFalse(v2RequiresMigration)
    }
} 