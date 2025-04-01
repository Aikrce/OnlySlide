# OnlySlide 多平台支持和预览指南

本文档提供了 OnlySlide 应用中多平台支持和预览的实现指南，帮助开发者理解和使用多平台适配容器及预览机制。

## 目录

1. [多平台支持概述](#多平台支持概述)
2. [PlatformAdaptiveContainer的使用](#platformadaptivecontainer的使用)
3. [SwiftUI预览的多平台配置](#swiftui预览的多平台配置)
4. [平台特定代码的编写](#平台特定代码的编写)
5. [最佳实践](#最佳实践)

## 多平台支持概述

OnlySlide 应用设计为同时支持 macOS、iOS（iPhone 和 iPad）平台，为确保在各个平台上提供最佳的用户体验，我们需要考虑以下几点：

- 不同平台的屏幕尺寸和分辨率
- 交互方式的差异（鼠标/触控板 vs 触摸屏）
- 系统特定的UI元素和习惯
- 平台特定的功能和限制

为此，我们开发了 `PlatformAdaptiveContainer` 容器组件，以及一套完整的多平台预览策略。

## PlatformAdaptiveContainer的使用

`PlatformAdaptiveContainer` 是一个通用容器，可以根据当前运行的平台自动调整其内容的显示方式。

### 基本用法

```swift
import SwiftUI

struct YourView: View {
    var body: some View {
        PlatformAdaptiveContainer {
            // 你的视图内容
            Text("Hello, World!")
        }
    }
}
```

### 平台特定配置

`PlatformAdaptiveContainer` 内部会根据不同平台应用不同的样式：

- **macOS**：适用于桌面环境，提供更大的窗口尺寸和桌面特定的背景
- **iPad**：适用于大屏触摸设备，提供适度的填充和优化的触摸目标大小
- **iPhone**：适用于小屏幕设备，使用更紧凑的布局和较小的填充

## SwiftUI预览的多平台配置

在开发中，使用SwiftUI预览来测试不同平台上的外观至关重要。以下是实现多平台预览的标准方法：

### 标准预览模板

```swift
struct YourView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // iOS - iPhone 预览
            YourView()
                .previewDevice(PreviewDevice(rawValue: "iPhone 13"))
                .previewDisplayName("iOS - iPhone 13")
            
            // iOS - iPad 预览
            YourView()
                .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch) (3rd generation)"))
                .previewDisplayName("iPadOS")
            
            // macOS 预览
            YourView()
                .previewDisplayName("macOS")
        }
    }
}
```

### 常用设备标识符

以下是一些常用的预览设备标识符：

- iPhone: "iPhone 13", "iPhone 13 Pro Max", "iPhone SE (3rd generation)"
- iPad: "iPad Pro (11-inch) (3rd generation)", "iPad Air (5th generation)", "iPad mini (6th generation)"
- Mac: macOS 预览不需要特定的设备标识符

## 平台特定代码的编写

### 条件编译

使用条件编译指令来为不同平台提供特定代码：

```swift
#if os(macOS)
// macOS 特定代码
#elseif os(iOS)
// iOS 特定代码
#endif
```

### iOS 设备类型检测

在 iOS 平台内，区分 iPhone 和 iPad：

```swift
#if os(iOS)
if UIDevice.current.userInterfaceIdiom == .pad {
    // iPad 特定代码
} else {
    // iPhone 特定代码
}
#endif
```

## 最佳实践

1. **视图分离**：将平台特定的视图逻辑分离到单独的扩展或文件中
2. **共享核心逻辑**：确保业务逻辑与UI呈现分离，以便跨平台重用
3. **响应式设计**：尽可能使用响应式布局而非硬编码尺寸
4. **平台特性谨慎使用**：只在必要时使用平台特定的API
5. **预览驱动开发**：积极使用SwiftUI预览来测试不同平台的外观和行为

---

## 示例

### 主启动视图示例

以下是 `MainLaunchView` 的实现示例，展示了如何创建一个跨平台兼容的主界面：

```swift
import SwiftUI

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
```

### PlatformAdaptiveContainer 自定义

如需为特定视图进一步自定义 `PlatformAdaptiveContainer`，可以创建其扩展：

```swift
extension PlatformAdaptiveContainer where Content == YourSpecificView {
    // 针对特定内容类型的容器自定义
    static func customContainer() -> PlatformAdaptiveContainer<YourSpecificView> {
        PlatformAdaptiveContainer {
            YourSpecificView()
                .customModifier()
        }
    }
}
```

---

> 注意：本指南将随着项目的发展而更新。如有任何问题或建议，请联系项目维护者。

_最后更新：2025年4月1日_ 