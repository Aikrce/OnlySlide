import Foundation
import CoreData

/// 统计信息结构体
public struct CacheStatistics: Sendable {
    /// 命中次数
    public let hits: Int
    
    /// 未命中次数
    public let misses: Int
    
    /// 命中率
    public let hitRate: Double
    
    /// 初始化
    public init(hits: Int, misses: Int) {
        self.hits = hits
        self.misses = misses
        self.hitRate = hits + misses > 0 ? Double(hits) / Double(hits + misses) : 0
    }
}

/// Core Data资源管理器
public actor CoreDataResourceManager: ResourceProviding {
    
    /// 共享实例
    public static let shared = CoreDataResourceManager()
    
    /// 数据栈
    private let dataStack: CoreDataStack
    
    /// 初始化资源管理器
    /// - Parameter dataStack: 数据栈实例，默认使用共享实例
    public init(dataStack: CoreDataStack = CoreDataStack.shared) {
        self.dataStack = dataStack
    }
    
    // MARK: - ResourceProviding 协议实现
    
    /// 获取合并的对象模型
    /// - Returns: 合并的对象模型
    public func mergedObjectModel() async -> NSManagedObjectModel? {
        return await dataStack.persistentContainer.managedObjectModel
    }
    
    /// 获取所有可用的模型
    /// - Returns: 所有可用的模型数组
    public func allModels() async -> [NSManagedObjectModel] {
        // 从searchBundles中加载所有模型文件
        return searchBundles.flatMap { bundle -> [NSManagedObjectModel] in
            let modelURLs = bundle.urls(forResourcesWithExtension: "momd", subdirectory: nil) ?? []
            return modelURLs.compactMap { modelURL -> NSManagedObjectModel? in
                NSManagedObjectModel(contentsOf: modelURL)
            }
        }
    }
    
    /// 获取用于搜索的包
    public var searchBundles: [Bundle] {
        [Bundle.main]
    }
    
    /// 备份Core Data存储的目录
    private func backupsDirectory() throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = try fileManager.url(for: .documentDirectory, 
                                             in: .userDomainMask, 
                                           appropriateFor: nil, 
                                             create: false)
        let backupsURL = documentsURL.appendingPathComponent("Backups", isDirectory: true)
        
        if !fileManager.fileExists(atPath: backupsURL.path) {
            try fileManager.createDirectory(at: backupsURL, 
                                            withIntermediateDirectories: true,
                                            attributes: nil)
        }
        
        return backupsURL
    }

    /// 获取所有可用的备份
    /// - Returns: 可用备份的URL列表，按修改日期排序
    public func getBackups() async throws -> [URL] {
        let fileManager = FileManager.default
        let backupsURL = try backupsDirectory()
        
        let backupURLs = try fileManager.contentsOfDirectory(at: backupsURL,
                                                         includingPropertiesForKeys: [.contentModificationDateKey],
                                                         options: .skipsHiddenFiles)
        
        return try backupURLs
            .filter { $0.pathExtension == "backup" }
            .sorted {
                let date1 = try $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                let date2 = try $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                return date1 > date2
            }
    }

    /// 获取指定存储的所有可用备份
    /// - Parameter storeURL: 存储的URL
    /// - Returns: 可用备份的URL列表，按修改日期排序
    public func getBackups(for storeURL: URL) async throws -> [URL] {
        let storeName = storeURL.deletingPathExtension().lastPathComponent
        
        do {
            let allBackups = try FileManager.default.contentsOfDirectory(at: try backupsDirectory(),
                                                                      includingPropertiesForKeys: [.contentModificationDateKey],
                                                                      options: .skipsHiddenFiles)
            
            // 过滤出特定存储的备份
            let storeBackups = allBackups.filter { 
                $0.pathExtension == "backup" && 
                $0.lastPathComponent.hasPrefix(storeName)
            }
            
            // 按修改日期排序
            return storeBackups.sorted {
                do {
                    let date1 = try $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                    let date2 = try $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                    return date1 > date2
                } catch {
                    return false
                }
            }
        } catch {
            // 如果发生错误，返回空数组
            throw CoreDataError.backupFailed(description: "无法访问备份目录: \(error.localizedDescription)")
        }
    }

    // MARK: - 备份相关方法 - 保持异步性并确保正确处理错误

    /// 创建备份目录
    public func createBackupDirectory() async throws -> URL {
        return try backupsDirectory()
    }
    
    /// 获取备份存储URL
    public func backupStoreURL() -> URL {
        do {
            let timestamp = Date().timeIntervalSince1970
            let backupURL = try backupsDirectory().appendingPathComponent("backup_\(Int(timestamp)).backup")
            return backupURL
        } catch {
            // 如果无法创建备份目录，则使用临时目录
            return FileManager.default.temporaryDirectory.appendingPathComponent("emergency_backup.backup")
        }
    }
    
    /// 获取所有备份
    public func allBackups() -> [URL] {
        do {
            let backupsURL = try backupsDirectory()
            let backupURLs = try FileManager.default.contentsOfDirectory(
                at: backupsURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            
            return backupURLs.filter { $0.pathExtension == "backup" }
        } catch {
            return []
        }
    }
    
    /// 清理备份
    public func cleanupBackups(keepLatest count: Int) {
        do {
            let backups = try getBackupsSynchronously().sorted { (url1, url2) -> Bool in
                do {
                    let date1 = try url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                    let date2 = try url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                    return date1 > date2
                } catch {
                    return false
                }
            }
            
            // 保留最新的count个备份，删除其余的
            if backups.count > count {
                let backupsToDelete = Array(backups.dropFirst(count))
                for backupURL in backupsToDelete {
                    try FileManager.default.removeItem(at: backupURL)
                }
            }
        } catch {
            // 记录错误但不抛出
            print("清理备份失败: \(error.localizedDescription)")
        }
    }
    
    /// 同步获取备份（内部辅助方法）
    private func getBackupsSynchronously() throws -> [URL] {
        let fileManager = FileManager.default
        let backupsURL = try backupsDirectory()
        
        let backupURLs = try fileManager.contentsOfDirectory(
            at: backupsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )
        
        return backupURLs.filter { $0.pathExtension == "backup" }
    }
    
    /// 解压备份
    func unzipBackup(from backupURL: URL, to targetDirectoryURL: URL) throws {
        // 将备份文件复制到目标位置
        try FileManager.default.copyItem(at: backupURL, to: targetDirectoryURL.appendingPathComponent("store.sqlite"))
    }
    
    /// 备份数据存储
    /// - Parameter storeURL: 要备份的存储URL
    /// - Returns: 备份文件的URL
    /// - Throws: 如果备份过程中出现错误，则抛出CoreDataError.backupFailed
    public func backupStore(at storeURL: URL) async throws -> URL {
        let fileManager = FileManager.default
        let backupURL = backupStoreURL()
        
        // 确保存储文件存在
        guard fileManager.fileExists(atPath: storeURL.path) else {
            throw CoreDataError.backupFailed(description: "存储文件不存在于路径: \(storeURL.path)")
        }
        
        do {
            // 复制存储文件到备份位置
            try fileManager.copyItem(at: storeURL, to: backupURL)
            
            // 复制相关的 -wal 和 -shm 文件（如果存在）
            let storePath = storeURL.deletingLastPathComponent()
            let storeFileName = storeURL.lastPathComponent
            let fileNameWithoutExtension = storeURL.deletingPathExtension().lastPathComponent
            
            // 检查并复制WAL文件
            let walURL = storePath.appendingPathComponent("\(fileNameWithoutExtension)-wal")
            let backupWalURL = backupURL.deletingPathExtension().appendingPathComponent("\(backupURL.deletingPathExtension().lastPathComponent)-wal")
            if fileManager.fileExists(atPath: walURL.path) {
                try fileManager.copyItem(at: walURL, to: backupWalURL)
            }
            
            // 检查并复制SHM文件
            let shmURL = storePath.appendingPathComponent("\(fileNameWithoutExtension)-shm")
            let backupShmURL = backupURL.deletingPathExtension().appendingPathComponent("\(backupURL.deletingPathExtension().lastPathComponent)-shm")
            if fileManager.fileExists(atPath: shmURL.path) {
                try fileManager.copyItem(at: shmURL, to: backupShmURL)
            }
            
            return backupURL
        } catch {
            throw CoreDataError.backupFailed(description: "备份过程中发生错误: \(error.localizedDescription)")
        }
    }
    
    /// 从备份恢复数据存储
    /// - Parameters:
    ///   - backupURL: 备份文件的URL
    ///   - storeURL: 要恢复到的存储URL
    /// - Throws: 如果恢复过程中出现错误，则抛出CoreDataError.backupRestoreFailed
    public func restoreBackup(at backupURL: URL, to storeURL: URL) async throws {
        let fileManager = FileManager.default
        
        // 确保备份文件存在
        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw CoreDataError.backupRestoreFailed(description: "备份文件不存在于路径: \(backupURL.path)")
        }
        
        // 关闭持久化存储
        await dataStack.closePersistentStores()
        
        do {
            // 如果存储文件已存在，先删除它
            if fileManager.fileExists(atPath: storeURL.path) {
                try fileManager.removeItem(at: storeURL)
                
                // 同时移除相关的 -wal 和 -shm 文件（如果存在）
                let storeDir = storeURL.deletingLastPathComponent()
                let storeNameWithoutExt = storeURL.deletingPathExtension().lastPathComponent
                
                let walURL = storeDir.appendingPathComponent("\(storeNameWithoutExt)-wal")
                if fileManager.fileExists(atPath: walURL.path) {
                    try fileManager.removeItem(at: walURL)
                }
                
                let shmURL = storeDir.appendingPathComponent("\(storeNameWithoutExt)-shm")
                if fileManager.fileExists(atPath: shmURL.path) {
                    try fileManager.removeItem(at: shmURL)
                }
            }
            
            // 复制备份文件到存储位置
            try fileManager.copyItem(at: backupURL, to: storeURL)
            
            // 复制相关的辅助文件（如果存在）
            let backupDir = backupURL.deletingLastPathComponent()
            let backupNameWithoutExt = backupURL.deletingPathExtension().lastPathComponent
            
            let storeDir = storeURL.deletingLastPathComponent()
            let storeNameWithoutExt = storeURL.deletingPathExtension().lastPathComponent
            
            // 复制WAL文件
            let backupWalURL = backupDir.appendingPathComponent("\(backupNameWithoutExt)-wal")
            let storeWalURL = storeDir.appendingPathComponent("\(storeNameWithoutExt)-wal")
            if fileManager.fileExists(atPath: backupWalURL.path) {
                try fileManager.copyItem(at: backupWalURL, to: storeWalURL)
            }
            
            // 复制SHM文件
            let backupShmURL = backupDir.appendingPathComponent("\(backupNameWithoutExt)-shm")
            let storeShmURL = storeDir.appendingPathComponent("\(storeNameWithoutExt)-shm")
            if fileManager.fileExists(atPath: backupShmURL.path) {
                try fileManager.copyItem(at: backupShmURL, to: storeShmURL)
            }
            
            // 重新加载存储
            await dataStack.reloadPersistentStores()
        } catch {
            throw CoreDataError.backupRestoreFailed(description: "恢复过程中发生错误: \(error.localizedDescription)")
        }
    }

    /// 获取缓存统计信息
    /// - Returns: 缓存统计信息
    public func getStatistics() async throws -> CacheStatistics {
        // 由于当前类没有明确的缓存跟踪机制
        // 我们返回一个默认的统计信息
        // 在实际实现中，应该根据您的缓存机制返回真实数据
        return CacheStatistics(hits: 0, misses: 0)
    }

    /// 清理过期的缓存
    /// 用于定期清理已过期的缓存项，提高性能和减少内存使用
    public func cleanupExpiredCache() async {
        // 由于当前没有内置的缓存系统，这个方法是一个占位符
        // 在实际实现中，应该清理任何实现的缓存机制
        
        // 清理旧备份，只保留最新的5个
        cleanupBackups(keepLatest: 5)
    }
}

// MARK: - ResourceProviding 协议扩展，提供同步访问方法
public extension CoreDataResourceManager {
    /// 同步访问方法
    nonisolated func mergedObjectModelSync() -> NSManagedObjectModel? {
        let task = Task { await mergedObjectModel() }
        return try? task.value
    }
    
    /// 同步访问方法
    nonisolated func allModelsSync() -> [NSManagedObjectModel] {
        let task = Task { await allModels() }
        return (try? task.value) ?? []
    }
} 