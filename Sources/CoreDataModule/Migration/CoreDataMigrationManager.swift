import CoreData
import Foundation

/// 迁移进度
public struct MigrationProgress {
    /// 当前步骤
    public let currentStep: Int
    /// 总步骤数
    public let totalSteps: Int
    /// 描述信息
    public let description: String
    /// 源版本
    public let sourceVersion: ModelVersion
    /// 目标版本
    public let destinationVersion: ModelVersion
    
    /// 进度百分比
    public var percentage: Double {
        return Double(currentStep) / Double(totalSteps) * 100
    }
}

/// 迁移结果
public enum MigrationResult {
    /// 成功完成迁移
    case success
    /// 不需要迁移
    case notNeeded
    /// 迁移失败
    case failure(Error)
}

/// 迁移配置
public struct MigrationConfiguration {
    /// 是否创建备份
    public let shouldCreateBackup: Bool
    
    /// 是否在失败时从备份恢复
    public let shouldRestoreFromBackupOnFailure: Bool
    
    /// 是否删除旧备份
    public let shouldRemoveOldBackups: Bool
    
    /// 要保留的最大备份数量
    public let maxBackupsToKeep: Int
    
    /// 初始化迁移配置
    /// - Parameters:
    ///   - shouldCreateBackup: 是否创建备份
    ///   - shouldRestoreFromBackupOnFailure: 是否在失败时从备份恢复
    ///   - shouldRemoveOldBackups: 是否删除旧备份
    ///   - maxBackupsToKeep: 要保留的最大备份数量
    public init(
        shouldCreateBackup: Bool,
        shouldRestoreFromBackupOnFailure: Bool,
        shouldRemoveOldBackups: Bool,
        maxBackupsToKeep: Int
    ) {
        self.shouldCreateBackup = shouldCreateBackup
        self.shouldRestoreFromBackupOnFailure = shouldRestoreFromBackupOnFailure
        self.shouldRemoveOldBackups = shouldRemoveOldBackups
        self.maxBackupsToKeep = maxBackupsToKeep
    }
    
    /// 默认配置
    public static let `default` = MigrationConfiguration(
        shouldCreateBackup: true,
        shouldRestoreFromBackupOnFailure: true,
        shouldRemoveOldBackups: true,
        maxBackupsToKeep: 5
    )
}

/// Core Data 迁移管理器
public final class CoreDataMigrationManager {
    // MARK: - Properties
    
    public static let shared = CoreDataMigrationManager()
    
    private let modelName: String = "OnlySlide"
    private let bundle: Bundle
    private let modelVersionManager: CoreDataModelVersionManager
    private let mappingModelFinder: MappingModelFinder
    
    private var migrationProgress: ((MigrationProgress) -> Void)?
    
    // 迁移配置
    private let configuration: MigrationConfiguration
    
    /// 创建迁移管理器
    /// - Parameters:
    ///   - bundle: 包含模型的Bundle
    ///   - configuration: 迁移配置
    public init(
        bundle: Bundle = .main, 
        configuration: MigrationConfiguration = .default
    ) {
        self.bundle = bundle
        self.configuration = configuration
        self.modelVersionManager = CoreDataModelVersionManager.shared
        self.mappingModelFinder = MappingModelFinder(versionManager: modelVersionManager)
    }
    
    // MARK: - Migration
    
    /// 执行迁移
    /// - Parameters:
    ///   - storeURL: 存储 URL
    ///   - progress: 进度回调
    /// - Returns: 是否成功迁移
    public func performMigration(
        at storeURL: URL,
        progress: ((MigrationProgress) -> Void)? = nil
    ) async throws -> Bool {
        self.migrationProgress = progress
        
        // 检查是否需要迁移
        guard try modelVersionManager.requiresMigration(at: storeURL) else {
            return false
        }
        
        // 在迁移前创建备份
        var backupURL: URL?
        if configuration.shouldCreateBackup {
            backupURL = try createBackup(of: storeURL)
        }
        
        do {
            // 获取存储元数据
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
            
            // 获取源模型和目标模型
            let sourceModel = try modelVersionManager.sourceModel(for: metadata)
            let destinationModel = try modelVersionManager.destinationModel()
            
            // 获取源模型和目标模型的版本
            let sourceVersion = try modelVersionManager.sourceModelVersion(for: metadata)
            let destinationVersion = try modelVersionManager.destinationModelVersion()
            
            // 执行渐进式迁移
            try await performProgressiveMigration(
                from: sourceModel,
                to: destinationModel,
                sourceVersion: sourceVersion,
                destinationVersion: destinationVersion,
                storeURL: storeURL
            )
            
            // 迁移成功后清理过期备份
            if configuration.shouldRemoveOldBackups {
                cleanupOldBackups()
            }
            
            return true
        } catch {
            // 如果迁移失败，尝试恢复备份
            print("迁移失败，尝试恢复备份: \(error.localizedDescription)")
            if configuration.shouldRestoreFromBackupOnFailure, let url = backupURL {
                try restoreBackup(from: url, to: storeURL)
            }
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    /// 执行渐进式迁移
    private func performProgressiveMigration(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel,
        sourceVersion: ModelVersion,
        destinationVersion: ModelVersion,
        storeURL: URL
    ) async throws {
        // 计算迁移路径
        let migrationPath = modelVersionManager.migrationPath(from: sourceVersion, to: destinationVersion)
        
        // 如果没有迁移步骤，抛出错误
        if migrationPath.isEmpty {
            throw CoreDataError.migrationFailed("无法确定迁移路径")
        }
        
        // 执行每个迁移步骤
        var currentURL = storeURL
        var tempURLs: [URL] = []
        
        for (stepIndex, step) in migrationPath.enumerated() {
            let stepSourceVersion = step.sourceVersion
            let stepDestinationVersion = step.destinationVersion
            
            // 获取源模型和目标模型
            let sourceModel = modelVersionManager.model(for: stepSourceVersion)
            let destinationModel = modelVersionManager.model(for: stepDestinationVersion)
            
            // 创建临时URL
            let temporaryURL = try createTemporaryURL()
            tempURLs.append(temporaryURL)
            
            try await performMigrationStep(
                from: sourceModel,
                to: destinationModel,
                sourceVersion: stepSourceVersion,
                destinationVersion: stepDestinationVersion,
                sourceURL: currentURL,
                destinationURL: temporaryURL,
                currentStep: stepIndex + 1,
                totalSteps: migrationPath.count
            )
            
            // 更新当前URL为临时URL
            currentURL = temporaryURL
        }
        
        // 替换原始存储
        try replaceStore(at: storeURL, with: currentURL)
        
        // 清理临时文件
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    /// 执行单个迁移步骤
    private func performMigrationStep(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel,
        sourceVersion: ModelVersion,
        destinationVersion: ModelVersion,
        sourceURL: URL,
        destinationURL: URL,
        currentStep: Int,
        totalSteps: Int
    ) async throws {
        let description = "正在迁移数据模型 (\(currentStep)/\(totalSteps)) 从 \(sourceVersion.identifier) 到 \(destinationVersion.identifier)"
        print(description)
        
        // 更新进度
        migrationProgress?(MigrationProgress(
            currentStep: currentStep,
            totalSteps: totalSteps,
            description: description,
            sourceVersion: sourceVersion,
            destinationVersion: destinationVersion
        ))
        
        // 查找映射模型
        var mappingModel = mappingModelFinder.mappingModel(
            from: sourceModel,
            to: destinationModel
        )
        
        // 如果没有找到映射模型，尝试创建自定义映射模型
        if mappingModel == nil {
            mappingModel = mappingModelFinder.createCustomMappingModel(
                from: sourceModel,
                to: destinationModel
            )
        }
        
        guard let finalMappingModel = mappingModel else {
            throw CoreDataError.migrationFailed("无法创建映射模型")
        }
        
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
                        from: sourceURL,
                        sourceType: NSSQLiteStoreType,
                        options: nil,
                        with: finalMappingModel,
                        toDestinationURL: destinationURL,
                        destinationType: NSSQLiteStoreType,
                        destinationOptions: nil
                    )
                    
                    continuation.resume()
                } catch {
                    print("迁移步骤失败: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // 移除观察者
        manager.removeObserver(
            self,
            forKeyPath: #keyPath(NSMigrationManager.migrationProgress)
        )
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
        
        // 创建辅助文件的URL
        let storeShmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        let storeWalURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let temporaryShmURL = temporaryURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        let temporaryWalURL = temporaryURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        
        // 如果存在原文件，先删除
        if fileManager.fileExists(atPath: storeURL.path) {
            try fileManager.removeItem(at: storeURL)
        }
        
        if fileManager.fileExists(atPath: storeShmURL.path) {
            try fileManager.removeItem(at: storeShmURL)
        }
        
        if fileManager.fileExists(atPath: storeWalURL.path) {
            try fileManager.removeItem(at: storeWalURL)
        }
        
        // 移动临时文件到目标位置
        try fileManager.moveItem(at: temporaryURL, to: storeURL)
        
        // 也移动辅助文件
        if fileManager.fileExists(atPath: temporaryShmURL.path) {
            try fileManager.moveItem(at: temporaryShmURL, to: storeShmURL)
        }
        
        if fileManager.fileExists(atPath: temporaryWalURL.path) {
            try fileManager.moveItem(at: temporaryWalURL, to: storeWalURL)
        }
    }
    
    // MARK: - Backup and Recovery
    
    /// 创建数据库备份
    /// - Parameter storeURL: 存储URL
    /// - Returns: 备份文件URL
    private func createBackup(of storeURL: URL) throws -> URL {
        let fileManager = FileManager.default
        
        // 确保备份目录存在
        let backupDirectory = try getBackupDirectory()
        
        // 创建带时间戳的备份文件名
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupName = "\(timestamp)_\(storeURL.lastPathComponent)"
        let backupURL = backupDirectory.appendingPathComponent(backupName)
        
        // 复制数据库文件
        if fileManager.fileExists(atPath: storeURL.path) {
            try fileManager.copyItem(at: storeURL, to: backupURL)
            
            // 复制辅助文件
            let storeShmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            let storeWalURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            let backupShmURL = backupURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            let backupWalURL = backupURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            
            if fileManager.fileExists(atPath: storeShmURL.path) {
                try fileManager.copyItem(at: storeShmURL, to: backupShmURL)
            }
            
            if fileManager.fileExists(atPath: storeWalURL.path) {
                try fileManager.copyItem(at: storeWalURL, to: backupWalURL)
            }
            
            print("已创建数据库备份: \(backupURL.lastPathComponent)")
        } else {
            print("没有找到数据库文件，跳过备份")
        }
        
        return backupURL
    }
    
    /// 从备份恢复数据库
    /// - Parameters:
    ///   - backupURL: 备份文件URL
    ///   - storeURL: 目标存储URL
    private func restoreBackup(from backupURL: URL, to storeURL: URL) throws {
        let fileManager = FileManager.default
        
        // 检查备份文件是否存在
        guard fileManager.fileExists(atPath: backupURL.path) else {
            print("备份文件不存在，无法恢复")
            return
        }
        
        // 删除现有文件
        if fileManager.fileExists(atPath: storeURL.path) {
            try fileManager.removeItem(at: storeURL)
        }
        
        // 复制备份文件到目标位置
        try fileManager.copyItem(at: backupURL, to: storeURL)
        
        // 复制辅助文件
        let backupShmURL = backupURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        let backupWalURL = backupURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let storeShmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        let storeWalURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        
        if fileManager.fileExists(atPath: backupShmURL.path) {
            if fileManager.fileExists(atPath: storeShmURL.path) {
                try fileManager.removeItem(at: storeShmURL)
            }
            try fileManager.copyItem(at: backupShmURL, to: storeShmURL)
        }
        
        if fileManager.fileExists(atPath: backupWalURL.path) {
            if fileManager.fileExists(atPath: storeWalURL.path) {
                try fileManager.removeItem(at: storeWalURL)
            }
            try fileManager.copyItem(at: backupWalURL, to: storeWalURL)
        }
        
        print("已从备份恢复数据库: \(backupURL.lastPathComponent)")
    }
    
    /// 获取备份目录
    private func getBackupDirectory() throws -> URL {
        let fileManager = FileManager.default
        
        // 在应用支持目录中创建备份目录
        let applicationSupportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let backupDirectory = applicationSupportDirectory
            .appendingPathComponent("OnlySlide")
            .appendingPathComponent("Database_Backups")
        
        // 如果备份目录不存在，创建它
        if !fileManager.fileExists(atPath: backupDirectory.path) {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        }
        
        return backupDirectory
    }
    
    /// 清理旧备份文件
    private func cleanupOldBackups() {
        do {
            let fileManager = FileManager.default
            let backupDirectory = try getBackupDirectory()
            
            // 获取所有备份文件
            let backupFiles = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "sqlite" }
            
            // 如果备份文件数量小于指定数量，不需要清理
            if backupFiles.count <= configuration.maxBackupsToKeep {
                return
            }
            
            // 按创建日期排序备份文件
            let sortedBackups = try backupFiles.sorted {
                let date1 = try $0.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                let date2 = try $1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                return date1 > date2 // 降序排列（最新的在前面）
            }
            
            // 删除最旧的备份文件
            let backupsToDelete = sortedBackups.suffix(sortedBackups.count - configuration.maxBackupsToKeep)
            for backupURL in backupsToDelete {
                try fileManager.removeItem(at: backupURL)
                
                // 也删除辅助文件
                let shmURL = backupURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
                let walURL = backupURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
                
                if fileManager.fileExists(atPath: shmURL.path) {
                    try fileManager.removeItem(at: shmURL)
                }
                
                if fileManager.fileExists(atPath: walURL.path) {
                    try fileManager.removeItem(at: walURL)
                }
            }
            
            print("已清理 \(backupsToDelete.count) 个旧备份文件")
        } catch {
            print("清理旧备份文件失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Recovery
    
    /// 查找可用的备份文件
    public func listAvailableBackups() throws -> [(url: URL, date: Date)] {
        let fileManager = FileManager.default
        let backupDirectory = try getBackupDirectory()
        
        // 获取所有备份文件
        let backupURLs = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey])
            .filter { $0.pathExtension == "sqlite" }
        
        // 获取每个备份文件的创建日期
        var result: [(url: URL, date: Date)] = []
        for url in backupURLs {
            if let date = try url.resourceValues(forKeys: [.creationDateKey]).creationDate {
                result.append((url: url, date: date))
            }
        }
        
        // 按日期降序排列（最新的在前面）
        return result.sorted { $0.date > $1.date }
    }
    
    /// 从指定备份文件恢复数据库
    /// - Parameters:
    ///   - backupURL: 备份文件URL
    ///   - storeURL: 目标存储URL
    public func restoreFromBackup(backupURL: URL, to storeURL: URL) throws {
        try restoreBackup(from: backupURL, to: storeURL)
    }
    
    /// 恢复到最近的备份
    /// - Parameter storeURL: 目标存储URL
    public func restoreToLatestBackup(for storeURL: URL) throws {
        let backups = try listAvailableBackups()
        
        guard let latestBackup = backups.first else {
            throw CoreDataError.migrationFailed("没有找到可用的备份文件")
        }
        
        try restoreFromBackup(backupURL: latestBackup.url, to: storeURL)
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

/// 迁移步骤
public struct MigrationStep {
    /// 源版本
    public let sourceVersion: ModelVersion
    
    /// 目标版本
    public let destinationVersion: ModelVersion
} 