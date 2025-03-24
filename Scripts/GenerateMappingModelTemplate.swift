#!/usr/bin/env swift

import Foundation

// MARK: - Constants

/// 输出目录
let outputDirectory = "Sources/CoreDataModule/Migration/CustomMappingModels"

/// 模板输出目录
let templateOutputDirectory = "Templates/MigrationModels"

/// 帮助信息
let helpText = """
生成自定义映射模型模板

用法:
    ./GenerateMappingModelTemplate.swift <源版本> <目标版本> <实体名称> [选项]

参数:
    <源版本>    源模型版本 (例如: version1)
    <目标版本>  目标模型版本 (例如: version2)
    <实体名称>  要迁移的实体名称 (例如: Slide)

选项:
    --force     覆盖已存在的文件
    --help      显示帮助信息

示例:
    ./GenerateMappingModelTemplate.swift version1 version2 Slide
    ./GenerateMappingModelTemplate.swift version1 version2 Document --force
"""

// MARK: - Templates

/// 自定义映射策略类模板
let migrationPolicyTemplate = """
import Foundation
import CoreData

/// {EntityName}映射模型
/// 用于将{EntityName}实体从{SourceVersionName}迁移到{DestinationVersionName}
public final class {EntityName}{SourceVersionId}To{EntityName}{DestinationVersionId}MappingModel: NSEntityMigrationPolicy {
    
    // MARK: - Constants
    
    /// 错误域
    private static let errorDomain = "{EntityName}{SourceVersionId}To{EntityName}{DestinationVersionId}MappingModel"
    
    // MARK: - Migration Methods
    
    /// 创建目标实例
    override public func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // 调用父类方法创建基本实例
        try super.createDestinationInstances(
            forSource: sInstance,
            in: mapping,
            manager: manager
        )
        
        // 获取源实例对应的目标实例
        guard let dInstance = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else {
            let error = NSError(
                domain: {EntityName}{SourceVersionId}To{EntityName}{DestinationVersionId}MappingModel.errorDomain,
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "无法获取目标实例"
                ]
            )
            throw error
        }
        
        // TODO: 从源实例提取数据
        // 示例:
        // let title = sInstance.value(forKey: "title") as? String ?? ""
        // let createdAt = sInstance.value(forKey: "createdAt") as? Date ?? Date()
        
        // TODO: 为新增的字段设置默认值
        // 示例:
        // let description = "从{SourceVersionName}迁移的{EntityName}: \\(title)"
        
        // TODO: 设置默认值
        // 示例:
        // dInstance.setValue(description, forKey: "description")
        
        // TODO: 迁移关联的对象
        // 示例:
        // migrateRelatedObjects(
        //     forSource: sInstance,
        //     destination: dInstance,
        //     manager: manager
        // )
        
        // TODO: 设置额外的元数据
        // 示例:
        // let metadata: [String: Any] = [
        //     "migrated": true,
        //     "migrationDate": Date(),
        //     "sourceVersion": "{SourceVersionName}",
        //     "destinationVersion": "{DestinationVersionName}"
        // ]
        //
        // if let data = try? JSONSerialization.data(withJSONObject: metadata),
        //    let metadataString = String(data: data, encoding: .utf8) {
        //     dInstance.setValue(metadataString, forKey: "metadataJSON")
        // }
    }
    
    /// 自定义验证
    override public func endInstanceCreation() throws {
        // 在所有实例创建完成后执行验证
        try super.endInstanceCreation()
        
        // TODO: 添加额外的验证逻辑
    }
    
    // MARK: - Helper Methods
    
    /// 迁移关联对象
    /// - Parameters:
    ///   - sourceInstance: 源实例
    ///   - destinationInstance: 目标实例
    ///   - manager: 迁移管理器
    private func migrateRelatedObjects(
        forSource sourceInstance: NSManagedObject,
        destination destinationInstance: NSManagedObject,
        manager: NSMigrationManager
    ) {
        // TODO: 迁移关联对象的逻辑
        // 示例:
        // guard let sourceRelatedObjects = sourceInstance.value(forKey: "relatedObjects") as? Set<NSManagedObject>,
        //      !sourceRelatedObjects.isEmpty else {
        //     return
        // }
        //
        // for sourceRelatedObject in sourceRelatedObjects {
        //     if let destinationRelatedObject = manager.destinationInstances(
        //         forEntityMappingName: "RelatedObjectToNewRelatedObject",
        //         sourceInstances: [sourceRelatedObject]
        //     ).first {
        //         // 建立关系
        //         destinationRelatedObject.setValue(destinationInstance, forKey: "parent")
        //         
        //         // 将关联对象添加到集合中
        //         if var relatedObjects = destinationInstance.value(forKey: "relatedObjects") as? Set<NSManagedObject> {
        //             relatedObjects.insert(destinationRelatedObject)
        //             destinationInstance.setValue(relatedObjects, forKey: "relatedObjects")
        //         } else {
        //             destinationInstance.setValue(
        //                 Set([destinationRelatedObject]),
        //                 forKey: "relatedObjects"
        //             )
        //         }
        //     }
        // }
    }
}
"""

/// 映射模型测试模板
let migrationTestTemplate = """
import XCTest
import CoreData
@testable import CoreDataModule

class {EntityName}{SourceVersionId}To{EntityName}{DestinationVersionId}MappingTests: XCTestCase {
    
    // MARK: - Properties
    
    /// 临时存储URL
    private var tempStoreURL: URL!
    
    /// 迁移管理器
    private var migrationManager: CoreDataMigrationManager!
    
    /// 版本管理器
    private var versionManager: CoreDataModelVersionManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // 创建临时目录和存储URL
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreDataModuleTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try? FileManager.default.createDirectory(
            at: tempDirectoryURL,
            withIntermediateDirectories: true
        )
        
        tempStoreURL = tempDirectoryURL.appendingPathComponent("TestStore.sqlite")
        migrationManager = CoreDataMigrationManager.shared
        versionManager = CoreDataModelVersionManager.shared
    }
    
    override func tearDown() {
        // 清理临时文件
        try? FileManager.default.removeItem(at: tempStoreURL.deletingLastPathComponent())
        
        tempStoreURL = nil
        migrationManager = nil
        versionManager = nil
        
        super.tearDown()
    }
    
    // MARK: - Tests
    
    /// 测试{EntityName}从{SourceVersionName}到{DestinationVersionName}的迁移
    func test{EntityName}Migration() async throws {
        // 创建{SourceVersionName}的存储并填充数据
        try createAndPopulateTestStore(
            version: .{sourceVersion},
            at: tempStoreURL
        )
        
        // 执行迁移
        let didMigrate = try await migrationManager.performMigration(
            at: tempStoreURL
        )
        
        XCTAssertTrue(
            didMigrate,
            "迁移应该成功执行"
        )
        
        // 加载迁移后的存储
        let container = try createTestStore(
            withModelName: ModelVersion.{destinationVersion}.rawValue,
            at: tempStoreURL
        )
        
        let context = container.viewContext
        
        // 检查数据是否正确迁移
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "{EntityName}")
        let objects = try context.fetch(fetchRequest)
        
        XCTAssertFalse(
            objects.isEmpty,
            "应该有{EntityName}对象"
        )
        
        // TODO: 添加更多的迁移验证逻辑
        // 示例:
        // for object in objects {
        //     XCTAssertNotNil(
        //         object.value(forKey: "newAttribute"),
        //         "新属性应该存在"
        //     )
        // }
    }
    
    // MARK: - Helper Methods
    
    /// 创建测试存储
    /// - Parameters:
    ///   - modelName: 模型名称
    ///   - storeURL: 存储URL
    /// - Returns: 持久化容器
    private func createTestStore(
        withModelName modelName: String,
        at storeURL: URL
    ) throws -> NSPersistentContainer {
        // 加载模型
        guard let modelURL = Bundle.module.url(
            forResource: modelName,
            withExtension: "momd"
        ) else {
            throw NSError(
                domain: "MigrationTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法找到模型: \\(modelName)"]
            )
        }
        
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw NSError(
                domain: "MigrationTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "无法加载模型: \\(modelName)"]
            )
        }
        
        // 创建持久化存储协调器
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        try persistentStoreCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        
        // 创建持久化容器
        let container = NSPersistentContainer(
            name: modelName,
            managedObjectModel: model
        )
        
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = false
        description.shouldInferMappingModelAutomatically = false
        
        container.persistentStoreDescriptions = [description]
        
        var loadError: Error?
        var loadSuccess = false
        
        container.loadPersistentStores { _, error in
            loadError = error
            loadSuccess = (error == nil)
        }
        
        if !loadSuccess {
            throw loadError ?? NSError(
                domain: "MigrationTests",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "无法加载持久化存储"]
            )
        }
        
        return container
    }
    
    /// 创建并填充测试存储
    /// - Parameters:
    ///   - modelVersion: 模型版本
    ///   - storeURL: 存储URL
    private func createAndPopulateTestStore(
        version modelVersion: ModelVersion,
        at storeURL: URL
    ) throws {
        // 获取模型名称
        let modelName = modelVersion.rawValue
        
        // 创建存储
        let container = try createTestStore(
            withModelName: modelName,
            at: storeURL
        )
        
        // 获取托管对象上下文
        let context = container.viewContext
        
        // TODO: 根据实体创建测试数据
        // 示例:
        // let entity = NSEntityDescription.entity(
        //     forEntityName: "{EntityName}",
        //     in: context
        // )!
        //
        // let object = NSManagedObject(entity: entity, insertInto: context)
        // object.setValue("Test Title", forKey: "title")
        // object.setValue(Date(), forKey: "createdAt")
        
        // 保存上下文
        try context.save()
    }
}
"""

/// README 模板，用于说明如何使用生成的映射模型
let readmeTemplate = """
# {EntityName} 从 {SourceVersionName} 到 {DestinationVersionName} 的自定义映射模型

## 概述

此映射模型定义了如何将 `{EntityName}` 实体从 `{SourceVersionName}` 版本迁移到 `{DestinationVersionName}` 版本。

## 主要变更

下面列出了 `{EntityName}` 实体的主要变更：

- TODO: 列出主要变更
- 例如：添加了新属性 `description`
- 例如：重命名了属性 `name` 为 `title`
- 例如：修改了关系 `items` 的目标实体

## 使用方法

1. 在 Xcode 中创建 `.xcmappingmodel` 文件：
   - File -> New -> File... -> Core Data -> Mapping Model
   - 选择源模型 `{SourceVersionName}` 和目标模型 `{DestinationVersionName}`
   - 命名为 `Mapping_{SourceVersionName}_to_{DestinationVersionName}.xcmappingmodel`

2. 在映射模型中，为 `{EntityName}` 实体映射设置自定义策略类：
   - 选择 `{EntityName}` 实体映射
   - 在 Inspector 面板中，设置 "Custom Policy" 为 `{EntityName}{SourceVersionId}To{EntityName}{DestinationVersionId}MappingModel`

3. 自定义策略类已在 `{EntityName}{SourceVersionId}To{EntityName}{DestinationVersionId}MappingModel.swift` 文件中实现。

## 迁移测试

迁移测试在 `{EntityName}{SourceVersionId}To{EntityName}{DestinationVersionId}MappingTests.swift` 文件中实现。
运行该测试以确保迁移正常工作。

## 注意事项

- 请确保在实施迁移之前已经彻底测试过迁移过程
- 如果迁移涉及到数据结构的重大变更，请考虑提供用户数据导出功能
"""

// MARK: - Helper Functions

/// 打印错误信息并退出程序
/// - Parameter message: 错误信息
func exitWithError(_ message: String) -> Never {
    print("错误: \(message)")
    print("\n\(helpText)")
    exit(1)
}

/// 检查文件是否存在
/// - Parameter path: 文件路径
/// - Returns: 文件是否存在
func fileExists(at path: String) -> Bool {
    return FileManager.default.fileExists(atPath: path)
}

/// 创建目录
/// - Parameter path: 目录路径
func createDirectory(at path: String) throws {
    try FileManager.default.createDirectory(
        atPath: path,
        withIntermediateDirectories: true,
        attributes: nil
    )
}

/// 写入文件
/// - Parameters:
///   - content: 文件内容
///   - path: 文件路径
///   - force: 是否强制覆盖已存在的文件
func writeToFile(content: String, path: String, force: Bool = false) throws {
    if fileExists(at: path) && !force {
        exitWithError("文件已存在: \(path)。使用 --force 参数覆盖。")
    }
    
    try content.write(
        toFile: path,
        atomically: true,
        encoding: .utf8
    )
    
    print("已创建文件: \(path)")
}

/// 使用占位符替换模板内容
/// - Parameters:
///   - template: 模板内容
///   - placeholders: 占位符替换对
/// - Returns: 替换后的内容
func replaceTemplatePlaceholders(_ template: String, with placeholders: [String: String]) -> String {
    var result = template
    
    for (key, value) in placeholders {
        result = result.replacingOccurrences(of: key, with: value)
    }
    
    return result
}

/// 获取版本标识符（去除前缀，首字母大写）
/// - Parameter version: 版本名称（例如 "version1"）
/// - Returns: 版本标识符（例如 "V1"）
func getVersionIdentifier(_ version: String) -> String {
    // 将 "version1" 转换为 "V1"
    let versionNumber = version.replacingOccurrences(of: "version", with: "")
    return "V\(versionNumber)"
}

// MARK: - Main Script

// 解析命令行参数
var sourceVersion = ""
var destinationVersion = ""
var entityName = ""
var force = false

let args = CommandLine.arguments.dropFirst() // 删除脚本名称
var i = 0

while i < args.count {
    let arg = args[i]
    
    if arg == "--help" {
        print(helpText)
        exit(0)
    } else if arg == "--force" {
        force = true
    } else if sourceVersion.isEmpty {
        sourceVersion = arg
    } else if destinationVersion.isEmpty {
        destinationVersion = arg
    } else if entityName.isEmpty {
        entityName = arg
    }
    
    i += 1
}

// 验证必需参数
if sourceVersion.isEmpty || destinationVersion.isEmpty || entityName.isEmpty {
    exitWithError("源版本、目标版本和实体名称是必需的")
}

// 准备占位符替换对
let sourceVersionId = getVersionIdentifier(sourceVersion)
let destinationVersionId = getVersionIdentifier(destinationVersion)

let sourceVersionName = sourceVersion
let destinationVersionName = destinationVersion

let placeholders = [
    "{EntityName}": entityName,
    "{SourceVersionId}": sourceVersionId,
    "{DestinationVersionId}": destinationVersionId,
    "{SourceVersionName}": sourceVersionName,
    "{DestinationVersionName}": destinationVersionName,
    "{sourceVersion}": sourceVersion,
    "{destinationVersion}": destinationVersion
]

// 创建输出目录
try createDirectory(at: outputDirectory)
try createDirectory(at: templateOutputDirectory)

// 生成映射策略类文件
let policyFileName = "\(entityName)\(sourceVersionId)To\(entityName)\(destinationVersionId)MappingModel.swift"
let policyFilePath = "\(outputDirectory)/\(policyFileName)"

let policyContent = replaceTemplatePlaceholders(migrationPolicyTemplate, with: placeholders)
try writeToFile(content: policyContent, path: policyFilePath, force: force)

// 生成映射测试文件
let testFileName = "\(entityName)\(sourceVersionId)To\(entityName)\(destinationVersionId)MappingTests.swift"
let testFilePath = "Tests/CoreDataModuleTests/Migration/\(testFileName)"

let testContent = replaceTemplatePlaceholders(migrationTestTemplate, with: placeholders)
try writeToFile(content: testContent, path: testFilePath, force: force)

// 生成README文件
let readmeFileName = "\(entityName)_\(sourceVersionName)_to_\(destinationVersionName)_README.md"
let readmeFilePath = "\(templateOutputDirectory)/\(readmeFileName)"

let readmeContent = replaceTemplatePlaceholders(readmeTemplate, with: placeholders)
try writeToFile(content: readmeContent, path: readmeFilePath, force: force)

print("\n生成完成! 现在您可以：")
print("1. 修改 \(policyFilePath) 以实现自定义迁移逻辑")
print("2. 修改 \(testFilePath) 以测试迁移逻辑")
print("3. 参考 \(readmeFilePath) 了解如何在Xcode中设置映射模型") 