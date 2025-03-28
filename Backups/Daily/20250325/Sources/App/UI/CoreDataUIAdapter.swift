import SwiftUI
import Combine
import CoreDataModule

@MainActor
final class CoreDataUIAdapter: ObservableObject {
    @Published var migrationProgress: Double = 0.0
    @Published var errorMessage: String? = nil
    @Published var isMigrating: Bool = false
    @Published var migrationState: MigrationStateWrapper = .notStarted
    
    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        coreDataManager.migrationProgressPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.migrationProgress, on: self)
            .store(in: &cancellables)
        
        coreDataManager.migrationStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                self.migrationState = state
                self.isMigrating = state == .migrating
            }
            .store(in: &cancellables)
        
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
        // 获取存储URL
        guard let storeURL = CoreDataStack.shared.persistentContainer.persistentStoreDescriptions.first?.url else {
            throw CoreDataError.storeNotFound("无法获取存储URL")
        }
        
        // 检查文件大小
        let fileManager = FileManager.default
        let fileAttributes = try fileManager.attributesOfItem(atPath: storeURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        
        // 获取版本信息
        let planner = MigrationPlanner()
        let needsMigration = try await planner.requiresMigration(at: storeURL)
        
        if !needsMigration {
            return DatabaseInfo(
                sizeInBytes: fileSize,
                currentVersion: "最新版本",
                targetVersion: "最新版本",
                migrationComplexity: .simple
            )
        }
        
        // 创建迁移计划以获取更多信息
        let plan = try await planner.createMigrationPlan(for: storeURL)
        
        let currentVersion = plan.sourceVersion.displayName
        let targetVersion = plan.destinationVersion.displayName
        
        // 根据步骤数确定复杂度
        let complexity: MigrationComplexity
        switch plan.steps.count {
        case 0:
            complexity = .simple
        case 1:
            complexity = .simple
        case 2...3:
            complexity = .moderate
        default:
            complexity = .complex
        }
        
        return DatabaseInfo(
            sizeInBytes: fileSize,
            currentVersion: currentVersion,
            targetVersion: targetVersion,
            migrationComplexity: complexity
        )
    }
    
    func resetMigration() {
        CoreDataMigrationManager.shared.reset()
    }
} 