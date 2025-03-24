import Foundation
import os.log

/// 缓存管理器协议
public protocol CacheManager {
    func set<T: Codable>(_ value: T, forKey key: String) throws
    func get<T: Codable>(forKey key: String) throws -> T?
    func remove(forKey key: String)
    func clear() throws
}

/// 缓存管理器实现
public class DefaultCacheManager: CacheManager {
    // MARK: - Properties
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let logger = Logger(label: "com.onlyslide.cache")
    
    // MARK: - Initialization
    public init() {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("OnlySlideCache", isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: cacheDirectory.path) {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            }
        } catch {
            logger.error("Failed to create cache directory: \(error)")
        }
    }
    
    // MARK: - Cache Operations
    public func set<T: Codable>(_ value: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try data.write(to: fileURL, options: .atomic)
    }
    
    public func get<T: Codable>(forKey key: String) throws -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    public func remove(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            logger.error("Failed to remove cache item: \(error)")
        }
    }
    
    public func clear() throws {
        if fileManager.fileExists(atPath: cacheDirectory.path) {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }
}

// 便于访问的扩展
public extension CacheManager {
    // 简化访问
    static func `default`() -> CacheManager {
        return DefaultCacheManager()
    }
} 