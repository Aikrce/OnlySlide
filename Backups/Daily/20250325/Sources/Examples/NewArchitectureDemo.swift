import Foundation
import CoreData
import Combine
import SwiftUI
import CoreDataModule

/// 新架构演示应用
/// 本文件展示如何在新项目中使用优化后的架构
@main
struct NewArchitectureDemoApp {
    static func main() async throws {
        // 1. 设置依赖注册表
        setupDependencyRegistry()
        
        // 2. 演示值类型和依赖注入
        try await demonstrateValueTypesAndDI()
        
        // 3. 演示并发安全
        try await demonstrateConcurrencySafety()
        
        // 4. 演示系统组件集成
        try await demonstrateSystemIntegration()
        
        // 5. 启动UI（如果在GUI环境）
        if #available(macOS 11.0, *) {
            DemoApp.main()
        } else {
            print("GUI演示需要macOS 11.0或更高版本")
        }
    }
    
    /// 设置依赖注册表
    static func setupDependencyRegistry() {
        print("\n📋 设置依赖注册表...")
        
        // 注册核心服务
        DependencyRegistry.shared.register(ModelVersionManaging.self) {
            EnhancedModelVersionManager.createDefault()
        }
        
        DependencyRegistry.shared.register(ErrorHandlingService.self) {
            EnhancedErrorHandler.createDefault()
        }
        
        DependencyRegistry.shared.register(RecoveryService.self) {
            EnhancedRecoveryService.createDefault()
        }
        
        // 注册工厂
        DependencyRegistry.shared.registerFactories()
        
        print("✅ 依赖注册完成\n")
    }
    
    /// 演示值类型和依赖注入
    static func demonstrateValueTypesAndDI() async throws {
        print("\n📋 演示值类型和依赖注入...")
        
        // 使用依赖注入获取服务
        let versionManager: ModelVersionManaging = resolve()
        let errorHandler: EnhancedErrorHandler = resolve()
        let migrationManager: EnhancedMigrationManager = resolve()
        
        // 使用值类型
        let options = MigrationOptions(
            shouldCreateBackup: true,
            shouldRestoreFromBackupOnFailure: true,
            mode: .customMapping
        )
        
        // 值类型操作
        let v1 = ModelVersion(versionString: "V1_0_0")!
        let v2 = ModelVersion(versionString: "V2_0_0")!
        
        // 值类型的比较和操作
        let needsMigration = v1 < v2
        let path = versionManager.migrationPath(from: v1, to: v2)
        
        print("📋 从 \(v1.identifier) 到 \(v2.identifier) 的迁移：")
        print("   需要迁移: \(needsMigration)")
        print("   迁移路径: \(path.map { $0.identifier }.joined(separator: " -> "))")
        print("   使用选项: 备份=\(options.shouldCreateBackup), 模式=\(options.mode)")
        
        print("✅ 值类型和依赖注入演示完成\n")
    }
    
    /// 演示并发安全
    static func demonstrateConcurrencySafety() async throws {
        print("\n📋 演示并发安全...")
        
        // 使用依赖注入获取服务
        let errorHandler: EnhancedErrorHandler = resolve()
        
        // 创建并发任务
        async let task1 = processError(id: 1, errorHandler: errorHandler)
        async let task2 = processError(id: 2, errorHandler: errorHandler)
        async let task3 = processError(id: 3, errorHandler: errorHandler)
        
        // 等待所有任务完成
        let (result1, result2, result3) = try await (task1, task2, task3)
        
        print("📋 并发任务结果:")
        print("   任务1: \(result1 ? "成功" : "失败")")
        print("   任务2: \(result2 ? "成功" : "失败")")
        print("   任务3: \(result3 ? "成功" : "失败")")
        
        print("✅ 并发安全演示完成\n")
    }
    
    /// 处理错误（并发任务）
    static func processError(id: Int, errorHandler: EnhancedErrorHandler) async -> Bool {
        print("📋 任务\(id)开始处理错误")
        
        // 模拟错误
        let error = NSError(domain: "测试域", code: id, userInfo: [NSLocalizedDescriptionKey: "测试错误\(id)"])
        
        // 处理错误
        errorHandler.handle(error, context: "任务\(id)")
        
        // 模拟恢复
        let result = await errorHandler.attemptRecovery(from: error, context: "任务\(id)")
        let success = result == .success
        
        print("📋 任务\(id)处理完成: \(success ? "恢复成功" : "恢复失败")")
        
        return success
    }
    
    /// 演示系统集成
    static func demonstrateSystemIntegration() async throws {
        print("\n📋 演示系统集成...")
        
        // 获取核心服务
        let dataService = DataService()
        
        // 模拟数据存储
        try await dataService.saveData()
        
        // 模拟数据迁移检查
        let migrationNeeded = try await dataService.checkMigration()
        print("📋 迁移需求: \(migrationNeeded ? "需要迁移" : "不需要迁移")")
        
        // 模拟错误恢复
        let recoveryResult = try await dataService.handleTestError()
        print("📋 错误恢复: \(recoveryResult ? "成功" : "失败")")
        
        print("✅ 系统集成演示完成\n")
    }
}

/// 数据服务
struct DataService {
    // 依赖注入
    private let migrationManager: EnhancedMigrationManager = resolve()
    private let errorHandler: EnhancedErrorHandler = resolve()
    private let versionManager: ModelVersionManaging = resolve()
    
    /// 获取测试存储URL
    private func getTestStoreURL() -> URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent("TestStore.sqlite")
    }
    
    /// 保存数据
    func saveData() async throws {
        print("📋 保存数据...")
        // 模拟数据保存操作
    }
    
    /// 检查迁移
    func checkMigration() async throws -> Bool {
        let storeURL = getTestStoreURL()
        
        do {
            return try await migrationManager.needsMigration(at: storeURL)
        } catch {
            errorHandler.handle(error, context: "迁移检查")
            throw error
        }
    }
    
    /// 处理测试错误
    func handleTestError() async throws -> Bool {
        // 创建测试错误
        let error = CoreDataError.modelNotFound("测试错误")
        
        // 处理错误
        errorHandler.handle(error, context: "测试")
        
        // 尝试恢复
        let result = await errorHandler.attemptRecovery(from: error, context: "测试")
        return result == .success
    }
}

// MARK: - SwiftUI演示

@available(macOS 11.0, *)
struct DemoApp: App {
    @StateObject private var viewModel = DemoViewModel()
    
    var body: some Scene {
        WindowGroup {
            DemoView(viewModel: viewModel)
        }
    }
}

@available(macOS 11.0, *)
class DemoViewModel: ObservableObject {
    // 依赖注入
    private let migrationManager: EnhancedMigrationManager = resolve()
    private let errorHandler: EnhancedErrorHandler = resolve()
    
    @Published var statusMessage = "准备就绪"
    @Published var progress: Double = 0.0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 订阅迁移进度
        migrationManager.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                if let progress = progress {
                    self?.progress = progress.fractionCompleted
                }
            }
            .store(in: &cancellables)
    }
    
    func checkMigration() {
        statusMessage = "正在检查迁移..."
        
        Task {
            do {
                let storeURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("TestStore.sqlite")
                
                let needsMigration = try await migrationManager.needsMigration(at: storeURL)
                
                DispatchQueue.main.async {
                    self.statusMessage = "迁移检查: \(needsMigration ? "需要迁移" : "不需要迁移")"
                }
            } catch {
                errorHandler.handle(error, context: "迁移检查")
                
                DispatchQueue.main.async {
                    self.statusMessage = "错误: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func simulateError() {
        let error = CoreDataError.migrationFailed("模拟错误")
        errorHandler.handle(error, context: "测试")
        
        statusMessage = "模拟错误触发: \(error.localizedDescription)"
        
        Task {
            let result = await errorHandler.attemptRecovery(from: error, context: "测试")
            
            DispatchQueue.main.async {
                self.statusMessage = "恢复结果: \(result)"
            }
        }
    }
}

@available(macOS 11.0, *)
struct DemoView: View {
    @ObservedObject var viewModel: DemoViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("新架构演示").font(.largeTitle)
            
            Divider()
            
            Button("检查迁移") {
                viewModel.checkMigration()
            }
            .buttonStyle(.borderedProminent)
            
            Button("模拟错误") {
                viewModel.simulateError()
            }
            .buttonStyle(.bordered)
            
            if viewModel.progress > 0 {
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                Text("\(Int(viewModel.progress * 100))%")
            }
            
            Text(viewModel.statusMessage)
                .padding()
                .frame(width: 300, height: 80)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .frame(width: 400, height: 400)
    }
} 