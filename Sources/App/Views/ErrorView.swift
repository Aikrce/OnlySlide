import SwiftUI

public struct ErrorView: View {
    let error: AppError
    let dismissAction: () -> Void
    let retryAction: (() -> Void)?
    
    @State private var showDetails = false
    
    public init(
        error: AppError,
        dismissAction: @escaping () -> Void,
        retryAction: (() -> Void)? = nil
    ) {
        self.error = error
        self.dismissAction = dismissAction
        self.retryAction = retryAction
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // 错误图标
            Image(systemName: errorIcon)
                .font(.system(size: 50))
                .foregroundColor(errorColor)
            
            // 错误标题
            Text(error.errorDescription ?? "发生错误")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            // 恢复建议
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // 操作按钮
            HStack(spacing: 16) {
                // 关闭按钮
                Button(action: dismissAction) {
                    Text("关闭")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.bordered)
                
                // 重试按钮（如果可用）
                if let retryAction = retryAction {
                    Button(action: retryAction) {
                        Text("重试")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.top)
            
            // 详细信息切换按钮
            Button(action: { showDetails.toggle() }) {
                Text(showDetails ? "隐藏详细信息" : "显示详细信息")
                    .font(.footnote)
            }
            
            // 详细信息视图
            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text("错误类型: \(String(describing: type(of: error)))")
                    Text("错误代码: \(error.helpAnchor ?? "unknown")")
                    if let suggestion = error.recoverySuggestion {
                        Text("建议操作: \(suggestion)")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
    
    // MARK: - Private Properties
    
    private var errorIcon: String {
        switch error {
        case .networkError, .syncError:
            return "wifi.slash"
        case .databaseError:
            return "externaldrive.badge.exclamationmark"
        case .authenticationFailed, .unauthorized, .sessionExpired:
            return "lock.shield"
        case .resourceNotFound, .resourceUnavailable:
            return "questionmark.folder"
        case .processingFailed, .aiProcessingError:
            return "exclamationmark.triangle"
        case .userCancelled:
            return "xmark.circle"
        case .invalidUserInput:
            return "exclamationmark.circle"
        case .insufficientPermissions:
            return "hand.raised.slash"
        default:
            return "exclamationmark.triangle"
        }
    }
    
    private var errorColor: Color {
        switch error {
        case .networkError, .syncError, .databaseError:
            return .red
        case .authenticationFailed, .unauthorized, .sessionExpired:
            return .orange
        case .resourceNotFound, .resourceUnavailable:
            return .yellow
        case .userCancelled:
            return .gray
        default:
            return .red
        }
    }
}

#Preview {
    ErrorView(
        error: .networkError(URLError(.notConnectedToInternet)),
        dismissAction: {},
        retryAction: {}
    )
} 