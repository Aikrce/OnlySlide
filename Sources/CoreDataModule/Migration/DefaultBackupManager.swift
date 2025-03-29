import Foundation

// 使用CoreDataModule模块中已经定义的协议，不再重复声明
// 原本的BackupManagerProtocol定义已移至EnhancedMigrationManager.swift

// MARK: - Default Backup Manager Implementation

/// 默认备份管理器
@MainActor public final class DefaultBackupManager: BackupManagerProtocol, @unchecked Sendable {
    // MARK: - Properties
    
    /// 实际使用的备份管理器
    private let backupManager: BackupManager
    
    // MARK: - Initialization
    
    /// 初始化默认备份管理器
    /// - Parameter backupManager: 实际使用的备份管理器
    public init(backupManager: BackupManager = BackupManager()) {
        self.backupManager = backupManager
    }
    
    // MARK: - BackupManagerProtocol
    
    /// 创建备份
    /// - Parameters:
    ///   - storeURL: 存储URL
    ///   - options: 迁移选项
    /// - Returns: 备份结果
    public func createBackup(for storeURL: URL, options: ExecutorMigrationOptions) async throws -> ManagerBackupResult {
        return try await backupManager.createBackup(for: storeURL)
    }
    
    /// 从最新备份恢复
    /// - Parameter storeURL: 存储URL
    /// - Returns: 恢复结果
    public func restoreFromLatestBackup(to storeURL: URL) async throws -> RestoreResult {
        return try await backupManager.restoreFromLatestBackup(to: storeURL)
    }
    
    /// 清理旧备份
    /// - Parameters:
    ///   - storeURL: 存储URL
    ///   - keeping: 要保留的备份数量
    public func cleanupOldBackups(for storeURL: URL, keeping: Int) async throws {
        try await backupManager.cleanupOldBackups(for: storeURL, keepLatest: keeping)
    }
}