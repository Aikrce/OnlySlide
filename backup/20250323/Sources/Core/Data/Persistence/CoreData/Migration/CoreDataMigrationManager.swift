import CoreData
import Foundation

/// 迁移进度
public struct MigrationProgress {
    let currentStep: Int
    let totalSteps: Int
    let description: String
    
    var percentage: Double {
        return Double(currentStep) / Double(totalSteps) * 100
    }
}

/// Core Data 迁移管理器
public final class CoreDataMigrationManager {
    // MARK: - Properties
    
    public static let shared = CoreDataMigrationManager()
    
    private let modelName: String
    private let bundle: Bundle
    private let modelVersionManager = CoreDataModelVersionManager.shared
    
    private var migrationProgress: ((MigrationProgress) -> Void)?
    
    private init(modelName: String, bundle: Bundle = .main) {
        self.modelName = modelName
        self.bundle = bundle
    }
    
    // MARK: - Migration
    
    /// 执行迁移
    /// - Parameters:
    ///   - storeURL: 存储 URL
    ///   - progress: 进度回调
    /// - Returns: 是否成功
    public func performMigration(
        at storeURL: URL,
        progress: ((MigrationProgress) -> Void)? = nil
    ) async throws -> Bool {
        self.migrationProgress = progress
        
        // 检查是否需要迁移
        guard try modelVersionManager.requiresMigration(at: storeURL) else {
            return false
        }
        
        // 获取存储元数据
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        
        // 获取源模型和目标模型
        let sourceModel = try modelVersionManager.sourceModel(for: metadata)
        let destinationModel = try modelVersionManager.destinationModel()
        
        // 执行渐进式迁移
        try await performProgressiveMigration(
            from: sourceModel,
            to: destinationModel,
            storeURL: storeURL
        )
        
        return true
    }
    
    // MARK: - Private Methods
    
    /// 执行渐进式迁移
    private func performProgressiveMigration(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel,
        storeURL: URL
    ) async throws {
        var currentModel = sourceModel
        var migrationSteps: [(NSManagedObjectModel, NSManagedObjectModel)] = []
        
        // 计算迁移步骤
        while !currentModel.isEqual(destinationModel) {
            guard let nextModel = try findNextModel(after: currentModel, towards: destinationModel) else {
                throw AppError.migrationError("无法确定下一个迁移模型")
            }
            migrationSteps.append((currentModel, nextModel))
            currentModel = nextModel
        }
        
        // 执行每个迁移步骤
        for (stepIndex, (stepSource, stepDestination)) in migrationSteps.enumerated() {
            try await performMigrationStep(
                from: stepSource,
                to: stepDestination,
                storeURL: storeURL,
                currentStep: stepIndex + 1,
                totalSteps: migrationSteps.count
            )
        }
    }
    
    /// 执行单个迁移步骤
    private func performMigrationStep(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel,
        storeURL: URL,
        currentStep: Int,
        totalSteps: Int
    ) async throws {
        // 创建临时 URL
        let temporaryURL = try createTemporaryURL()
        
        // 获取映射模型
        let mappingModel = try modelVersionManager.migrationMapping(
            from: sourceModel,
            to: destinationModel
        )
        
        // 创建迁移管理器
        let manager = NSMigrationManager(
            sourceModel: sourceModel,
            destinationModel: destinationModel
        )
        
        // 设置进度回调
        manager.addObserver(
            self,
            forKeyPath: #keyPath(NSMigrationManager.migrationProgress),
            options: [.new],
            context: nil
        )
        
        // 执行迁移
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try manager.migrateStore(
                        from: storeURL,
                        sourceType: NSSQLiteStoreType,
                        options: nil,
                        with: mappingModel,
                        toDestinationURL: temporaryURL,
                        destinationType: NSSQLiteStoreType,
                        destinationOptions: nil
                    )
                    
                    // 替换原始存储
                    try self.replaceStore(at: storeURL, with: temporaryURL)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // 更新进度
        migrationProgress?(MigrationProgress(
            currentStep: currentStep,
            totalSteps: totalSteps,
            description: "正在迁移数据模型 (\(currentStep)/\(totalSteps))"
        ))
        
        // 移除观察者
        manager.removeObserver(
            self,
            forKeyPath: #keyPath(NSMigrationManager.migrationProgress)
        )
    }
    
    /// 查找下一个模型版本
    private func findNextModel(
        after sourceModel: NSManagedObjectModel,
        towards destinationModel: NSManagedObjectModel
    ) throws -> NSManagedObjectModel? {
        // 这里可以实现更复杂的模型版本查找逻辑
        // 当前简单返回目标模型
        return destinationModel
    }
    
    /// 创建临时 URL
    private func createTemporaryURL() throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let temporaryName = UUID().uuidString
        return temporaryDirectory.appendingPathComponent(temporaryName + ".sqlite")
    }
    
    /// 替换存储文件
    private func replaceStore(at storeURL: URL, with temporaryURL: URL) throws {
        let fileManager = FileManager.default
        
        // 备份原始存储
        let backupURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("backup_" + UUID().uuidString + ".sqlite")
        
        if fileManager.fileExists(atPath: storeURL.path) {
            try fileManager.moveItem(at: storeURL, to: backupURL)
        }
        
        // 移动临时存储到原始位置
        try fileManager.moveItem(at: temporaryURL, to: storeURL)
        
        // 清理备份
        try? fileManager.removeItem(at: backupURL)
    }
    
    // MARK: - KVO
    
    public override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == #keyPath(NSMigrationManager.migrationProgress),
           let progress = change?[.newKey] as? Float {
            // 更新迁移进度
            print("Migration progress: \(progress * 100)%")
        }
    }
}

// MARK: - Error Extension
extension AppError {
    static func migrationError(_ message: String) -> AppError {
        return .databaseError(.migrationFailed(message))
    }
} 