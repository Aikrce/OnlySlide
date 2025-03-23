import Foundation

public final class BackupManager {
    // MARK: - Properties
    
    public static let shared = BackupManager()
    private let logger = Logger(label: "com.onlyslide.backup")
    
    private let fileManager: FileManager
    private let backupDirectory: URL
    
    // MARK: - Initialization
    
    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        // 获取备份目录
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.backupDirectory = documentsDirectory.appendingPathComponent("Backups")
        
        // 创建备份目录（如果不存在）
        try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    public func performBackup(type: BackupType, components: Set<BackupComponent>) async throws {
        logger.info("Starting backup of type: \(type), components: \(components)")
        
        // 创建备份文件夹
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupName = "\(type.rawValue)_\(timestamp)"
        let backupPath = backupDirectory.appendingPathComponent(backupName)
        
        try fileManager.createDirectory(at: backupPath, withIntermediateDirectories: true)
        
        // 备份每个组件
        for component in components {
            try await backupComponent(component, to: backupPath)
        }
        
        // 创建备份清单
        try createManifest(for: backupPath, type: type, components: components)
        
        logger.info("Backup completed successfully at: \(backupPath.path)")
    }
    
    // MARK: - Private Methods
    
    private func backupComponent(_ component: BackupComponent, to path: URL) async throws {
        let componentPath = path.appendingPathComponent(component.rawValue)
        try fileManager.createDirectory(at: componentPath, withIntermediateDirectories: true)
        
        switch component {
        case .source:
            try await backupSourceCode(to: componentPath)
        case .database:
            try await backupDatabase(to: componentPath)
        case .assets:
            try await backupAssets(to: componentPath)
        }
    }
    
    private func backupSourceCode(to path: URL) async throws {
        let sourceDirectory = fileManager.currentDirectoryPath
        let excludePatterns = [
            ".git",
            ".build",
            "Backups",
            ".DS_Store",
            "*.xcodeproj",
            "*.xcworkspace"
        ]
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = [
            "czf",
            path.appendingPathComponent("source.tar.gz").path,
            "-C",
            sourceDirectory,
            "--exclude=" + excludePatterns.joined(separator: " --exclude="),
            "."
        ]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw BackupError.sourceBackupFailed
        }
    }
    
    private func backupDatabase(to path: URL) async throws {
        // TODO: 实现数据库备份
        // 这里应该实现具体的数据库备份逻辑
        throw BackupError.notImplemented
    }
    
    private func backupAssets(to path: URL) async throws {
        let assetsDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent("Resources")
            .appendingPathComponent("Assets")
        
        guard fileManager.fileExists(atPath: assetsDirectory.path) else {
            throw BackupError.assetsDirectoryNotFound
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = [
            "czf",
            path.appendingPathComponent("assets.tar.gz").path,
            "-C",
            assetsDirectory.path,
            "."
        ]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw BackupError.assetsBackupFailed
        }
    }
    
    private func createManifest(for path: URL, type: BackupType, components: Set<BackupComponent>) throws {
        let manifest = BackupManifest(
            timestamp: Date(),
            type: type,
            components: Array(components),
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let manifestData = try encoder.encode(manifest)
        let manifestPath = path.appendingPathComponent("manifest.json")
        
        try manifestData.write(to: manifestPath)
    }
}

// MARK: - Types

public enum BackupType: String {
    case development
    case release
    case hotfix
}

public enum BackupComponent: String {
    case source
    case database
    case assets
}

public enum BackupError: LocalizedError {
    case sourceBackupFailed
    case databaseBackupFailed
    case assetsBackupFailed
    case assetsDirectoryNotFound
    case notImplemented
    
    public var errorDescription: String? {
        switch self {
        case .sourceBackupFailed:
            return "Failed to backup source code"
        case .databaseBackupFailed:
            return "Failed to backup database"
        case .assetsBackupFailed:
            return "Failed to backup assets"
        case .assetsDirectoryNotFound:
            return "Assets directory not found"
        case .notImplemented:
            return "This feature is not implemented yet"
        }
    }
}

// MARK: - Manifest

private struct BackupManifest: Codable {
    let timestamp: Date
    let type: BackupType
    let components: [BackupComponent]
    let version: String
} 