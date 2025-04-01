# OnlySlide 项目重复代码重构指南

本文档提供了解决 OnlySlide 项目中重复代码问题的指南和最佳实践，以减少技术债务并提高代码质量。

## 目录

1. [重复代码问题概述](#重复代码问题概述)
2. [统一日志系统](#统一日志系统)
3. [平台适配器改进](#平台适配器改进)
4. [迁移指南](#迁移指南)
5. [未来工作](#未来工作)

## 重复代码问题概述

OnlySlide 项目发展过程中，出现了多处重复实现的模块，主要集中在以下几个领域：

1. **日志记录系统**：项目中存在多个不同的日志实现
   - `Sources/Common/Utils/CommonLogger.swift`
   - `Sources/Logging/Logger.swift`
   - `Sources/CoreDataModule/Utils/CoreLogger.swift`
   - `Sources/Core/Application/Services/Logging/LoggingService.swift`

2. **平台适配代码**：多处包含相似的平台适配逻辑
   - `Sources/Common/PlatformAdapter.swift`
   - `Sources/Common/AdaptiveComponents.swift`
   - 多处重复的条件编译代码 (#if os(macOS)/#else)

为解决这些问题，我们进行了以下重构：

## 统一日志系统

我们在 `Sources/Logging/Logger.swift` 中实现了统一的日志记录系统，具有以下优势：

- **多层次的日志级别**：debug、info、notice、warning、error、critical
- **可扩展的处理器架构**：控制台、文件、OSLog
- **结构化日志**：支持元数据和上下文信息
- **线程安全**：所有操作都是线程安全的
- **性能优化**：批处理和异步处理

### 使用示例

```swift
// 导入模块
import Logging

// 在应用启动时配置
func setupLogging() {
    // 设置全局日志级别
    Logger.shared.setGlobalLogLevel(.info)
    
    // 启用文件日志
    Logger.shared.enableFileLogging()
    
    // 可选：添加自定义日志处理器
    let customHandler = CustomLogHandler()
    Logger.shared.addHandler(customHandler)
}

// 使用日志器记录消息
func doSomething() {
    // 简单日志
    log.info("操作开始")
    
    // 带元数据的日志
    log.debug("处理数据", metadata: ["itemCount": "42", "batchId": "xyz123"])
    
    // 错误日志
    if let error = operationError {
        log.error("操作失败: \(error.localizedDescription)", 
                 metadata: ["errorCode": "\(error.code)"])
    }
    
    // 类别特定的日志器
    let networkLogger = Logger(subsystem: "com.onlyslide", category: "Network")
    networkLogger.info("网络请求完成")
}
```

## 平台适配器改进

我们扩展了 `Sources/Common/PlatformAdapter.swift` 以提供更全面的平台适配功能，具有以下特点：

- **命名空间组织**：使用结构体划分不同的功能领域
- **类型安全API**：提供类型安全且易于使用的API
- **全面的平台支持**：支持macOS、iOS、tvOS和watchOS
- **SwiftUI集成**：提供与SwiftUI无缝集成的功能
- **可扩展架构**：易于添加新的平台特定功能

### 使用示例

```swift
import SwiftUI
import Common

// 颜色适配
let adaptiveColor = PlatformAdapter.Color.dynamicColor(
    light: .white,
    dark: .black
)

let platformSpecificColor = PlatformAdapter.Color.platform(
    macOS: { .gray },
    iOS: { .blue }
)

// UI组件适配
struct ContentView: View {
    var body: some View {
        VStack(spacing: PlatformAdapter.UI.standardSpacing) {
            Text("Hello, World!")
                .padding()
                .background(PlatformAdapter.UI.platformRoundedRectangle())
            
            // 平台特定修饰符
            Button("Click me") { }
                .platformSpecific(
                    macOS: { $0.buttonStyle(.link) },
                    iOS: { $0.buttonStyle(.bordered) }
                )
        }
        .frame(width: PlatformAdapter.UI.ControlSize.standard * 5)
    }
}

// 平台特定功能
func openDocument() {
    PlatformAdapter.FileSystem.openFile { url in
        if let url = url {
            // 处理文件
        }
    }
}

// 平台检测
if Platform.current == .macOS {
    // macOS特定代码
}
```

## 迁移指南

### 从旧日志系统迁移

1. **导入模块**：替换旧的导入语句
   ```swift
   // 旧代码
   import Utils
   
   // 新代码
   import Logging
   ```

2. **创建日志器**：替换旧的日志器创建
   ```swift
   // 旧代码
   let logger = CommonLogger(label: "Network")
   
   // 新代码
   let logger = Logger(subsystem: "com.onlyslide", category: "Network")
   ```

3. **使用日志方法**：更新日志记录方法
   ```swift
   // 旧代码
   logger.info("下载完成")
   logger.error("请求失败: \(error)")
   
   // 新代码
   logger.info("下载完成")
   logger.error("请求失败: \(error.localizedDescription)", 
               metadata: ["statusCode": "\(statusCode)"])
   ```

### 从旧平台适配器迁移

1. **更新导入**：确保导入正确的模块
   ```swift
   import Common
   ```

2. **更新颜色创建**：使用新的命名空间
   ```swift
   // 旧代码
   let color = PlatformAdapter.color(red: 0.2, green: 0.5, blue: 0.8)
   
   // 新代码
   let color = PlatformAdapter.Color.rgb(red: 0.2, green: 0.5, blue: 0.8)
   ```

3. **更新平台特定功能**：使用新的结构化API
   ```swift
   // 旧代码
   #if os(macOS)
   PlatformAdapter.openWindow(with: contentView)
   #else
   PlatformAdapter.presentModally(contentView, in: viewController)
   #endif
   
   // 新代码
   #if os(macOS)
   PlatformAdapter.MacOS.openWindow(with: contentView)
   #else
   PlatformAdapter.iOS.presentModally(contentView, in: viewController)
   #endif
   
   // 或者使用视图修饰符
   view.platformSpecific(
       macOS: { $0.frame(width: 400, height: 300) },
       iOS: { $0.frame(maxWidth: .infinity) }
   )
   ```

## 未来工作

未来我们将继续改进和扩展这些系统，计划包括：

1. **日志分析工具**：添加日志分析和可视化工具
2. **更多平台适配**：增加对watchOS和其他平台的全面支持
3. **组件库扩展**：继续扩展自适应组件库
4. **测试覆盖**：增加单元测试覆盖率
5. **性能优化**：进一步优化性能和内存使用

---

文档最后更新: 2025年4月1日 