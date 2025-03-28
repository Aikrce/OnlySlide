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
                
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("源版本:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(progress.sourceVersion.description)")
                            .font(.caption2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("目标版本:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(progress.destinationVersion.description)")
                            .font(.caption2)
                    }
                }
                .padding(.horizontal)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Text("准备中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                withAnimation {
                    showDetails.toggle()
                }
            }) {
                Text(showDetails ? "隐藏详情" : "显示详情")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            
            if showDetails {
                migrationDetailsContent
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding()
    }
    
    /// 迁移详情内容
    private var migrationDetailsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("迁移详情")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
            
            Divider()
            
            if let progress = migrationManager.progress {
                Group {
                    detailRow(title: "当前步骤", value: "\(progress.currentStep)")
                    detailRow(title: "总步骤", value: "\(progress.totalSteps)")
                    detailRow(title: "进度", value: "\(Int(progress.percentage))%")
                    detailRow(title: "源版本", value: progress.sourceVersion.description)
                    detailRow(title: "目标版本", value: progress.destinationVersion.description)
                    detailRow(title: "描述", value: progress.description)
                }
            } else {
                Text("正在加载迁移信息...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }
    
    /// 详情行
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
        }
    }
    
    // MARK: - Migration Error Content
    
    /// 迁移错误内容
    private func migrationErrorContent(error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("迁移失败")
                .font(.headline)
            
            Text("数据库升级过程中发生错误")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("重试") {
                Task {
                    await migrationManager.checkAndMigrateStoreIfNeeded()
                }
            }
            .buttonStyle(BorderedButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding()
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