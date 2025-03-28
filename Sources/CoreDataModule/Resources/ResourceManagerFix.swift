@preconcurrency import Foundation
@preconcurrency import CoreData
import os
import Combine

/// 资源管理器修复扩展
extension CoreDataResourceManager {
    
    /// 安全获取可能为nil的URL数组
    /// 解决for-in循环要求对象符合Sequence问题
    func safelyGetURLs(from bundle: Bundle, withExtension ext: String, subdirectory: String? = nil) -> [URL] {
        guard let urls = try? bundle.urls(forResourcesWithExtension: ext, subdirectory: subdirectory) else {
            return []
        }
        return urls
    }
    
    /// 安全的缓存访问方法
    /// 解决inout参数可能设置为其他类型值的问题
    func setCachedValueSafely<T>(_ value: T, in cache: inout [String: Any], forKey key: String) {
        cache[key] = value
    }
    
    /// 安全转换缓存的值
    /// 解决从NSManagedObjectModel?转到[NSManagedObjectModel]的类型转换问题
    func safelyGetCachedModels(from cache: [String: Any], forKey key: String) -> [NSManagedObjectModel]? {
        if let models = cache[key] as? [NSManagedObjectModel] {
            return models
        }
        return nil
    }
    
    /// 安全获取单个模型
    func safelyGetCachedModel(from cache: [String: Any], forKey key: String) -> NSManagedObjectModel? {
        return cache[key] as? NSManagedObjectModel
    }
    
    /// 实现ModelVersion的Hashable协议
    /// 解决使用Set<ModelVersion>时需要ModelVersion遵循Hashable的问题
    func makeUniqueVersions(_ versions: [ModelVersion]) -> [ModelVersion] {
        var uniqueVersions: [ModelVersion] = []
        
        // 手动去重
        for version in versions {
            if !uniqueVersions.contains(where: { $0.identifier == version.identifier }) {
                uniqueVersions.append(version)
            }
        }
        
        return uniqueVersions
    }
}

/// 为ModelVersion添加Hashable一致性
extension ModelVersion: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(major)
        hasher.combine(minor)
        hasher.combine(patch)
        hasher.combine(identifier)
    }
}

/// 安全的异步预加载
extension CoreDataResourceManager {
    /// 安全的异步预加载模型
    public func safePreloadModels() async {
        // 预加载基本模型资源
        let urls = getAllModelURLsSync()
        os.Logger.CoreData.info("预加载了 \(urls.count) 个模型URL")
        
        // 预加载合并对象模型
        let _ = await mergedObjectModel()
        
        // 预加载所有可用的模型版本
        let models = await allModels()
        os.Logger.CoreData.info("预加载了 \(models.count) 个模型版本")
    }
}

/// 资源提供协议实现
extension CoreDataResourceManager: ResourceProviding {
    /// 合并的对象模型
    public func mergedObjectModel() async -> NSManagedObjectModel? {
        // 如果启用了缓存，先检查缓存
        if cachingEnabled, let cachedModel = getCachedValue(from: modelCache, forKey: "merged") as? NSManagedObjectModel {
            return cachedModel
        }
        
        // 获取所有模型
        let models = allModelsSync()
        
        // 创建合并模型
        let mergedModel = NSManagedObjectModel(byMerging: models) ?? NSManagedObjectModel()
        
        // 如果启用了缓存，保存到缓存
        if cachingEnabled {
            setCachedValue(mergedModel, in: &modelCache, forKey: "merged")
        }
        
        return mergedModel
    }
    
    /// 所有可用的模型
    public func allModels() async -> [NSManagedObjectModel] {
        return allModelsSync()
    }
    
    /// 同步获取所有模型
    private func allModelsSync() -> [NSManagedObjectModel] {
        let urls = getAllModelURLsSync()
        return urls.compactMap { NSManagedObjectModel(contentsOf: $0) }
    }
    
    /// 同步获取所有模型URL
    private func getAllModelURLsSync() -> [URL] {
        var urls: [URL] = []
        
        for bundle in searchBundles {
            // 查找.momd目录
            guard let momdURLs = try? bundle.urls(forResourcesWithExtension: "momd", subdirectory: nil) else {
                continue
            }
            
            for momdURL in momdURLs {
                // 查找.mom文件
                if let momURLs = try? bundle.urls(forResourcesWithExtension: "mom", subdirectory: momdURL.lastPathComponent) {
                    urls.append(contentsOf: momURLs)
                }
            }
        }
        
        return urls
    }
    
    /// 搜索包
    @MainActor public var searchBundles: [Bundle] {
        return [Bundle.main]
    }
}

/// 模型版本协议
public protocol ModelVersionType: Sendable, Hashable, CaseIterable, RawRepresentable where RawValue == String {
    /// 获取最新版本
    static var latest: Self { get }
    
    /// 获取当前版本
    static var current: Self { get }
    
    /// 检查是否为最新版本
    var isLatest: Bool { get }
    
    /// 获取下一个版本（如果有）
    var next: Self? { get }
    
    /// 获取上一个版本（如果有）
    var previous: Self? { get }
    
    /// 获取模型对应的URL
    func modelURL() -> URL?
}

/// 安全资源管理器协议
public protocol SafeResourceManager: Sendable {
    /// 获取资源
    func getResource<T: Sendable>(name: String, type: T.Type) async -> T?
    
    /// 加载模型
    func loadModel(version: any ModelVersionType) async -> NSManagedObjectModel?
    
    /// 获取所有模型URL
    func getAllModelURLs() async -> [URL]
    
    /// 获取所有迁移路径
    func getMigrationPaths(from source: any ModelVersionType, to destination: any ModelVersionType) async -> [any ModelVersionType]
}

/// 改进的资源管理器
public actor ResourceManagerFix: SafeResourceManager {
    /// 共享实例
    public static let shared = ResourceManagerFix()
    
    /// 资源缓存
    private var resourceCache: [String: Any] = [:]
    
    /// 模型缓存
    private var modelCache: [String: NSManagedObjectModel] = [:]
    
    /// 获取资源
    public func getResource<T: Sendable>(name: String, type: T.Type) async -> T? {
        // 检查缓存
        if let cachedResource = resourceCache[name] as? T {
            return cachedResource
        }
        
        // 加载资源
        guard let resource = await loadResource(name: name, type: type) else {
            return nil
        }
        
        // 缓存并返回
        resourceCache[name] = resource
        return resource
    }
    
    /// 加载模型
    public func loadModel(version: any ModelVersionType) async -> NSManagedObjectModel? {
        let versionKey = version.rawValue
        
        // 检查缓存
        if let cachedModel = await modelCache[versionKey] {
            return cachedModel
        }
        
        // 加载模型
        guard let modelURL = version.modelURL() else {
            return nil
        }
        
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            return nil
        }
        
        // 缓存并返回
        modelCache[versionKey] = model
        return model
    }
    
    /// 获取所有模型URL
    public func getAllModelURLs() async -> [URL] {
        let bundle = Bundle.main
        guard let modelDirectoryURLs = bundle.urls(forResourcesWithExtension: "momd", subdirectory: nil) else {
            return []
        }
        
        var modelURLs: [URL] = []
        
        for directoryURL in modelDirectoryURLs {
            if let versionedModelURLs = bundle.urls(forResourcesWithExtension: "mom", subdirectory: directoryURL.lastPathComponent) {
                modelURLs.append(contentsOf: versionedModelURLs)
            }
        }
        
        return modelURLs
    }
    
    /// 获取迁移路径
    public func getMigrationPaths(from source: any ModelVersionType, to destination: any ModelVersionType) async -> [any ModelVersionType] {
        // 如果源和目标相同，返回空路径
        if source.rawValue == destination.rawValue {
            return []
        }
        
        // 获取所有可能的版本
        let sourceType = type(of: source)
        guard let allVersions = sourceType.allCases as? [any ModelVersionType] else {
            return []
        }
        
        // 查找源和目标的索引
        guard let sourceIndex = allVersions.firstIndex(where: { $0.rawValue == source.rawValue }),
              let destinationIndex = allVersions.firstIndex(where: { $0.rawValue == destination.rawValue }) else {
            return []
        }
        
        // 确定迁移方向
        if sourceIndex < destinationIndex {
            // 向前迁移
            return Array(allVersions[sourceIndex + 1...destinationIndex])
        } else if sourceIndex > destinationIndex {
            // 向后迁移（降级）
            return Array(allVersions[destinationIndex..<sourceIndex].reversed())
        }
        
        return []
    }
    
    /// 清除缓存
    public func clearCache() {
        resourceCache.removeAll()
        modelCache.removeAll()
    }
    
    // MARK: - 私有方法
    
    /// 加载资源
    private func loadResource<T>(name: String, type: T.Type) async -> T? {
        let bundle = Bundle.main
        
        // 处理不同的资源类型
        switch type {
        case is String.Type:
            if let path = bundle.path(forResource: name, ofType: nil),
               let content = try? String(contentsOfFile: path) {
                return content as? T
            }
            
        case is Data.Type:
            if let path = bundle.path(forResource: name, ofType: nil),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                return data as? T
            }
            
        case is [String: Any].Type:
            if let path = bundle.path(forResource: name, ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
                return dict as? T
            }
            
        case is [Any].Type:
            if let path = bundle.path(forResource: name, ofType: "plist"),
               let array = NSArray(contentsOfFile: path) as? [Any] {
                return array as? T
            }
            
        // 修复UIImage相关错误
        case is UIImage.Type:
            #if canImport(UIKit)
            if let image = UIKit.UIImage(named: name, in: bundle, with: nil) {
                return image as? T
            }
            #elseif canImport(AppKit)
            if let image = AppKit.NSImage(named: NSImage.Name(name)) {
                return image as? T
            }
            #endif
            
        case is NSManagedObjectModel.Type:
            if let url = bundle.url(forResource: name, withExtension: "momd"),
               let model = NSManagedObjectModel(contentsOf: url) {
                return model as? T
            }
            
        default:
            break
        }
        
        return nil
    }
}

// MARK: - 工具扩展

/// UIImage 类型别名，用于跨平台兼容
#if canImport(UIKit)
import UIKit
public typealias UIImage = UIKit.UIImage
#elseif canImport(AppKit)
import AppKit
public typealias UIImage = AppKit.NSImage
#endif

/// ModelVersion 的 Hashable 实现
extension ModelVersionType {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.rawValue)
    }
}

/// 默认实现的 ModelVersionType 扩展
extension ModelVersionType {
    public var isLatest: Bool {
        return self == Self.latest
    }
    
    public var next: Self? {
        guard let allCases = Self.allCases as? [Self],
              let currentIndex = allCases.firstIndex(of: self),
              currentIndex < allCases.count - 1 else {
            return nil
        }
        return allCases[currentIndex + 1]
    }
    
    public var previous: Self? {
        guard let allCases = Self.allCases as? [Self],
              let currentIndex = allCases.firstIndex(of: self),
              currentIndex > 0 else {
            return nil
        }
        return allCases[currentIndex - 1]
    }
    
    public func modelURL() -> URL? {
        let modelName = String(describing: type(of: self)).replacingOccurrences(of: "Version", with: "")
        let versionName = self.rawValue
        
        // 尝试找到 .momd 目录下的 .mom 文件
        if Bundle.main.url(forResource: "\(modelName)", withExtension: "momd") != nil {
            return Bundle.main.url(forResource: versionName, withExtension: "mom", subdirectory: "\(modelName).momd")
        }
        
        // 如果没有找到，尝试直接查找 .mom 文件
        return Bundle.main.url(forResource: versionName, withExtension: "mom")
    }
}

// MARK: - Logger 扩展

extension Logger {
    static var CoreData: Logger {
        Logger(subsystem: "com.onlyslide.coredatamodule", category: "CoreData")
    }
}

// MARK: - 异步版本的ResourceProviding

@preconcurrency
protocol AsyncResourceProviding: Sendable {
    @MainActor
    var searchBundles: [Bundle] { get }
    
    func modelURL() -> URL?
    func mergedObjectModel() async -> NSManagedObjectModel?
    func allModels() async -> [NSManagedObjectModel]
    func model(for version: ModelVersion) -> NSManagedObjectModel?
    func mappingModel(from sourceVersion: ModelVersion, to destinationVersion: ModelVersion) async -> NSMappingModel?
    func modelVersions() async throws -> [ModelVersion]?
}

// MARK: - 模型加载器

@MainActor
class ModelLoader: ObservableObject {
    private var modelCache: [String: NSManagedObjectModel] = [:]
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    
    /// 异步加载模型
    /// - Parameter version: 模型版本
    /// - Returns: 托管对象模型
    @MainActor
    func loadModel(version: ModelVersion) -> NSManagedObjectModel? {
        let versionKey = version.identifier
        
        // 检查缓存
        if let cachedModel = modelCache[versionKey] {
            return cachedModel
        }
        
        // 从资源管理器加载模型
        if let model = CoreDataResourceManager.shared.model(for: version) {
            // 缓存并返回
            modelCache[versionKey] = model
            return model
        }
        
        return nil
    }
    
    /// 获取缓存统计信息
    func cacheStatistics() -> (hits: Int, misses: Int, hitRate: Double) {
        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
        return (cacheHits, cacheMisses, hitRate)
    }
    
    /// 清除缓存
    func clearCache() {
        modelCache.removeAll()
        cacheHits = 0
        cacheMisses = 0
    }
} 