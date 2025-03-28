import SwiftUI

/// 迁移进度视图
/// 用于在迁移过程中显示进度
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct MigrationProgressView: View {
    
    // MARK: - Properties
    
    /// 迁移管理器
    @ObservedObject var migrationManager: MigrationManager
    
    /// 是否显示详情
    @State private var showDetails: Bool = false
    
    /// 内容视图构建器
    private let contentBuilder: () -> AnyView
    
    /// 状态描述
    private var statusDescription: String {
        if let progress = migrationManager.progress {
            return progress.description
        } else {
            return "准备迁移..."
        }
    }
    
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
        VStack(spacing: 16) {
            // 标题
            Text("数据库迁移")
                .font(.headline)
                .padding(.top)
            
            // 状态描述
            Text(statusDescription)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // 进度条
            if let progressData = migrationManager.progress {
                ProgressView(value: progressData.fraction)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 8)
                
                // 进度百分比
                Text("\(Int(progressData.fraction * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
            
            // 显示详情按钮
            Button(action: {
                withAnimation {
                    showDetails.toggle()
                }
            }) {
                HStack {
                    Text(showDetails ? "隐藏详情" : "显示详情")
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.top, 8)
            
            // 详情视图
            if showDetails {
                detailsView
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: 400)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    /// 详情视图
    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 详细信息标题
            Text("详细信息")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            
            // 详细信息内容
            if let progressData = migrationManager.progress {
                VStack {
                    detailRow(title: "当前步骤", value: "\(progressData.currentStep)")
                    detailRow(title: "总步骤", value: "\(progressData.totalSteps)")
                }
            }
            
            // 状态日志
            Text("迁移状态")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            // 显示状态
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    switch migrationManager.status {
                    case .inProgress:
                        Text("正在进行迁移...")
                    case .completed:
                        Text("迁移已完成")
                    case .failed(let error):
                        Text("迁移失败: \(error.localizedDescription)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 100)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    /// 详细信息行
    /// - Parameters:
    ///   - title: 标题
    ///   - value: 值
    /// - Returns: 详细信息行视图
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
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