# OnlySlide

OnlySlide 是一款智能幻灯片创建应用，旨在简化演示文稿的制作过程。通过分析 PPT 模板和结构化内容，OnlySlide 帮助用户快速生成符合专业设计标准的演示文稿。

## 项目架构

OnlySlide 采用模块化 MVVM 架构，分为两个主要模块：

```
┌─────────────────────────────────────────────────────────────┐
│                    OnlySlide Application                    │
├────────────────────────────┬────────────────────────────────┤
│                            │                                │
│    ┌────────────────────┐  │  ┌────────────────────────┐    │
│    │   OnlySlideCore    │  │  │      OnlySlideUI       │    │
│    │                    │  │  │     (MVVM 架构)         │    │
│    │ ┌────────────────┐ │  │  │ ┌────────────────────┐ │    │
│    │ │     Models     │ │  │  │ │       Views        │ │    │
│    │ └────────────────┘ │  │  │ └────────────────────┘ │    │
│    │                    │  │  │           ▲            │    │
│    │ ┌────────────────┐ │  │  │           │            │    │
│    │ │    Services    │ │  │  │ ┌────────────────────┐ │    │
│    │ └────────────────┘ │  │  │ │    ViewModels      │ │    │
│    │         ▲          │  │  │ └────────────────────┘ │    │
│    │         │          │  │  │           ▲            │    │
│    │ ┌────────────────┐ │  │  │           │            │    │
│    │ │   Protocols    │◄┼──┼──┼───────────┘            │    │
│    │ └────────────────┘ │  │  │                        │    │
│    │                    │  │  │ ┌────────────────────┐ │    |
│    │ ┌────────────────┐ │  │  │ │  Models(引用)       │ │    │
│    │ │    CoreData    │◄┼──┼──┼─┤                    │ │    │
│    │ └────────────────┘ │  │  │ └────────────────────┘ │    │
│    └────────────────────┘  │  └────────────────────────┘    │
│                            │                                │
│             依赖方向：       │                                │
│     OnlySlideUI ──────────►─── OnlySlideCore                │
│                            │                                │
└────────────────────────────┴────────────────────────────────┘
```

- **OnlySlideCore**：核心业务逻辑和数据处理，不依赖任何 UI 框架
- **OnlySlideUI**：基于 SwiftUI 的用户界面层，采用 MVVM 架构

## 项目整体结构
```
OnlySlide/
├── src/                       // 源代码主目录
│   ├── OnlySlideCore/         // 核心逻辑模块，不包含UI相关代码
│   │   ├── Models/            // 数据模型定义
│   │   │   ├── Document/      // 文档模型（如PPT文档结构）
│   │   │   ├── Template/      // 模板相关模型
│   │   │   ├── Style/         // 样式相关模型（颜色、字体等）
│   │   │   └── Content/       // 内容相关模型（文本、图片等）
│   │   ├── Services/          // 核心业务服务实现
│   │   │   ├── FileService/   // 文件操作服务（导入导出等）
│   │   │   ├── AnalysisService/ // 模板分析服务
│   │   │   ├── GenerationService/ // 幻灯片生成服务
│   │   │   └── AIService/     // AI辅助功能服务
│   │   ├── Protocols/         // 核心接口定义，用于依赖注入和模块解耦
│   │   │   ├── FileManagement/ // 文件管理相关协议
│   │   │   ├── TemplateAnalysis/ // 模板分析相关协议
│   │   │   ├── ContentProcessing/ // 内容处理相关协议
│   │   │   └── SlideGeneration/ // 幻灯片生成相关协议
│   │   └── CoreData/          // 数据持久化实现
│   │       ├── Models/        // CoreData模型定义
│   │       ├── Repositories/  // 数据仓库实现，封装CRUD操作
│   │       └── Migrations/    // 数据模型迁移管理
│   │
│   ├── OnlySlideUI/           // UI模块，依赖于OnlySlideCore
│   │   ├── Views/             // SwiftUI视图实现
│   │   │   ├── Home/          // 主页相关视图
│   │   │   ├── Analysis/      // 分析相关视图
│   │   │   ├── Content/       // 内容编辑相关视图
│   │   │   └── Generation/    // 生成相关视图
│   │   ├── ViewModels/        // 视图模型，连接View和Core服务
│   │   │   ├── Base/          // 基础ViewModel和通用功能组合
│   │   │   ├── Home/          // 主页相关ViewModel
│   │   │   ├── Analysis/      // 分析相关ViewModel
│   │   │   └── Content/       // 内容编辑相关ViewModel
│   │   ├── DesignSystem/      // 设计系统组件库
│   │   │   ├── Foundations/   // 基础UI元素（颜色、字体等）
│   │   │   ├── Components/    // 基础UI组件（按钮、输入框等）
│   │   │   └── Patterns/      // 复合UI组件（卡片、列表等）
│   │   ├── ViewModifiers/     // SwiftUI视图修饰器
│   │   │   ├── Animations/    // 动画相关修饰器
│   │   │   └── Styles/        // 样式相关修饰器
│   │   ├── PlatformAdapters/  // 平台适配层，处理平台差异
│   │   │   ├── PlatformAdapter.swift // 平台适配协议
│   │   │   ├── iOSAdapter.swift // iOS平台特定实现
│   │   │   └── macOSAdapter.swift // macOS平台特定实现
│   │   ├── State/             // 全局状态管理
│   │   │   ├── AppStateManager.swift // 应用状态管理器
│   │   │   └── StateStorage.swift // 状态持久化
│   │   └── Utilities/         // UI相关工具类
│   │       ├── Extensions/    // SwiftUI扩展
│   │       ├── Formatters/    // 数据格式化工具
│   │       └── Helpers/       // 辅助函数和工具
│   │
│   ├── OnlySlide/             // 主应用入口
│   │   ├── App/               // App入口点和生命周期
│   │   ├── Resources/         // 应用资源
│   │   │   ├── Assets/        // 图像和资源文件
│   │   │   └── Localization/  // 本地化文件
│   │   └── Configuration/     // 应用配置
│   │       ├── Environment.swift // 环境变量配置
│   │       └── FeatureFlags.swift // 功能标志管理
│   │
│   ├── Build/                 // 构建脚本
│   │   ├── pre-build.sh       // 构建前执行的脚本
│   │   └── post-build.sh      // 构建后执行的脚本
│   │
│   ├── CI/                    // CI/CD配置脚本
│   │   ├── test.sh            // 自动化测试脚本
│   │   └── deploy.sh          // 部署脚本
│   │
│   └── Utilities/             // 项目工具脚本
│       ├── generate-docs.sh   // 文档生成脚本
│       └── analyze-code.sh    // 代码分析脚本
│
├── Tests/                     // 测试目录
│   ├── UnitTests/             // 单元测试
│   │   ├── CoreTests/         // 核心模块单元测试
│   │   └── UtilityTests/      // 工具类单元测试
│   ├── UITests/               // UI测试
│   │   ├── ViewTests/         // 视图单元测试
│   │   └── FlowTests/         // 用户流程测试
│   ├── PerformanceTests/      // 性能测试
│   └── TestUtilities/         // 测试辅助工具
│       ├── MockFactory.swift  // 模拟对象工厂
│       ├── TestContext.swift  // 测试上下文
│       └── BaseTestCase.swift // 测试基类
│
├── .github/                   // GitHub配置
│   ├── workflows/             // GitHub Actions工作流程
│   │   ├── ci.yml             // 持续集成工作流
│   │   └── release.yml        // 发布工作流
│   └── ISSUE_TEMPLATE/        // Issue模板
│
├── .gitignore                 // Git忽略文件配置
├── .gitattributes             // Git属性配置
├── README.md                  // 项目主要文档
├── CONTRIBUTING.md            // 贡献指南
├── LICENSE                    // 许可证文件
└── CHANGELOG.md               // 变更日志
```
## 代码规范

本项目使用SwiftLint维护代码质量，请在提交代码前执行检查：

```bash
swiftlint
```

主要代码规范：
- 使用驼峰命名法
- 避免强制解包
- 函数体不超过150行
- 类型体不超过300行

# XCFramework实施方案

本方案旨在为OnlySlide项目创建跨平台XCFramework，同时保持现有的项目结构不变。通过引用方式使用现有文件，实现iOS和macOS平台的支持。

## 1. 项目结构保持不变

现有的项目结构将保持不变：

```
src/
├── OnlySlideCore/         // 核心逻辑模块
│   ├── CoreData/          // 数据持久化
│   ├── Models/            // 数据模型
│   ├── Protocols/         // 接口定义
│   └── Services/          // 业务服务
└── OnlySlideUI/           // UI模块
    ├── DesignSystem/      // 设计系统
    ├── PlatformAdapters/  // 平台适配
    ├── State/             // 状态管理
    ├── ViewModels/        // 视图模型
    ├── ViewModifiers/     // 视图修饰器
    └── Views/             // 视图组件
```

## 2. 创建XCFramework目标

### 2.1 创建OnlySlideCore框架目标

1. 打开OnlySlide.xcodeproj
2. 在Xcode菜单中选择 **File > New > Target...**
3. 在弹出的窗口中，选择 **Framework & Library** 选项卡
4. 选择 **Framework**
5. 点击 **Next**
6. 在配置页面上：
   - Product Name: 输入 `OnlySlideCore`
   - Team: 选择您的开发团队
   - Organization Identifier: 保持与主项目一致
   - Bundle Identifier: 自动填充，通常格式为 `com.yourcompany.OnlySlideCore`
   - Language: 选择 **Swift**
   - Include Tests: 勾选
   - Platforms: 选择 **iOS** 和 **macOS**
7. 点击 **Finish**
8. 在弹出的对话框中，选择 **Activate scheme** (激活方案)

### 2.2 创建OnlySlideUI框架目标

重复上述步骤，但在第6步中将产品名称改为 `OnlySlideUI`

## 3. 配置Framework目标

### 3.1 设置OnlySlideCore的构建设置

1. 在Xcode左侧的项目导航器中，选中 **OnlySlideCore** 目标
2. 切换到 **Build Settings** 选项卡
3. 设置以下构建选项：
   ```
   SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx
   SUPPORTS_MACCATALYST = NO
   BUILD_LIBRARY_FOR_DISTRIBUTION = YES
   SKIP_INSTALL = NO
   ```
4. 设置部署目标：
   - iOS Deployment Target = 18.0
   - macOS Deployment Target = 15.0
5. 设置架构支持：
   ```
   VALID_ARCHS[sdk=iphoneos*] = arm64
   VALID_ARCHS[sdk=iphonesimulator*] = x86_64 arm64
   VALID_ARCHS[sdk=macosx*] = x86_64 arm64
   ```

### 3.2 设置OnlySlideUI的构建设置

重复上述步骤，为OnlySlideUI配置相同的构建选项

## 方案4：使用Xcode的引用路径

### 1. 打开Xcode项目

- 双击 `OnlySlide.xcodeproj` 文件以打开项目。

### 2. 选择目标

- 在左侧导航栏中，选择您的项目（OnlySlide）。
- 然后选择 **OnlySlideCore** 目标。

### 3. 进入Build Settings

- 切换到 **Build Settings** 选项卡。

### 4. 添加Header Search Paths

1. **找到Header Search Paths**：
   - 在搜索框中输入“Header Search Paths”以快速找到该设置。

2. **展开Debug和Release**：
   - 点击 **Header Search Paths** 旁边的箭头，展开Debug和Release配置。

3. **为Debug添加路径**：
   - 在Debug下，双击空白区域，添加以下路径：
     ```
     $(SRCROOT)/src/OnlySlideCore
     $(SRCROOT)/src/OnlySlideUI
     ```

4. **为Release添加路径**：
   - 在Release下，双击空白区域，添加相同的路径：
     ```
     $(SRCROOT)/src/OnlySlideCore
     $(SRCROOT)/src/OnlySlideUI
     ```

### 5. 确保路径设置为递归

- 在添加路径时，确保将路径设置为递归（如果有此选项），以便Xcode能够找到子目录中的文件。

### 6. 保存设置

- 完成后，确保保存项目。

### 7. 验证

- 在Swift文件中尝试导入模块：
  ```swift
  import OnlySlideCore
  import OnlySlideUI
  ```

- 按 **Command+B** 构建项目，确保没有错误。

### 8. 处理可能的错误

- 如果遇到找不到模块的错误，请检查路径是否正确设置，并确保文件在指定目录中。

通过这种方式，您可以确保Xcode能够找到源文件，而不需要移动或复制文件。这种方法灵活且不侵入性，适合保持现有项目结构。


## 5. 配置框架依赖关系

### 5.1 设置OnlySlideUI依赖OnlySlideCore

1. 在项目导航器中，选择 **OnlySlideUI** 目标
2. 切换到 **General** 选项卡
3. 滚动到 **Frameworks and Libraries** 部分
4. 点击 **+** 按钮
5. 在搜索框中输入 `OnlySlideCore`
6. 选择 **OnlySlideCore.framework**
7. 在 "Embed" 下拉菜单中，选择 **Do Not Embed**
8. 点击 **Add**

### 5.2 设置主应用依赖两个框架

1. 在项目导航器中，选择 **OnlySlide** 主应用目标
2. 切换到 **General** 选项卡
3. 滚动到 **Frameworks and Libraries** 部分
4. 点击 **+** 按钮
5. 添加 **OnlySlideCore.framework**，设置 "Embed" 为 **Embed & Sign**
6. 再次点击 **+** 按钮
7. 添加 **OnlySlideUI.framework**，设置 "Embed" 为 **Embed & Sign**

## 6. 配置访问级别

### 6.1 在OnlySlideCore中添加公开访问修饰符

1. 打开 **src/OnlySlideCore** 中的关键文件
2. 添加 `public` 修饰符到需要暴露的类型和成员:

```swift
// 修改前
struct Template {
    var id: UUID
    var name: String
}

// 修改后
public struct Template {
    public var id: UUID
    public var name: String
    
    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
```

### 6.2 在OnlySlideUI中添加公开访问修饰符

类似地，为OnlySlideUI中需要暴露的类型添加公开访问修饰符

## 7. 处理平台特定代码

### 7.1 使用条件编译

对于需要针对不同平台实现的功能，使用条件编译：

```swift
#if os(iOS)
public class IOSFileManager: FileManaging {
    public func openFile() -> URL? {
        // iOS特定实现
    }
}
#elseif os(macOS)
public class MacOSFileManager: FileManaging {
    public func openFile() -> URL? {
        // macOS特定实现
    }
}
#endif

// 平台无关的工厂方法
public func createFileManager() -> FileManaging {
    #if os(iOS)
    return IOSFileManager()
    #elseif os(macOS)
    return MacOSFileManager()
    #endif
}
```

### 7.2 使用协议抽象平台差异

```swift
// 在OnlySlideCore中定义协议
public protocol PlatformAdapter {
    func getScreenSize() -> CGSize
    func openDocument() -> URL?
}

// 在OnlySlideUI中实现平台特定适配器
#if os(iOS)
public class IOSPlatformAdapter: PlatformAdapter {
    // iOS实现
}
#elseif os(macOS)
public class MacOSPlatformAdapter: PlatformAdapter {
    // macOS实现
}
#endif
```

## 8. 创建XCFramework构建脚本

创建一个脚本文件 `scripts/build-xcframeworks.sh`：

```bash
#!/bin/bash

# 设置变量
PROJECT_NAME="OnlySlide"
SCHEME_CORE="OnlySlideCore"
SCHEME_UI="OnlySlideUI"
BUILD_DIR="./build"
XCFRAMEWORK_DIR="${BUILD_DIR}/xcframeworks"

# 清理旧的构建产物
rm -rf "${BUILD_DIR}"
mkdir -p "${XCFRAMEWORK_DIR}"

# 构建OnlySlideCore
echo "Building ${SCHEME_CORE}..."

# iOS设备
xcodebuild archive \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_CORE}" \
  -destination "generic/platform=iOS" \
  -archivePath "${BUILD_DIR}/${SCHEME_CORE}-iOS" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# iOS模拟器
xcodebuild archive \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_CORE}" \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "${BUILD_DIR}/${SCHEME_CORE}-iOS-Simulator" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# macOS
xcodebuild archive \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_CORE}" \
  -destination "generic/platform=macOS" \
  -archivePath "${BUILD_DIR}/${SCHEME_CORE}-macOS" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# 创建XCFramework
xcodebuild -create-xcframework \
  -framework "${BUILD_DIR}/${SCHEME_CORE}-iOS.framework" \
  -framework "${BUILD_DIR}/${SCHEME_CORE}-iOS-Simulator.framework" \
  -framework "${BUILD_DIR}/${SCHEME_CORE}-macOS.framework" \
  -output "${XCFRAMEWORK_DIR}/${SCHEME_CORE}.xcframework"

# 构建OnlySlideUI (类似步骤)
echo "Building ${SCHEME_UI}..."

# iOS设备
xcodebuild archive \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_UI}" \
  -destination "generic/platform=iOS" \
  -archivePath "${BUILD_DIR}/${SCHEME_UI}-iOS" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# iOS模拟器
xcodebuild archive \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_UI}" \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "${BUILD_DIR}/${SCHEME_UI}-iOS-Simulator" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# macOS
xcodebuild archive \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_UI}" \
  -destination "generic/platform=macOS" \
  -archivePath "${BUILD_DIR}/${SCHEME_UI}-macOS" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# 创建XCFramework
xcodebuild -create-xcframework \
  -framework "${BUILD_DIR}/${SCHEME_UI}-iOS.framework" \
  -framework "${BUILD_DIR}/${SCHEME_UI}-iOS-Simulator.framework" \
  -framework "${BUILD_DIR}/${SCHEME_UI}-macOS.framework" \
  -output "${XCFRAMEWORK_DIR}/${SCHEME_UI}.xcframework"

echo "XCFrameworks built successfully at ${XCFRAMEWORK_DIR}"
```

## 9. 更新CI配置

更新GitHub Actions工作流配置 `.github/workflows/ci.yml`：

```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  build:
    name: Build and Test
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode
      run: sudo xcode-select -switch /Applications/Xcode.app
      
    - name: Build iOS
      run: |
        xcodebuild clean build -project OnlySlide.xcodeproj -scheme OnlySlide -destination "platform=iOS Simulator,name=iPhone 14" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
        
    - name: Build macOS
      run: |
        xcodebuild clean build -project OnlySlide.xcodeproj -scheme OnlySlide -destination "platform=macOS" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
        
    - name: Run iOS tests
      run: |
        xcodebuild test -project OnlySlide.xcodeproj -scheme OnlySlide -destination "platform=iOS Simulator,name=iPhone 14" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
        
    - name: Run macOS tests
      run: |
        xcodebuild test -project OnlySlide.xcodeproj -scheme OnlySlide -destination "platform=macOS" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
        
    - name: Build XCFrameworks
      run: |
        chmod +x ./scripts/build-xcframeworks.sh
        ./scripts/build-xcframeworks.sh
        
    - name: Archive XCFrameworks
      uses: actions/upload-artifact@v3
      with:
        name: xcframeworks
        path: build/xcframeworks/
```

## 10. 故障排除指南

### 10.1 找不到模块错误

如果遇到 "No such module 'OnlySlideCore'" 错误:
1. 清理项目 (Product > Clean Build Folder)
2. 关闭并重新打开Xcode
3. 确保Framework正确嵌入到主应用中
4. 检查Build Phases中的依赖关系

### 10.2 访问控制错误

如果遇到 "'XXX' is inaccessible due to 'internal' protection level" 错误:
1. 确保相关类型和成员已添加 `public` 修饰符
2. 确保公开类型的初始化方法也标记为 `public`
3. 检查是否所有需要跨模块访问的属性都标记为 `public`

### 10.3 平台特定编译错误

如果遇到平台特定的编译错误:
1. 使用条件编译 (`#if os(iOS)` / `#elseif os(macOS)`)隔离平台特定代码
2. 确保使用了正确的平台API
3. 考虑使用协议抽象平台差异

### 10.4 XCFramework构建错误

如果构建XCFramework时遇到错误:
1. 确保所有依赖关系正确配置
2. 检查构建设置中的架构配置
3. 确保脚本中的路径和项目名称正确

## 11. 最佳实践

### 11.1 模块化设计

- 保持OnlySlideCore不依赖UI框架
- 通过协议定义模块间接口
- 使用依赖注入而非直接实例化

### 11.2 跨平台兼容性

- 尽可能使用平台无关的API
- 将平台特定代码隔离到适配器中
- 使用条件编译处理不可避免的平台差异

### 11.3 性能优化

- 最小化公共API数量
- 避免在启动时执行昂贵的操作
- 使用懒加载初始化大型资源

### 11.4 版本管理

- 在每个模块中维护版本号
- 使用语义化版本控制
- 记录API变更到CHANGELOG.md

## 12. 发布流程

1. 更新版本号
2. 运行测试确保所有平台通过
3. 构建XCFramework
4. 更新CHANGELOG.md
5. 创建Git标签
6. 发布GitHub Release，附加XCFramework文件

