import Foundation
import os.log

/// 磁盘缓存管理器实现
public class DiskCacheManager: UnifiedCacheManager {
    // MARK: - Properties
    private let logger = os.Logger(subsystem: "com.onlyslide", category: "diskcache")
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let metadataFile: URL
    private let ioQueue = DispatchQueue(label: "com.onlyslide.diskcache.io", qos: .background)
    private var metadata: [String: Date] = [:]
    
    // MARK: - Initialization
    
    /// 初始化磁盘缓存管理器
    /// - Parameter directory: 自定义缓存目录名称。默认为 "OnlySlideCache"
    public init(directory: String = "OnlySlideCache") {
        do {
            // 获取应用支持目录
            let applicationSupport = try fileManager.url(for: .applicationSupportDirectory,
                                                        in: .userDomainMask,
                                                        appropriateFor: nil,
                                                        create: true)
            
            // 创建缓存目录
            cacheDirectory = applicationSupport.appendingPathComponent(directory)
            metadataFile = cacheDirectory.appendingPathComponent("metadata.json")
            
            // 确保缓存目录存在
            if !fileManager.fileExists(atPath: cacheDirectory.path) {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            }
            
            // 加载元数据
            loadMetadata()
            
            logger.info("磁盘缓存管理器初始化于: \(cacheDirectory.path)")
            
            // 启动定期清理过期缓存的计时器
            setupExpirationTimer()
        } catch {
            logger.error("初始化磁盘缓存失败: \(error.localizedDescription)")
            // 使用临时目录作为备选
            cacheDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(directory)
            metadataFile = cacheDirectory.appendingPathComponent("metadata.json")
        }
    }
    
    // MARK: - UnifiedCacheManager (同步方法)
    
    public func set<T: Codable>(_ value: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        let fileURL = cacheURL(for: key)
        
        do {
            let data = try encoder.encode(value)
            try data.write(to: fileURL)
            logger.debug("已将缓存项写入磁盘: \(key)")
        } catch {
            logger.error("写入缓存项到磁盘失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func get<T: Codable>(forKey key: String) throws -> T? {
        let fileURL = cacheURL(for: key)
        
        // 检查文件是否存在
        guard fileManager.fileExists(atPath: fileURL.path) else {
            logger.debug("缓存中未找到项: \(key)")
            return nil
        }
        
        // 检查是否过期
        if isExpired(key: key) {
            remove(forKey: key)
            logger.debug("缓存项已过期: \(key)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let value = try decoder.decode(T.self, from: data)
            logger.debug("从磁盘读取缓存项: \(key)")
            return value
        } catch {
            logger.error("从磁盘读取或解码缓存项失败: \(error.localizedDescription)")
            remove(forKey: key) // 移除无效数据
            throw error
        }
    }
    
    public func remove(forKey key: String) {
        let fileURL = cacheURL(for: key)
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            
            // 更新元数据
            ioQueue.sync {
                metadata.removeValue(forKey: key)
                saveMetadata()
            }
            
            logger.debug("已移除缓存项: \(key)")
        } catch {
            logger.error("移除缓存项失败: \(error.localizedDescription)")
        }
    }
    
    public func clear() throws {
        do {
            // 获取所有文件
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            
            // 删除所有文件
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
            
            // 清空元数据
            ioQueue.sync {
                metadata.removeAll()
                saveMetadata()
            }
            
            logger.info("已清空磁盘缓存")
        } catch {
            logger.error("清空磁盘缓存失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - UnifiedCacheManager (异步方法)
    
    public func cache<T: Codable>(_ data: T, forKey key: String, expirationInterval: TimeInterval? = nil) async throws {
        try set(data, forKey: key)
        
        // 设置过期时间
        if let interval = expirationInterval {
            let expirationDate = Date().addingTimeInterval(interval)
            ioQueue.sync {
                metadata[key] = expirationDate
                saveMetadata()
            }
            logger.debug("缓存项设置为过期: \(key) 过期时间: \(expirationDate)")
        }
    }
    
    public func clearExpired() async {
        var keysToRemove: [String] = []
        
        ioQueue.sync {
            let now = Date()
            for (key, expirationDate) in metadata {
                if expirationDate <= now {
                    keysToRemove.append(key)
                }
            }
        }
        
        for key in keysToRemove {
            remove(forKey: key)
        }
        
        if !keysToRemove.isEmpty {
            logger.info("已清除 \(keysToRemove.count) 个过期缓存项")
        }
    }
    
    // MARK: - 辅助方法
    
    private func cacheURL(for key: String) -> URL {
        let hashedKey = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return cacheDirectory.appendingPathComponent(hashedKey)
    }
    
    private func isExpired(key: String) -> Bool {
        var expired = false
        ioQueue.sync {
            if let expirationDate = metadata[key], expirationDate <= Date() {
                expired = true
            }
        }
        return expired
    }
    
    private func loadMetadata() {
        ioQueue.sync {
            guard fileManager.fileExists(atPath: metadataFile.path) else {
                metadata = [:]
                return
            }
            
            do {
                let data = try Data(contentsOf: metadataFile)
                let decoder = JSONDecoder()
                metadata = try decoder.decode([String: Date].self, from: data)
            } catch {
                logger.error("加载缓存元数据失败: \(error.localizedDescription)")
                metadata = [:]
            }
        }
    }
    
    private func saveMetadata() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(metadata)
            try data.write(to: metadataFile)
        } catch {
            logger.error("保存缓存元数据失败: \(error.localizedDescription)")
        }
    }
    
    private func setupExpirationTimer() {
        // 每小时清理一次过期缓存
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task {
                await self?.clearExpired()
            }
        }
    }
} 