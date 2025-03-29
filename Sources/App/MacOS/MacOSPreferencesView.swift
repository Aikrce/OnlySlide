#if os(macOS)
// MacOSPreferencesView.swift
// macOS专用的首选项设置面板

import SwiftUI
import AppKit

// MARK: - 应用首选项管理器
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

// MARK: - 首选项窗口管理器
class PreferencesWindowManager {
    private var preferencesWindow: NSWindow?
    private let preferences: AppPreferences
    
    init(preferences: AppPreferences) {
        self.preferences = preferences
    }
    
    // 显示首选项窗口
    func showPreferences() {
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        // 创建首选项视图
        let preferencesView = MacOSPreferencesView(preferences: preferences)
        
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.setFrameAutosaveName("PreferencesWindow")
        window.contentView = NSHostingView(rootView: preferencesView)
        window.title = "OnlySlide 首选项"
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        
        self.preferencesWindow = window
    }
}

// MARK: - 首选项视图
struct MacOSPreferencesView: View {
    @ObservedObject var preferences: AppPreferences
    @State private var selectedTab = 0
    
    // 可用字体列表
    private let availableFonts = NSFontManager.shared.availableFontFamilies.sorted()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 常规设置
            generalTab
                .tabItem {
                    Label("常规", systemImage: "gear")
                }
                .tag(0)
            
            // 编辑器设置
            editorTab
                .tabItem {
                    Label("编辑器", systemImage: "pencil")
                }
                .tag(1)
            
            // 演示设置
            presentationTab
                .tabItem {
                    Label("演示", systemImage: "play.rectangle")
                }
                .tag(2)
            
            // 高级设置
            advancedTab
                .tabItem {
                    Label("高级", systemImage: "slider.horizontal.3")
                }
                .tag(3)
        }
        .padding(20)
        .frame(width: 600, height: 450)
    }
    
    // MARK: - 常规设置标签
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 默认主题
            VStack(alignment: .leading) {
                Text("默认主题")
                    .font(.headline)
                
                Picker("", selection: $preferences.defaultTheme) {
                    Text("标准").tag("standard")
                    Text("现代").tag("modern")
                    Text("轻盈").tag("light")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            Divider()
            
            // 自动保存设置
            VStack(alignment: .leading, spacing: 10) {
                Toggle("启用自动保存", isOn: $preferences.autoSaveEnabled)
                
                HStack {
                    Text("自动保存间隔:")
                    
                    Picker("", selection: $preferences.autoSaveInterval) {
                        Text("1分钟").tag(1)
                        Text("5分钟").tag(5)
                        Text("10分钟").tag(10)
                        Text("15分钟").tag(15)
                        Text("30分钟").tag(30)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    .labelsHidden()
                }
                .disabled(!preferences.autoSaveEnabled)
            }
            
            Divider()
            
            // 默认幻灯片时长
            VStack(alignment: .leading) {
                Text("默认幻灯片时长:")
                    .font(.headline)
                
                Picker("", selection: $preferences.defaultSlideDuration) {
                    Text("30秒").tag(30)
                    Text("1分钟").tag(60)
                    Text("2分钟").tag(120)
                    Text("3分钟").tag(180)
                    Text("5分钟").tag(300)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            Spacer()
            
            // 重置按钮
            HStack {
                Spacer()
                
                Button("重置为默认设置") {
                    let alert = NSAlert()
                    alert.messageText = "重置为默认设置"
                    alert.informativeText = "确定要将所有设置重置为默认值吗？此操作无法撤销。"
                    alert.addButton(withTitle: "重置")
                    alert.addButton(withTitle: "取消")
                    alert.alertStyle = .warning
                    
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        preferences.resetToDefaults()
                    }
                }
            }
        }
    }
    
    // MARK: - 编辑器设置标签
    private var editorTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 视觉辅助
            VStack(alignment: .leading, spacing: 10) {
                Text("视觉辅助")
                    .font(.headline)
                
                Toggle("显示标尺", isOn: $preferences.showRulers)
                Toggle("显示网格", isOn: $preferences.showGrid)
                
                HStack {
                    Text("网格大小:")
                    
                    Slider(value: Binding(
                        get: { Double(preferences.gridSize) },
                        set: { preferences.gridSize = Int($0) }
                    ), in: 5...50, step: 5)
                    
                    Text("\(preferences.gridSize) 像素")
                        .frame(width: 80, alignment: .trailing)
                }
                .disabled(!preferences.showGrid)
            }
            
            Divider()
            
            // 字体设置
            VStack(alignment: .leading, spacing: 10) {
                Text("默认字体")
                    .font(.headline)
                
                Picker("默认字体:", selection: $preferences.defaultFont) {
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                
                if let selectedFont = NSFont(name: preferences.defaultFont, size: 13) {
                    Text("示例文本")
                        .font(.init(selectedFont))
                        .padding(.top, 5)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - 演示设置标签
    private var presentationTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 演示前设置
            VStack(alignment: .leading, spacing: 10) {
                Text("演示开始前")
                    .font(.headline)
                
                Toggle("开始前显示倒计时", isOn: $preferences.countdownBeforePresentation)
            }
            
            Divider()
            
            // 演示中设置
            VStack(alignment: .leading, spacing: 10) {
                Text("演示过程中")
                    .font(.headline)
                
                Toggle("显示时钟", isOn: $preferences.showClock)
                Toggle("显示进度条", isOn: $preferences.showProgressBar)
            }
            
            Divider()
            
            // 屏幕设置
            VStack(alignment: .leading, spacing: 10) {
                Text("屏幕设置")
                    .font(.headline)
                
                Toggle("有外部显示器时自动使用", isOn: $preferences.useSecondaryScreen)
                
                Text("外部显示器将用于向观众展示幻灯片，主显示器将显示演讲者视图。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 高级设置标签
    private var advancedTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 性能设置
            VStack(alignment: .leading, spacing: 10) {
                Text("性能设置")
                    .font(.headline)
                
                HStack {
                    Text("最大撤销步骤:")
                    
                    Picker("", selection: .constant(50)) {
                        Text("20").tag(20)
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("无限制").tag(999)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    .labelsHidden()
                }
            }
            
            Divider()
            
            // 调试选项
            VStack(alignment: .leading, spacing: 10) {
                Text("调试选项")
                    .font(.headline)
                
                Toggle("启用调试日志", isOn: .constant(false))
            }
            
            Divider()
            
            // 数据管理
            VStack(alignment: .leading, spacing: 10) {
                Text("数据管理")
                    .font(.headline)
                
                Button("清除最近文件列表") {
                    UserDefaults.standard.removeObject(forKey: "recentDocuments")
                }
                
                Button("重置所有设置") {
                    let alert = NSAlert()
                    alert.messageText = "重置所有设置"
                    alert.informativeText = "确定要重置所有应用设置吗？此操作无法撤销。"
                    alert.addButton(withTitle: "重置")
                    alert.addButton(withTitle: "取消")
                    alert.alertStyle = .warning
                    
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        preferences.resetToDefaults()
                        
                        // 清除其他设置
                        UserDefaults.standard.removeObject(forKey: "recentDocuments")
                        UserDefaults.standard.removeObject(forKey: "hasInitializedDefaults")
                    }
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - 预览
#Preview {
    MacOSPreferencesView(preferences: AppPreferences())
        .frame(width: 600, height: 450)
}
#endif 