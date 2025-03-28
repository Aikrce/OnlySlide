import SwiftUI

struct MigrationProgressView: View {
    @ObservedObject var adapter: CoreDataUIAdapter
    @State private var animateProgress = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题区域
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("数据迁移")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(statusDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 状态图标
                statusIcon
            }
            
            // 进度区域
            if adapter.isMigrating {
                VStack(spacing: 16) {
                    // 进度条
                    ProgressView(value: adapter.migrationProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    
                    // 百分比显示
                    HStack {
                        Text(progressText)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("正在迁移...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 迁移步骤指示器
                    MigrationStepsView(currentStep: currentStep)
                }
                .padding(.vertical, 8)
            }
            
            // 信息区域
            VStack(alignment: .leading, spacing: 12) {
                Text("请勿关闭应用，此过程可能需要几分钟")
                    .font(.callout)
                    .foregroundColor(.orange)
                
                if adapter.isMigrating {
                    Text("• 正在处理您的数据，请耐心等待")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• 数据已自动备份，确保安全")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• 迁移完成后，您将获得更好的性能和新功能")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 错误显示
            if let error = adapter.errorMessage {
                ErrorAlertView(errorMessage: .constant(error), onRetry: {
                    Task {
                        await adapter.startMigration()
                    }
                })
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.3), value: adapter.isMigrating)
        .animation(.easeInOut(duration: 0.3), value: adapter.errorMessage)
        .onAppear {
            // 延迟一点开始动画，以便获得更好的过渡效果
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animateProgress = true
            }
        }
    }
    
    // 当前状态的图标
    private var statusIcon: some View {
        Group {
            switch adapter.migrationState {
            case .notStarted:
                Image(systemName: "hourglass")
                    .foregroundColor(.gray)
            case .preparing:
                Image(systemName: "gear")
                    .foregroundColor(.orange)
                    .rotationEffect(.degrees(animateProgress ? 360 : 0))
                    .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: animateProgress)
            case .migrating:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(animateProgress ? 360 : 0))
                    .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: animateProgress)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.system(size: 32))
    }
    
    // 当前状态的描述
    private var statusDescription: String {
        switch adapter.migrationState {
        case .notStarted:
            return "准备开始迁移..."
        case .preparing:
            return "正在准备数据迁移..."
        case .migrating:
            return "正在迁移您的数据..."
        case .completed:
            return "迁移已完成！"
        case .failed:
            return "迁移遇到问题"
        }
    }
    
    // 格式化的进度文本
    private var progressText: String {
        let percent = Int(adapter.migrationProgress * 100)
        return "\(percent)%"
    }
    
    // 当前迁移步骤
    private var currentStep: Int {
        let progress = adapter.migrationProgress
        if progress < 0.25 {
            return 1
        } else if progress < 0.5 {
            return 2
        } else if progress < 0.75 {
            return 3
        } else if progress < 1.0 {
            return 4
        } else {
            return 5
        }
    }
}

// 迁移步骤视图
struct MigrationStepsView: View {
    let currentStep: Int
    
    private let steps = [
        "准备",
        "备份",
        "转换",
        "验证",
        "完成"
    ]
    
    var body: some View {
        HStack {
            ForEach(0..<steps.count, id: \.self) { index in
                let isCompleted = index + 1 < currentStep
                let isCurrent = index + 1 == currentStep
                
                VStack(spacing: 4) {
                    // 步骤指示器
                    ZStack {
                        Circle()
                            .fill(stepColor(isCompleted: isCompleted, isCurrent: isCurrent))
                            .frame(width: 24, height: 24)
                        
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.white)
                        } else if isCurrent {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 步骤名称
                    Text(steps[index])
                        .font(.caption2)
                        .foregroundColor(isCurrent ? .primary : .secondary)
                }
                
                // 连接线
                if index < steps.count - 1 {
                    Spacer()
                    Rectangle()
                        .fill(stepLineColor(stepIndex: index, currentStep: currentStep))
                        .frame(height: 2)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // 步骤颜色
    private func stepColor(isCompleted: Bool, isCurrent: Bool) -> Color {
        if isCompleted {
            return .green
        } else if isCurrent {
            return .blue
        } else {
            return Color(.systemGray5)
        }
    }
    
    // 连接线颜色
    private func stepLineColor(stepIndex: Int, currentStep: Int) -> Color {
        if stepIndex + 1 < currentStep {
            return .green
        } else {
            return Color(.systemGray4)
        }
    }
} 