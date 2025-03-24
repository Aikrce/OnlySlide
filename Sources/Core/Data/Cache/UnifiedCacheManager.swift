import Foundation
import os.log

/// 统一的缓存管理器接口
/// 整合了同步和异步缓存操作
public protocol UnifiedCacheManager {
    // 同步操作 (来自原 CacheManager)
    func set<T: Codable>(_ value: T, forKey key: String) throws
    func get<T: Codable>(forKey key: String) throws -> T?
    func remove(forKey key: String)
    func clear() throws
    
    // 异步操作 (来自 CompositeCacheManager)
    func cache<T: Codable>(_ data: T, forKey key: String, expirationInterval: TimeInterval?) async throws
    func get<T: Codable>(forKey key: String) async throws -> T?
    func remove(forKey key: String) async
    func clearAll() async
    func clearExpired() async
}

// 默认实现，简化适配过程
public extension UnifiedCacheManager {
    // 提供异步方法的默认实现，桥接到同步方法
    func cache<T: Codable>(_ data: T, forKey key: String, expirationInterval: TimeInterval? = nil) async throws {
        try set(data, forKey: key)
    }
    
    func get<T: Codable>(forKey key: String) async throws -> T? {
        return try get(forKey: key)
    }
    
    func remove(forKey key: String) async {
        remove(forKey: key)
    }
    
    func clearAll() async {
        try? clear()
    }
    
    func clearExpired() async {
        // 默认实现不处理过期项，子类可以覆盖
    }
    
    // 提供同步方法的默认实现，桥接到异步方法
    func set<T: Codable>(_ value: T, forKey key: String) throws {
        do {
            try Task.detached {
                try await self.cache(value, forKey: key)
            }.value
        } catch {
            throw error
        }
    }
    
    func clear() throws {
        do {
            try Task.detached {
                await self.clearAll()
            }.value
        } catch {
            throw error
        }
    }
}

/// 缓存项
struct CacheItem<T: Codable> {
    let value: T
    let expiration: Date?
    
    var isExpired: Bool {
        guard let expiration = expiration else { return false }
        return Date() > expiration
    }
} 