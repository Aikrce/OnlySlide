import Foundation
import os.log

/// 组合缓存管理器
final class CompositeCacheManager: UnifiedCacheManager {
    // MARK: - Properties
    private let logger = os.Logger(subsystem: "com.onlyslide", category: "compositecache")
    private let memoryCache: MemoryCacheManager
    private let diskCache: DiskCacheManager
    
    // MARK: - Initialization
    init() {
        self.memoryCache = MemoryCacheManager()
        self.diskCache = DiskCacheManager()
        logger.info("组合缓存管理器初始化完成")
    }
    
    // MARK: - UnifiedCacheManager (同步方法)
    
    public func set<T: Codable>(_ value: T, forKey key: String) throws {
        // 同时写入内存和磁盘缓存
        try memoryCache.set(value, forKey: key)
        try diskCache.set(value, forKey: key)
        logger.debug("同步缓存项: \(key)")
    }
    
    public func get<T: Codable>(forKey key: String) throws -> T? {
        // 先尝试从内存缓存获取
        if let data = try memoryCache.get(forKey: key) as T? {
            logger.debug("从内存缓存获取: \(key)")
            return data
        }
        
        // 如果内存中没有，尝试从磁盘缓存获取
        if let data = try diskCache.get(forKey: key) as T? {
            // 找到后写入内存缓存
            try memoryCache.set(data, forKey: key)
            logger.debug("从磁盘缓存获取并更新内存缓存: \(key)")
            return data
        }
        
        logger.debug("缓存未命中: \(key)")
        return nil
    }
    
    public func remove(forKey key: String) {
        // 同时从内存和磁盘缓存中移除
        memoryCache.remove(forKey: key)
        diskCache.remove(forKey: key)
        logger.debug("同步移除缓存项: \(key)")
    }
    
    public func clear() throws {
        // 清除所有缓存
        try memoryCache.clear()
        try diskCache.clear()
        logger.info("同步清空所有缓存")
    }
    
    // MARK: - UnifiedCacheManager (异步方法)
    
    public func cache<T: Codable>(_ data: T, forKey key: String, expirationInterval: TimeInterval? = nil) async throws {
        // 同时写入内存和磁盘缓存
        try await memoryCache.cache(data, forKey: key, expirationInterval: expirationInterval)
        try await diskCache.cache(data, forKey: key, expirationInterval: expirationInterval)
        logger.debug("异步缓存项: \(key)")
    }
    
    public func get<T: Codable>(forKey key: String) async throws -> T? {
        // 先尝试从内存缓存获取
        if let data = try await memoryCache.get(forKey: key) as T? {
            logger.debug("异步从内存缓存获取: \(key)")
            return data
        }
        
        // 如果内存中没有，尝试从磁盘缓存获取
        if let data = try await diskCache.get(forKey: key) as T? {
            // 找到后写入内存缓存
            try await memoryCache.cache(data, forKey: key)
            logger.debug("异步从磁盘缓存获取并更新内存缓存: \(key)")
            return data
        }
        
        logger.debug("异步缓存未命中: \(key)")
        return nil
    }
    
    public func remove(forKey key: String) async {
        // 同时从内存和磁盘缓存中移除
        await memoryCache.remove(forKey: key)
        await diskCache.remove(forKey: key)
        logger.debug("异步移除缓存项: \(key)")
    }
    
    public func clearAll() async {
        // 清除所有缓存
        await memoryCache.clearAll()
        await diskCache.clearAll()
        logger.info("异步清空所有缓存")
    }
    
    public func clearExpired() async {
        // 清除过期缓存
        await memoryCache.clearExpired()
        await diskCache.clearExpired()
        logger.info("清理过期缓存完成")
    }
}

// MARK: - Factory
extension CompositeCacheManager {
    /// 创建默认的缓存管理器
    static func createDefault() -> UnifiedCacheManager {
        return CompositeCacheManager()
    }
} 