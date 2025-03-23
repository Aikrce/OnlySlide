import Foundation

/// 组合缓存管理器
final class CompositeCacheManager: CacheManager {
    // MARK: - Properties
    private let memoryCache: MemoryCacheManager
    private let diskCache: DiskCacheManager
    
    // MARK: - Initialization
    init() throws {
        self.memoryCache = MemoryCacheManager()
        self.diskCache = try DiskCacheManager()
    }
    
    // MARK: - CacheManager
    func cache<T: Codable>(_ data: T, forKey key: String, expirationInterval: TimeInterval? = nil) async throws {
        // 同时写入内存和磁盘缓存
        try await memoryCache.cache(data, forKey: key, expirationInterval: expirationInterval)
        try await diskCache.cache(data, forKey: key, expirationInterval: expirationInterval)
    }
    
    func get<T: Codable>(forKey key: String) async throws -> T? {
        // 先尝试从内存缓存获取
        if let data = try await memoryCache.get(forKey: key) as T? {
            return data
        }
        
        // 如果内存中没有，尝试从磁盘缓存获取
        if let data = try await diskCache.get(forKey: key) as T? {
            // 找到后写入内存缓存
            try await memoryCache.cache(data, forKey: key)
            return data
        }
        
        return nil
    }
    
    func remove(forKey key: String) async {
        // 同时从内存和磁盘缓存中移除
        await memoryCache.remove(forKey: key)
        await diskCache.remove(forKey: key)
    }
    
    func clearAll() async {
        // 清除所有缓存
        await memoryCache.clearAll()
        await diskCache.clearAll()
    }
    
    func clearExpired() async {
        // 清除过期缓存
        await memoryCache.clearExpired()
        await diskCache.clearExpired()
    }
}

// MARK: - Factory
extension CompositeCacheManager {
    /// 创建默认的缓存管理器
    static func createDefault() throws -> CacheManager {
        return try CompositeCacheManager()
    }
} 