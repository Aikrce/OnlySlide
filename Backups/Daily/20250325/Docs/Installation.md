# OnlySlide CoreDataModule 安装和集成指南

本文档提供了关于如何将 OnlySlide 的 CoreDataModule 集成到您的项目中的详细指导。

## 目录

- [系统要求](#系统要求)
- [安装](#安装)
  - [使用 Swift Package Manager](#使用-swift-package-manager)
  - [手动集成](#手动集成)
- [项目配置](#项目配置)
- [基本设置](#基本设置)
- [迁移步骤](#迁移步骤)
  - [从老架构迁移](#从老架构迁移)
  - [全新项目集成](#全新项目集成)
- [验证安装](#验证安装)
- [高级集成](#高级集成)
- [故障排除](#故障排除)

## 系统要求

- **Swift 版本**: Swift 5.9 或更高
- **Xcode 版本**: Xcode 15.0 或更高
- **iOS 版本**: iOS 16.0 或更高
- **macOS 版本**: macOS 13.0 或更高
- **依赖项**: Foundation, CoreData, Combine

## 安装

### 使用 Swift Package Manager

1. 在您的 Xcode 项目中，选择 **File** > **Add Packages...**
2. 在搜索栏中输入包的 URL: `https://github.com/yourorganization/onlyslide-coredatamodule.git`
3. 选择版本规则 (例如 "Up to Next Major Version")
4. 点击 **Add Package**
5. 选择要集成的目标，然后点击 **Add Package**

或者，您可以直接在 `Package.swift` 文件中添加依赖:

```swift
dependencies: [
    .package(url: "https://github.com/yourorganization/onlyslide-coredatamodule.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "CoreDataModule", package: "onlyslide-coredatamodule")
        ]
    )
]
```

### 手动集成

如果您需要手动集成 CoreDataModule，请按照以下步骤操作:

1. 下载最新的 CoreDataModule 源代码 (或者克隆仓库)
2. 将 `Sources/CoreDataModule` 文件夹拖拽到您的 Xcode 项目中
3. 在弹出的对话框中，确保选中 "Copy items if needed" 和您的目标应用
4. 点击 **Finish** 完成添加

## 项目配置

### 添加必要的权限

如果您的应用使用 iCloud 同步功能，需要添加以下权限到您的 `Info.plist` 文件:

```xml
<key>NSUbiquitousContainers</key>
<dict>
    <key>iCloud.com.yourcompany.appname</key>
    <dict>
        <key>NSUbiquitousContainerIsDocumentScopePublic</key>
        <true/>
        <key>NSUbiquitousContainerName</key>
        <string>AppName</string>
        <key>NSUbiquitousContainerSupportedFolderLevels</key>
        <string>Any</string>
    </dict>
</dict>
```

### 配置数据模型

确保您的 Core Data 模型文件 (.xcdatamodeld) 在项目中，并且正确配置了版本:

1. 在 Xcode 中选择您的 .xcdatamodeld 文件
2. 选择 **Editor** > **Add Model Version...**
3. 为新的模型版本命名，例如 "MyModel_2.0"
4. 设置当前模型版本: 选择您的 .xcdatamodeld 文件，在属性检查器中设置 "Current" 为最新版本

## 基本设置

在您的应用中集成 CoreDataModule 的基本步骤:

### 1. 导入模块

在需要使用 CoreDataModule 的文件中导入模块:

```swift
import CoreDataModule
```

### 2. 应用启动时初始化

在应用的入口点或 AppDelegate 中初始化 CoreDataModule:

```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 初始化依赖注册表
        DependencyRegistry.shared.registerDefaults()
        
        // 自定义设置 (可选)
        setupCustomDependencies()
        
        return true
    }
    
    private func setupCustomDependencies() {
        // 注册自定义实现或重写默认实现
        DependencyRegistry.shared.register(CustomService.self) { CustomServiceImpl() }
    }
}
```

### 3. 配置数据存储

配置 Core Data 存储位置和选项:

```swift
@MainActor
func configureDataStore() {
    let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        .first!.appendingPathComponent("MyStore.sqlite")
    
    // 获取 CoreDataStack
    let coreDataStack: CoreDataStack = resolve()
    
    // 配置存储选项
    let options: [String: Any] = [
        NSMigratePersistentStoresAutomaticallyOption: false,
        NSInferMappingModelAutomaticallyOption: false
    ]
    
    // 加载存储
    coreDataStack.loadStore(at: storeURL, options: options)
}
```

## 迁移步骤

### 从老架构迁移

如果您正在将应用从旧架构迁移到 CoreDataModule，请按照以下步骤操作:

#### 1. 替换单例访问方式

使用依赖注入替换直接的单例访问:

```swift
// 旧代码
let context = CoreDataManager.shared.managedObjectContext

// 新代码
let coreDataStack: CoreDataStack = resolve()
let context = coreDataStack.viewContext
```

#### 2. 使用适配器类进行平滑过渡

CoreDataModule 提供了适配器类，帮助您逐步迁移:

```swift
// 创建一个扩展，使旧代码仍然可以工作
extension CoreDataManager {
    static var shared: CoreDataManager {
        return CoreDataManagerAdapter.shared
    }
}

class CoreDataManagerAdapter: CoreDataManager {
    static let shared = CoreDataManagerAdapter()
    
    private let stack: CoreDataStack = resolve()
    
    override var managedObjectContext: NSManagedObjectContext {
        return stack.viewContext
    }
    
    // 实现其他需要适配的方法...
}
```

#### 3. 更新错误处理

更新代码以使用新的错误处理系统:

```swift
// 旧代码
do {
    try operation()
} catch {
    CoreDataErrorManager.shared.handleError(error)
}

// 新代码
do {
    try operation()
} catch {
    let errorHandler: ErrorHandlingService = resolve()
    errorHandler.handle(error, context: "操作上下文")
}
```

#### 4. 迁移数据迁移逻辑

更新数据库迁移代码:

```swift
// 旧代码
let manager = CoreDataMigrationManager()
try manager.migrateStore(at: storeURL)

// 新代码
let migrationManager: EnhancedMigrationManager = resolve()
try await migrationManager.migrate(storeAt: storeURL)
```

### 全新项目集成

如果您正在将 CoreDataModule 集成到新项目中，可以直接采用最佳实践:

#### 1. 初始化依赖注册表

```swift
// 在应用启动时
DependencyRegistry.shared.registerDefaults()
```

#### 2. 创建服务层

```swift
struct DataService {
    // 使用依赖注入获取所需组件
    private let coreDataStack: CoreDataStack = resolve()
    private let migrationManager: EnhancedMigrationManager = resolve()
    private let errorHandler: EnhancedErrorHandler = resolve()
    
    // 实现数据操作方法
    func fetchEntities() async throws -> [MyEntity] {
        // 使用上下文访问器
        let contextAccessor = CoreDataContextAccessor(context: coreDataStack.viewContext)
        return try await contextAccessor.performAsync { context in
            let request = MyEntity.fetchRequest()
            return try context.fetch(request) as! [MyEntity]
        }
    }
    
    // 初始化数据库
    func initializeDatabase() async throws {
        let storeURL = getStoreURL()
        
        // 检查是否需要迁移
        if try await migrationManager.needsMigration(at: storeURL) {
            // 执行迁移
            try await migrationManager.migrate(storeAt: storeURL)
        }
        
        // 加载存储
        coreDataStack.loadStore(at: storeURL)
    }
}
```

## 验证安装

完成安装和配置后，您可以运行以下代码验证 CoreDataModule 是否正确集成:

```swift
func testCoreDataModuleIntegration() async {
    do {
        // 1. 解析依赖
        let migrationManager: EnhancedMigrationManager = resolve()
        let errorHandler: EnhancedErrorHandler = resolve()
        let versionManager: ModelVersionManaging = resolve()
        
        // 2. 检查模型版本
        let currentVersion = try versionManager.currentModelVersion()
        print("当前模型版本: \(currentVersion)")
        
        // 3. 测试错误处理
        errorHandler.handle(CoreDataError.storeNotFound("Test"), context: "验证测试")
        
        print("CoreDataModule 集成成功!")
    } catch {
        print("CoreDataModule 集成测试失败: \(error)")
    }
}
```

## 高级集成

### 注册自定义组件

您可以注册自定义实现来替换默认组件:

```swift
// 注册自定义的模型版本管理器
DependencyRegistry.shared.register(ModelVersionManaging.self) {
    CustomModelVersionManager()
}

// 注册带配置的错误处理器
DependencyRegistry.shared.register(ErrorHandlingService.self) {
    let handler = EnhancedErrorHandler.createDefault()
    handler.logLevel = .detailed
    handler.shouldDisplayAlerts = true
    return handler
}
```

### 配置 CoreData 存储选项

您可以配置高级存储选项:

```swift
// 创建存储配置
let storeDescription = NSPersistentStoreDescription()
storeDescription.url = storeURL
storeDescription.type = NSSQLiteStoreType
storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

// 配置自定义容器
let container = IsolatedPersistentContainer(name: "MyModel")
```

### 添加云同步支持

配置 iCloud 同步支持:

```swift
// 获取同步管理器
let syncManager: EnhancedSyncManager = resolve()

// 配置同步选项
let options = SyncOptions(
    direction: .bidirectional,
    autoMergeStrategy: .mostRecent,
    rollbackOnFailure: true
)

// 执行同步
Task {
    do {
        let success = try await syncManager.sync(with: options)
        print("同步结果: \(success ? "成功" : "已在进行中")")
    } catch {
        print("同步失败: \(error)")
    }
}
```

## 故障排除

### 常见问题

#### 1. 找不到符号

**问题**: 编译错误，找不到 CoreDataModule 中的符号。

**解决方案**:
- 确认已正确导入模块 (`import CoreDataModule`)
- 检查项目设置中是否正确链接了 CoreDataModule 库
- 清理项目 (Xcode -> Product -> Clean Build Folder) 然后重新构建

#### 2. 运行时依赖注入错误

**问题**: 尝试解析依赖时出现运行时错误。

**解决方案**:
- 确保在使用之前调用了 `DependencyRegistry.shared.registerDefaults()`
- 检查依赖类型是否与注册类型匹配
- 如果使用自定义实现，确保已经注册

#### 3. 迁移失败

**问题**: 数据库迁移失败，应用无法启动。

**解决方案**:
- 启用详细日志记录以查看具体错误
- 使用备份选项进行迁移，以便在失败时恢复
- 检查映射模型文件是否正确设置

```swift
// 启用详细日志
Logger.shared.logLevel = .debug

// 使用备份选项
let options = MigrationOptions(
    backupStore: true,
    recoveryEnabled: true
)
```

#### 4. 并发错误

**问题**: Core Data 并发错误，例如 "Core Data could not fulfill a fault for..."

**解决方案**:
- 使用 `CoreDataContextAccessor` 确保在正确的线程上访问 Core Data
- 不要跨线程传递托管对象，而是传递对象 ID
- 在后台操作中使用新的上下文

## 高级配置示例

### 多环境配置

```swift
enum Environment {
    case development
    case staging
    case production
}

func configureCoreDataModule(for environment: Environment) {
    DependencyRegistry.shared.registerDefaults()
    
    switch environment {
    case .development:
        // 开发环境配置
        DependencyRegistry.shared.register(ErrorHandlingService.self) {
            let handler = EnhancedErrorHandler.createDefault()
            handler.logLevel = .debug
            return handler
        }
        
    case .staging:
        // 测试环境配置
        DependencyRegistry.shared.register(ErrorHandlingService.self) {
            let handler = EnhancedErrorHandler.createDefault()
            handler.logLevel = .info
            return handler
        }
        
    case .production:
        // 生产环境配置
        DependencyRegistry.shared.register(ErrorHandlingService.self) {
            let handler = EnhancedErrorHandler.createDefault()
            handler.logLevel = .error
            return handler
        }
    }
}
```

### UI集成示例

```swift
class DataMigrationViewController: UIViewController {
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var statusLabel: UILabel!
    
    private var cancellables = Set<AnyCancellable>()
    private let migrationManager: EnhancedMigrationManager = resolve()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // 订阅迁移进度
        migrationManager.migrationProgressPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                self?.progressBar.progress = Float(progress.fractionCompleted)
                self?.statusLabel.text = progress.localizedDescription
            }
            .store(in: &cancellables)
    }
    
    @IBAction func startMigration(_ sender: Any) {
        Task {
            do {
                let result = try await migrationManager.migrate(storeAt: getStoreURL())
                await MainActor.run {
                    // 处理完成
                    switch result {
                    case .success:
                        statusLabel.text = "迁移成功"
                    case .noMigrationNeeded:
                        statusLabel.text = "无需迁移"
                    case .cancelled:
                        statusLabel.text = "迁移已取消"
                    }
                }
            } catch {
                await MainActor.run {
                    // 处理错误
                    statusLabel.text = "迁移失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
```

## 更多资源

有关更多信息，请参阅以下资源:

- [Core Data 架构文档](Architecture/CoreDataArchitecture.md)
- [使用指南](UsageGuide.md)
- [迁移指南](Migration/MigrationGuide.md)
- [错误处理最佳实践](ErrorHandling/BestPractices.md)
- [示例项目](Examples/README.md)

如有任何问题或需要帮助，请联系我们的支持团队:

- 邮件: support@onlyslide.com
- 内部讨论组: #onlyslide-support 