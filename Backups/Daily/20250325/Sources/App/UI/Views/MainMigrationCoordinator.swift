import SwiftUI
import CoreDataModule

/// 迁移协调器视图
/// 根据应用状态显示不同的迁移相关视图
struct MainMigrationCoordinator<Content: View>: View {
    @StateObject private var adapter = CoreDataUIAdapter()
    @State private var showHomeScreen = false
    @State private var needsMigration = false
    @State private var isCheckingMigration = true
    
    let content: () -> Content
    
    var body: some View {
        ZStack {
            // 主要内容
            if showHomeScreen {
                content()
                    .transition(.opacity)
            }
            // 加载中
            else if isCheckingMigration {
                checkingMigrationView
                    .transition(.opacity)
            }
            // 需要迁移
            else if needsMigration {
                // 根据迁移状态显示不同视图
                switch adapter.migrationState {
                case .notStarted, .preparing:
                    MigrationConfirmationView(adapter: adapter)
                        .transition(.opacity)
                        .padding()
                
                case .migrating:
                    MigrationProgressView(adapter: adapter)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                
                case .completed:
                    migrationCompletedView
                        .transition(.opacity)
                        .padding()
                
                case .failed:
                    if let error = adapter.errorMessage {
                        ErrorAlertView(
                            errorMessage: .constant(error),
                            onRetry: { 
                                Task { await adapter.startMigration() }
                            },
                            onDismiss: {
                                // 如果用户选择跳过，则显示主界面
                                withAnimation { showHomeScreen = true }
                            }
                        )
                        .transition(.scale)
                        .padding()
                    }
                }
            }
            // 不需要迁移
            else {
                // 直接显示主界面
                content()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: showHomeScreen)
        .animation(.easeInOut, value: needsMigration)
        .animation(.easeInOut, value: isCheckingMigration)
        .animation(.easeInOut, value: adapter.migrationState)
        .onAppear {
            checkIfMigrationNeeded()
        }
    }
    
    // 检查是否需要迁移
    private func checkIfMigrationNeeded() {
        isCheckingMigration = true
        
        Task {
            do {
                // 检查是否需要迁移
                let requiresMigration = try await adapter.checkIfMigrationNeeded()
                
                await MainActor.run {
                    needsMigration = requiresMigration
                    isCheckingMigration = false
                    
                    // 如果不需要迁移，直接显示主界面
                    if !requiresMigration {
                        withAnimation {
                            showHomeScreen = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    // 如果检查失败，显示错误并允许继续
                    adapter.errorMessage = error.localizedDescription
                    needsMigration = false
                    isCheckingMigration = false
                    
                    // 显示主界面
                    withAnimation {
                        showHomeScreen = true
                    }
                }
            }
        }
    }
    
    // 检查迁移视图
    private var checkingMigrationView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("正在检查数据库...")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("应用正在准备您的数据，请稍候...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
    
    // 迁移完成视图
    private var migrationCompletedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("迁移完成！")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("您的数据已成功更新到最新版本。")
                .font(.body)
                .multilineTextAlignment(.center)
            
            Button("继续") {
                withAnimation {
                    showHomeScreen = true
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

// 扩展 CoreDataUIAdapter 添加检查迁移需求的方法
extension CoreDataUIAdapter {
    func checkIfMigrationNeeded() async throws -> Bool {
        return try await coreDataManager.requiresMigration()
    }
} 