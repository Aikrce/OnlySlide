import Foundation
import os.log

/// 文件系统监控器
final class FileSystemMonitor {
    // MARK: - Properties
    static let shared = FileSystemMonitor()
    private let logger = Logger(label: "com.onlyslide.automation.filesystem")
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var watchedFiles: [String: DispatchSourceFileSystemObject] = [:]
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    /// 开始监控项目文件
    func startMonitoring(projectPath: String) {
        logger.info("开始监控项目文件变化: \(projectPath)")
        
        // 递归遍历项目目录
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: projectPath),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            logger.error("无法访问项目目录")
            return
        }
        
        // 监控Swift文件
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            watchFile(at: fileURL)
        }
        
        // 设置目录监控
        setupDirectoryMonitoring(path: projectPath)
    }
    
    /// 停止监控
    func stopMonitoring() {
        watchedFiles.values.forEach { $0.cancel() }
        watchedFiles.removeAll()
        fileWatcher?.cancel()
        fileWatcher = nil
    }
    
    // MARK: - Private Methods
    private func watchFile(at url: URL) {
        let path = url.path
        let fileDescriptor = open(path, O_EVTONLY)
        
        guard fileDescriptor >= 0 else {
            logger.error("无法监控文件: \(path)")
            return
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .global()
        )
        
        source.setEventHandler { [weak self] in
            self?.handleFileChange(at: url)
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        watchedFiles[path] = source
        source.resume()
    }
    
    private func setupDirectoryMonitoring(path: String) {
        let fileDescriptor = open(path, O_EVTONLY)
        
        guard fileDescriptor >= 0 else {
            logger.error("无法监控目录: \(path)")
            return
        }
        
        fileWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write],
            queue: .global()
        )
        
        fileWatcher?.setEventHandler { [weak self] in
            self?.handleDirectoryChange(path: path)
        }
        
        fileWatcher?.setCancelHandler {
            close(fileDescriptor)
        }
        
        fileWatcher?.resume()
    }
    
    private func handleFileChange(at url: URL) {
        Task {
            do {
                logger.info("检测到文件变化: \(url.lastPathComponent)")
                
                // 执行实时代码检查
                try await CodeQualityMonitor.shared.performLiveCheck()
                
                // 执行规则检查
                try await RuleEnforcer.shared.checkMVVMRules()
                try await RuleEnforcer.shared.checkDependencyInjectionRules()
                
                // 更新监控指标
                MonitoringSystem.shared.handleFileChange(url)
            } catch {
                logger.error("处理文件变化时出错: \(error)")
            }
        }
    }
    
    private func handleDirectoryChange(path: String) {
        // 检查新文件
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift",
                  watchedFiles[fileURL.path] == nil else { continue }
            
            // 监控新文件
            watchFile(at: fileURL)
        }
    }
} 