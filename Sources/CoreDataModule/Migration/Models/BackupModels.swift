import Foundation

/// 备份配置
public struct BackupConfiguration: Equatable, Sendable {
    /// 是否创建备份
    public let shouldCreateBackup: Bool
    
    /// 是否在失败时从备份恢复
    public let shouldRestoreFromBackupOnFailure: Bool
    
    /// 是否删除旧备份
    public let shouldRemoveOldBackups: Bool
    
    /// 要保留的最大备份数量
    public let maxBackupsToKeep: Int
    
    /// 初始化备份配置
    /// - Parameters:
    ///   - shouldCreateBackup: 是否创建备份
    ///   - shouldRestoreFromBackupOnFailure: 是否在失败时从备份恢复
    ///   - shouldRemoveOldBackups: 是否删除旧备份
    ///   - maxBackupsToKeep: 要保留的最大备份数量
    public init(
        shouldCreateBackup: Bool = true,
        shouldRestoreFromBackupOnFailure: Bool = true,
        shouldRemoveOldBackups: Bool = true,
        maxBackupsToKeep: Int = 5
    ) {
        self.shouldCreateBackup = shouldCreateBackup
        self.shouldRestoreFromBackupOnFailure = shouldRestoreFromBackupOnFailure
        self.shouldRemoveOldBackups = shouldRemoveOldBackups
        self.maxBackupsToKeep = maxBackupsToKeep
    }
    
    /// 默认配置
    public static let `default` = BackupConfiguration()
    
    /// 无备份配置
    public static let noBackup = BackupConfiguration(
        shouldCreateBackup: false,
        shouldRestoreFromBackupOnFailure: false,
        shouldRemoveOldBackups: false
    )
}

/// 备份信息
public struct BackupInfo: Identifiable, Equatable, Sendable {
    /// 唯一标识符
    public let id: UUID
    
    /// 备份文件 URL
    public let fileURL: URL
    
    /// 创建日期
    public let creationDate: Date
    
    /// 备份大小（字节）
    public let sizeInBytes: Int64
    
    /// 相关的辅助文件（如 WAL、SHM）
    public let auxiliaryFiles: [URL]
    
    /// 源版本（如果可用）
    public let sourceVersion: ModelVersion?
    
    /// 备份名称
    public var name: String {
        return fileURL.lastPathComponent
    }
    
    /// 友好的创建日期
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: creationDate)
    }
    
    /// 友好的大小表示
    public var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }
    
    /// 初始化备份信息
    /// - Parameters:
    ///   - id: 唯一标识符
    ///   - fileURL: 备份文件 URL
    ///   - creationDate: 创建日期
    ///   - sizeInBytes: 备份大小
    ///   - auxiliaryFiles: 辅助文件
    ///   - sourceVersion: 源版本
    public init(
        id: UUID = UUID(),
        fileURL: URL,
        creationDate: Date,
        sizeInBytes: Int64,
        auxiliaryFiles: [URL] = [],
        sourceVersion: ModelVersion? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.creationDate = creationDate
        self.sizeInBytes = sizeInBytes
        self.auxiliaryFiles = auxiliaryFiles
        self.sourceVersion = sourceVersion
    }
    
    /// 从文件 URL 创建备份信息
    /// - Parameter fileURL: 备份文件 URL
    /// - Returns: 备份信息
    public static func from(fileURL: URL) -> BackupInfo? {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // 获取创建日期
        guard let creationDate = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate else {
            return nil
        }
        
        // 获取文件大小
        guard let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return nil
        }
        
        // 查找辅助文件
        let directoryURL = fileURL.deletingLastPathComponent()
        let fileName = fileURL.lastPathComponent
        let walURL = directoryURL.appendingPathComponent(fileName + "-wal")
        let shmURL = directoryURL.appendingPathComponent(fileName + "-shm")
        
        var auxiliaryFiles: [URL] = []
        
        if fileManager.fileExists(atPath: walURL.path) {
            auxiliaryFiles.append(walURL)
        }
        
        if fileManager.fileExists(atPath: shmURL.path) {
            auxiliaryFiles.append(shmURL)
        }
        
        return BackupInfo(
            fileURL: fileURL,
            creationDate: creationDate,
            sizeInBytes: Int64(fileSize),
            auxiliaryFiles: auxiliaryFiles
        )
    }
}

/// 备份结果
public enum BackupResult: Equatable, Sendable {
    /// 成功
    case success(info: BackupInfo)
    /// 失败
    case failure(error: Error)
    
    /// 是否成功
    public var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    /// 是否失败
    public var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }
    
    /// 获取备份信息（如果成功）
    public var backupInfo: BackupInfo? {
        if case .success(let info) = self {
            return info
        }
        return nil
    }
    
    /// 获取错误（如果失败）
    public var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
    
    public static func == (lhs: BackupResult, rhs: BackupResult) -> Bool {
        switch (lhs, rhs) {
        case (.success(let lhsInfo), .success(let rhsInfo)):
            return lhsInfo == rhsInfo
        case (.failure, .failure):
            // 由于 Error 不符合 Equatable 协议，我们只能比较错误类型
            return true
        default:
            return false
        }
    }
}

/// 恢复结果
public enum RestoreResult: Equatable, Sendable {
    /// 成功
    case success
    /// 失败
    case failure(error: Error)
    
    /// 是否成功
    public var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    /// 是否失败
    public var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }
    
    /// 获取错误（如果失败）
    public var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
    
    public static func == (lhs: RestoreResult, rhs: RestoreResult) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success):
            return true
        case (.failure, .failure):
            // 由于 Error 不符合 Equatable 协议，我们只能比较错误类型
            return true
        default:
            return false
        }
    }
} 