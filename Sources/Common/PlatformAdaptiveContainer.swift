import SwiftUI

/// 平台适配性容器，根据不同平台提供定制的UI体验
public struct PlatformAdaptiveContainer<Content: View>: View {
    private let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        #if os(macOS)
        macOSContainer
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            iPadContainer
        } else {
            iPhoneContainer
        }
        #else
        content
        #endif
    }
    
    // MARK: - 平台特定容器
    
    // macOS 容器样式
    private var macOSContainer: some View {
        content
            .frame(minWidth: 800, minHeight: 600)
            .background(Color(.windowBackgroundColor))
    }
    
    // iPad 容器样式
    private var iPadContainer: some View {
        content
            .padding(.horizontal, 20)
            .background(Color(.systemBackground))
    }
    
    // iPhone 容器样式
    private var iPhoneContainer: some View {
        content
            .padding(.horizontal, 10)
            .background(Color(.systemBackground))
    }
}

// MARK: - 预览
struct PlatformAdaptiveContainer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // iOS 预览 - iPhone
            PlatformAdaptiveContainer {
                VStack {
                    Text("iPhone 适配界面")
                        .font(.headline)
                    
                    Text("这是为iPhone优化的界面")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .previewDevice(PreviewDevice(rawValue: "iPhone 13"))
            .previewDisplayName("iOS - iPhone")
            
            // iOS 预览 - iPad
            PlatformAdaptiveContainer {
                VStack {
                    Text("iPad 适配界面")
                        .font(.headline)
                    
                    Text("这是为iPad优化的界面，拥有更多空间")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch)"))
            .previewDisplayName("iPadOS")
            
            // macOS 预览
            PlatformAdaptiveContainer {
                VStack {
                    Text("macOS 适配界面")
                        .font(.headline)
                    
                    Text("这是为macOS优化的界面，具有桌面应用风格")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(width: 800, height: 500)
            .previewDisplayName("macOS")
        }
    }
} 