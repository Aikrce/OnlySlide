// PlatformAdapter.swift
// 提供跨平台统一API的适配器

import Foundation
import SwiftUI

#if os(macOS)
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformImage = NSImage
public typealias PlatformFont = NSFont
public typealias PlatformViewController = NSViewController
public typealias PlatformHostingController = NSHostingController
public typealias PlatformWindow = NSWindow
public typealias PlatformApplication = NSApplication
#elseif os(iOS) || os(tvOS)
import UIKit
public typealias PlatformColor = UIColor
public typealias PlatformImage = UIImage
public typealias PlatformFont = UIFont
public typealias PlatformViewController = UIViewController
public typealias PlatformHostingController = UIHostingController
public typealias PlatformWindow = UIWindow
public typealias PlatformApplication = UIApplication
#endif

// MARK: - 平台适配器命名空间
public enum PlatformAdapter {
    
    // MARK: - 颜色转换
    public struct Color {
        /// 创建RGB颜色
        public static func rgb(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) -> PlatformColor {
            #if os(macOS)
            return NSColor(red: red, green: green, blue: blue, alpha: alpha)
            #else
            return UIColor(red: red, green: green, blue: blue, alpha: alpha)
            #endif
        }
        
        /// 获取系统强调色
        public static var accentColor: SwiftUI.Color {
            #if os(macOS)
            return SwiftUI.Color(NSColor.controlAccentColor)
            #elseif os(iOS) || os(tvOS)
            return SwiftUI.Color(UIColor.systemBlue)
            #else
            return SwiftUI.Color.blue
            #endif
        }
        
        /// 创建动态颜色（深色/浅色模式自适应）
        public static func dynamicColor(light: SwiftUI.Color, dark: SwiftUI.Color) -> SwiftUI.Color {
            return SwiftUI.Color(dynamicProvider: { colorScheme in
                colorScheme == .dark ? dark : light
            })
        }
        
        /// 获取平台特定的颜色
        public static func platform(
            macOS: @escaping () -> SwiftUI.Color,
            iOS: @escaping () -> SwiftUI.Color,
            fallback: @escaping () -> SwiftUI.Color = { SwiftUI.Color.primary }
        ) -> SwiftUI.Color {
            #if os(macOS)
            return macOS()
            #elseif os(iOS) || os(tvOS)
            return iOS()
            #else
            return fallback()
            #endif
        }
    }

    // MARK: - 视图相关
    public struct UI {
        /// 获取屏幕比例
        public static var mainScreenScale: CGFloat {
            #if os(macOS)
            return NSScreen.main?.backingScaleFactor ?? 1.0
            #else
            return UIScreen.main.scale
            #endif
        }
        
        /// 获取安全区域边距
        public static var safeAreaInsets: EdgeInsets {
            #if os(macOS)
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            #elseif os(iOS)
            guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
                return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            }
            let insets = window.safeAreaInsets
            return EdgeInsets(
                top: CGFloat(insets.top),
                leading: CGFloat(insets.left),
                bottom: CGFloat(insets.bottom),
                trailing: CGFloat(insets.right)
            )
            #else
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            #endif
        }
        
        /// 创建与平台样式一致的圆角矩形
        public static func platformRoundedRectangle(cornerRadius: CGFloat = 8) -> some Shape {
            #if os(macOS)
            return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            #else
            return RoundedRectangle(cornerRadius: cornerRadius)
            #endif
        }
        
        /// 获取与平台一致的标准间距
        public static var standardSpacing: CGFloat {
            #if os(macOS)
            return 10
            #else
            return 8
            #endif
        }
        
        /// 平台标准控件尺寸
        public enum ControlSize {
            public static let small: CGFloat = {
                #if os(macOS)
                return 24
                #else
                return 28
                #endif
            }()
            
            public static let standard: CGFloat = {
                #if os(macOS)
                return 32
                #else
                return 44
                #endif
            }()
            
            public static let large: CGFloat = {
                #if os(macOS)
                return 40
                #else
                return 56
                #endif
            }()
        }
    }
    
    // MARK: - 平台特定功能
    #if os(macOS)
    /// macOS特定功能
    public struct MacOS {
        /// 打开新窗口
        @MainActor
        public static func openWindow(with content: some View, title: String = "", size: CGSize? = nil) {
            let controller = NSHostingController(rootView: content)
            let window = NSWindow(
                contentRect: NSRect(
                    x: 0, 
                    y: 0, 
                    width: size?.width ?? 800, 
                    height: size?.height ?? 600
                ),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = title
            window.contentViewController = controller
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
        
        /// 设置窗口透明度
        @MainActor
        public static func setWindowTransparency(_ window: NSWindow, isTransparent: Bool) {
            if isTransparent {
                window.isOpaque = false
                window.backgroundColor = .clear
            } else {
                window.isOpaque = true
                window.backgroundColor = .windowBackgroundColor
            }
        }
        
        /// 获取暗色模式状态
        public static var isDarkMode: Bool {
            let appearance = NSAppearance.current
            if let bestMatch = appearance.bestMatch(from: [.aqua, .darkAqua]) {
                return bestMatch == .darkAqua
            }
            return false
        }
    }
    #elseif os(iOS) || os(tvOS)
    /// iOS特定功能
    public struct iOS {
        /// 以模态方式呈现视图
        @MainActor
        public static func presentModally<Content: View>(
            _ content: Content,
            in viewController: UIViewController,
            animated: Bool = true
        ) {
            let hostingController = UIHostingController(rootView: content)
            viewController.present(hostingController, animated: animated)
        }
        
        /// 设置状态栏样式
        @MainActor
        public static func setStatusBarStyle(_ style: UIStatusBarStyle) {
            if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                if let rootVC = window.rootViewController {
                    let statusBarMethod = rootVC.classForCoder.instanceMethod(
                        for: NSSelectorFromString("setNeedsStatusBarAppearanceUpdate"))
                    
                    if let method = statusBarMethod {
                        let implementation = method_getImplementation(method)
                        let setStyleMethod = unsafeBitCast(implementation, to: (@convention(c) (Any, Selector) -> Void).self)
                        setStyleMethod(rootVC, NSSelectorFromString("setNeedsStatusBarAppearanceUpdate"))
                    }
                }
            }
        }
        
        /// 获取暗色模式状态
        public static var isDarkMode: Bool {
            return UITraitCollection.current.userInterfaceStyle == .dark
        }
    }
    #endif
    
    // MARK: - 文件操作适配
    public struct FileSystem {
        /// 打开文件
        @MainActor
        public static func openFile(completion: @escaping (URL?) -> Void) {
            #if os(macOS)
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.begin { result in
                if result == .OK {
                    completion(panel.url)
                } else {
                    completion(nil)
                }
            }
            #else
            // iOS需要使用UIDocumentPickerViewController
            // 由于需要UIViewController上下文，此处仅为占位
            completion(nil)
            #endif
        }
        
        /// 保存文件
        @MainActor
        public static func saveFile(url: URL, completion: @escaping (URL?) -> Void) {
            #if os(macOS)
            let panel = NSSavePanel()
            panel.nameFieldStringValue = url.lastPathComponent
            panel.begin { result in
                if result == .OK {
                    if let panelURL = panel.url {
                        do {
                            try FileManager.default.copyItem(at: url, to: panelURL)
                            completion(panelURL)
                        } catch {
                            print("Save error: \(error)")
                            completion(nil)
                        }
                    }
                } else {
                    completion(nil)
                }
            }
            #else
            // iOS需要使用UIActivityViewController
            // 由于需要UIViewController上下文，此处仅为占位
            completion(nil)
            #endif
        }
        
        /// 获取文档目录
        public static func getDocumentsDirectory() -> URL {
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        
        /// 获取缓存目录
        public static func getCachesDirectory() -> URL {
            return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        }
    }
    
    // MARK: - 通知与反馈
    public struct Feedback {
        /// 触发触觉反馈
        public static func triggerHapticFeedback(style: FeedbackStyle = .medium) {
            #if os(iOS)
            switch style {
            case .light:
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            case .medium:
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            case .heavy:
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
            case .success:
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            case .error:
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            case .warning:
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            }
            #endif
        }
        
        /// 反馈风格
        public enum FeedbackStyle {
            case light, medium, heavy, success, error, warning
        }
        
        /// 显示通知
        @MainActor
        public static func showNotification(title: String, message: String? = nil) {
            #if os(macOS)
            let notification = NSUserNotification()
            notification.title = title
            if let message = message {
                notification.informativeText = message
            }
            NSUserNotificationCenter.default.deliver(notification)
            #endif
        }
    }
}

// MARK: - 视图适配器协议
public protocol AdaptiveView {
    associatedtype MacContent: View
    associatedtype IOSContent: View
    
    @ViewBuilder
    func macView() -> MacContent
    
    @ViewBuilder
    func iosView() -> IOSContent
}

// MARK: - 适配视图包装器
public struct AdaptiveViewWrapper<Content: AdaptiveView>: View {
    private let content: Content
    
    public init(content: Content) {
        self.content = content
    }
    
    public var body: some View {
        #if os(macOS)
        content.macView()
        #else
        content.iosView()
        #endif
    }
}

// MARK: - 视图扩展
public extension View {
    /// 适用于当前平台的修饰符
    @ViewBuilder
    func platformSpecific<T: View, U: View>(
        macOS: @escaping (Self) -> T,
        iOS: @escaping (Self) -> U
    ) -> some View {
        #if os(macOS)
        macOS(self)
        #else
        iOS(self)
        #endif
    }
    
    /// 仅在指定平台应用修饰符
    @ViewBuilder
    func onlyOn<T: View>(platform: Platform, apply: @escaping (Self) -> T) -> some View {
        #if os(macOS)
        if platform == .macOS {
            apply(self)
        } else {
            self
        }
        #elseif os(iOS)
        if platform == .iOS {
            apply(self)
        } else {
            self
        }
        #elseif os(tvOS)
        if platform == .tvOS {
            apply(self)
        } else {
            self
        }
        #elseif os(watchOS)
        if platform == .watchOS {
            apply(self)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

// MARK: - 平台枚举
public enum Platform {
    case macOS, iOS, tvOS, watchOS
    
    /// 当前运行的平台
    public static var current: Platform {
        #if os(macOS)
        return .macOS
        #elseif os(iOS)
        return .iOS
        #elseif os(tvOS)
        return .tvOS
        #elseif os(watchOS)
        return .watchOS
        #else
        fatalError("未知平台")
        #endif
    }
}

// MARK: - 环境值
private struct PlatformKey: EnvironmentKey {
    static var defaultValue: Platform = Platform.current
}

public extension EnvironmentValues {
    /// 当前平台环境值
    var platform: Platform {
        get { self[PlatformKey.self] }
        set { self[PlatformKey.self] = newValue }
    }
} 