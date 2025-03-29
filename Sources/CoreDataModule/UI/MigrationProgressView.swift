import SwiftUI
import CoreData
import Combine

/// 迁移进度视图
/// 用于在迁移过程中显示进度
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct MigrationProgressView: View {
    
    // MARK: - Properties
    
    /// 迁移管理器
    @ObservedObject private var migrationManager: CoreDataMigrationManager
    
    /// 是否显示详细信息
    @State private var showDetails = false
    
    /// 迁移进度
    @State private var progress: CDMigrationProgress
    
    /// 迁移状态
    @State private var state: EnhancedMigrationState
    
    /// 初始化进度视图
    /// - Parameter migrationManager: 迁移管理器
    public init(migrationManager: CoreDataMigrationManager = CoreDataMigrationManager.shared) {
        self.migrationManager = migrationManager
        // 使用State的包装值初始化，而不是直接调用函数
        _progress = State(initialValue: migrationManager.getCurrentProgress())
        _state = State(initialValue: migrationManager.getCurrentState())
    }
    
    /// 状态描述
    private var statusDescription: String {
        return progress.description
    }
    
    /// 是否正在迁移
    private var isInProgress: Bool {
        switch state {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }
    
    /// 进度条
    private var progressValue: Double {
        return progress.fraction
    }
    
    // MARK: - Body
    
    /// 视图主体
    public var body: some View {
        VStack(spacing: 16) {
            // 标题
            Text("数据库迁移")
                .font(.headline)
                .padding(.top)
            
            // 状态描述
            Text(statusDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(height: 20)
                .padding(.horizontal)
            
            // 进度条
            if isInProgress {
                ProgressView(value: progressValue)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 8)
                    .padding(.horizontal)
            }
            
            // 详情按钮
            Button(action: {
                withAnimation {
                    showDetails.toggle()
                }
            }) {
                HStack {
                    Text(showDetails ? "隐藏详情" : "显示详情")
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                }
                .font(.footnote)
                .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, showDetails ? 0 : 16)
            
            // 详细信息
            if showDetails {
                detailsView
                    .transition(.opacity)
                    .padding(.bottom)
            }
        }
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 2)
        .padding()
        .onAppear {
            updateProgress()
            updateState()
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            updateProgress()
            updateState()
        }
    }
    
    /// 更新进度
    private func updateProgress() {
        // 直接赋值，不调用函数
        progress = migrationManager.getCurrentProgress()
    }
    
    /// 更新状态
    private func updateState() {
        // 直接赋值，不调用函数
        state = migrationManager.getCurrentState()
    }
    
    /// 详细信息视图
    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 迁移状态
            detailRow(title: "迁移状态", value: stateDescription)
            
            // 迁移步骤
            VStack {
                detailRow(title: "当前步骤", value: "\(progress.currentStep)")
                detailRow(title: "总步骤", value: "\(progress.totalSteps)")
            }
            
            // 迁移进度
            detailRow(title: "完成百分比", value: "\(Int(progressValue * 100))%")
            
            // 错误信息
            if case .failed(let error) = state {
                detailRow(title: "错误信息", value: error.localizedDescription)
                    .foregroundColor(.red)
            }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
    
    /// 转换状态为描述
    private var stateDescription: String {
        switch state {
        case .idle:
            return "空闲"
        case .preparing:
            return "准备中"
        case .backingUp:
            return "创建备份中"
        case .inProgress:
            return "迁移中"
        case .finishing:
            return "完成中"
        case .completed:
            return "已完成"
        case .failed:
            return "迁移失败"
        case .recovering:
            return "从备份恢复中"
        }
    }
    
    /// 详细信息行
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title + ":")
                .fontWeight(.medium)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .background(Color.white.opacity(0.3))
        .cornerRadius(4)
    }
}

// MARK: - Previews

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
struct MigrationProgressView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建一个用于预览的迁移管理器
        let migrationManager = CoreDataMigrationManager()
        
        // 设置迁移状态
        return Group {
            // 迁移进行中预览
            MigrationProgressView(migrationManager: migrationManager)
            .previewDisplayName("迁移进行中")
            
            // 迁移完成预览
            MigrationProgressView(migrationManager: migrationManager)
            .previewDisplayName("迁移完成")
            
            // 迁移失败预览
            MigrationProgressView(migrationManager: migrationManager)
            .previewDisplayName("迁移失败")
        }
    }
} 