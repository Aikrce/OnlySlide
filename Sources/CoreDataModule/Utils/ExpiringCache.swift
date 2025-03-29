import Foundation

/// 支持过期机制的缓存类
@MainActor public final class ExpiringCache<Key: Hashable & Sendable, Value: AnyObject>: @unchecked Sendable {
    /// 缓存条目
    private final class CacheEntry: @unchecked Sendable {
        let value: AnyObject
        let timestamp: Date
        let cost: Int
        
        init(value: AnyObject, timestamp: Date, cost: Int = 1) {
            self.value = value
            self.timestamp = timestamp
            self.cost = cost
        }
    }
    
    /// 包装Key以用于NSCache
    private final class WrappedKey: NSObject, @unchecked Sendable {
        let key: Key
        
        init(_ key: Key) {
            self.key = key
            super.init()
        }
        
        override var hash: Int { return key.hashValue }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let value = object as? WrappedKey else { return false }
            return value.key == key
        }
    }
    
    /// 底层缓存存储
    private let cache = NSCache<WrappedKey, CacheEntry>()
    
    /// 过期间隔（秒）
    private let expirationInterval: TimeInterval
    
    /// 最后访问日期记录
    private var lastAccessDates = [Key: Date]()
    
    /// 线程安全锁
    private let lock = NSLock()
    
    /// 是否有活跃的清理计时器
    private var hasActiveCleanupTimer: Bool = false
    
    /// 缓存命中计数
    private var _hitCount: Int = 0
    
    /// 缓存未命中计数
    private var _missCount: Int = 0
    
    /// 获取缓存命中次数
    public var hitCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _hitCount
    }
    
    /// 获取缓存未命中次数
    public var missCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _missCount
    }
    
    /// 初始化缓存
    /// - Parameters:
    ///   - name: 缓存名称
    ///   - countLimit: 最大项数
    ///   - totalCostLimit: 总成本限制
    ///   - expirationInterval: 过期时间（秒）
    public init(
        name: String = "ExpiringCache",
        countLimit: Int = 1000,
        totalCostLimit: Int = 50 * 1024 * 1024,
        expirationInterval: TimeInterval = 3600
    ) {
        self.expirationInterval = expirationInterval
        
        // 配置缓存
        cache.name = name
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
        
        // 启动定期清理
        scheduleCleanup()
    }
    
    deinit {
        // 在 deinit 中不再直接访问 Timer
        // 注意：在 deinit 中不能调用 actor 隔离的方法，所以我们只更新标志
        hasActiveCleanupTimer = false
        // 任何需要停止的 Timer 应该在其他地方停止，例如在应用程序退出前
    }
    
    /// 获取缓存项
    /// - Parameter key: 缓存键
    /// - Returns: 缓存值（如果存在且未过期）
    public func object(forKey key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        
        let wrappedKey = WrappedKey(key)
        guard let entry = cache.object(forKey: wrappedKey) else {
            // 记录缓存未命中
            _missCount += 1
            return nil
        }
        
        // 检查是否过期
        let now = Date()
        if now.timeIntervalSince(entry.timestamp) > expirationInterval {
            // 过期了，移除并记录未命中
            cache.removeObject(forKey: wrappedKey)
            lastAccessDates[key] = nil
            _missCount += 1
            return nil
        }
        
        // 更新访问时间并记录命中
        lastAccessDates[key] = now
        _hitCount += 1
        return entry.value as? Value
    }
    
    /// 设置缓存项
    /// - Parameters:
    ///   - value: 缓存值
    ///   - key: 缓存键
    ///   - cost: 成本（默认为1）
    public func setObject(_ value: Value, forKey key: Key, cost: Int = 1) {
        lock.lock()
        defer { lock.unlock() }
        
        let wrappedKey = WrappedKey(key)
        let entry = CacheEntry(value: value, timestamp: Date(), cost: cost)
        cache.setObject(entry, forKey: wrappedKey, cost: cost)
        lastAccessDates[key] = Date()
    }
    
    /// 移除缓存项
    /// - Parameter key: 缓存键
    public func removeObject(forKey key: Key) {
        lock.lock()
        defer { lock.unlock() }
        
        let wrappedKey = WrappedKey(key)
        cache.removeObject(forKey: wrappedKey)
        lastAccessDates[key] = nil
    }
    
    /// 移除所有缓存项
    public func removeAllObjects() {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAllObjects()
        lastAccessDates.removeAll()
        // 重置统计
        _hitCount = 0
        _missCount = 0
    }
    
    /// 移除过期对象
    public func removeExpiredObjects() {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        for (key, lastAccess) in lastAccessDates {
            if now.timeIntervalSince(lastAccess) > expirationInterval {
                let wrappedKey = WrappedKey(key)
                cache.removeObject(forKey: wrappedKey)
                lastAccessDates[key] = nil
            }
        }
    }
    
    /// 设置定期清理
    private func scheduleCleanup() {
        stopCleanup() // 先停止已有的计时器
        
        Timer.scheduledTimer(withTimeInterval: expirationInterval / 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.removeExpiredObjects()
            }
        }
        hasActiveCleanupTimer = true
    }
    
    /// 停止定期清理
    private func stopCleanup() {
        // 不直接操作 Timer
        hasActiveCleanupTimer = false
    }
    
    /// 重置缓存统计
    public func resetStatistics() {
        lock.lock()
        defer { lock.unlock() }
        
        _hitCount = 0
        _missCount = 0
    }
    
    /// 获取统计信息
    public var statistics: (count: Int, keys: [Key], hitRate: Double) {
        lock.lock()
        defer { lock.unlock() }
        
        let totalAccesses = _hitCount + _missCount
        let hitRate = totalAccesses > 0 ? Double(_hitCount) / Double(totalAccesses) : 0.0
        
        return (lastAccessDates.count, Array(lastAccessDates.keys), hitRate)
    }
} 