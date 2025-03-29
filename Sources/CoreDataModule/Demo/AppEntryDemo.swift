import SwiftUI
import Foundation

/// 应用入口点演示
/// 展示如何在应用启动时使用迁移管理器进行数据库迁移
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct AppEntryDemo: App {
    // MARK: - Properties
    
    /// 迁移管理器
    @StateObject private var migrationManager = CoreDataMigrationManager.shared
    
    // MARK: - Body
    
    public var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                
                // 显示迁移进度视图
                MigrationProgressView(migrationManager: migrationManager)
            }
        }
    }
    
    // MARK: - Initialization
    
    /// 初始化应用入口点演示
    public init() {}
}

/// 内容视图
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
private struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("数据库迁移成功")) {
                    Text("应用顺利启动")
                    Text("数据库迁移已完成")
                    Text("您现在可以使用应用的全部功能")
                }
                
                Section(header: Text("更多信息")) {
                    NavigationLink(destination: DataViewDemo()) {
                        Label("查看数据", systemImage: "doc.text.magnifyingglass")
                    }
                    
                    NavigationLink(destination: SettingsViewDemo()) {
                        Label("设置", systemImage: "gear")
                    }
                }
            }
            .navigationTitle("OnlySlide")
        }
    }
}

/// 数据视图演示
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
private struct DataViewDemo: View {
    var body: some View {
        List {
            ForEach(1...10, id: \.self) { index in
                HStack {
                    Image(systemName: "doc")
                        .foregroundColor(.blue)
                    Text("幻灯片 \(index)")
                }
            }
        }
        .navigationTitle("数据")
    }
}

/// 设置视图演示
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
private struct SettingsViewDemo: View {
    var body: some View {
        Form {
            Section(header: Text("账户")) {
                Text("用户名: OnlySlideUser")
                Text("邮箱: user@example.com")
            }
            
            Section(header: Text("数据库")) {
                HStack {
                    Text("当前版本")
                    Spacer()
                    Text("v2.0")
                        .foregroundColor(.secondary)
                }
                
                Button("导出数据库") {
                    // 导出数据库的操作
                }
                
                Button("清除数据") {
                    // 清除数据的操作
                }
                .foregroundColor(.red)
            }
            
            Section(header: Text("关于")) {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("开发者")
                    Spacer()
                    Text("Ni Qian")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("设置")
    }
} 