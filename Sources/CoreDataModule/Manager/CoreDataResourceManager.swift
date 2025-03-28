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
public final class CoreDataResourceManager {
    
    /// 共享实例
    public static let shared = CoreDataResourceManager()
    
    /// 数据栈
    private let dataStack: CoreDataStack
    
    /// 初始化资源管理器
    /// - Parameter dataStack: 数据栈实例，默认使用共享实例
    public init(dataStack: CoreDataStack = CoreDataStack.shared) {
        self.dataStack = dataStack
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
    public func getBackups(for storeURL: URL) -> [URL] {
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
            return []
        }
    }

    /// 从备份文件恢复数据
    /// - Parameter backupURL: 备份文件的URL
    /// - Returns: 是否成功恢复
    public func restoreBackup(from backupURL: URL) async throws -> Bool {
        guard backupURL.pathExtension == "backup" else {
            throw CoreDataError.invalidBackupFile
        }
        
        // 获取Core Data存储的URL
        let coordinator = dataStack.persistentContainer.persistentStoreCoordinator
        guard let storeURL = coordinator.persistentStores.first?.url else {
            throw CoreDataError.storeNotFound("无法获取持久化存储URL")
        }
        
        // 关闭当前存储
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
        
        let fileManager = FileManager.default
        
        // 备份当前存储，以防恢复失败
        let temporaryBackup = storeURL.deletingLastPathComponent().appendingPathComponent("temp_before_restore.sqlite")
        if fileManager.fileExists(atPath: temporaryBackup.path) {
            try fileManager.removeItem(at: temporaryBackup)
        }
        
        if fileManager.fileExists(atPath: storeURL.path) {
            try fileManager.copyItem(at: storeURL, to: temporaryBackup)
        }
        
        do {
            // 删除当前存储
            if fileManager.fileExists(atPath: storeURL.path) {
                try fileManager.removeItem(at: storeURL)
            }
            
            // 解压备份文件到存储位置
            try unzipBackup(from: backupURL, to: storeURL.deletingLastPathComponent())
            
            // 重新加载存储
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: dataStack.persistentStoreOptions
            )
            
            // 恢复成功，删除临时备份
            if fileManager.fileExists(atPath: temporaryBackup.path) {
                try fileManager.removeItem(at: temporaryBackup)
            }
            
            return true
        } catch {
            // 恢复失败，恢复原有存储
            if fileManager.fileExists(atPath: temporaryBackup.path) {
                if fileManager.fileExists(atPath: storeURL.path) {
                    try fileManager.removeItem(at: storeURL)
                }
                try fileManager.copyItem(at: temporaryBackup, to: storeURL)
                try fileManager.removeItem(at: temporaryBackup)
                
                // 重新加载原有存储
                try coordinator.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: storeURL,
                    options: dataStack.persistentStoreOptions
                )
            }
            
            throw error
        }
    }

    /// 从备份文件恢复数据到指定位置
    /// - Parameters:
    ///   - backupURL: 备份文件的URL
    ///   - destinationURL: 目标存储URL
    /// - Throws: 恢复过程中的错误
    public func restoreBackup(at backupURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        
        guard backupURL.pathExtension == "backup" else {
            throw CoreDataError.invalidBackupFile
        }
        
        // 确保备份文件存在
        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw CoreDataError.notFound("备份文件不存在")
        }
        
        // 创建临时目录用于解包
        let tempDirURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
        
        do {
            // 解压备份文件到临时目录
            try unzipBackup(from: backupURL, to: tempDirURL)
            
            // 如果目标文件存在，则先删除
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // 确保目标目录存在
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), 
                                            withIntermediateDirectories: true)
            
            // 将解压的文件复制到目标位置
            let storeName = destinationURL.deletingPathExtension().lastPathComponent
            let storeExtension = destinationURL.pathExtension
            let sourceStoreFiles = try fileManager.contentsOfDirectory(at: tempDirURL, 
                                                                    includingPropertiesForKeys: nil)
            
            for fileURL in sourceStoreFiles {
                let fileName = fileURL.lastPathComponent
                if fileName.hasSuffix(".\(storeExtension)") || 
                   fileName.hasSuffix(".\(storeExtension)-wal") || 
                   fileName.hasSuffix(".\(storeExtension)-shm") {
                    let targetURL = destinationURL.deletingLastPathComponent().appendingPathComponent(fileName)
                    try fileManager.copyItem(at: fileURL, to: targetURL)
                }
            }
            
            // 清理临时目录
            try fileManager.removeItem(at: tempDirURL)
            
        } catch {
            // 清理临时目录
            if fileManager.fileExists(atPath: tempDirURL.path) {
                try? fileManager.removeItem(at: tempDirURL)
            }
            throw CoreDataError.backupRestoreFailed(reason: error.localizedDescription)
        }
    }

    /// 解压备份文件
    /// - Parameters:
    ///   - backupURL: 备份文件URL
    ///   - destination: 目标目录URL
    private func unzipBackup(from backupURL: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", backupURL.path, "-d", destination.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            throw CoreDataError.backupRestoreFailed(reason: "Unzip failed: \(output)")
        }
    }
    
    /// 清理过期缓存
    /// - Returns: 被清理的项目数量
    public func cleanupExpiredCache() async -> Int {
        // 实际实现中需要扫描并清理过期的缓存文件或数据
        // 这里提供一个简单的实现
        let context = dataStack.backgroundContext
        var cleanedCount = 0
        
        await context.perform {
            // 查找过期的缓存记录
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "CacheRecord")
            fetchRequest.predicate = NSPredicate(format: "expirationDate < %@", Date() as NSDate)
            
            do {
                let expiredRecords = try context.fetch(fetchRequest)
                cleanedCount = expiredRecords.count
                
                // 删除过期记录
                for record in expiredRecords {
                    context.delete(record)
                }
                
                // 保存更改
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                print("清理缓存失败: \(error)")
            }
        }
        
        return cleanedCount
    }
    
    /// 获取缓存统计信息
    /// - Returns: 缓存统计信息
    public func getStatistics() async throws -> CacheStatistics {
        let context = dataStack.backgroundContext
        
        return await context.perform {
            // 获取所有缓存记录
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "CacheRecord")
            
            do {
                let allRecords = try context.fetch(fetchRequest)
                
                // 获取命中和未命中数量
                let hits = allRecords.filter { ($0.value(forKey: "isHit") as? Bool) ?? false }.count
                let misses = allRecords.count - hits
                
                return CacheStatistics(hits: hits, misses: misses)
            } catch {
                CoreLogger.error("获取缓存统计失败: \(error.localizedDescription)", category: "Cache")
                return CacheStatistics(hits: 0, misses: 0)
            }
        }
    }
    
    /// 为指定存储创建备份
    /// - Parameter storeURL: 存储的URL
    /// - Throws: 备份过程中的错误
    public func backupStore(at storeURL: URL) throws {
        let fileManager = FileManager.default
        
        // 获取备份目录
        let backupsDir = try backupsDirectory()
        
        // 创建备份文件名 (使用时间戳)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let backupFileName = "\(storeURL.deletingPathExtension().lastPathComponent)_\(timestamp).backup"
        let backupURL = backupsDir.appendingPathComponent(backupFileName)
        
        // 确保存储文件存在
        guard fileManager.fileExists(atPath: storeURL.path) else {
            throw CoreDataError.storeNotFound("文件不存在: \(storeURL.path)")
        }
        
        // 创建临时目录用于打包
        let tempDirURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
        
        do {
            // 复制存储文件及相关文件到临时目录
            let storeDirectory = storeURL.deletingLastPathComponent()
            let storeName = storeURL.deletingPathExtension().lastPathComponent
            
            // 复制主存储文件
            let mainStoreFileURL = storeURL
            if fileManager.fileExists(atPath: mainStoreFileURL.path) {
                try fileManager.copyItem(at: mainStoreFileURL, to: tempDirURL.appendingPathComponent(mainStoreFileURL.lastPathComponent))
            }
            
            // 复制WAL文件
            let walFileURL = storeDirectory.appendingPathComponent("\(storeName).sqlite-wal")
            if fileManager.fileExists(atPath: walFileURL.path) {
                try fileManager.copyItem(at: walFileURL, to: tempDirURL.appendingPathComponent(walFileURL.lastPathComponent))
            }
            
            // 复制SHM文件
            let shmFileURL = storeDirectory.appendingPathComponent("\(storeName).sqlite-shm")
            if fileManager.fileExists(atPath: shmFileURL.path) {
                try fileManager.copyItem(at: shmFileURL, to: tempDirURL.appendingPathComponent(shmFileURL.lastPathComponent))
            }
            
            // 打包临时目录为zip文件
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.arguments = ["-r", backupURL.path, "."]
            process.currentDirectoryURL = tempDirURL
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                throw CoreDataError.backupFailed(NSError(domain: "CoreDataResourceManager", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "创建备份zip文件失败"]))
            }
            
            // 清理临时目录
            try fileManager.removeItem(at: tempDirURL)
            
        } catch {
            // 清理临时目录
            if fileManager.fileExists(atPath: tempDirURL.path) {
                try? fileManager.removeItem(at: tempDirURL)
            }
            throw CoreDataError.backupFailed(error)
        }
    }
} 