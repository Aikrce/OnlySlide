import Foundation
import os.log

/// 文档缓存管理器
/// 提供内存缓存以减少数据库访问，提高性能
final class DocumentCache {
    // MARK: - Properties
    
    /// 单例实例
    static let shared = DocumentCache()
    
    private let logger = Logger(label: "com.onlyslide.cache.document")
    
    /// 文档缓存，使用文档ID作为键
    private var cache: [UUID: CachedDocument] = [:]
    
    /// 标签文档映射缓存，使用标签作为键，文档ID列表作为值
    private var tagCache: [String: Set<UUID>] = [:]
    
    /// 读写锁，确保线程安全
    private let cacheLock = NSRecursiveLock()
    
    /// 缓存配置
    private let config: CacheConfig
    
    // MARK: - Initialization
    
    init(config: CacheConfig = CacheConfig()) {
        self.config = config
        
        // 设置缓存清理定时器
        if config.enableAutomaticPurge {
            setupPurgeTimer()
        }
    }
    
    // MARK: - Cache Operations
    
    /// 获取缓存的文档
    /// - Parameter id: 文档ID
    /// - Returns: 缓存的文档，如果不存在则返回nil
    func getDocument(id: UUID) -> Document? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        if let cachedDocument = cache[id], !cachedDocument.isExpired() {
            logger.debug("缓存命中: 文档 \(id)")
            return cachedDocument.document
        }
        
        logger.debug("缓存未命中: 文档 \(id)")
        return nil
    }
    
    /// 获取多个缓存的文档
    /// - Parameter ids: 文档ID列表
    /// - Returns: 缓存的文档列表，不存在的文档将被排除
    func getDocuments(ids: [UUID]) -> [Document] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        var documents: [Document] = []
        var missCount = 0
        
        for id in ids {
            if let cachedDocument = cache[id], !cachedDocument.isExpired() {
                documents.append(cachedDocument.document)
            } else {
                missCount += 1
            }
        }
        
        logger.debug("批量缓存查询: \(ids.count - missCount)命中, \(missCount)未命中")
        return documents
    }
    
    /// 获取包含指定标签的文档ID列表
    /// - Parameter tag: 标签
    /// - Returns: 包含指定标签的文档ID列表
    func getDocumentIds(forTag tag: String) -> Set<UUID> {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        return tagCache[tag] ?? []
    }
    
    /// 缓存文档
    /// - Parameter document: 要缓存的文档
    func cacheDocument(_ document: Document) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        cache[document.id] = CachedDocument(document: document)
        logger.debug("已缓存文档: \(document.id)")
        
        // 更新标签缓存
        if let tags = document.tags {
            for tag in tags {
                var documentIds = tagCache[tag] ?? Set<UUID>()
                documentIds.insert(document.id)
                tagCache[tag] = documentIds
            }
        }
    }
    
    /// 批量缓存文档
    /// - Parameter documents: 要缓存的文档列表
    func cacheDocuments(_ documents: [Document]) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        for document in documents {
            cache[document.id] = CachedDocument(document: document)
            
            // 更新标签缓存
            if let tags = document.tags {
                for tag in tags {
                    var documentIds = tagCache[tag] ?? Set<UUID>()
                    documentIds.insert(document.id)
                    tagCache[tag] = documentIds
                }
            }
        }
        
        logger.debug("已批量缓存 \(documents.count) 个文档")
    }
    
    /// 移除缓存的文档
    /// - Parameter id: 要移除的文档ID
    func invalidateDocument(id: UUID) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        if let cachedDocument = cache[id], let tags = cachedDocument.document.tags {
            // 更新标签缓存
            for tag in tags {
                var documentIds = tagCache[tag] ?? Set<UUID>()
                documentIds.remove(id)
                if documentIds.isEmpty {
                    tagCache.removeValue(forKey: tag)
                } else {
                    tagCache[tag] = documentIds
                }
            }
        }
        
        cache.removeValue(forKey: id)
        logger.debug("已移除缓存: 文档 \(id)")
    }
    
    /// 批量移除缓存的文档
    /// - Parameter ids: 要移除的文档ID列表
    func invalidateDocuments(ids: [UUID]) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        for id in ids {
            if let cachedDocument = cache[id], let tags = cachedDocument.document.tags {
                // 更新标签缓存
                for tag in tags {
                    var documentIds = tagCache[tag] ?? Set<UUID>()
                    documentIds.remove(id)
                    if documentIds.isEmpty {
                        tagCache.removeValue(forKey: tag)
                    } else {
                        tagCache[tag] = documentIds
                    }
                }
            }
            
            cache.removeValue(forKey: id)
        }
        
        logger.debug("已批量移除 \(ids.count) 个文档的缓存")
    }
    
    /// 清空所有缓存
    func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        cache.removeAll()
        tagCache.removeAll()
        logger.info("已清空文档缓存")
    }
    
    /// 清除过期缓存
    func purgeExpiredCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        let expiredCount = cache.values.filter { $0.isExpired() }.count
        
        // 移除过期项
        cache = cache.filter { !$1.isExpired() }
        
        // 重建标签缓存
        rebuildTagCache()
        
        logger.info("已清除 \(expiredCount) 个过期的缓存项")
    }
    
    // MARK: - Private Methods
    
    /// 重建标签缓存
    private func rebuildTagCache() {
        tagCache.removeAll()
        
        for (id, cachedDocument) in cache {
            if let tags = cachedDocument.document.tags {
                for tag in tags {
                    var documentIds = tagCache[tag] ?? Set<UUID>()
                    documentIds.insert(id)
                    tagCache[tag] = documentIds
                }
            }
        }
    }
    
    /// 设置缓存清理定时器
    private func setupPurgeTimer() {
        DispatchQueue.global(qos: .background).async {
            let timer = Timer.scheduledTimer(withTimeInterval: self.config.purgeInterval, repeats: true) { [weak self] _ in
                self?.purgeExpiredCache()
            }
            RunLoop.current.add(timer, forMode: .common)
            RunLoop.current.run()
        }
    }
}

// MARK: - Supporting Types

/// 缓存的文档
fileprivate struct CachedDocument {
    /// 文档
    let document: Document
    
    /// 缓存时间
    let cachedAt: Date
    
    /// 过期时间（秒）
    let expiresIn: TimeInterval
    
    init(document: Document, expiresIn: TimeInterval = 300) {
        self.document = document
        self.cachedAt = Date()
        self.expiresIn = expiresIn
    }
    
    /// 检查缓存是否已过期
    func isExpired() -> Bool {
        return Date().timeIntervalSince(cachedAt) > expiresIn
    }
}

/// 缓存配置
struct CacheConfig {
    /// 是否启用自动清理
    let enableAutomaticPurge: Bool
    
    /// 清理间隔（秒）
    let purgeInterval: TimeInterval
    
    /// 默认缓存过期时间（秒）
    let defaultExpirationTime: TimeInterval
    
    /// 最大缓存项数
    let maxCacheItems: Int
    
    init(
        enableAutomaticPurge: Bool = true,
        purgeInterval: TimeInterval = 300,
        defaultExpirationTime: TimeInterval = 300,
        maxCacheItems: Int = 1000
    ) {
        self.enableAutomaticPurge = enableAutomaticPurge
        self.purgeInterval = purgeInterval
        self.defaultExpirationTime = defaultExpirationTime
        self.maxCacheItems = maxCacheItems
    }
} 