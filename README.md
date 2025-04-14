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

# Xcode嵌入式框架（Framework Targets）实施指南

## 1. 创建Framework目标

### 1.1 创建OnlySlideCore框架

1. 打开OnlySlide.xcodeproj
2. 在Xcode菜单中选择 **File > New > Target...**
3. 在弹出的窗口中，选择 **Framework & Library** 选项卡
4. 在iOS部分，选择 **Framework**
5. 点击 **Next**
6. 在配置页面上：
   - Product Name: 输入 `OnlySlideCore`
   - Team: 选择您的开发团队
   - Organization Identifier: 保持与主项目一致
   - Bundle Identifier: 自动填充，通常格式为 `com.yourcompany.OnlySlideCore`
   - Language: 选择 **Swift**
   - Include Tests: 勾选
7. 点击 **Finish**
8. 在弹出的对话框中，选择 **Activate scheme** (激活方案)

### 1.2 创建OnlySlideUI框架

重复上述步骤，但在第6步中将产品名称改为 `OnlySlideUI`

## 2. 配置Framework目标

### 2.1 设置OnlySlideCore的部署目标

1. 在Xcode左侧的项目导航器中，选中 **OnlySlideCore** 目标
2. 在 **General** 选项卡中：
   - Deployment Info > iOS部分：将最低部署目标设置为 **iOS 18.0**
   - Deployment Info > macOS部分：将最低部署目标设置为 **macOS 15.0**

### 2.2 设置OnlySlideUI的部署目标

重复上述步骤，为OnlySlideUI配置相同的部署目标

## 3. 配置源文件引用

### 3.1 移除默认生成的文件

1. 在Xcode导航器中，展开 **OnlySlideCore** 组
2. 找到自动生成的 `OnlySlideCore.h` 和其他文件
3. 右键单击 > 选择 **Delete**
4. 在弹出的对话框中，选择 **Move to Trash**
5. 对 **OnlySlideUI** 重复相同操作

### 3.2 添加OnlySlideCore的源文件

1. 右键单击 **OnlySlideCore** 组
2. 选择 **Add Files to "OnlySlideCore"...**
3. 导航到项目的 **src/OnlySlideCore** 目录
4. 选择所有需要包含的子目录（Models, Services, Protocols, CoreData等）
5. 配置添加选项：
   - **取消勾选** "Copy items if needed"（不复制文件）
   - 选择 **Create groups** (为添加的文件创建组)
   - Targets部分：确保 **OnlySlideCore** 被勾选
6. 点击 **Add**

### 3.3 添加OnlySlideUI的源文件

重复上述步骤，但选择 **src/OnlySlideUI** 目录下的文件，并确保目标是 **OnlySlideUI**

## 4. 配置框架依赖关系

### 4.1 设置OnlySlideUI依赖OnlySlideCore

1. 在项目导航器中，选择 **OnlySlideUI** 目标
2. 切换到 **General** 选项卡
3. 滚动到 **Frameworks and Libraries** 部分
4. 点击 **+** 按钮
5. 在搜索框中输入 `OnlySlideCore`
6. 选择 **OnlySlideCore.framework**
7. 在 "Embed" 下拉菜单中，选择 **Do Not Embed**
8. 点击 **Add**

### 4.2 设置主应用依赖两个框架

1. 在项目导航器中，选择 **OnlySlide** 主应用目标
2. 切换到 **General** 选项卡
3. 滚动到 **Frameworks and Libraries** 部分
4. 点击 **+** 按钮
5. 添加 **OnlySlideCore.framework**，设置 "Embed" 为 **Embed & Sign**
6. 再次点击 **+** 按钮
7. 添加 **OnlySlideUI.framework**，设置 "Embed" 为 **Embed & Sign**

## 5. 配置访问级别

### 5.1 在OnlySlideCore中添加公开访问修饰符

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

### 5.2 在OnlySlideUI中添加公开访问修饰符

类似地，为OnlySlideUI中需要暴露的类型添加公开访问修饰符

## 6. 构建设置优化

### 6.1 配置OnlySlideCore的构建设置

1. 选择 **OnlySlideCore** 目标
2. 切换到 **Build Settings** 选项卡
3. 在搜索框中输入 `build lib`
4. 找到 **Build Libraries for Distribution** 设置并将其设为 **Yes**
5. 搜索 `always embed`，确认 **Always Embed Swift Standard Libraries** 设为 **No**

### 6.2 配置OnlySlideUI的构建设置

重复上述步骤，为OnlySlideUI设置相同的构建选项

### 6.3 配置主应用构建设置

1. 选择主应用目标
2. 搜索 `always embed`
3. 将 **Always Embed Swift Standard Libraries** 设为 **Yes**

## 7. 验证配置

### 7.1 构建项目

1. 在Xcode工具栏中，选择主应用方案
2. 按 **Command+B** 构建项目
3. 确保构建成功，无编译错误

### 7.2 测试模块导入

在主应用的任意源文件顶部添加:

```swift
import OnlySlideCore
import OnlySlideUI
```

确保没有报错，表示框架正确配置并可使用

## 8. 解决常见问题

### 8.1 找不到模块错误

如果遇到 "No such module 'OnlySlideCore'" 错误:
1. 清理项目 (Product > Clean Build Folder)
2. 关闭并重新打开Xcode
3. 重新构建

### 8.2 访问控制错误

如果遇到 "'XXX' is inaccessible due to 'internal' protection level" 错误:
1. 确保相关类型和成员已添加 `public` 修饰符
2. 确保公开类型的初始化方法也标记为 `public`

### 8.3 链接错误

如果遇到链接错误:
1. 检查 "Frameworks and Libraries" 部分的配置
2. 确保 "Embed" 设置正确
3. 重新构建框架目标

完成这些步骤后，您将拥有一个基于Xcode Framework的模块化项目结构，便于维护和开发。

# 迁移实施指南

这个迁移计划是渐进式的，允许在保持应用功能的同时逐步改进结构。关键点包括：

1. **保持功能连续性**：每个迁移步骤后，确保应用仍然可以构建和运行
2. **模块测试**：每个模块迁移后，编写单元测试验证功能
3. **先迁移核心层**：优先处理OnlySlideCore的迁移，然后是OnlySlideUI
4. **清理临时结构**：完成整体迁移后，移除不再需要的临时文件和目录

通过按阶段执行这个迁移计划，我们可以平稳地将当前结构转换为理想的模块化架构，同时持续保持项目的可开发性和稳定性。
