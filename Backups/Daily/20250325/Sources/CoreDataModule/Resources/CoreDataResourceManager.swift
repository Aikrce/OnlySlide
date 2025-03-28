@preconcurrency import Foundation
@preconcurrency import CoreData
import os

/// 核心数据资源管理器
/// 负责统一管理和访问 CoreData 相关资源，如模型文件、映射模型等
@MainActor public final class CoreDataResourceManager: @unchecked Sendable {
    // MARK: - Properties
    
    /// 共享实例
    public static let shared = CoreDataResourceManager()
    
    /// 创建带有自定义 Bundle 集的共享实例
    /// - Parameter bundles: 要搜索的 Bundle 数组
    /// - Returns: 配置了指定 Bundle 的资源管理器实例
    public static func shared(withBundles bundles: [Bundle]) -> CoreDataResourceManager {
        let manager = CoreDataResourceManager(bundles: bundles)
        return manager
    }
    
    /// 模型名称
    private let modelName: String
    
    /// 主要资源 Bundle
    private let primaryBundle: Bundle
    
    /// 额外的资源 Bundle 数组
    private let additionalBundles: [Bundle]
    
    /// 是否启用缓存
    private let cachingEnabled: Bool
    
    /// 模型 URL 缓存
    private var modelURLCache: [String: URL] = [:]
    
    /// 版本模型 URL 缓存
    private var versionModelURLCache: [String: URL] = [:]
    
    /// 模型对象缓存
    private var modelCache: [String: NSManagedObjectModel] = [:]
    
    /// 映射模型缓存
    private var mappingModelCache: [String: NSMappingModel] = [:]
    
    /// 缓存命中计数
    private var cacheHits: Int = 0
    
    /// 缓存未命中计数
    private var cacheMisses: Int = 0
    
    /// 用于缓存访问的锁
    private let cacheLock = NSLock()
    
    /// 成功的资源搜索路径缓存
    private var successfulSearchPaths: [String: String] = [:]
    
    /// 模型URL映射，存储模型对象和对应的URL
    private var modelURLMap: [NSManagedObjectModel: URL] = [:]
    
    /// 所有需要搜索的 Bundles
    private var searchBundles: [Bundle] {
        var bundles = [primaryBundle] + additionalBundles
        
        // 添加模块自己的 Bundle，如果尚未包含
        let moduleBundle = Bundle(for: Self.self)
        if !bundles.contains(moduleBundle) {
            bundles.append(moduleBundle)
        }
        
        // 添加模块相关的资源 Bundle
        if let moduleBundleURL = Bundle(for: Self.self).resourceURL?.appendingPathComponent("\(modelName)_CoreDataModule.bundle"),
           let resourceBundle = Bundle(url: moduleBundleURL),
           !bundles.contains(resourceBundle) {
            bundles.append(resourceBundle)
        }
        
        return bundles
    }
    
    // MARK: - Initialization
    
    /// 初始化资源管理器
    /// - Parameters:
    ///   - modelName: 模型名称
    ///   - bundle: 主要资源 Bundle
    ///   - additionalBundles: 额外的资源 Bundle 数组
    ///   - enableCaching: 是否启用缓存
    public init(
        modelName: String = "OnlySlide",
        bundle: Bundle = .main,
        additionalBundles: [Bundle] = [],
        enableCaching: Bool = true
    ) {
        self.modelName = modelName
        self.primaryBundle = bundle
        self.additionalBundles = additionalBundles
        self.cachingEnabled = enableCaching
        
        // 如果启用缓存，预加载常用资源
        if enableCaching {
            Task { 
                await self.preloadCommonResources()
            }
        }
    }
    
    /// 使用 Bundle 数组初始化资源管理器
    /// - Parameters:
    ///   - modelName: 模型名称
    ///   - bundles: 要搜索的 Bundle 数组
    ///   - enableCaching: 是否启用缓存
    public convenience init(
        modelName: String = "OnlySlide", 
        bundles: [Bundle],
        enableCaching: Bool = true
    ) {
        if let primaryBundle = bundles.first {
            self.init(
                modelName: modelName, 
                bundle: primaryBundle, 
                additionalBundles: Array(bundles.dropFirst()),
                enableCaching: enableCaching
            )
        } else {
            self.init(modelName: modelName, enableCaching: enableCaching)
        }
    }
    
    // MARK: - Cache Management
    
    /// 缓存类型枚举
    public enum CacheType {
        /// 模型 URL 缓存
        case modelURL
        /// 模型对象缓存
        case model
        /// 映射模型缓存
        case mappingModel
        /// 所有缓存
        case all
    }
    
    /// 清除特定类型的缓存
    /// - Parameter cacheType: 要清除的缓存类型
    public func clearCache(_ cacheType: CacheType) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        switch cacheType {
        case .modelURL:
            modelURLCache.removeAll()
            versionModelURLCache.removeAll()
        case .model:
            modelCache.removeAll()
        case .mappingModel:
            mappingModelCache.removeAll()
        case .all:
            modelURLCache.removeAll()
            versionModelURLCache.removeAll()
            modelCache.removeAll()
            mappingModelCache.removeAll()
            successfulSearchPaths.removeAll()
        }
        
        Logger.info("已清除 \(cacheType) 缓存", category: .coreData)
    }
    
    /// 获取缓存统计信息
    /// - Returns: 缓存命中次数、未命中次数和命中率
    @MainActor
    public func cacheStatistics() -> (hits: Int, misses: Int, hitRate: Double) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
        return (cacheHits, cacheMisses, hitRate)
    }
    
    /// 从缓存中获取值
    /// - Parameters:
    ///   - cache: 缓存字典
    ///   - key: 缓存键
    /// - Returns: 缓存的值，如果不存在则返回 nil
    private func getCachedValue<T>(from cache: [String: T], forKey key: String) -> T? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        if let value = cache[key] {
            cacheHits += 1
            return value
        }
        
        cacheMisses += 1
        return nil
    }
    
    /// 将值设置到缓存中
    /// - Parameters:
    ///   - value: 要缓存的值
    ///   - cache: 缓存字典引用
    ///   - key: 缓存键
    private func setCachedValue<T>(_ value: T, in cache: inout [String: T], forKey key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        cache[key] = value
    }
    
    /// 专用于数组的缓存方法，具有正确的类型信息
    private func setCachedValueForArray<T>(_ array: [T], in cache: inout [String: Any], forKey key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        // 确保数组被作为特定类型的数组存储，而不是作为 "Any" 数组
        cache[key] = array as Any
    }
    
    /// 预加载常用的资源到缓存中
    /// 此方法可在应用启动时或进入数据密集型部分之前调用，以提前填充缓存
    @MainActor
    public func preloadCommonResources() async {
        guard cachingEnabled else {
            Logger.info("预加载被跳过，因为缓存已禁用", category: .coreData)
            return
        }
        
        Logger.info("开始预加载常用资源", category: .coreData)
        
        // 预加载基本模型 URL
        _ = self.modelURL()
        
        // 预加载合并对象模型
        _ = self.mergedObjectModel()
        
        // 预加载所有可用的模型版本
        do {
            let models = try self.allModels()
            Logger.info("预加载了 \(models.count) 个模型版本", category: .coreData)
            
            // 尝试加载一些常见的映射模型组合
            // 如果模型数量大于1，则尝试预加载相邻版本之间的映射模型
            if models.count > 1 {
                // 尝试获取模型版本
                if let versions = try await modelVersions() {
                    // 预加载相邻版本之间的映射模型
                    for i in 0..<(versions.count - 1) {
                        let sourceVersion = versions[i]
                        let destVersion = versions[i + 1]
                        _ = self.mappingModel(from: sourceVersion, to: destVersion)
                    }
                }
            }
        } catch {
            Logger.error("预加载模型版本时出错: \(error.localizedDescription)", category: .coreData)
        }
        
        // 输出缓存统计
        let stats = self.cacheStatistics()
        Logger.info("资源预加载完成。缓存命中: \(stats.hits), 未命中: \(stats.misses), 命中率: \(stats.hitRate)", category: .coreData)
    }
    
    // MARK: - Model Access
    
    /// 获取合并后的管理对象模型
    /// - Returns: 合并后的模型
    @MainActor
    public func mergedObjectModel() -> NSManagedObjectModel? {
        // 如果启用了缓存，先检查缓存
        if cachingEnabled, let cachedModel = getCachedValue(from: modelCache, forKey: "merged") {
            return cachedModel
        }
        
        // 首先尝试从所有 Bundles 合并模型
        if let model = NSManagedObjectModel.mergedModel(from: searchBundles) {
            // 如果启用了缓存，保存到缓存
            if cachingEnabled {
                setCachedValue(model, in: &modelCache, forKey: "merged")
            }
            return model
        }
        
        // 如果合并失败，尝试直接加载单个模型文件
        if let modelURL = findModelURL() {
            let model = NSManagedObjectModel(contentsOf: modelURL)
            
            // 如果启用了缓存，保存到缓存
            if let model = model, cachingEnabled {
                setCachedValue(model, in: &modelCache, forKey: "merged")
            }
            
            return model
        }
        
        // 记录错误日志
        Logger.error("无法加载合并模型或单个模型文件", category: .coreData)
        return nil
    }
    
    /// 查找模型 URL
    /// - Returns: 找到的模型 URL
    private func findModelURL() -> URL? {
        // 如果启用了缓存，先检查缓存
        if cachingEnabled, let cachedURL = getCachedValue(from: modelURLCache, forKey: "default") {
            return cachedURL
        }
        
        // 如果有成功的搜索路径，优先检查
        if cachingEnabled, let successPath = getCachedValue(from: successfulSearchPaths, forKey: "model_\(modelName)"),
           let successBundle = Bundle(path: successPath),
           let momdURL = successBundle.url(forResource: modelName, withExtension: "momd") {
            setCachedValue(momdURL, in: &modelURLCache, forKey: "default")
            return momdURL
        }
        
        // 在所有 Bundles 中查找模型
        for bundle in searchBundles {
            // 首先尝试找 .momd 目录
            if let momdURL = bundle.url(forResource: modelName, withExtension: "momd") {
                // 如果启用了缓存，保存成功路径和 URL
                if cachingEnabled {
                    setCachedValue(bundle.bundlePath, in: &successfulSearchPaths, forKey: "model_\(modelName)")
                    setCachedValue(momdURL, in: &modelURLCache, forKey: "default")
                }
                return momdURL
            }
            
            // 如果找不到 .momd，尝试找单个 .mom 文件
            if let momURL = bundle.url(forResource: modelName, withExtension: "mom") {
                // 如果启用了缓存，保存成功路径和 URL
                if cachingEnabled {
                    setCachedValue(bundle.bundlePath, in: &successfulSearchPaths, forKey: "model_\(modelName)")
                    setCachedValue(momURL, in: &modelURLCache, forKey: "default")
                }
                return momURL
            }
        }
        
        // 记录错误日志
        Logger.warning("在所有 Bundle 中未找到 \(modelName).momd 或 \(modelName).mom", category: .coreData)
        return nil
    }
    
    /// 获取模型 URL
    /// - Returns: 模型 URL
    @MainActor
    public func modelURL() -> URL? {
        return findModelURL()
    }
    
    /// 获取指定版本模型 URL
    /// - Parameter version: 模型版本
    /// - Returns: 版本对应的模型 URL
    public func modelURL(for version: ModelVersion) -> URL? {
        let cacheKey = version.identifier
        
        // 如果启用了缓存，先检查缓存
        if cachingEnabled, let cachedURL = getCachedValue(from: versionModelURLCache, forKey: cacheKey) {
            return cachedURL
        }
        
        var foundURL: URL? = nil
        
        // 首先尝试在主模型目录中查找
        if let modelDirectoryURL = modelURL(), modelDirectoryURL.pathExtension == "momd" {
            let versionIdentifier = version.identifier
            let versionURL = modelDirectoryURL.appendingPathComponent("\(versionIdentifier).mom")
            
            // 检查文件是否存在
            if FileManager.default.fileExists(atPath: versionURL.path) {
                foundURL = versionURL
            }
        }
        
        // 如果在主目录中找不到，在所有 Bundles 中查找
        if foundURL == nil {
            for bundle in searchBundles {
                // 尝试直接找对应版本的 .mom 文件
                if let url = bundle.url(forResource: version.identifier, withExtension: "mom") {
                    foundURL = url
                    break
                }
                
                // 也尝试找 modelName_版本标识符.mom 格式的文件
                if let url = bundle.url(forResource: "\(modelName)_\(version.identifier)", withExtension: "mom") {
                    foundURL = url
                    break
                }
            }
        }
        
        // 如果找到了 URL，并且启用了缓存，保存到缓存
        if let url = foundURL, cachingEnabled {
            setCachedValue(url, in: &versionModelURLCache, forKey: cacheKey)
        } else if foundURL == nil {
            Logger.warning("未找到版本 \(version.identifier) 的模型", category: .coreData)
        }
        
        return foundURL
    }
    
    /// 获取所有可用的模型版本 URL
    /// - Returns: 所有可用版本的模型 URL 数组
    public func allModelVersionURLs() -> [URL] {
        var modelURLs: [URL] = []
        
        // 首先检查主模型目录
        if let modelDirectoryURL = modelURL(), modelDirectoryURL.pathExtension == "momd" {
            do {
                // 获取所有 .mom 文件
                modelURLs = try FileManager.default.contentsOfDirectory(
                    at: modelDirectoryURL,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                ).filter { $0.pathExtension == "mom" }
            } catch {
                Logger.error("获取模型版本失败: \(error.localizedDescription)", category: .coreData)
            }
        }
        
        // 如果主目录中没有找到，在所有 Bundles 中查找单独的 .mom 文件
        if modelURLs.isEmpty {
            for bundle in searchBundles {
                guard let resourcePath = bundle.resourcePath else { continue }
                
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    
                    // 查找两种格式：直接 .mom 和 modelName 开头的 .mom
                    let momFiles = contents.filter { 
                        $0.hasSuffix(".mom") && 
                        ($0.hasPrefix(modelName) || !$0.contains("_"))
                    }
                    
                    for file in momFiles {
                        let url = URL(fileURLWithPath: resourcePath).appendingPathComponent(file)
                        if !modelURLs.contains(url) {
                            modelURLs.append(url)
                        }
                    }
                } catch {
                    Logger.error("搜索单独模型文件失败: \(error.localizedDescription)", category: .coreData)
                }
            }
        }
        
        return modelURLs
    }
    
    /// 获取所有可用的管理对象模型
    /// - Returns: 所有可用的模型数组
    @MainActor
    public func allModels() -> [NSManagedObjectModel] {
        // 如果启用了缓存，先检查缓存
        if cachingEnabled, let cachedModels = getCachedValue(from: modelCache, forKey: "all") as? [NSManagedObjectModel] {
            return cachedModels
        }
        
        var models: [NSManagedObjectModel] = []
        
        // 尝试从mom文件加载单个模型
        for bundle in searchBundles {
            // 在bundle中查找.mom文件
            do {
                let urls = try bundle.urls(forResourcesWithExtension: "mom", subdirectory: "\(modelName).momd")
                for url in urls {
                    if let model = NSManagedObjectModel(contentsOf: url) {
                        models.append(model)
                        modelURLMap[model] = url  // 记录模型和URL的映射
                    }
                }
            } catch {
                Logger.warning("获取.mom文件失败: \(error.localizedDescription)", category: .coreData)
            }
            
            // 在bundle中查找.xcdatamodeld文件
            do {
                let urls = try bundle.urls(forResourcesWithExtension: "xcdatamodeld", subdirectory: nil)
                for url in urls {
                    do {
                        let modelDirectoryURLs = try FileManager.default.contentsOfDirectory(
                            at: url, 
                            includingPropertiesForKeys: nil, 
                            options: [.skipsHiddenFiles]
                        )
                        for modelURL in modelDirectoryURLs {
                            if let model = NSManagedObjectModel(contentsOf: modelURL) {
                                models.append(model)
                                modelURLMap[model] = modelURL  // 记录模型和URL的映射
                            }
                        }
                    } catch {
                        Logger.warning("获取模型目录内容失败: \(error.localizedDescription)", category: .coreData)
                    }
                }
            } catch {
                Logger.warning("获取.xcdatamodeld文件失败: \(error.localizedDescription)", category: .coreData)
            }
        }
        
        // 如果没有找到任何模型，尝试加载合并模型
        if models.isEmpty, let mergedModel = NSManagedObjectModel.mergedModel(from: searchBundles) {
            models.append(mergedModel)
        }
        
        // 如果启用了缓存，保存到缓存
        if cachingEnabled {
            setCachedValueForArray(models, in: &modelCache, forKey: "all")
        }
        
        return models
    }
    
    /// 获取模型对应的URL
    /// - Parameter model: 管理对象模型
    /// - Returns: 对应的URL，如果没有则返回nil
    public func url(for model: NSManagedObjectModel) -> URL? {
        return modelURLMap[model]
    }
    
    // MARK: - Mapping Model Access
    
    /// 获取自定义映射模型
    /// - Parameters:
    ///   - sourceVersion: 源版本
    ///   - destinationVersion: 目标版本
    /// - Returns: 映射模型，如果不存在则返回 nil
    @MainActor
    public func mappingModel(from sourceVersion: ModelVersion, to destinationVersion: ModelVersion) -> NSMappingModel? {
        let cacheKey = "mapping_\(sourceVersion.identifier)_to_\(destinationVersion.identifier)"
        
        // 如果启用了缓存，先检查缓存
        if cachingEnabled, let cachedMapping = getCachedValue(from: mappingModelCache, forKey: cacheKey) {
            return cachedMapping
        }
        
        // 构建映射模型名称（尝试多种命名格式）
        let mappingNames = [
            "Mapping_\(sourceVersion.identifier)_to_\(destinationVersion.identifier)",
            "\(modelName)_Mapping_\(sourceVersion.identifier)_to_\(destinationVersion.identifier)",
            "Mapping_\(sourceVersion.major).\(sourceVersion.minor)_to_\(destinationVersion.major).\(destinationVersion.minor)"
        ]
        
        var foundMappingModel: NSMappingModel? = nil
        
        // 在所有 Bundles 中查找映射模型
        for bundle in searchBundles {
            for mappingName in mappingNames {
                if let mappingPath = bundle.path(forResource: mappingName, ofType: "cdm"),
                   let mapping = NSMappingModel(contentsOf: URL(fileURLWithPath: mappingPath)) {
                    foundMappingModel = mapping
                    break
                }
            }
            
            if foundMappingModel != nil {
                break
            }
        }
        
        // 如果找不到自定义映射模型，尝试使用标准 API
        if foundMappingModel == nil,
           let sourceModel = model(for: sourceVersion), 
           let destinationModel = model(for: destinationVersion) {
            do {
                foundMappingModel = try NSMappingModel(
                    from: searchBundles,
                    forSourceModel: sourceModel,
                    destinationModel: destinationModel
                )
            } catch {
                Logger.warning("无法创建自动映射模型: \(error.localizedDescription)", category: .coreData)
            }
        }
        
        // 如果找到了映射模型，并且启用了缓存，保存到缓存
        if let mappingModel = foundMappingModel, cachingEnabled {
            setCachedValue(mappingModel, in: &mappingModelCache, forKey: cacheKey)
        } else if foundMappingModel == nil {
            Logger.warning("无法找到从 \(sourceVersion.identifier) 到 \(destinationVersion.identifier) 的映射模型",
                          category: .coreData)
        }
        
        return foundMappingModel
    }
    
    /// 获取指定版本的模型
    /// - Parameter version: 模型版本
    /// - Returns: 对应版本的模型
    public func model(for version: ModelVersion) -> NSManagedObjectModel? {
        let cacheKey = version.identifier
        
        // 如果启用了缓存，先检查缓存
        if cachingEnabled, let cachedModel = getCachedValue(from: modelCache, forKey: cacheKey) {
            return cachedModel
        }
        
        // 加载模型
        guard let url = modelURL(for: version) else {
            return nil
        }
        
        guard let model = NSManagedObjectModel(contentsOf: url) else {
            return nil
        }
        
        // 如果启用了缓存，保存到缓存
        if cachingEnabled {
            setCachedValue(model, in: &modelCache, forKey: cacheKey)
        }
        
        return model
    }
    
    // MARK: - Store Access
    
    /// 获取存储 URL
    /// - Returns: 存储 URL
    public func defaultStoreURL() -> URL {
        // 获取应用支持目录
        let appSupportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        let bundleID = Bundle.main.bundleIdentifier ?? "com.onlyslide"
        let storeDirectory = appSupportDirectory.appendingPathComponent(bundleID, isDirectory: true)
        
        // 确保目录存在
        do {
            try FileManager.default.createDirectory(
                at: storeDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            Logger.error("创建存储目录失败: \(error.localizedDescription)", category: .coreData)
        }
        
        // 返回存储 URL
        return storeDirectory.appendingPathComponent("\(modelName).sqlite")
    }
    
    /// 获取备份存储 URL
    /// - Parameter timestamp: 时间戳，默认为当前时间
    /// - Returns: 备份 URL
    public func backupStoreURL(timestamp: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: timestamp)
        
        return defaultStoreURL().deletingLastPathComponent()
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("\(modelName)_\(dateString).sqlite")
    }
    
    /// 创建备份目录
    /// - Returns: 备份目录 URL
    public func createBackupDirectory() -> URL? {
        let backupDirectory = defaultStoreURL().deletingLastPathComponent()
            .appendingPathComponent("Backups", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(
                at: backupDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return backupDirectory
        } catch {
            Logger.error("创建备份目录失败: \(error.localizedDescription)", category: .coreData)
            return nil
        }
    }
    
    /// 获取所有备份文件
    /// - Returns: 备份文件 URL 数组
    public func allBackups() -> [URL] {
        guard let backupDirectory = createBackupDirectory() else {
            return []
        }
        
        do {
            // 获取所有 .sqlite 文件
            return try FileManager.default.contentsOfDirectory(
                at: backupDirectory, 
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ).filter { $0.pathExtension == "sqlite" }
        } catch {
            Logger.error("获取备份文件失败: \(error.localizedDescription)", category: .coreData)
            return []
        }
    }
    
    /// 清理旧备份
    /// - Parameter keepLatest: 要保留的最新备份数量
    public func cleanupBackups(keepLatest: Int = 5) {
        let backups = allBackups()
        
        // 如果备份数量不超过保留数量，不需要清理
        if backups.count <= keepLatest {
            Logger.info("当前备份数量(\(backups.count))不超过要保留的数量(\(keepLatest))，不需要清理", category: .coreData)
            return
        }
        
        Logger.info("开始清理备份：总共\(backups.count)个备份，将保留最新的\(keepLatest)个", category: .coreData)
        
        // 初始化排序后的备份数组
        var sortedBackups: [URL] = []
        
        do {
            // 按修改日期排序
            sortedBackups = try backups.sorted { (url1, url2) -> Bool in
                do {
                    let values1 = try url1.resourceValues(forKeys: [.contentModificationDateKey])
                    let values2 = try url2.resourceValues(forKeys: [.contentModificationDateKey])
                    
                    let date1 = values1.contentModificationDate
                    let date2 = values2.contentModificationDate
                    
                    // 确保两个日期都不为nil
                    guard let date1 = date1, let date2 = date2 else {
                        // 如果其中一个日期为nil，则按路径比较
                        Logger.warning("文件缺少修改日期信息，使用路径比较", category: .coreData)
                        return url1.path > url2.path
                    }
                    
                    return date1 > date2
                } catch {
                    Logger.warning("获取文件修改日期失败: \(error.localizedDescription)", category: .coreData)
                    // 发生错误时按路径比较
                    return url1.path > url2.path
                }
            }
        } catch {
            Logger.error("排序备份文件失败: \(error.localizedDescription)", category: .coreData)
            // 如果排序失败，使用原始列表
            sortedBackups = backups
            Logger.warning("使用未排序的备份列表", category: .coreData)
        }
        
        // 删除旧备份
        if sortedBackups.count > keepLatest {
            let backupsToDelete = sortedBackups.suffix(from: keepLatest)
            Logger.info("将删除\(backupsToDelete.count)个旧备份", category: .coreData)
            
            for backupURL in backupsToDelete {
                do {
                    Logger.info("尝试删除旧备份: \(backupURL.lastPathComponent)", category: .coreData)
                    
                    // 删除备份文件
                    try FileManager.default.removeItem(at: backupURL)
                    
                    // 删除相关的 -wal 和 -shm 文件
                    let directoryURL = backupURL.deletingLastPathComponent()
                    let fileName = backupURL.lastPathComponent
                    let walURL = directoryURL.appendingPathComponent(fileName + "-wal")
                    let shmURL = directoryURL.appendingPathComponent(fileName + "-shm")
                    
                    if FileManager.default.fileExists(atPath: walURL.path) {
                        try FileManager.default.removeItem(at: walURL)
                        Logger.info("已删除相关WAL文件: \(walURL.lastPathComponent)", category: .coreData)
                    }
                    
                    if FileManager.default.fileExists(atPath: shmURL.path) {
                        try FileManager.default.removeItem(at: shmURL)
                        Logger.info("已删除相关SHM文件: \(shmURL.lastPathComponent)", category: .coreData)
                    }
                    
                    Logger.info("成功删除旧备份: \(backupURL.lastPathComponent)", category: .coreData)
                } catch {
                    Logger.warning("删除旧备份失败: \(backupURL.lastPathComponent) - \(error.localizedDescription)", category: .coreData)
                    // 继续处理其他备份，不中断循环
                }
            }
            
            // 清理完成后验证
            let remainingBackups = allBackups()
            Logger.info("备份清理完成，剩余\(remainingBackups.count)个备份", category: .coreData)
        }
    }
    
    /// 预加载所有资源
    /// 这可以减少首次访问时的延迟
    @MainActor
    public func preload() async {
        Logger.info("开始预加载 Core Data 资源...", category: .coreData)
        
        // 预加载基本模型 URL
        _ = await modelURL()
        
        // 预加载合并对象模型
        _ = await mergedObjectModel()
        
        // 预加载所有可用的模型版本
        do {
            let models = try allModels()
            Logger.info("预加载了 \(models.count) 个模型版本", category: .coreData)
            
            do {
                // 预加载模型版本
                if let versions = try await modelVersions() {
                    Logger.info("预加载了 \(versions.count) 个版本标识", category: .coreData)
                    
                    // 预加载映射模型
                    if versions.count > 1 {
                        for i in 0..<(versions.count - 1) {
                            let sourceVersion = versions[i]
                            let destVersion = versions[i + 1]
                            _ = await mappingModel(from: sourceVersion, to: destVersion)
                        }
                    }
                }
            } catch {
                Logger.error("预加载版本信息时出错: \(error.localizedDescription)", category: .coreData)
            }
        } catch {
            Logger.error("预加载模型版本时出错: \(error.localizedDescription)", category: .coreData)
        }
        
        // 输出缓存统计
        let stats = await cacheStatistics()
        Logger.info("资源预加载完成。缓存命中: \(stats.hits), 未命中: \(stats.misses), 命中率: \(stats.hitRate)", category: .coreData)
    }
    
    /// 获取模型版本列表
    /// - Returns: 模型版本列表
    @MainActor
    public func modelVersions() async throws -> [ModelVersion]? {
        // 加载所有模型
        let models = try allModels()
        
        if models.isEmpty {
            Logger.error("找不到任何 Core Data 模型", category: .coreData)
            return nil
        }
        
        // 从模型中提取版本信息
        var versions: [ModelVersion] = []
        
        for model in models {
            // 尝试从模型的版本标识符集合中提取版本
            if let version = ModelVersion(versionIdentifiers: model.versionIdentifiers) {
                versions.append(version)
                Logger.info("从版本标识符中提取版本: \(version.identifier)", category: .coreData)
            } 
            // 如果无法从版本标识符提取，尝试从URL中提取
            else if let url = url(for: model), let version = ModelVersion.from(url: url) {
                versions.append(version)
                Logger.info("从URL中提取版本: \(version.identifier)", category: .coreData)
            } else {
                // 如果仍然无法提取版本，记录一个警告
                Logger.warning("无法从模型中提取版本信息: \(model)", category: .coreData)
            }
        }
        
        // 如果没有找到任何版本，返回nil
        if versions.isEmpty {
            Logger.warning("未能从\(models.count)个模型中提取任何版本信息", category: .coreData)
            return nil
        }
        
        // 去除重复的版本
        let uniqueVersions = Array(Set(versions)).sorted()
        
        // 如果去重后的版本数量与原始版本数量不一致，记录一个信息
        if uniqueVersions.count != versions.count {
            Logger.info("移除了\(versions.count - uniqueVersions.count)个重复版本", category: .coreData)
        }
        
        Logger.info("找到\(uniqueVersions.count)个唯一版本", category: .coreData)
        
        // 按版本号排序并返回
        return uniqueVersions
    }
}

// MARK: - Logger

/// 简单的日志记录器
fileprivate enum Logger {
    enum Category: String {
        case coreData = "CoreData"
    }
    
    enum Level: String {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    static func log(_ message: String, level: Level, category: Category) {
        #if DEBUG
        print("[\(level.rawValue)][\(category.rawValue)] \(message)")
        #endif
    }
    
    static func info(_ message: String, category: Category) {
        log(message, level: .info, category: category)
    }
    
    static func warning(_ message: String, category: Category) {
        log(message, level: .warning, category: category)
    }
    
    static func error(_ message: String, category: Category) {
        log(message, level: .error, category: category)
    }
} 