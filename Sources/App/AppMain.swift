// AppMain.swift
// 主应用入口

import SwiftUI

#if os(macOS)
import AppKit
#endif

/// OnlySlide 应用入口点
@main
public struct AppMain: App {
    private let appPreferences = AppPreferences()
    
    public init() {}
    
    public var body: some Scene {
        #if os(macOS)
        WindowGroup {
            PlatformAdaptiveContainer {
                MainLaunchView()
            }
            .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // 添加macOS菜单命令
            CommandGroup(replacing: .newItem) {
                Button("新建演示文稿") {
                    NotificationCenter.default.post(name: NSNotification.Name("NewDocument"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Button("打开内容生成器...") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenContentGenerator"), object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .option])
            }
        }
        #else
        WindowGroup {
            PlatformAdaptiveContainer {
                MainLaunchView()
            }
        }
        #endif
    }
}

#if os(macOS)
/// macOS应用首选项设置
class AppPreferences: ObservableObject {
    // 常规设置
    @Published var defaultSlideDuration: Int {
        didSet { UserDefaults.standard.set(defaultSlideDuration, forKey: "defaultSlideDuration") }
    }
    
    @Published var defaultTheme: String {
        didSet { UserDefaults.standard.set(defaultTheme, forKey: "defaultTheme") }
    }
    
    @Published var autoSaveEnabled: Bool {
        didSet { UserDefaults.standard.set(autoSaveEnabled, forKey: "autoSaveEnabled") }
    }
    
    @Published var autoSaveInterval: Int {
        didSet { UserDefaults.standard.set(autoSaveInterval, forKey: "autoSaveInterval") }
    }
    
    // 编辑器设置
    @Published var showRulers: Bool {
        didSet { UserDefaults.standard.set(showRulers, forKey: "showRulers") }
    }
    
    @Published var showGrid: Bool {
        didSet { UserDefaults.standard.set(showGrid, forKey: "showGrid") }
    }
    
    @Published var gridSize: Int {
        didSet { UserDefaults.standard.set(gridSize, forKey: "gridSize") }
    }
    
    @Published var defaultFont: String {
        didSet { UserDefaults.standard.set(defaultFont, forKey: "defaultFont") }
    }
    
    // 演示设置
    @Published var countdownBeforePresentation: Bool {
        didSet { UserDefaults.standard.set(countdownBeforePresentation, forKey: "countdownBeforePresentation") }
    }
    
    @Published var showClock: Bool {
        didSet { UserDefaults.standard.set(showClock, forKey: "showClock") }
    }
    
    @Published var showProgressBar: Bool {
        didSet { UserDefaults.standard.set(showProgressBar, forKey: "showProgressBar") }
    }
    
    @Published var useSecondaryScreen: Bool {
        didSet { UserDefaults.standard.set(useSecondaryScreen, forKey: "useSecondaryScreen") }
    }
    
    // 初始化，从UserDefaults加载设置
    init() {
        self.defaultSlideDuration = UserDefaults.standard.integer(forKey: "defaultSlideDuration")
        if self.defaultSlideDuration == 0 { self.defaultSlideDuration = 60 } // 默认60秒
        
        self.defaultTheme = UserDefaults.standard.string(forKey: "defaultTheme") ?? "standard"
        self.autoSaveEnabled = UserDefaults.standard.bool(forKey: "autoSaveEnabled")
        
        self.autoSaveInterval = UserDefaults.standard.integer(forKey: "autoSaveInterval")
        if self.autoSaveInterval == 0 { self.autoSaveInterval = 5 } // 默认5分钟
        
        self.showRulers = UserDefaults.standard.bool(forKey: "showRulers")
        self.showGrid = UserDefaults.standard.bool(forKey: "showGrid")
        
        self.gridSize = UserDefaults.standard.integer(forKey: "gridSize")
        if self.gridSize == 0 { self.gridSize = 10 } // 默认10像素
        
        self.defaultFont = UserDefaults.standard.string(forKey: "defaultFont") ?? "SF Pro"
        self.countdownBeforePresentation = UserDefaults.standard.bool(forKey: "countdownBeforePresentation")
        self.showClock = UserDefaults.standard.bool(forKey: "showClock")
        self.showProgressBar = UserDefaults.standard.bool(forKey: "showProgressBar")
        self.useSecondaryScreen = UserDefaults.standard.bool(forKey: "useSecondaryScreen")
        
        // 设置默认值
        if !UserDefaults.standard.bool(forKey: "hasInitializedDefaults") {
            self.autoSaveEnabled = true
            self.showClock = true
            self.showProgressBar = true
            self.useSecondaryScreen = true
            UserDefaults.standard.set(true, forKey: "hasInitializedDefaults")
        }
    }
    
    // 重置为默认设置
    func resetToDefaults() {
        self.defaultSlideDuration = 60
        self.defaultTheme = "standard"
        self.autoSaveEnabled = true
        self.autoSaveInterval = 5
        self.showRulers = false
        self.showGrid = false
        self.gridSize = 10
        self.defaultFont = "SF Pro"
        self.countdownBeforePresentation = false
        self.showClock = true
        self.showProgressBar = true
        self.useSecondaryScreen = true
    }
}
#else
/// iOS应用首选项设置 - 简化版
class AppPreferences: ObservableObject {
    // 基本设置
    @Published var defaultTheme: String = UserDefaults.standard.string(forKey: "defaultTheme") ?? "standard"
    @Published var autoSaveEnabled: Bool = UserDefaults.standard.bool(forKey: "autoSaveEnabled")
    
    init() {
        // 设置默认值
        if !UserDefaults.standard.bool(forKey: "hasInitializedDefaults") {
            self.autoSaveEnabled = true
            UserDefaults.standard.set(true, forKey: "hasInitializedDefaults")
        }
    }
}
#endif

/// 内容分析器 - 跨平台共享
struct ContentAnalyzer {
    static func analyzeText(_ text: String, maxSlides: Int) -> [SlideAnalysisItem] {
        // 去除空行和调整格式
        let lines = text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if lines.isEmpty {
            return []
        }
        
        var result: [SlideAnalysisItem] = []
        
        // 简单的启发式方法识别标题和内容
        if lines.count > 1 {
            // 首行作为总标题
            var currentTitle = lines[0]
            var currentContent = ""
            var currentNotes = ""
            
            for i in 1..<lines.count {
                let line = lines[i]
                
                // 判断是否为新标题的启发式规则
                let isPotentialTitle = line.count < 50 && // 较短
                    !line.contains(". ") && // 不含多个句子
                    (line.hasSuffix("?") || line.hasSuffix("：") || line.hasSuffix(":") || // 常见标题结尾
                     line.first?.isUppercase == true) // 首字母大写
                
                if isPotentialTitle && !currentContent.isEmpty {
                    // 保存当前幻灯片并开始新的
                    result.append(SlideAnalysisItem(
                        title: currentTitle,
                        content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                        notes: currentNotes
                    ))
                    
                    // 重置为新的幻灯片
                    currentTitle = line
                    currentContent = ""
                    currentNotes = ""
                    
                    // 检查是否达到最大幻灯片数
                    if result.count >= maxSlides {
                        break
                    }
                } else if line.hasPrefix("注:") || line.hasPrefix("注：") || line.hasPrefix("Note:") {
                    // 识别备注
                    currentNotes += line + "\n"
                } else {
                    // 添加为当前内容
                    if !currentContent.isEmpty {
                        currentContent += "\n"
                    }
                    currentContent += line
                }
            }
            
            // 添加最后一张幻灯片
            if !currentTitle.isEmpty && !currentContent.isEmpty && result.count < maxSlides {
                result.append(SlideAnalysisItem(
                    title: currentTitle,
                    content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: currentNotes
                ))
            }
        } else if lines.count == 1 {
            // 只有一行，作为标题
            result.append(SlideAnalysisItem(
                title: lines[0],
                content: "请在此处添加内容",
                notes: ""
            ))
        }
        
        return result
    }
}

/// 分析结果项目 - 跨平台共享
struct SlideAnalysisItem: Identifiable {
    let id = UUID()
    var title: String
    var content: String
    var notes: String
}

// MARK: - 主内容视图
struct ContentView: View {
    @ObservedObject var viewModel: SlideEditorViewModel
    @ObservedObject var documentManager: SlideDocumentManager
    
    var body: some View {
        AdaptiveViewWrapper(content: SlideEditorView(viewModel: viewModel))
            .onChange(of: viewModel.slides) { newSlides in
                documentManager.isDocumentSaved = false
            }
            .onChange(of: viewModel.documentTitle) { newTitle in
                documentManager.isDocumentSaved = false
            }
    }
} 