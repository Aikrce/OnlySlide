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
#else
import UIKit
public typealias PlatformColor = UIColor
public typealias PlatformImage = UIImage
public typealias PlatformFont = UIFont
public typealias PlatformViewController = UIViewController
public typealias PlatformHostingController = UIHostingController
#endif

// MARK: - 平台适配器
public enum PlatformAdapter {
    // MARK: - 颜色转换
    public static func color(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) -> PlatformColor {
        #if os(macOS)
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
        #else
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        #endif
    }
    
    // MARK: - 主题色
    public static var accentColor: Color {
        Color.blue // 可以根据需要自定义
    }
    
    // MARK: - 屏幕相关
    public static var mainScreenScale: CGFloat {
        #if os(macOS)
        return NSScreen.main?.backingScaleFactor ?? 1.0
        #else
        return UIScreen.main.scale
        #endif
    }
    
    // MARK: - 平台特定功能
    #if os(macOS)
    // macOS特定功能
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
    #else
    // iOS特定功能
    @MainActor
    public static func presentModally<Content: View>(
        _ content: Content,
        in viewController: UIViewController,
        animated: Bool = true
    ) {
        let hostingController = UIHostingController(rootView: content)
        viewController.present(hostingController, animated: animated)
    }
    #endif
    
    // MARK: - 文件操作适配
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