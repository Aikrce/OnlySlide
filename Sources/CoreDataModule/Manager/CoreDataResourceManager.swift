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