import SwiftUI
import CoreDataModule

@main
struct MigrationDemoApp: App {
    var body: some Scene {
        WindowGroup {
            MainMigrationCoordinator {
                HomeView()
            }
        }
    }
}

struct HomeView: View {
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding()
                
                Text("OnlySlide")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("您的数据已准备就绪")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer().frame(height: 40)
                
                // 示例按钮
                Button(action: {
                    // 打开新文档
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("新建文档")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                
                Button(action: {
                    // 打开现有文档
                }) {
                    HStack {
                        Image(systemName: "folder.fill")
                        Text("打开文档")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // 版本信息
                Text("版本 1.0.0 (使用 Core Data 模型 V2)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(
                trailing: Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gear")
                }
            )
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var migrationInfo = "加载中..."
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("数据库信息")) {
                    Text(migrationInfo)
                        .font(.callout)
                }
                
                Section(header: Text("数据管理")) {
                    Button("触发测试迁移") {
                        triggerTestMigration()
                    }
                    
                    Button("清理备份文件") {
                        cleanupBackups()
                    }
                    
                    Button("重置数据库") {
                        resetDatabase()
                    }
                    .foregroundColor(.red)
                }
                
                Section(header: Text("关于")) {
                    Text("OnlySlide 是一个专业的跨平台幻灯片创建工具，旨在提供简洁、高效且功能强大的演示文稿创建体验。")
                        .font(.callout)
                }
            }
            .navigationBarTitle("设置", displayMode: .inline)
            .navigationBarItems(
                trailing: Button("完成") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                loadMigrationInfo()
            }
        }
    }
    
    private func loadMigrationInfo() {
        Task {
            do {
                let adapter = CoreDataUIAdapter()
                let info = try await adapter.getDatabaseInfo()
                
                await MainActor.run {
                    migrationInfo = """
                    数据库大小: \(info.formattedSize)
                    当前版本: \(info.currentVersion)
                    目标版本: \(info.targetVersion)
                    迁移复杂度: \(info.complexityDescription)
                    """
                }
            } catch {
                await MainActor.run {
                    migrationInfo = "无法加载信息: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func triggerTestMigration() {
        Task {
            do {
                let adapter = CoreDataUIAdapter()
                try await adapter.startMigration()
                
                await MainActor.run {
                    migrationInfo = "迁移测试已完成"
                }
            } catch {
                await MainActor.run {
                    migrationInfo = "迁移失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func cleanupBackups() {
        Task {
            do {
                let resourceManager = CoreDataResourceManager.shared
                resourceManager.cleanupBackups(keepLatest: 3)
                
                await MainActor.run {
                    migrationInfo = "备份清理成功"
                }
            } catch {
                await MainActor.run {
                    migrationInfo = "备份清理失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func resetDatabase() {
        // 实际实现中应该添加确认对话框
        
        Task {
            do {
                // 在实际实现中，应该提供重置数据库的功能
                // 这里只是简单模拟
                
                await MainActor.run {
                    migrationInfo = "数据库重置成功"
                }
            } catch {
                await MainActor.run {
                    migrationInfo = "数据库重置失败: \(error.localizedDescription)"
                }
            }
        }
    }
} 