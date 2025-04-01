// MainLaunchView.swift
// 应用程序的主启动视图

import SwiftUI
import DocumentAnalysis

/// 应用程序的主启动视图，作为入口视图
struct MainLaunchView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                AppHomeView()
            }
            .tabItem {
                Label("主页", systemImage: "house")
            }
            .tag(0)
            
            NavigationView {
                DocumentAnalysisView()
            }
            .tabItem {
                Label("文档分析", systemImage: "doc.text.magnifyingglass")
            }
            .tag(1)
            
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gear")
            }
            .tag(2)
        }
        #if os(macOS)
        .frame(minWidth: 700, minHeight: 500)
        #endif
    }
}

// 预览提供者
struct MainLaunchView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // iOS - iPhone 预览
            MainLaunchView()
                .previewDevice(PreviewDevice(rawValue: "iPhone 13"))
                .previewDisplayName("iOS - iPhone 13")
            
            // iOS - iPad 预览
            MainLaunchView()
                .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch) (3rd generation)"))
                .previewDisplayName("iPadOS")
            
            // macOS 预览
            MainLaunchView()
                .previewDisplayName("macOS")
        }
    }
} 