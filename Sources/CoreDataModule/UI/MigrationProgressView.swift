import SwiftUI

/// 迁移进度视图
/// 用于在迁移过程中显示进度
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct MigrationProgressView: View {
    
    // MARK: - Properties
    
    /// 迁移管理器
    @ObservedObject private var migrationManager: MigrationManager
    
    /// 是否显示详细信息
    @State private var showDetails: Bool = false
    
    /// 内容视图构建器
    private let contentBuilder: () -> AnyView
    
    // MARK: - Initialization
    
    /// 初始化迁移进度视图
    /// - Parameters:
    ///   - migrationManager: 迁移管理器
    ///   - content: 内容视图构建器，在迁移完成后显示
    public init<Content: View>(
        migrationManager: MigrationManager,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.migrationManager = migrationManager
        self.contentBuilder = { AnyView(content()) }
    }
    
    // MARK: - Body
    
    public var body: some View {
        Group {
            switch migrationManager.status {
            case .inProgress:
                migrationProgressContent
            case .completed:
                contentBuilder()
            case .failed(let error):
                migrationErrorContent(error: error)
            }
        }
        .onAppear {
            Task {
                await migrationManager.checkAndMigrateStoreIfNeeded()
            }
        }
    }
    
    // MARK: - Migration Progress Content
    
    /// 迁移进度内容
    private var migrationProgressContent: some View {
        VStack(spacing: 20) {
            Text("数据库升级中")
                .font(.headline)
            
            if let progress = migrationManager.progress {
                ProgressView(value: progress.percentage / 100)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 8)
                
                Text("\(Int(progress.percentage))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(progress.currentStep)/\(progress.totalSteps) \(progress.description)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !showDetails {
                    Button("显示详细信息") {
                        withAnimation {
                            showDetails = true
                        }
                    }
                    .buttonStyle(.borderless)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("从模型版本: \(progress.sourceVersion?.description ?? "未知")")
                        Text("到模型版本: \(progress.destinationVersion.description)")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    
                    Button("隐藏详细信息") {
                        withAnimation {
                            showDetails = false
                        }
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                
                Text("准备中...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - Migration Error Content
    
    /// 迁移错误内容
    /// - Parameter error: 错误
    /// - Returns: 迁移错误视图
    private func migrationErrorContent(error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("迁移失败")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重试") {
                Task {
                    await migrationManager.checkAndMigrateStoreIfNeeded()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Previews

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
struct MigrationProgressView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建一个用于预览的迁移管理器
        let migrationManager = MigrationManager()
        
        // 设置迁移状态
        return Group {
            // 迁移进行中预览
            MigrationProgressView(migrationManager: migrationManager) {
                Text("迁移完成后显示的内容")
            }
            .previewDisplayName("迁移进行中")
            
            // 迁移完成预览
            MigrationProgressView(migrationManager: migrationManager) {
                Text("迁移完成后显示的内容")
            }
            .previewDisplayName("迁移完成")
            
            // 迁移失败预览
            MigrationProgressView(migrationManager: migrationManager) {
                Text("迁移完成后显示的内容")
            }
            .previewDisplayName("迁移失败")
        }
    }
} 