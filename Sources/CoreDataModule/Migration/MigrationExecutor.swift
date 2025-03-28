import Foundation
import CoreData

/// 负责执行迁移步骤
@MainActor public final class MigrationExecutor: @unchecked Sendable {
    // MARK: - Properties
    
    /// 负责创建迁移计划的规划器
    public let planner: MigrationPlanner
    
    // MARK: - Initialization
    
    /// 初始化迁移执行器
    /// - Parameter planner: 迁移计划器
    public init(planner: MigrationPlanner = MigrationPlanner()) {
        self.planner = planner
    }
    
    // MARK: - Public Methods
    
    /// 执行迁移步骤
    /// - Parameter step: 迁移步骤
    /// - Parameter storeURL: 存储 URL
    public func executeStep(_ step: MigrationStep, at storeURL: URL) async throws {
        do {
            // 获取源模型和目标模型
            let sourceModel = try planner.sourceModel(for: step)
            let destinationModel = try planner.destinationModel(for: step)
            
            // 获取映射模型
            let mappingModel = try planner.mappingModel(for: step)
            
            // 创建目标存储 URL
            let destinationStoreURL = storeURL.deletingLastPathComponent()
                .appendingPathComponent("intermediate_\(UUID().uuidString).sqlite")
            
            // 创建迁移管理器
            let migrationManager = NSMigrationManager(
                sourceModel: sourceModel,
                destinationModel: destinationModel
            )
            
            // 执行实际迁移
            try migrationManager.migrateStore(
                from: storeURL,
                sourceType: NSSQLiteStoreType,
                options: nil as [String: Any]?,
                with: mappingModel,
                toDestinationURL: destinationStoreURL,
                destinationType: NSSQLiteStoreType,
                destinationOptions: nil as [String: Any]?
            )
            
            // 替换原始存储
            try FileManager.default.removeItem(at: storeURL)
            try FileManager.default.moveItem(at: destinationStoreURL, to: storeURL)
        } catch {
            throw MigrationError.stepExecutionFailed(
                step: step,
                description: error.localizedDescription
            )
        }
    }
    
    /// 执行迁移计划
    /// - Parameters:
    ///   - plan: 迁移计划
    ///   - options: 迁移选项
    ///   - progressHandler: 进度处理器
    public func executePlan(
        _ plan: MigrationPlan,
        options: MigrationOptions,
        progressHandler: @escaping (Float) -> Void
    ) async throws {
        // 如果没有步骤，什么都不做
        if plan.steps.isEmpty {
            return
        }
        
        // 创建临时目录存放迁移过程中的中间文件
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try FileManager.default.createDirectory(
            at: tempDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // 完成后清理临时目录
        defer {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
        
        // 拷贝原始存储到临时位置
        let tempStoreURL = tempDirectoryURL.appendingPathComponent("temp_store.sqlite")
        try FileManager.default.copyItem(at: plan.storeURL, to: tempStoreURL)
        
        // 总步骤数
        let totalSteps = plan.steps.count
        
        // 遍历迁移步骤，逐步迁移
        for (stepIndex, step) in plan.steps.enumerated() {
            // 创建本步骤的进度
            let progress = MigrationProgress(
                currentStep: step.index,
                totalSteps: totalSteps,
                description: "正在迁移数据模型 (\(step.index)/\(totalSteps)) 从 \(step.sourceVersion.description) 到 \(step.destinationVersion.description)",
                sourceVersion: plan.sourceVersion,
                destinationVersion: plan.destinationVersion
            )
            
            // 更新进度 - 转换为 Float 进度值 (0.0 - 1.0)
            let progressValue = Float(stepIndex) / Float(totalSteps)
            progressHandler(progressValue)
            
            // 执行本步骤的迁移
            try await executeStep(step, at: tempStoreURL)
        }
        
        // 迁移完成 - 设置为 100% 完成
        progressHandler(1.0)
        
        // 迁移完成后，替换原始存储
        try FileManager.default.removeItem(at: plan.storeURL)
        try FileManager.default.copyItem(at: tempStoreURL, to: plan.storeURL)
    }
} 