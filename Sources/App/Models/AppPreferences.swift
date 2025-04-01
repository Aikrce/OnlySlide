// AppPreferences.swift
// 应用程序首选项管理

import Foundation
import SwiftUI

/// 应用程序首选项管理类
class AppPreferences: ObservableObject {
    // MARK: - UI 偏好设置
    
    /// 用户首选主题
    @Published var preferredTheme: AppTheme = .system {
        didSet {
            UserDefaults.standard.set(preferredTheme.rawValue, forKey: "preferredTheme")
            applyTheme()
        }
    }
    
    /// 用户首选语言
    @Published var preferredLanguage: AppLanguage = .system {
        didSet {
            UserDefaults.standard.set(preferredLanguage.rawValue, forKey: "preferredLanguage")
        }
    }
    
    // MARK: - 功能偏好设置
    
    /// 是否启用自动保存
    @Published var autoSaveEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(autoSaveEnabled, forKey: "autoSaveEnabled")
        }
    }
    
    /// 自动保存时间间隔（分钟）
    @Published var autoSaveInterval: Int = 5 {
        didSet {
            UserDefaults.standard.set(autoSaveInterval, forKey: "autoSaveInterval")
        }
    }
    
    // MARK: - 生命周期
    
    init() {
        loadPreferences()
    }
    
    // MARK: - 私有方法
    
    /// 从UserDefaults加载首选项
    private func loadPreferences() {
        if let themeValue = UserDefaults.standard.string(forKey: "preferredTheme"),
           let theme = AppTheme(rawValue: themeValue) {
            preferredTheme = theme
        }
        
        if let languageValue = UserDefaults.standard.string(forKey: "preferredLanguage"),
           let language = AppLanguage(rawValue: languageValue) {
            preferredLanguage = language
        }
        
        autoSaveEnabled = UserDefaults.standard.bool(forKey: "autoSaveEnabled")
        
        if let interval = UserDefaults.standard.object(forKey: "autoSaveInterval") as? Int {
            autoSaveInterval = interval
        }
        
        // 应用主题
        applyTheme()
    }
    
    /// 应用当前主题
    private func applyTheme() {
        #if os(macOS)
        // macOS 主题应用逻辑
        switch preferredTheme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
        #endif
    }
}

// MARK: - App主题枚举
enum AppTheme: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .system: return "跟随系统"
        }
    }
}

// MARK: - App语言枚举
enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-CN"
    case english = "en-US"
    case system = "system"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .chinese: return "简体中文"
        case .english: return "English"
        case .system: return "跟随系统"
        }
    }
} 