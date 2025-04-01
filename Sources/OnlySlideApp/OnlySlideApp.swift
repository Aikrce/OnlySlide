import SwiftUI

/// OnlySlide主应用程序入口
@main
public struct OnlySlideApp: App {
    /// 应用程序的主体
    public var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            // 自定义菜单
            CommandMenu("文档") {
                Button("导入文档...") {
                    // 触发文档导入
                    NotificationCenter.default.post(
                        name: Notification.Name("ImportDocument"),
                        object: nil
                    )
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()
                
                Button("导出为PowerPoint") {
                    // 触发导出PowerPoint
                    NotificationCenter.default.post(
                        name: Notification.Name("ExportPowerPoint"),
                        object: nil
                    )
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                
                Button("导出为PDF") {
                    // 触发导出PDF
                    NotificationCenter.default.post(
                        name: Notification.Name("ExportPDF"),
                        object: nil
                    )
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Button("导出为图片") {
                    // 触发导出图片
                    NotificationCenter.default.post(
                        name: Notification.Name("ExportImages"),
                        object: nil
                    )
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                
                Button("导出为文本") {
                    // 触发导出文本
                    NotificationCenter.default.post(
                        name: Notification.Name("ExportText"),
                        object: nil
                    )
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
            
            CommandMenu("模板") {
                Button("模板库") {
                    // 打开模板库
                    NotificationCenter.default.post(
                        name: Notification.Name("OpenTemplateLibrary"),
                        object: nil
                    )
                }
                .keyboardShortcut("l", modifiers: .command)
                
                Button("导入模板...") {
                    // 触发模板导入
                    NotificationCenter.default.post(
                        name: Notification.Name("ImportTemplate"),
                        object: nil
                    )
                }
                .keyboardShortcut("i", modifiers: .command)
            }
            
            CommandGroup(replacing: .help) {
                Button("OnlySlide 帮助") {
                    // 打开帮助页面
                    if let url = URL(string: "https://onlyslide.app/help") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("教程") {
                    // 打开教程页面
                    if let url = URL(string: "https://onlyslide.app/tutorials") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Divider()
                
                Button("关于 OnlySlide") {
                    // 显示关于对话框
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "OnlySlide",
                            NSApplication.AboutPanelOptionKey.applicationVersion: "1.0.0",
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string: "一个高效的文档演示转换工具\n© 2023 OnlySlide Team"
                            )
                        ]
                    )
                }
            }
        }
    }
}

/// 隐藏标题栏但保留窗口控件的窗口样式
struct HiddenTitleBarWindowStyle: WindowStyle {
    func makeBody(configuration: Configuration) -> some Scene {
        configuration
            .titlebarAppearsTransparent(true)
            .titleHidden(true)
    }
} 