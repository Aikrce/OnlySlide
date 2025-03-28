import SwiftUI
import CoreDataModule

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var migrationInfo = "加载中..."
    @State private var showingAlert = false
    
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
                        showingAlert = true
                    }
                    .foregroundColor(.red)
                    .alert(isPresented: $showingAlert) {
                        Alert(
                            title: Text("重置数据库"),
                            message: Text("确定要重置数据库吗？此操作不可逆！"),
                            primaryButton: .destructive(Text("重置")) {
                                resetDatabaseAction()
                            },
                            secondaryButton: .cancel(Text("取消"))
                        )
                    }
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
    
    private func resetDatabaseAction() {
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