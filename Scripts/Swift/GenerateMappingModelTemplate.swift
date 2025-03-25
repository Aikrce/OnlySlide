#!/usr/bin/env swift

import Foundation

// MARK: - 包装所有代码到主函数中
func main() {
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
                "应该至少有一个{EntityName}对象"
            )
            
            // TODO: 添加具体的迁移测试代码
            // 检查特定字段是否正确迁移
            
            // 示例：
            // if let object = objects.first {
            //     XCTAssertNotNil(
            //         object.value(forKey: "newField"),
            //         "新字段应该已被设置"
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
            
            // 创建持久化容器
            let container = NSPersistentContainer(
                name: modelName,
                managedObjectModel: model
            )
            
            let description = NSPersistentStoreDescription(url: storeURL)
            description.shouldAddStoreAsynchronously = false
            
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
            
            // 填充测试数据
            let entity = NSEntityDescription.entity(
                forEntityName: "{EntityName}",
                in: context
            )!
            
            // 创建示例数据
            let object = NSManagedObject(entity: entity, insertInto: context)
            
            // TODO: 设置对象属性
            // 示例:
            // object.setValue("测试标题", forKey: "title")
            // object.setValue(Date(), forKey: "createdAt")
            
            // 保存上下文
            try context.save()
        }
    }
    """

    /// README模板
    let readmeTemplate = """
    # {EntityName} 从 {SourceVersionName} 到 {DestinationVersionName} 的迁移指南

    本文档介绍如何设置从 {SourceVersionName} 到 {DestinationVersionName} 的 {EntityName} 实体迁移。

    ## 目录

    1. [概述](#概述)
    2. [迁移策略类](#迁移策略类)
    3. [在Xcode中配置](#在xcode中配置)
    4. [测试迁移](#测试迁移)

    ## 概述

    从 {SourceVersionName} 到 {DestinationVersionName} 的迁移涉及以下变化：

    - TODO: 列出实体模型的变化
    - 例如：添加了新的 "description" 属性
    - 例如：删除了 "obsoleteField" 属性
    - 例如：修改了 "relatedEntities" 关系

    ## 迁移策略类

    我们创建了 `{EntityName}{SourceVersionId}To{EntityName}{DestinationVersionId}MappingModel` 类来处理自定义迁移逻辑。
    此类位于 `Sources/CoreDataModule/Migration/CustomMappingModels/{EntityName}{SourceVersionId}To{EntityName}{DestinationVersionId}MappingModel.swift`。

    主要功能：

    - 复制基本属性
    - 设置新增字段的默认值
    - 处理关系迁移
    - 执行自定义验证

    ## 在Xcode中配置

    要在Xcode中使用此自定义映射模型：

    1. 打开Xcode并打开您的项目
    2. 选择 Core Data 模型文件 (`.xcdatamodeld`)
    3. 在编辑器右上角选择 "Editor" > "Add Model Version..."
    4. 创建从 {SourceVersionName} 到 {DestinationVersionName} 的映射模型
    5. 在映射模型中，选择 {EntityName} 实体
    6. 在属性检查器中，设置 "Custom Policy" 为 `{EntityName}{SourceVersionId}To{EntityName}{DestinationVersionId}MappingModel`
    7. 保存并构建项目

    ## 测试迁移

    我们提供了 `{EntityName}{SourceVersionId}To{EntityName}{DestinationVersionId}MappingTests` 测试类来验证迁移。

    要运行测试：

    ```bash
    swift test --filter {EntityName}{SourceVersionId}To{EntityName}{DestinationVersionId}MappingTests
    ```

    或者在Xcode中选择并运行测试类。

    ## 常见问题

    **Q: 迁移过程中出现错误 "无法获取目标实例"**

    A: 确保映射模型中正确配置了实体映射，并且提供了正确的自定义策略类名称。

    **Q: 如何处理复杂的关系迁移？**

    A: 在 `migrateRelatedObjects()` 方法中实现自定义关系迁移逻辑。

    """

    // MARK: - Helper Functions

    /// 退出并显示错误
    /// - Parameter message: 错误消息
    func exitWithError(_ message: String) -> Never {
        print("错误: \(message)")
        print("\n使用 --help 查看帮助")
        exit(1)
    }

    /// 创建目录
    /// - Parameter path: 目录路径
    func createDirectory(at path: String) throws {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        
        if !fileManager.fileExists(atPath: path, isDirectory: &isDir) {
            try fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    /// 写入文件
    /// - Parameters:
    ///   - content: 文件内容
    ///   - path: 文件路径
    ///   - force: 是否强制覆盖
    func writeToFile(content: String, path: String, force: Bool) throws {
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: path) && !force {
            print("⚠️ 文件已存在: \(path)")
            print("   使用 --force 选项覆盖现有文件")
            return
        }
        
        try content.write(
            toFile: path,
            atomically: true,
            encoding: .utf8
        )
        
        print("✅ 已创建文件: \(path)")
    }

    /// 替换模板中的占位符
    /// - Parameters:
    ///   - template: 模板字符串
    ///   - placeholders: 占位符替换对
    /// - Returns: 替换后的字符串
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
}

// 执行主程序
main() 