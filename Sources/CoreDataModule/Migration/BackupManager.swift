import Foundation

/// 负责管理 Core Data 存储的备份
@MainActor public final class BackupManager: @unchecked Sendable {
    // MARK: - Properties
    
    /// 资源管理器
    private let resourceManager: CoreDataResourceManager
    
    /// 备份配置
    private let configuration: BackupConfiguration
    
    // MARK: - Initialization
    
    /// 初始化备份管理器
    /// - Parameters:
    ///   - resourceManager: 资源管理器
    ///   - configuration: 备份配置
    public init(
        resourceManager: CoreDataResourceManager = .shared,
        configuration: BackupConfiguration = .default
    ) {
        self.resourceManager = resourceManager
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// 获取所有备份
    /// - Returns: 备份信息数组
    public func getAllBackups() -> [BackupInfo] {
        return resourceManager.allBackups().compactMap { BackupInfo.from(fileURL: $0) }
    }
    
    /// 获取最新备份
    /// - Returns: 最新备份信息
    public func getLatestBackup() -> BackupInfo? {
        let backups = getAllBackups().sorted { $0.creationDate > $1.creationDate }
        return backups.first
    }
    
    /// 创建备份
    /// - Parameter storeURL: 存储 URL
    /// - Returns: 备份结果
    public func createBackup(for storeURL: URL) async throws -> BackupResult {
        // 检查配置
        if !configuration.shouldCreateBackup {
            throw MigrationError.backupFailed(description: "备份功能已禁用")
        }
        
        let backupURL = resourceManager.backupStoreURL()
        
        // 确保备份目录存在
        guard let _ = resourceManager.createBackupDirectory() else {
            let error = MigrationError.backupFailed(description: "无法创建备份目录")
            return .failure(error: error)
        }
        
        do {
            // 复制当前存储文件到备份位置
            try FileManager.default.copyItem(at: storeURL, to: backupURL)
            
            // 复制相关的 -wal 和 -shm 文件
            let auxiliaryFiles = try copyAuxiliaryFiles(from: storeURL, to: backupURL)
            
            // 如果配置了，清理旧备份
            if configuration.shouldRemoveOldBackups {
                cleanupOldBackups()
            }
            
            // 创建备份信息
            guard let backupInfo = BackupInfo.from(fileURL: backupURL) else {
                let error = MigrationError.backupFailed(description: "无法获取备份信息")
                return .failure(error: error)
            }
            
            return .success(info: backupInfo)
        } catch {
            let migrationError = MigrationError.backupFailed(description: error.localizedDescription)
            return .failure(error: migrationError)
        }
    }
    
    /// 从备份恢复
    /// - Parameters:
    ///   - backupInfo: 备份信息
    ///   - targetURL: 目标存储 URL
    /// - Returns: 恢复结果
    public func restoreFromBackup(
        _ backupInfo: BackupInfo,
        to targetURL: URL
    ) async throws -> RestoreResult {
        do {
            // 删除当前存储
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            
            // 复制备份到存储位置
            try FileManager.default.copyItem(at: backupInfo.fileURL, to: targetURL)
            
            // 复制辅助文件
            for auxiliaryFile in backupInfo.auxiliaryFiles {
                let fileName = auxiliaryFile.lastPathComponent
                let targetAuxiliaryURL = targetURL.deletingLastPathComponent().appendingPathComponent(fileName)
                
                if FileManager.default.fileExists(atPath: auxiliaryFile.path) {
                    try FileManager.default.copyItem(at: auxiliaryFile, to: targetAuxiliaryURL)
                }
            }
            
            return .success
        } catch {
            let migrationError = MigrationError.restorationFailed(description: error.localizedDescription)
            return .failure(error: migrationError)
        }
    }
    
    /// 从最新备份恢复
    /// - Parameter targetURL: 目标存储 URL
    /// - Returns: 恢复结果
    public func restoreFromLatestBackup(to targetURL: URL) async throws -> RestoreResult {
        guard let latestBackup = getLatestBackup() else {
            let error = MigrationError.restorationFailed(description: "没有可用的备份")
            return .failure(error: error)
        }
        
        return try await restoreFromBackup(latestBackup, to: targetURL)
    }
    
    /// 删除指定备份
    /// - Parameter backupInfo: 备份信息
    /// - Returns: 是否成功删除
    public func deleteBackup(_ backupInfo: BackupInfo) -> Bool {
        do {
            // 删除主备份文件
            try FileManager.default.removeItem(at: backupInfo.fileURL)
            
            // 删除辅助文件
            for auxiliaryFile in backupInfo.auxiliaryFiles {
                if FileManager.default.fileExists(atPath: auxiliaryFile.path) {
                    try FileManager.default.removeItem(at: auxiliaryFile)
                }
            }
            
            return true
        } catch {
            print("删除备份失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 清理旧备份
    public func cleanupOldBackups() {
        resourceManager.cleanupBackups(keepLatest: configuration.maxBackupsToKeep)
    }
    
    // MARK: - Private Methods
    
    /// 复制辅助文件
    /// - Parameters:
    ///   - sourceURL: 源 URL
    ///   - targetURL: 目标 URL
    /// - Returns: 已复制的辅助文件 URL 数组
    private func copyAuxiliaryFiles(from sourceURL: URL, to targetURL: URL) throws -> [URL] {
        let fileManager = FileManager.default
        let sourceDirectoryURL = sourceURL.deletingLastPathComponent()
        let sourceFileName = sourceURL.lastPathComponent
        let walFileName = sourceFileName + "-wal"
        let shmFileName = sourceFileName + "-shm"
        
        let walURL = sourceDirectoryURL.appendingPathComponent(walFileName)
        let shmURL = sourceDirectoryURL.appendingPathComponent(shmFileName)
        
        let targetDirectoryURL = targetURL.deletingLastPathComponent()
        let targetFileName = targetURL.lastPathComponent
        let targetWalURL = targetDirectoryURL.appendingPathComponent(targetFileName + "-wal")
        let targetShmURL = targetDirectoryURL.appendingPathComponent(targetFileName + "-shm")
        
        var copiedFiles: [URL] = []
        
        // 如果存在 WAL 文件，复制它
        if fileManager.fileExists(atPath: walURL.path) {
            try fileManager.copyItem(at: walURL, to: targetWalURL)
            copiedFiles.append(targetWalURL)
        }
        
        // 如果存在 SHM 文件，复制它
        if fileManager.fileExists(atPath: shmURL.path) {
            try fileManager.copyItem(at: shmURL, to: targetShmURL)
            copiedFiles.append(targetShmURL)
        }
        
        return copiedFiles
    }
} 