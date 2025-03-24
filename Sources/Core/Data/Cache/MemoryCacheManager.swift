import Foundation
import os.log

/// 内存缓存管理器实现
public class MemoryCacheManager: UnifiedCacheManager {
    // MARK: - Properties
    private let logger = os.Logger(subsystem: "com.onlyslide", category: "memorycache")
    private let cache = NSCache<NSString, NSData>()
    private var expirations: [String: Date] = [:]
    private let expirationQueue = DispatchQueue(label: "com.onlyslide.memorycache.expiration")
    
    // MARK: - Initialization
    public init() {
        logger.info("初始化内存缓存管理器")
        
        // 设置默认限制
        cache.countLimit = 100 // 最多100个对象
        cache.totalCostLimit = 10 * 1024 * 1024 // 最多10MB
        
        // 启动定期清理过期缓存的计时器
        setupExpirationTimer()
    }
    
    // MARK: - UnifiedCacheManager (同步方法)
    
    public func set<T: Codable>(_ value: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(value)
            cache.setObject(data as NSData, forKey: key as NSString)
            logger.debug("缓存项已设置: \(key)")
        } catch {
            logger.error("编码缓存项失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func get<T: Codable>(forKey key: String) throws -> T? {
        guard let data = cache.object(forKey: key as NSString) as Data? else {
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
            let decoder = JSONDecoder()
            let value = try decoder.decode(T.self, from: data)
            logger.debug("从缓存获取项: \(key)")
            return value
        } catch {
            logger.error("解码缓存项失败: \(error.localizedDescription)")
            remove(forKey: key) // 移除无效数据
            throw error
        }
    }
    
    public func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
        expirationQueue.sync {
            expirations.removeValue(forKey: key)
        }
        logger.debug("缓存项已移除: \(key)")
    }
    
    public func clear() throws {
        cache.removeAllObjects()
        expirationQueue.sync {
            expirations.removeAll()
        }
        logger.info("缓存已清空")
    }
    
    // MARK: - UnifiedCacheManager (异步方法)
    
    public func cache<T: Codable>(_ data: T, forKey key: String, expirationInterval: TimeInterval? = nil) async throws {
        try set(data, forKey: key)
        
        // 设置过期时间
        if let interval = expirationInterval {
            let expirationDate = Date().addingTimeInterval(interval)
            expirationQueue.sync {
                expirations[key] = expirationDate
            }
            logger.debug("缓存项设置为过期: \(key) 过期时间: \(expirationDate)")
        }
    }
    
    public func clearExpired() async {
        var keysToRemove: [String] = []
        
        expirationQueue.sync {
            let now = Date()
            for (key, expirationDate) in expirations {
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
    
    private func isExpired(key: String) -> Bool {
        var expired = false
        expirationQueue.sync {
            if let expirationDate = expirations[key], expirationDate <= Date() {
                expired = true
            }
        }
        return expired
    }
    
    private func setupExpirationTimer() {
        // 每分钟清理一次过期缓存
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task {
                await self?.clearExpired()
            }
        }
    }
} 