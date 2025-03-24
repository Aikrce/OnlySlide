import Foundation
import os.log

public final class CoreBackupManager {
    // MARK: - Properties
    
    public static let shared = CoreBackupManager()
    private let logger = os.Logger(subsystem: "com.onlyslide", category: "backup")
    
    private let fileManager: FileManager
    private let backupDirectory: URL
    
    // MARK: - Initialization
    
    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        // 获取备份目录
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.backupDirectory = documentsDirectory.appendingPathComponent("Backups")
        
        // 创建备份目录（如果不存在）
        do {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create backup directory: \(error.localizedDescription)")
            // 我们不能在init中抛出错误，所以记录错误并继续
            // 在后续的操作中会再次尝试创建目录
        }
    }
    
    // MARK: - Public Methods
    
    public func performBackup(type: BackupType, components: Set<BackupComponent>) async throws {
        logger.info("Starting backup of type: \(type.rawValue), components: \(Array(components).map { $0.rawValue }.joined(separator: ", "))")
        
        // 创建备份文件夹
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupName = "\(type.rawValue)_\(timestamp)"
        let backupPath = backupDirectory.appendingPathComponent(backupName)
        
        do {
            try fileManager.createDirectory(at: backupPath, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create backup directory at \(backupPath.path): \(error.localizedDescription)")
            throw BackupError.preparationFailed(reason: "Could not create backup directory: \(error.localizedDescription)")
        }
        
        // 备份每个组件，收集错误而不是立即失败
        var failedComponents: [(BackupComponent, Error)] = []
        
        for component in components {
            do {
                try await backupComponent(component, to: backupPath)
                logger.info("Successfully backed up component: \(component.rawValue)")
            } catch {
                logger.error("Failed to backup component \(component.rawValue): \(error.localizedDescription)")
                failedComponents.append((component, error))
                // 继续备份其他组件而不是立即失败
            }
        }
        
        // 创建备份清单
        do {
            // 只包含成功的组件
            let successfulComponents = Set(components).subtracting(Set(failedComponents.map { $0.0 }))
            if !successfulComponents.isEmpty {
                try createManifest(for: backupPath, type: type, components: successfulComponents)
            }
        } catch {
            logger.error("Failed to create backup manifest: \(error.localizedDescription)")
            failedComponents.append((BackupComponent.source, error)) // 使用source作为占位符
        }
        
        // 处理错误
        if !failedComponents.isEmpty {
            if failedComponents.count == components.count {
                // 所有组件都失败
                logger.critical("All backup components failed")
                throw BackupError.allComponentsFailed(errors: failedComponents.map { "\($0.0.rawValue): \($0.1.localizedDescription)" })
            } else {
                // 部分组件失败，但备份仍然部分成功
                logger.warning("Backup partially completed with \(failedComponents.count) failed components")
                throw BackupError.partialBackupCompleted(
                    path: backupPath,
                    failedComponents: failedComponents.map { "\($0.0.rawValue): \($0.1.localizedDescription)" }
                )
            }
        }
        
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
        logger.info("Starting source code backup")
        
        let sourceDirectory = fileManager.currentDirectoryPath
        let excludePatterns = [
            ".git",
            ".build",
            "Backups",
            ".DS_Store",
            "*.xcodeproj",
            "*.xcworkspace"
        ]
        
        // 构建排除参数数组，而不是单个字符串
        var arguments = ["czf", path.appendingPathComponent("source.tar.gz").path, "-C", sourceDirectory]
        
        // 正确添加每个排除模式
        for pattern in excludePatterns {
            arguments.append("--exclude=\(pattern)")
        }
        
        // 添加要打包的目录
        arguments.append(".")
        
        do {
            _ = try executeProcess(
                executableURL: URL(fileURLWithPath: "/usr/bin/tar"),
                arguments: arguments
            )
            logger.info("Source code backup completed successfully")
        } catch {
            logger.error("Source code backup failed: \(error.localizedDescription)")
            throw BackupError.sourceBackupFailed
        }
    }
    
    private func backupDatabase(to path: URL) async throws {
        logger.info("Starting database backup")
        
        // 获取数据库目录
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let databaseDirectory = appSupportDirectory?.appendingPathComponent("Database")
        
        guard let dbDirectory = databaseDirectory, fileManager.fileExists(atPath: dbDirectory.path) else {
            logger.warning("Database directory not found, skipping database backup")
            return // 没有数据库目录，跳过备份而不是失败
        }
        
        // 创建tar归档
        let arguments = [
            "czf",
            path.appendingPathComponent("database.tar.gz").path,
            "-C",
            dbDirectory.path,
            "."
        ]
        
        do {
            _ = try executeProcess(
                executableURL: URL(fileURLWithPath: "/usr/bin/tar"),
                arguments: arguments
            )
            logger.info("Database backup completed successfully")
        } catch {
            logger.error("Database backup failed: \(error.localizedDescription)")
            throw BackupError.databaseBackupFailed
        }
    }
    
    private func backupAssets(to path: URL) async throws {
        logger.info("Starting assets backup")
        
        // 尝试多个可能的资源目录位置
        let possibleAssetsPaths = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent("Resources")
                .appendingPathComponent("Assets"),
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent("Assets"),
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Assets")
        ].compactMap { $0 }
        
        // 查找第一个存在的资源目录
        guard let assetsDirectory = possibleAssetsPaths.first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            logger.warning("Assets directory not found at any of the expected locations. Skipping assets backup.")
            return // 跳过而不是失败
        }
        
        logger.info("Found assets directory at: \(assetsDirectory.path)")
        
        // 定义tar命令参数
        let arguments = [
            "czf",
            path.appendingPathComponent("assets.tar.gz").path,
            "-C",
            assetsDirectory.path,
            "."
        ]
        
        // 使用辅助方法执行tar命令
        do {
            _ = try executeProcess(
                executableURL: URL(fileURLWithPath: "/usr/bin/tar"),
                arguments: arguments
            )
            logger.info("Assets backup completed successfully")
        } catch {
            logger.error("Assets backup failed: \(error.localizedDescription)")
            throw BackupError.assetsBackupFailed
        }
    }
    
    private func createManifest(for path: URL, type: BackupType, components: Set<BackupComponent>) throws {
        logger.info("Creating backup manifest for \(components.count) component(s)")
        
        // 获取应用版本，提供更健壮的回退逻辑
        let version: String
        if let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            version = bundleVersion
        } else if let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            version = bundleVersion
        } else {
            // 在脚本环境中，Bundle.main可能不包含应用信息
            version = ProcessInfo.processInfo.operatingSystemVersionString
            logger.warning("Could not determine app version, using OS version instead: \(version)")
        }
        
        // 创建清单
        let manifest = BackupManifest(
            timestamp: Date(),
            type: type,
            components: Array(components),
            version: version
        )
        
        // 编码为JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let manifestData = try encoder.encode(manifest)
            let manifestPath = path.appendingPathComponent("manifest.json")
            
            // 写入文件
            try manifestData.write(to: manifestPath)
            
            // 验证文件已创建
            guard fileManager.fileExists(atPath: manifestPath.path) else {
                throw BackupError.manifestCreationFailed(reason: "File not created")
            }
            
            logger.info("Backup manifest created successfully at \(manifestPath.path)")
        } catch {
            logger.error("Failed to create manifest: \(error.localizedDescription)")
            throw BackupError.manifestCreationFailed(reason: error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    private func executeProcess(executableURL: URL, arguments: [String], workingDirectory: String? = nil) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = executableURL
        process.arguments = arguments
        
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        logger.debug("Executing command: \(executableURL.path) \(arguments.joined(separator: " "))")
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            logger.error("Process failed with status: \(process.terminationStatus)")
            logger.error("Error output: \(error)")
            return error
        }
        
        return output
    }
}

// MARK: - Types

public enum BackupType: String, Codable {
    case development
    case release
    case hotfix
}

public enum BackupComponent: String, Codable {
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
    case preparationFailed(reason: String)
    case partialBackupCompleted(path: URL, failedComponents: [String])
    case allComponentsFailed(errors: [String])
    case manifestCreationFailed(reason: String)
    
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
        case .preparationFailed(let reason):
            return "Failed to prepare for backup: \(reason)"
        case .partialBackupCompleted(let path, let failedComponents):
            return "Backup partially completed at \(path.path). Failed components: \(failedComponents.joined(separator: ", "))"
        case .allComponentsFailed(let errors):
            return "All backup components failed: \(errors.joined(separator: ", "))"
        case .manifestCreationFailed(let reason):
            return "Failed to create backup manifest: \(reason)"
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