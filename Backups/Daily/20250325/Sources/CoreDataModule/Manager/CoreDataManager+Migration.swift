import Foundation
import Combine
import CoreData

@MainActor
public extension CoreDataManager {
    
    // MARK: - Migration Properties
    
    /// 迁移管理器
    private var migrationManager: CoreDataMigrationManager {
        return CoreDataMigrationManager.shared
    }
    
    /// 迁移进度发布器
    var migrationProgressPublisher: AnyPublisher<Double, Never> {
        return migrationManager.$state
            .compactMap { state -> Double? in
                if case .inProgress(let progress) = state {
                    return progress.fraction
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    /// 迁移状态发布器
    var migrationStatePublisher: AnyPublisher<MigrationStateWrapper, Never> {
        return migrationManager.$state
            .map { state -> MigrationStateWrapper in
                switch state {
                case .notStarted, .preparing, .backingUp, .restoring:
                    return .preparing
                case .inProgress:
                    return .migrating
                case .completed:
                    return .completed
                case .failed:
                    return .failed
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// 迁移错误发布器
    var migrationErrorPublisher: AnyPublisher<Error?, Never> {
        return migrationManager.$state
            .map { state -> Error? in
                if case .failed(let error) = state {
                    return error
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Migration Methods
    
    /// 开始迁移
    /// - Returns: 是否成功迁移
    func startMigration() async throws {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            throw CoreDataError.storeNotFound("无法获取存储URL")
        }
        
        _ = try await migrationManager.checkAndMigrateStoreIfNeeded(at: storeURL)
    }
    
    /// 执行迁移
    /// - Parameter storeURL: 存储URL
    /// - Returns: 是否执行了迁移
    func performMigration(at storeURL: URL) async throws {
        try await migrationManager.performMigration(at: storeURL)
    }
    
    /// 检查是否需要迁移
    /// - Parameter storeURL: 存储URL
    /// - Returns: 是否需要迁移
    func requiresMigration() async throws -> Bool {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            throw CoreDataError.storeNotFound("无法获取存储URL")
        }
        
        let planner = MigrationPlanner()
        return try await planner.requiresMigration(at: storeURL)
    }
}

/// 迁移状态包装器
/// 简化的迁移状态枚举，用于UI层
public enum MigrationStateWrapper: Equatable {
    case notStarted
    case preparing
    case migrating
    case completed
    case failed
} 