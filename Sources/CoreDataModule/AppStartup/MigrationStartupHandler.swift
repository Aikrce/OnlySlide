import Foundation
import CoreData

/// 迁移启动处理器
/// 负责在应用启动时执行必要的数据库迁移
public final class MigrationStartupHandler {
    
    // MARK: - Properties
    
    /// 共享实例
    public static let shared = MigrationStartupHandler()
    
    /// 迁移管理器
    private let migrationManager: CoreDataMigrationManager
    
    /// 版本管理器
    private let versionManager: CoreDataModelVersionManager
    
    /// 迁移进度观察者
    private var migrationProgressObserver: ((MigrationProgress) -> Void)?
    
    /// 迁移是否完成
    private var migrationCompleted = false
    
    /// 迁移错误
    private var migrationError: Error?
    
    // MARK: - Initialization
    
    /// 初始化迁移启动处理器
    /// - Parameters:
    ///   - migrationManager: 迁移管理器
    ///   - versionManager: 版本管理器
    public init(
        migrationManager: CoreDataMigrationManager = CoreDataMigrationManager.shared,
        versionManager: CoreDataModelVersionManager = CoreDataModelVersionManager.shared
    ) {
        self.migrationManager = migrationManager
        self.versionManager = versionManager
    }
    
    // MARK: - Public Methods
    
    /// 在应用启动时调用此方法检查并执行必要的迁移
    /// - Parameters:
    ///   - storeURL: 存储URL
    ///   - progressObserver: 进度观察者
    /// - Returns: 迁移是否成功
    public func checkAndMigrateStoreIfNeeded(
        at storeURL: URL,
        progressObserver: ((MigrationProgress) -> Void)? = nil
    ) async -> Bool {
        // 设置进度观察者
        self.migrationProgressObserver = progressObserver
        
        do {
            // 检查是否需要迁移
            let needsMigration = try versionManager.requiresMigration(at: storeURL)
            
            if needsMigration {
                // 需要迁移，执行迁移
                let didMigrate = try await migrationManager.performMigration(at: storeURL) { [weak self] progress in
                    self?.migrationProgressObserver?(progress)
                }
                
                self.migrationCompleted = true
                return didMigrate
            } else {
                // 不需要迁移
                self.migrationCompleted = true
                return false
            }
        } catch {
            // 迁移失败
            self.migrationError = error
            self.migrationCompleted = true
            return false
        }
    }
    
    /// 获取迁移状态
    /// - Returns: 迁移状态
    public func getMigrationStatus() -> MigrationStatus {
        if !migrationCompleted {
            return .inProgress
        }
        
        if let error = migrationError {
            return .failed(error)
        }
        
        return .completed
    }
    
    // MARK: - Helper Methods
    
    /// 获取存储URL
    /// - Parameters:
    ///   - fileName: 文件名
    ///   - fileManager: 文件管理器
    /// - Returns: 存储URL
    public static func getStoreURL(
        fileName: String = "OnlySlide.sqlite",
        fileManager: FileManager = .default
    ) -> URL {
        // 获取应用文档目录
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }
}

/// 迁移状态
public enum MigrationStatus: Equatable {
    /// 正在进行
    case inProgress
    /// 已完成
    case completed
    /// 失败
    case failed(Error)
    
    public static func == (lhs: MigrationStatus, rhs: MigrationStatus) -> Bool {
        switch (lhs, rhs) {
        case (.inProgress, .inProgress), (.completed, .completed):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI

/// 迁移管理器包装器
/// 用于在SwiftUI中使用迁移管理器
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public class MigrationManager: ObservableObject {
    
    /// 迁移启动处理器
    private let startupHandler: MigrationStartupHandler
    
    /// 最新的迁移进度
    @Published public private(set) var progress: MigrationProgress?
    
    /// 迁移状态
    @Published public private(set) var status: MigrationStatus = .inProgress
    
    /// 初始化迁移管理器
    /// - Parameter startupHandler: 迁移启动处理器
    public init(startupHandler: MigrationStartupHandler = MigrationStartupHandler.shared) {
        self.startupHandler = startupHandler
    }
    
    /// 检查并执行必要的迁移
    /// - Parameter storeURL: 存储URL
    public func checkAndMigrateStoreIfNeeded(at storeURL: URL? = nil) async {
        let url = storeURL ?? MigrationStartupHandler.getStoreURL()
        
        _ = await startupHandler.checkAndMigrateStoreIfNeeded(at: url) { [weak self] progress in
            DispatchQueue.main.async {
                self?.progress = progress
            }
        }
        
        DispatchQueue.main.async {
            self.status = self.startupHandler.getMigrationStatus()
        }
    }
}
#endif 