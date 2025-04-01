import SwiftUI
import Combine
// import CoreDataModule

/// 数据库信息结构体
public struct DatabaseInfo {
    let sizeInBytes: Int64
    let currentVersion: String
    let targetVersion: String
    let migrationComplexity: MigrationComplexity
}

/// 迁移复杂度枚举
public enum MigrationComplexity {
    case simple
    case moderate
    case complex
}

/// CoreData UI适配器
@MainActor
final class CoreDataUIAdapter: ObservableObject {
    @Published var migrationProgress: Double = 0.0
    @Published var errorMessage: String? = nil
    @Published var isMigrating: Bool = false
    @Published var migrationState: MigrationStateWrapper = .notStarted
    
    private let coreDataManager: CoreDataManagerProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 使用工厂方法获取CoreDataManager实例
        self.coreDataManager = CoreDataManagerFactory.getManager()
        setupBindings()
    }
    
    private func setupBindings() {
        // 订阅迁移进度
        coreDataManager.migrationProgressPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.migrationProgress, on: self)
            .store(in: &cancellables)
        
        // 订阅迁移状态
        coreDataManager.migrationStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                self.migrationState = state
                self.isMigrating = state == .migrating
            }
            .store(in: &cancellables)
        
        // 订阅错误信息
        coreDataManager.migrationErrorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }
    
    func startMigration() async {
        do {
            try await coreDataManager.startMigration()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func getDatabaseInfo() async throws -> DatabaseInfo {
        return try await coreDataManager.getDatabaseInfo()
    }
    
    func resetMigration() {
        coreDataManager.resetMigration()
    }
    
    func checkIfMigrationNeeded() async throws -> Bool {
        return try await coreDataManager.requiresMigration()
    }
} 