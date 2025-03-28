import Foundation
import CoreData
import Combine
import SwiftUI

/// 架构优化示例
/// 本文件展示如何使用优化后的架构组件，包括依赖注入、错误处理和迁移管理
@main
struct ArchitectureExampleApp {
    static func main() async throws {
        // 1. 初始化依赖注册表
        setupDependencies()
        
        // 2. 使用增强的错误处理
        let errorExample = ErrorHandlingExample()
        try await errorExample.demonstrateErrorHandling()
        
        // 3. 使用增强的迁移管理
        let migrationExample = MigrationExample()
        try await migrationExample.demonstrateMigration()
        
        // 4. 使用增强的模型版本管理
        let versionExample = ModelVersionExample()
        try await versionExample.demonstrateVersionManagement()
        
        // 5. 使用依赖注入的UI示例
        if #available(macOS 11.0, *) {
            ExampleApp.main()
        } else {
            print("UI示例需要macOS 11.0或更高版本")
        }
    }
    
    /// 设置依赖注册表
    static func setupDependencies() {
        // 注册默认服务
        DependencyRegistry.shared.registerFactories()
        
        // 注册现有的单例（兼容性支持）
        DependencyRegistry.shared.registerShared { CoreDataManager.shared }
        
        // 注册增强服务
        DependencyRegistry.shared.register(EnhancedMigrationManager.self) {
            EnhancedMigrationManager.createDefault()
        }
        
        DependencyRegistry.shared.register(ErrorHandlingService.self) {
            EnhancedErrorHandler.createDefault()
        }
        
        DependencyRegistry.shared.register(RecoveryService.self) {
            EnhancedRecoveryService.createDefault()
        }
        
        DependencyRegistry.shared.register(ModelVersionManaging.self) {
            EnhancedModelVersionManager.createDefault()
        }
        
        print("✅ 依赖注册完成")
    }
}

// MARK: - 模型版本管理示例
struct ModelVersionExample {
    // 使用依赖注入获取服务
    private let versionManager: ModelVersionManaging = resolve()
    
    func demonstrateVersionManagement() async throws {
        print("\n📋 开始模型版本管理示例...")
        
        // 创建模拟模型版本
        let v1 = ModelVersion(versionString: "V1_0_0")!
        let v2 = ModelVersion(versionString: "V2_0_0")!
        let v3 = ModelVersion(versionString: "V3_0_0")!
        
        // 计算迁移路径
        let path = versionManager.migrationPath(from: v1, to: v3)
        print("📋 从 \(v1.identifier) 到 \(v3.identifier) 的迁移路径:")
        
        if path.isEmpty {
            print("   路径为空（不需要迁移）")
        } else {
            for (index, version) in path.enumerated() {
                print("   \(index + 1). \(version.identifier)")
            }
        }
        
        // 获取可用版本
        let versions = ["V1_0_0", "V2_0_0", "V3_0_0"].map { ModelVersion(versionString: $0)! }
        print("📋 可用的模型版本: \(versions.map { $0.identifier }.joined(separator: ", "))")
        
        // 演示版本比较
        let comparisons = [
            "\(v1.identifier) < \(v2.identifier): \(v1 < v2)",
            "\(v2.identifier) > \(v1.identifier): \(v2 > v1)",
            "\(v1.identifier) == \(v1.identifier): \(v1 == v1)"
        ]
        
        print("📋 版本比较:")
        for comparison in comparisons {
            print("   \(comparison)")
        }
        
        // 模型版本检测
        print("📋 迁移需求:")
        let needsMigrationV1V2 = !v1.identifier.contains(v2.identifier)
        let needsMigrationV1V1 = !v1.identifier.contains(v1.identifier)
        print("   \(v1.identifier) 到 \(v2.identifier): \(needsMigrationV1V2 ? "需要迁移" : "不需要迁移")")
        print("   \(v1.identifier) 到 \(v1.identifier): \(needsMigrationV1V1 ? "需要迁移" : "不需要迁移")")
        
        print("📋 模型版本管理示例完成\n")
    }
}

// MARK: - 错误处理示例
struct ErrorHandlingExample {
    // 使用依赖注入获取服务
    private let errorService: ErrorHandlingService = resolve()
    private let recoveryService: RecoveryService = resolve()
    
    func demonstrateErrorHandling() async throws {
        print("\n📋 开始错误处理示例...")
        
        // 注册自定义恢复策略
        recoveryService.registerRecoveryStrategy(for: ExampleError.dataCorruption) { error, context in
            print("📋 尝试从数据损坏恢复: \(context)")
            // 模拟恢复逻辑
            return .success
        }
        
        do {
            try performRiskyOperation()
            print("✅ 操作成功完成")
        } catch {
            // 处理错误
            errorService.handle(error, context: "示例操作")
            print("❌ 捕获到错误: \(error.localizedDescription)")
            
            // 尝试恢复
            let recoveryResult = await errorService.attemptRecovery(from: error, context: "示例操作")
            print("🔄 恢复结果: \(recoveryResult)")
        }
        
        print("📋 错误处理示例完成\n")
    }
    
    private func performRiskyOperation() throws {
        // 模拟错误情况
        let random = Int.random(in: 1...3)
        
        if random == 1 {
            throw ExampleError.dataCorruption
        } else if random == 2 {
            throw NSError(domain: "com.example", code: 1001, userInfo: [NSLocalizedDescriptionKey: "模拟的NSError"])
        }
        
        // 无错误情况
        print("📋 操作成功，没有错误")
    }
}

// MARK: - 迁移示例
struct MigrationExample {
    // 使用依赖注入获取服务
    private let migrationManager: EnhancedMigrationManager = resolve()
    private let versionManager: ModelVersionManaging = resolve()
    
    func demonstrateMigration() async throws {
        print("\n📋 开始迁移示例...")
        
        // 获取示例存储URL
        let storeURL = try getExampleStoreURL()
        
        // 检查是否需要迁移
        let needsMigration = try await migrationManager.needsMigration(at: storeURL)
        print("📋 需要迁移: \(needsMigration)")
        
        if needsMigration {
            // 配置迁移选项
            let options = MigrationOptions(
                shouldCreateBackup: true,
                shouldRestoreFromBackupOnFailure: true,
                mode: .customMapping
            )
            
            // 迁移进度更新
            let cancellable = migrationManager.progressPublisher
                .sink { progress in
                    if let progress = progress {
                        let percentage = Int(progress.percentComplete * 100)
                        print("📋 迁移进度: \(percentage)%")
                    }
                }
            
            // 执行迁移
            let result = try await migrationManager.migrate(storeAt: storeURL, options: options)
            
            // 取消订阅
            cancellable.cancel()
            
            print("📋 迁移结果: \(result)")
        } else {
            print("📋 不需要迁移")
        }
        
        print("📋 迁移示例完成\n")
    }
    
    private func getExampleStoreURL() throws -> URL {
        // 获取一个临时目录用于示例
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("ExampleStore.sqlite")
    }
}

// MARK: - SwiftUI示例
@available(macOS 11.0, *)
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

@available(macOS 11.0, *)
struct ContentView: View {
    // 使用依赖注入获取服务
    @StateObject private var viewModel = ExampleViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("架构优化示例").font(.largeTitle)
            
            Divider()
            
            Text("错误处理演示").font(.headline)
            Button("触发错误") {
                viewModel.triggerError()
            }
            .buttonStyle(.borderedProminent)
            
            Divider()
            
            Text("迁移演示").font(.headline)
            Button("检查迁移") {
                viewModel.checkMigration()
            }
            .buttonStyle(.borderedProminent)
            
            if viewModel.isShowingProgress {
                ProgressView(value: viewModel.migrationProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                Text("\(Int(viewModel.migrationProgress * 100))%")
            }
            
            Divider()
            
            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}

@available(macOS 11.0, *)
class ExampleViewModel: ObservableObject {
    // 使用依赖注入获取服务
    private let errorService: ErrorHandlingService = resolve()
    private let migrationManager: EnhancedMigrationManager = resolve()
    private let versionManager: ModelVersionManaging = resolve()
    
    @Published var statusMessage = ""
    @Published var migrationProgress: Double = 0.0
    @Published var isShowingProgress = false
    
    private var progressCancellable: AnyCancellable?
    
    func triggerError() {
        do {
            try performRiskyOperation()
            statusMessage = "操作成功完成"
        } catch {
            errorService.handle(error, context: "UI操作")
            statusMessage = "错误: \(error.localizedDescription)"
            
            // 尝试恢复
            Task {
                let result = await errorService.attemptRecovery(from: error, context: "UI操作")
                
                DispatchQueue.main.async {
                    self.statusMessage = "恢复结果: \(result)"
                }
            }
        }
    }
    
    func checkMigration() {
        isShowingProgress = true
        migrationProgress = 0.0
        
        // 订阅进度更新
        progressCancellable = migrationManager.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                if let progress = progress {
                    self?.migrationProgress = progress.percentComplete
                }
            }
        
        // 执行迁移检查
        Task {
            do {
                let storeURL = try getExampleStoreURL()
                let needsMigration = try await migrationManager.needsMigration(at: storeURL)
                
                if needsMigration {
                    let options = MigrationOptions(shouldCreateBackup: true)
                    let result = try await migrationManager.migrate(storeAt: storeURL, options: options)
                    
                    DispatchQueue.main.async {
                        self.statusMessage = "迁移结果: \(result)"
                        self.isShowingProgress = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.statusMessage = "不需要迁移"
                        self.isShowingProgress = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "迁移错误: \(error.localizedDescription)"
                    self.isShowingProgress = false
                }
            }
            
            // 取消进度订阅
            self.progressCancellable?.cancel()
        }
    }
    
    private func performRiskyOperation() throws {
        // 模拟错误情况
        let random = Int.random(in: 1...3)
        
        if random == 1 {
            throw ExampleError.dataCorruption
        } else if random == 2 {
            throw NSError(domain: "com.example", code: 1001, userInfo: [NSLocalizedDescriptionKey: "模拟的NSError"])
        }
    }
    
    private func getExampleStoreURL() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("ExampleStore.sqlite")
    }
}

// MARK: - 辅助类型

/// 示例错误类型
enum ExampleError: Error {
    case dataCorruption
    case operationFailed
    case unknown
}

extension ExampleError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .dataCorruption:
            return "数据损坏"
        case .operationFailed:
            return "操作失败"
        case .unknown:
            return "未知错误"
        }
    }
}

/// 简单值类型示例
struct RecoveryResult: Equatable {
    enum State {
        case success
        case partialSuccess
        case requiresUserInteraction
        case failure
    }
    
    let state: State
    let message: String?
    let error: Error?
    
    static let success = RecoveryResult(state: .success, message: nil, error: nil)
    static let requiresUserInteraction = RecoveryResult(state: .requiresUserInteraction, message: nil, error: nil)
    
    static func failure(_ error: Error) -> RecoveryResult {
        return RecoveryResult(state: .failure, message: nil, error: error)
    }
    
    static func partialSuccess(_ message: String) -> RecoveryResult {
        return RecoveryResult(state: .partialSuccess, message: message, error: nil)
    }
    
    static func == (lhs: RecoveryResult, rhs: RecoveryResult) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success):
            return true
        case (.partialSuccess(let lhsMsg), .partialSuccess(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.requiresUserInteraction, .requiresUserInteraction):
            return true
        case (.failure, .failure):
            return true
        default:
            return false
        }
    }
}

// 注意：此示例中的定义已重命名为ExampleMigrationResult，避免与统一定义冲突
// 实际应用中应使用CoreDataModule/Migration/MigrationResultFix.swift中的统一定义
/// 简化版迁移结果枚举（仅用于示例）
enum ExampleMigrationResult: Equatable {
    case success
    case notNeeded
}

// 打印扩展
extension RecoveryResult: CustomStringConvertible {
    var description: String {
        switch self {
        case .success:
            return "成功"
        case .partialSuccess(let message):
            return "部分成功: \(message)"
        case .requiresUserInteraction:
            return "需要用户交互"
        case .failure(let error):
            return "失败: \(error.localizedDescription)"
        }
    }
}

extension ExampleMigrationResult: CustomStringConvertible {
    var description: String {
        switch self {
        case .success:
            return "成功"
        case .notNeeded:
            return "不需要"
        }
    }
}

// MARK: - 示例执行
@MainActor
public func runArchitectureExamples() async throws {
    // 初始化依赖注册表
    let registry = DependencyRegistry.shared
    registry.registerDefaults()
    
    // 运行各种示例
    print("开始执行架构示例...")
    
    // 依赖注入示例
    let injectionExample = DependencyInjectionExample()
    try await injectionExample.demonstrateDependencyInjection()
    
    // 错误处理示例
    let errorExample = ErrorHandlingExample()
    try await errorExample.demonstrateErrorHandling()
    
    // 迁移示例
    let migrationExample = MigrationExample()
    try await migrationExample.demonstrateMigration()
    
    // 模型版本示例
    let versionExample = ModelVersionExample()
    try await versionExample.demonstrateVersionManagement()
    
    // 同步示例
    let syncExample = SyncExample()
    try await syncExample.demonstrateSync()
    
    print("架构示例执行完成！")
}

// MARK: - 同步示例
/// 同步示例
public struct SyncExample {
    /// 演示同步
    public func demonstrateSync() async throws {
        print("\n📱 开始同步演示...")
        
        // 从依赖注册表获取同步管理器
        let syncManager = DependencyRegistry.shared.resolve(EnhancedSyncManager.self)
        
        // 创建各种同步选项
        let downloadOptions = SyncOptions(direction: .download)
        let uploadOptions = SyncOptions(direction: .upload)
        let bidirectionalOptions = SyncOptions(
            direction: .bidirectional,
            autoMergeStrategy: .mostRecent
        )
        
        print("🔄 执行下载同步")
        try await executeSync(syncManager, with: downloadOptions)
        
        print("🔄 执行上传同步")
        try await executeSync(syncManager, with: uploadOptions)
        
        print("🔄 执行双向同步")
        try await executeSync(syncManager, with: bidirectionalOptions)
        
        // 演示同步状态和进度监控
        await demonstrateSyncMonitoring(syncManager)
        
        print("📱 同步演示完成！")
    }
    
    /// 执行同步并处理结果
    private func executeSync(_ manager: EnhancedSyncManager, with options: SyncOptions) async throws {
        do {
            let success = try await manager.sync(with: options)
            if success {
                print("✅ 同步成功")
            } else {
                print("⚠️ 同步已在进行中")
            }
        } catch {
            print("❌ 同步失败: \(error.localizedDescription)")
        }
    }
    
    /// 演示同步监控
    private func demonstrateSyncMonitoring(_ manager: EnhancedSyncManager) async {
        print("\n📊 开始监控同步状态和进度...")
        
        // 创建订阅
        var statusCancellable: AnyCancellable?
        var progressCancellable: AnyCancellable?
        
        let expectation = expectation(description: "Sync Monitoring")
        
        // 订阅状态变化
        statusCancellable = manager.statePublisher
            .sink { state in
                print("👀 状态更新: \(state)")
                
                if case .completed = state {
                    expectation.fulfill()
                }
            }
        
        // 订阅进度变化
        progressCancellable = manager.progressPublisher
            .sink { progress in
                let percentage = Int(progress * 100)
                print("📈 进度更新: \(percentage)%")
            }
        
        // 异步执行同步
        Task {
            do {
                _ = try await manager.sync()
            } catch {
                print("监控期间同步失败: \(error)")
                expectation.fulfill()
            }
        }
        
        // 等待5秒或直到收到完成状态
        _ = await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                expectation.fulfill()
                continuation.resume()
            }
        }
        
        // 清理订阅
        statusCancellable?.cancel()
        progressCancellable?.cancel()
        
        print("📊 同步监控演示完成")
    }
}

// 创建期望
private func expectation(description: String) -> ExpectationProtocol {
    return ExpectationImpl(description: description)
}

// 简单的期望协议和实现
private protocol ExpectationProtocol {
    func fulfill()
}

private class ExpectationImpl: ExpectationProtocol {
    let description: String
    var fulfilled = false
    
    init(description: String) {
        self.description = description
    }
    
    func fulfill() {
        if !fulfilled {
            fulfilled = true
            print("✅ 期望满足: \(description)")
        }
    }
} 