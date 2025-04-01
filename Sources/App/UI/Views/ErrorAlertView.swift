import SwiftUI

struct ErrorAlertView: View {
    @Binding var errorMessage: String?
    var onRetry: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    @State private var errorType: ErrorType = .unknown
    
    var body: some View {
        Group {
            if let error = errorMessage {
                VStack(spacing: 16) {
                    // 错误图标
                    errorType.icon
                        .font(.system(size: 48))
                        .foregroundColor(errorType.iconColor)
                    
                    // 错误标题
                    Text(errorType.title)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    // 错误描述
                    Text(error)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // 恢复建议
                    Text(errorType.recommendation)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // 操作按钮
                    HStack(spacing: 16) {
                        Button(action: {
                            errorMessage = nil
                            onDismiss?()
                        }) {
                            Text("关闭")
                                .frame(minWidth: 80)
                        }
                        .buttonStyle(.bordered)
                        
                        if let onRetry = onRetry {
                            Button(action: {
                                errorMessage = nil
                                onRetry()
                            }) {
                                Text(errorType.actionTitle)
                                    .frame(minWidth: 80)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 5)
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    classifyError(error)
                }
            }
        }
        .animation(.spring(), value: errorMessage)
    }
    
    private func classifyError(_ errorMessage: String) {
        // 根据错误消息内容分类错误类型
        if errorMessage.contains("migration") || errorMessage.contains("迁移") {
            errorType = .migration
        } else if errorMessage.contains("connection") || errorMessage.contains("网络") || errorMessage.contains("连接") {
            errorType = .connection
        } else if errorMessage.contains("permission") || errorMessage.contains("权限") {
            errorType = .permission
        } else if errorMessage.contains("not found") || errorMessage.contains("找不到") || errorMessage.contains("不存在") {
            errorType = .notFound
        } else if errorMessage.contains("timeout") || errorMessage.contains("超时") {
            errorType = .timeout
        } else if errorMessage.contains("disk") || errorMessage.contains("storage") || errorMessage.contains("磁盘") || errorMessage.contains("存储") {
            errorType = .storage
        } else {
            errorType = .unknown
        }
    }
}

enum ErrorType {
    case migration
    case connection
    case permission
    case notFound
    case timeout
    case storage
    case unknown
    
    var icon: Image {
        switch self {
        case .migration:
            return Image(systemName: "arrow.triangle.2.circlepath.circle")
        case .connection:
            return Image(systemName: "network.slash")
        case .permission:
            return Image(systemName: "lock.circle")
        case .notFound:
            return Image(systemName: "questionmark.circle")
        case .timeout:
            return Image(systemName: "clock")
        case .storage:
            return Image(systemName: "internaldrive")
        case .unknown:
            return Image(systemName: "exclamationmark.triangle")
        }
    }
    
    var iconColor: Color {
        switch self {
        case .migration:
            return .orange
        case .connection:
            return .red
        case .permission:
            return .red
        case .notFound:
            return .orange
        case .timeout:
            return .yellow
        case .storage:
            return .red
        case .unknown:
            return .red
        }
    }
    
    var title: String {
        switch self {
        case .migration:
            return "迁移错误"
        case .connection:
            return "连接错误"
        case .permission:
            return "权限错误"
        case .notFound:
            return "资源不存在"
        case .timeout:
            return "操作超时"
        case .storage:
            return "存储空间不足"
        case .unknown:
            return "发生错误"
        }
    }
    
    var recommendation: String {
        switch self {
        case .migration:
            return "数据迁移时出现问题。应用已自动备份您的数据，您可以安全地重试或稍后再试。"
        case .connection:
            return "请检查您的网络连接并确保服务器可访问。"
        case .permission:
            return "请确保应用有足够的权限访问所需资源。"
        case .notFound:
            return "请确认资源文件存在并且没有被移动或删除。"
        case .timeout:
            return "操作耗时过长，请检查您的网络连接或稍后再试。"
        case .storage:
            return "您的设备存储空间不足，请释放一些空间后重试。"
        case .unknown:
            return "发生了意外错误，请重试或联系客服支持。"
        }
    }
    
    var actionTitle: String {
        switch self {
        case .migration:
            return "重试迁移"
        case .connection:
            return "重新连接"
        case .permission:
            return "授权"
        case .notFound:
            return "重新加载"
        case .timeout:
            return "重试"
        case .storage:
            return "检查存储"
        case .unknown:
            return "重试"
        }
    }
} 