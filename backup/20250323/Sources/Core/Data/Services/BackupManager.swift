import Foundation
import CoreData
import Compression
import CryptoKit

/// 备份类型
enum BackupType {
    case daily
    case weekly
    case release
    
    var folderName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .release: return "Release"
        }
    }
}

/// 备份组件
enum BackupComponent {
    case source
    case database
    case assets
    
    var folderName: String {
        switch self {
        case .source: return "Source"
        case .database: return "Database"
        case .assets: return "Assets"
        }
    }
}

/// 备份状态
enum BackupStatus {
    case notStarted
    case inProgress(progress: Double)
    case completed(path: URL)
    case failed(error: Error)
}

/// 备份配置
struct BackupConfiguration {
    let maxBackupCount: Int
    let compressionLevel: Int
    let encryptionEnabled: Bool
    let retentionDays: Int
    
    static let `default` = BackupConfiguration(
        maxBackupCount: 10,
        compressionLevel: 6,
        encryptionEnabled: true,
        retentionDays: 30
    )
}

/// 备份管理器
final class BackupManager {
    // MARK: - Properties
    
    static let shared = BackupManager()
    
    private let configuration: BackupConfiguration
    private let backupQueue = DispatchQueue(label: "com.onlyslide.backup", qos: .utility)
    private let fileManager = FileManager.default
    
    private var backupRoot: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("Backups")
    }
    
    // MARK: - Initialization
    
    init(configuration: BackupConfiguration = .default) {
        self.configuration = configuration
        setupBackupDirectories()
    }
    
    // MARK: - Backup Management
    
    /// 执行备份
    /// - Parameters:
    ///   - type: 备份类型（每日/每周/发布）
    ///   - components: 要备份的组件
    func performBackup(type: BackupType, components: [BackupComponent]) async throws {
        // 创建备份目录
        let backupDirectory = try createBackupDirectory(for: type)
        
        // 执行各组件的备份
        for component in components {
            try await backupComponent(component, to: backupDirectory)
        }
        
        // 清理旧备份
        try cleanupOldBackups(type: type)
        
        // 更新备份记录
        try updateBackupRecord(type: type, path: backupDirectory)
    }
    
    /// 恢复备份
    /// - Parameters:
    ///   - backupId: 备份ID
    ///   - components: 要恢复的组件
    func restore(from backupId: String, components: [BackupComponent]) async throws {
        // 验证备份完整性
        guard let backupPath = try findBackup(withId: backupId) else {
            throw BackupError.backupNotFound
        }
        
        try validateBackupIntegrity(at: backupPath)
        
        // 准备恢复环境
        try prepareRestoreEnvironment()
        
        // 执行各组件的恢复
        for component in components {
            try await restoreComponent(component, from: backupPath)
        }
        
        // 验证恢复结果
        try validateRestoreResult()
    }
    
    // MARK: - Private Methods
    
    private func setupBackupDirectories() {
        do {
            // 创建根目录
            try fileManager.createDirectory(at: backupRoot, withIntermediateDirectories: true)
            
            // 创建组件目录
            for component in BackupComponent.allCases {
                let componentPath = backupRoot.appendingPathComponent(component.folderName)
                try fileManager.createDirectory(at: componentPath, withIntermediateDirectories: true)
            }
        } catch {
            print("设置备份目录失败: \(error)")
        }
    }
    
    private func createBackupDirectory(for type: BackupType) throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupId = "\(type.folderName)_\(timestamp)"
        let backupPath = backupRoot.appendingPathComponent(backupId)
        
        try fileManager.createDirectory(at: backupPath, withIntermediateDirectories: true)
        
        return backupPath
    }
    
    private func backupComponent(_ component: BackupComponent, to directory: URL) async throws {
        let componentDirectory = directory.appendingPathComponent(component.folderName)
        try fileManager.createDirectory(at: componentDirectory, withIntermediateDirectories: true)
        
        switch component {
        case .database:
            try await backupDatabase(to: componentDirectory)
        case .source:
            try await backupSourceCode(to: componentDirectory)
        case .assets:
            try await backupAssets(to: componentDirectory)
        }
    }
    
    private func backupDatabase(to directory: URL) async throws {
        // 获取 Core Data 存储 URL
        guard let storeURL = CoreDataStack.shared.persistentContainer.persistentStoreCoordinator.persistentStores.first?.url else {
            throw BackupError.storeNotFound
        }
        
        // 创建临时目录
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // 复制数据库文件
        let backupURL = directory.appendingPathComponent("store.sqlite")
        try fileManager.copyItem(at: storeURL, to: backupURL)
        
        // 压缩备份
        if configuration.compressionLevel > 0 {
            try compressFile(at: backupURL)
        }
        
        // 加密备份
        if configuration.encryptionEnabled {
            try encryptFile(at: backupURL)
        }
        
        // 清理临时文件
        try fileManager.removeItem(at: tempDirectory)
    }
    
    private func backupSourceCode(to directory: URL) async throws {
        // 获取项目根目录
        let sourceRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        // 创建源代码备份
        let backupURL = directory.appendingPathComponent("source.zip")
        try await compressDirectory(sourceRoot, to: backupURL)
    }
    
    private func backupAssets(to directory: URL) async throws {
        // 获取资源目录
        let assetsRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Assets")
        
        // 创建资源备份
        let backupURL = directory.appendingPathComponent("assets.zip")
        try await compressDirectory(assetsRoot, to: backupURL)
    }
    
    private func cleanupOldBackups(type: BackupType) throws {
        let typeDirectory = backupRoot.appendingPathComponent(type.folderName)
        let contents = try fileManager.contentsOfDirectory(at: typeDirectory, includingPropertiesForKeys: [.creationDateKey])
        
        // 按创建日期排序
        let sortedContents = contents.sorted { (url1, url2) -> Bool in
            let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate
            let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate
            return date1 ?? Date() > date2 ?? Date()
        }
        
        // 删除超出限制的旧备份
        if sortedContents.count > configuration.maxBackupCount {
            for url in sortedContents[configuration.maxBackupCount...] {
                try fileManager.removeItem(at: url)
            }
        }
        
        // 删除过期备份
        let expirationDate = Date().addingTimeInterval(-TimeInterval(configuration.retentionDays * 24 * 60 * 60))
        for url in sortedContents {
            if let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
               creationDate < expirationDate {
                try fileManager.removeItem(at: url)
            }
        }
    }
    
    private func updateBackupRecord(type: BackupType, path: URL) throws {
        let record = BackupRecord(
            id: path.lastPathComponent,
            type: type,
            date: Date(),
            path: path
        )
        
        // 保存备份记录
        let recordURL = backupRoot.appendingPathComponent("backup_records.json")
        var records = try loadBackupRecords()
        records.append(record)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(records)
        try data.write(to: recordURL)
    }
    
    private func loadBackupRecords() throws -> [BackupRecord] {
        let recordURL = backupRoot.appendingPathComponent("backup_records.json")
        guard fileManager.fileExists(atPath: recordURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: recordURL)
        return try JSONDecoder().decode([BackupRecord].self, from: data)
    }
    
    // MARK: - Restore Methods
    
    private func findBackup(withId backupId: String) throws -> URL? {
        let records = try loadBackupRecords()
        return records.first { $0.id == backupId }?.path
    }
    
    private func validateBackupIntegrity(at path: URL) throws {
        // 验证备份文件完整性
        let checksumURL = path.appendingPathComponent("checksum.sha256")
        guard let storedChecksum = try? String(contentsOf: checksumURL) else {
            throw BackupError.invalidBackup
        }
        
        // 计算当前文件校验和
        let fileURL = path.appendingPathComponent("backup.zip")
        let fileData = try Data(contentsOf: fileURL)
        let checksum = SHA256.hash(data: fileData).description
        
        guard checksum == storedChecksum else {
            throw BackupError.integrityCheckFailed
        }
    }
    
    private func prepareRestoreEnvironment() throws {
        // 停止所有活动的 Core Data 操作
        CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
            context.reset()
        }
    }
    
    private func restoreComponent(_ component: BackupComponent, from backupPath: URL) async throws {
        let componentPath = backupPath.appendingPathComponent(component.folderName)
        
        switch component {
        case .database:
            try await restoreDatabase(from: componentPath)
        case .source:
            try await restoreSourceCode(from: componentPath)
        case .assets:
            try await restoreAssets(from: componentPath)
        }
    }
    
    private func validateRestoreResult() throws {
        // 验证数据库完整性
        try CoreDataStack.shared.persistentContainer.viewContext.save()
        
        // 验证文件完整性
        // TODO: 实现文件完整性检查
    }
    
    private func restoreDatabase(from path: URL) async throws {
        let fileManager = FileManager.default
        let databaseURL = try getDatabaseURL()
        
        // 确保目标目录存在
        try fileManager.createDirectory(at: databaseURL.deletingLastPathComponent(),
                                      withIntermediateDirectories: true)
        
        // 如果数据库文件已存在，先删除它
        if fileManager.fileExists(atPath: databaseURL.path) {
            try fileManager.removeItem(at: databaseURL)
        }
        
        // 复制备份文件到数据库位置
        try fileManager.copyItem(at: path, to: databaseURL)
    }
    
    private func restoreSourceCode(from path: URL) async throws {
        let fileManager = FileManager.default
        let sourceCodeURL = try getSourceCodeURL()
        
        // 确保目标目录存在
        try fileManager.createDirectory(at: sourceCodeURL.deletingLastPathComponent(),
                                      withIntermediateDirectories: true)
        
        // 如果源代码目录已存在，先删除它
        if fileManager.fileExists(atPath: sourceCodeURL.path) {
            try fileManager.removeItem(at: sourceCodeURL)
        }
        
        // 复制备份文件到源代码位置
        try fileManager.copyItem(at: path, to: sourceCodeURL)
    }
    
    private func restoreAssets(from path: URL) async throws {
        let fileManager = FileManager.default
        let assetsURL = try getAssetsURL()
        
        // 确保目标目录存在
        try fileManager.createDirectory(at: assetsURL.deletingLastPathComponent(),
                                      withIntermediateDirectories: true)
        
        // 如果资源目录已存在，先删除它
        if fileManager.fileExists(atPath: assetsURL.path) {
            try fileManager.removeItem(at: assetsURL)
        }
        
        // 复制备份文件到资源位置
        try fileManager.copyItem(at: path, to: assetsURL)
    }
    
    private func getDatabaseURL() throws -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw BackupError.invalidPath
        }
        return appSupport.appendingPathComponent("Database/OnlySlide.sqlite")
    }
    
    private func getSourceCodeURL() throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw BackupError.invalidPath
        }
        return documents.appendingPathComponent("SourceCode")
    }
    
    private func getAssetsURL() throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw BackupError.invalidPath
        }
        return documents.appendingPathComponent("Assets")
    }
    
    // MARK: - Utility Methods
    
    private func compressFile(at url: URL) throws {
        let data = try Data(contentsOf: url)
        var compressed = Data()
        
        data.withUnsafeBytes { (sourcePtr: UnsafeRawBufferPointer) -> Void in
            let sourceSize = sourcePtr.count
            let destinationSize = sourceSize * 2
            
            compressed.count = destinationSize
            let algorithm = COMPRESSION_ZLIB
            
            compressed.withUnsafeMutableBytes { (destinationPtr: UnsafeMutableRawBufferPointer) -> Void in
                let destSize = compression_encode_buffer(
                    destinationPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    destinationSize,
                    sourcePtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    sourceSize,
                    nil,
                    algorithm
                )
                compressed.count = destSize
            }
        }
        
        try compressed.write(to: url)
    }
    
    private func compressDirectory(_ sourceURL: URL, to destinationURL: URL) async throws {
        // 使用系统 zip 命令压缩目录
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", destinationURL.path, sourceURL.path]
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw BackupError.compressionFailed
        }
    }
    
    private func encryptFile(at url: URL) throws {
        let data = try Data(contentsOf: url)
        
        // 生成随机密钥
        let key = SymmetricKey(size: .bits256)
        let nonce = try AES.GCM.Nonce()
        
        // 加密数据
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        try sealedBox.combined?.write(to: url)
        
        // 保存密钥（在实际应用中应该安全存储）
        let keyURL = url.deletingLastPathComponent().appendingPathComponent("key.bin")
        try key.withUnsafeBytes { bytes in
            try Data(bytes).write(to: keyURL)
        }
    }
    
    private func compressData(_ data: Data) throws -> Data {
        let sourceSize = data.count
        let destinationSize = sourceSize * 2  // 预留足够的空间
        var compressed = Data(count: destinationSize)
        var compressedSize: Int = 0
        
        try data.withUnsafeBytes { sourceBuffer in
            try compressed.withUnsafeMutableBytes { destBuffer in
                guard let sourcePtr = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let destPtr = destBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else {
                    throw BackupError.compressionFailed("Failed to get buffer pointers")
                }
                
                compressedSize = compression_encode_buffer(
                    destPtr,
                    destinationSize,
                    sourcePtr,
                    sourceSize,
                    nil,
                    COMPRESSION_LZFSE
                )
                
                if compressedSize == 0 {
                    throw BackupError.compressionFailed("Compression failed")
                }
            }
        }
        
        return compressed.prefix(compressedSize)
    }
    
    private func encryptData(_ data: Data) throws -> Data {
        let key = SymmetricKey(size: .bits256)
        let nonce = AES.GCM.Nonce()
        
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        return sealedBox.combined ?? Data()
    }
}

// MARK: - Supporting Types

/// 备份记录
struct BackupRecord: Codable {
    let id: String
    let type: BackupType
    let date: Date
    let path: URL
}

/// 备份错误
enum BackupError: Error {
    case storeNotFound
    case backupNotFound
    case invalidBackup
    case integrityCheckFailed
    case compressionFailed
    case encryptionFailed
    case restorationFailed
    case invalidPath
}

// MARK: - Extensions

extension BackupComponent: CaseIterable {}

extension BackupType: Codable {}
extension BackupComponent: Codable {} 