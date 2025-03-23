# OnlySlide 开发指南 | Development Guide

## 1. 架构设计 | Architecture Design

### 1.1 整体架构 | Overall Architecture
```
┌─────────────────────────────┐
│    Presentation Layer (UI)  │
│    ┌──────────────────┐     │
│    │      Views       │     │
│    │    ViewModels    │     │
│    └──────────────────┘     │
├─────────────────────────────┤
│    Domain Layer (Business)  │
│    ┌──────────────────┐     │
│    │    Use Cases     │     │
│    │  Domain Models   │     │
│    └──────────────────┘     │
├─────────────────────────────┤
│    Data Layer (Access)      │
│    ┌──────────────────┐     │
│    │   Repositories   │     │
│    │   Data Sources   │     │
│    └──────────────────┘     │
└─────────────────────────────┘

// 架构说明：
// 1. Presentation Layer: 负责UI展示和用户交互，采用SwiftUI和MVVM模式
// 2. Domain Layer: 包含业务逻辑和领域模型，确保业务规则的独立性
// 3. Data Layer: 处理数据访问和持久化，包括本地存储和网络请求
```

### 1.2 依赖注入 | Dependency Injection
```swift
/// 依赖注入容器 - 使用工厂模式管理依赖
final class DependencyContainer {
    static let shared = DependencyContainer()
    
    // MARK: - Factory Methods
    
    /// 创建文档列表视图及其依赖
    /// - Returns: 完整配置的DocumentListView实例
    /// - Note: 自动注入所有必要的依赖，包括仓库、用例和视图模型
    func makeDocumentListView() -> DocumentListView {
        let repository = makeDocumentRepository()
        let useCase = makeDocumentUseCase(repository: repository)
        let viewModel = makeDocumentListViewModel(useCase: useCase)
        return DocumentListView(viewModel: viewModel)
    }
    
    /// 创建AI模型工厂
    /// - Returns: 配置完成的AI模型工厂实例
    /// - Note: 预注册所有支持的AI模型（OpenAI、DeepSeek等）
    func makeAIModelFactory() -> AIModelFactory {
        let factory = AIModelFactory()
        // 注册默认模型
        return factory
    }
}
```

### 1.3 AI模型集成 | AI Model Integration
```swift
/// AI模型抽象接口 - 定义AI能力的统一接口
protocol AIModelProtocol {
    /// 生成内容
    /// - Parameter prompt: 输入提示
    /// - Returns: 生成的内容
    /// - Throws: AIModelError
    func generateContent(prompt: String) async throws -> String
    
    /// 分析内容
    /// - Parameter text: 待分析文本
    /// - Returns: 内容分析结果
    /// - Throws: AIModelError
    func analyzeContent(text: String) async throws -> ContentAnalysis
    
    /// 提取问题
    /// - Parameter text: 源文本
    /// - Returns: 提取的问题列表
    /// - Throws: AIModelError
    func extractQuestions(text: String) async throws -> [Question]
}

/// AI模型工厂 - 管理和切换不同的AI模型实现
final class AIModelFactory {
    static let shared = AIModelFactory()
    private var registeredModels: [String: AIModelProtocol] = [:]
    
    /// 注册新的AI模型
    /// - Parameters:
    ///   - model: AI模型实现
    ///   - key: 模型标识符
    func register(model: AIModelProtocol, for key: String)
    
    /// 获取指定的AI模型
    /// - Parameter key: 模型标识符
    /// - Returns: AI模型实例或nil
    func getModel(for key: String) -> AIModelProtocol?
}
```

### 1.4 内容处理架构 | Content Processing Architecture
```swift
/// 内容处理流水线 - 处理文本和结构化内容
final class ContentProcessingPipeline {
    // MARK: - Processing Steps
    
    /// 预处理内容
    /// - Parameter content: 原始内容
    /// - Returns: 预处理后的内容
    /// - Throws: ProcessingError
    func preprocess(content: String) async throws -> ProcessedContent
    
    /// 提取关键信息
    /// - Parameter content: 预处理后的内容
    /// - Returns: 提取的信息
    /// - Throws: ProcessingError
    func extract(from content: ProcessedContent) async throws -> ExtractedInfo
    
    /// 转换为演示文稿格式
    /// - Parameter info: 提取的信息
    /// - Returns: 演示文稿内容
    /// - Throws: ProcessingError
    func transform(info: ExtractedInfo) async throws -> PresentationContent
}

/// 视频处理流水线 - 处理视频内容
final class VideoProcessingPipeline {
    // MARK: - Video Processing
    
    /// 下载并验证视频
    /// - Parameter url: 视频URL
    /// - Returns: 本地视频对象
    /// - Throws: VideoProcessingError
    func download(from url: URL) async throws -> LocalVideo
    
    /// 提取关键帧
    /// - Parameter video: 本地视频
    /// - Returns: 关键帧数组
    /// - Throws: VideoProcessingError
    func extractKeyFrames(from video: LocalVideo) async throws -> [Frame]
    
    /// 转换为PPT兼容格式
    /// - Parameter frames: 关键帧
    /// - Returns: PPT视频资源
    /// - Throws: VideoProcessingError
    func convertToPPTFormat(frames: [Frame]) async throws -> PPTVideoAsset
}
```

### 1.5 错误处理与恢复策略
```swift
// 统一错误处理
enum AppError: Error {
    case aiModelError(AIModelError)
    case contentProcessingError(ProcessingError)
    case networkError(NetworkError)
    case storageError(StorageError)
    
    var recoveryStrategy: RecoveryStrategy {
        switch self {
        case .aiModelError: return .retryWithFallback
        case .contentProcessingError: return .partialProcess
        case .networkError: return .retryWithBackoff
        case .storageError: return .useLocalCache
        }
    }
}
```

### 1.6 缓存与性能优化
```swift
// 多级缓存策略
final class CacheManager {
    // 内存缓存
    private let memoryCache: NSCache<NSString, AnyObject>
    // 磁盘缓存
    private let diskCache: DiskCache
    // 网络缓存
    private let networkCache: URLCache
    
    // 智能缓存策略
    func cached<T>(key: String, generator: () async throws -> T) async throws -> T
}
```

### 1.7 性能监控与分析
```swift
// 性能监控系统
final class PerformanceMonitor {
    // AI调用性能
    func trackAIModelPerformance(model: String, operation: String, duration: TimeInterval)
    // 内容处理性能
    func trackContentProcessing(type: ContentType, size: Int, duration: TimeInterval)
    // 资源使用情况
    func trackResourceUsage(memory: Int, cpu: Double, storage: Int)
}
```

### 1.8 安全与隐私
```swift
// 数据安全管理
final class SecurityManager {
    // 敏感数据处理
    func securelySaveAPIKey(_ key: String) throws
    // 内容加密
    func encryptContent(_ content: Data) throws -> EncryptedData
    // 用户隐私保护
    func sanitizeContent(_ content: String) throws -> String
}
```

### 1.9 代码备份与版本控制架构
```swift
// 代码备份管理器
final class CodeBackupManager {
    // 本地代码备份
    func backupLocalCode(to path: URL) async throws -> BackupResult
    // 远程代码备份
    func backupToRemote(credentials: BackupCredentials) async throws -> BackupResult
    // 增量备份
    func incrementalBackup() async throws -> BackupResult
    // 版本追踪
    func trackVersionChanges() async throws -> [VersionChange]
}

// 备份策略定义
protocol BackupStrategy {
    // 确定备份时机
    func shouldBackup(lastBackupDate: Date) -> Bool
    // 确定备份内容
    func determineBackupContent() -> BackupContent
    // 执行备份
    func performBackup(content: BackupContent) async throws
}

// 自动备份配置
struct AutoBackupConfig {
    // 备份周期
    let interval: TimeInterval
    // 备份位置
    let locations: [BackupLocation]
    // 备份保留策略
    let retentionPolicy: RetentionPolicy
    // 压缩策略
    let compressionStrategy: CompressionStrategy
}

// 备份监控
final class BackupMonitor {
    // 监控备份状态
    func monitorBackupStatus() -> AnyPublisher<BackupStatus, Never>
    // 备份失败通知
    func notifyBackupFailure(_ error: Error)
    // 备份统计
    func getBackupStatistics() -> BackupStats
}
```

### 1.10 系统集成架构
```swift
// 系统集成管理器
final class IntegrationManager {
    // AI模型集成
    private let aiModelManager: AIModelFactory
    // 内容处理集成
    private let contentProcessor: ContentProcessingPipeline
    // 备份集成
    private let backupManager: CodeBackupManager
    // 安全管理
    private let securityManager: SecurityManager
    
    // 统一配置管理
    func configure(with config: SystemConfig) async throws
    // 健康检查
    func performHealthCheck() async -> SystemHealth
    // 系统状态监控
    func monitorSystemStatus() -> AnyPublisher<SystemStatus, Never>
}

// 系统配置
struct SystemConfig {
    // AI模型配置
    let aiConfig: AIModelConfig
    // 内容处理配置
    let processingConfig: ProcessingConfig
    // 备份配置
    let backupConfig: AutoBackupConfig
    // 安全配置
    let securityConfig: SecurityConfig
}
```

## 2. 项目结构 | Project Structure

```
OnlySlide/
├── App/                    # 应用层
│   └── Presentation/      # UI展示层
│       ├── Views/         # SwiftUI视图
│       ├── ViewModels/    # 视图模型
│       └── Components/    # 可复用UI组件
├── Core/                   # 核心层
│   ├── Application/      # 应用服务层
│   │   ├── UseCases/    # 用例实现
│   │   ├── Services/    # 应用服务
│   │   └── DTOs/        # 数据传输对象
│   ├── Domain/          # 领域层
│   │   ├── Models/      # 领域模型
│   │   ├── Interfaces/  # 接口定义
│   │   └── Services/    # 领域服务
│   ├── Data/            # 数据层
│   │   ├── Infrastructure/  # 基础设施
│   │   ├── Persistence/     # 持久化
│   │   └── Services/        # 数据服务
│   ├── Automation/      # 自动化工具
│   ├── DI/             # 依赖注入
│   └── Backup/         # 备份系统
├── Features/              # 功能模块
│   ├── DocumentProcessing/  # 文档处理
│   ├── AIAssistant/        # AI助手
│   └── TemplateAnalysis/   # 模板分析
├── Common/                # 公共组件
│   ├── Extensions/      # Swift扩展
│   ├── Utilities/       # 工具类
│   └── Constants/       # 常量定义
├── Sources/               # SPM主入口
├── Tests/                # 测试
│   ├── UnitTests/       # 单元测试
│   ├── IntegrationTests/# 集成测试
│   └── UITests/         # UI测试
└── Scripts/              # 工具脚本
    ├── Build/           # 构建脚本
    └── Deploy/          # 部署脚本
```

## 3. 编码规范 | Coding Standards

### 3.1 文件命名规范 | File Naming
- Views: `{Name}View.swift`, `{Name}Screen.swift`
- ViewModels: `{Name}ViewModel.swift`
- Use Cases: `{Action}{Entity}UseCase.swift`
- Repositories: `{Name}Repository.swift`
- Services: `{Name}Service.swift`
- Protocols: `{Name}Protocol.swift`

### 3.2 代码组织 | Code Organization
```swift
// MARK: - 视图结构示例
struct DocumentListView: View {
    // MARK: - Properties
    @StateObject private var viewModel: DocumentListViewModel
    
    // MARK: - View Components
    private var listContent: some View { }
    
    // MARK: - Body
    var body: some View { }
    
    // MARK: - Actions
    private func handleDocumentTap(_ document: Document) { }
}

// MARK: - ViewModel结构示例
final class DocumentListViewModel: ObservableObject {
    @Published private(set) var state: ViewState
    private let useCase: ProcessDocumentUseCase
}
```

### 3.3 文档注释规范 | Documentation
```swift
/// 组件的详细描述
/// - Parameters:
///   - param1: 参数1的说明
///   - param2: 参数2的说明
/// - Returns: 返回值说明
/// - Throws: 可能的异常
/// - Note: 补充说明
```

## 4. 数据管理 | Data Management

### 4.1 Core Data 模型设计

#### 4.1.1 模型位置
```
Core/Data/Persistence/CoreData/
├── OnlySlide.xcdatamodeld/     # Core Data 模型文件
├── CoreDataStack.swift         # Core Data 栈管理
├── CoreDataManager.swift       # Core Data 管理器
├── CoreDataError.swift        # 错误定义
├── Migration/                 # 数据迁移
├── Performance/              # 性能优化
├── Sync/                    # 数据同步
├── Test/                   # 测试支持
├── Error/                 # 错误处理
└── Extensions/           # Core Data 扩展
```

#### 4.1.2 实体设计
- **Document** (文档实体)
  ```swift
  entity Document {
      // 基本属性
      attribute uuid: UUID
      attribute title: String
      attribute creationDate: Date
      attribute lastModifiedAt: Date
      attribute content: Binary
      attribute metadata: Binary?
      
      // 关系
      relationship slides: Slide (to-many)
      relationship owner: User (to-one)
      relationship template: Template? (to-one)
      relationship version: Version (to-many)
  }
  ```

- **Slide** (幻灯片实体)
  ```swift
  entity Slide {
      attribute uuid: UUID
      attribute index: Int32
      attribute content: Binary
      attribute thumbnail: Binary?
      
      relationship document: Document (to-one)
      relationship elements: Element (to-many)
  }
  ```

- **Element** (元素实体)
  ```swift
  entity Element {
      attribute uuid: UUID
      attribute type: String
      attribute content: Binary
      attribute position: Binary
      attribute style: Binary?
      
      relationship slide: Slide (to-one)
  }
  ```

- **Template** (模板实体)
  ```swift
  entity Template {
      attribute uuid: UUID
      attribute name: String
      attribute preview: Binary?
      attribute content: Binary
      attribute metadata: Binary?
      
      relationship documents: Document (to-many)
  }
  ```

- **User** (用户实体)
  ```swift
  entity User {
      attribute uuid: UUID
      attribute username: String
      attribute settings: Binary?
      
      relationship documents: Document (to-many)
  }
  ```

- **Settings** (设置实体)
  ```swift
  entity Settings {
      attribute uuid: UUID
      attribute preferences: Binary
      attribute lastSync: Date?
      
      relationship user: User (to-one)
  }
  ```

- **Version** (版本实体)
  ```swift
  entity Version {
      attribute uuid: UUID
      attribute versionNumber: String
      attribute timestamp: Date
      attribute changes: Binary
      
      relationship document: Document (to-one)
  }
  ```

- **Cache** (缓存实体)
  ```swift
  entity Cache {
      attribute key: String
      attribute data: Binary
      attribute timestamp: Date
      attribute expiryDate: Date?
  }
  ```

#### 4.1.3 索引和优化
```swift
// Document 索引
index Document(uuid)
index Document(creationDate)
index Document(lastModifiedAt)

// Slide 索引
index Slide(uuid)
index Slide(index)

// Cache 索引
index Cache(key)
index Cache(expiryDate)
```

#### 4.1.4 数据迁移
```swift
// 版本迁移路径
V1 -> V2: 轻量级迁移
V2 -> V3: 自定义迁移映射
```

### 4.2 数据备份策略
```
Core/Backup/
├── Source/                 # 源代码备份（每日、每周、发布版本）
├── Database/              # 数据库备份（结构和数据）
│   ├── CoreData/         # Core Data 存储
│   └── Migrations/       # 迁移历史
└── Assets/                # 资源文件备份
    ├── Templates/        # 模板资源
    └── Media/           # 媒体文件
```

#### 自动备份机制
```swift
/// 备份管理器
final class BackupManager {
    /// 执行备份
    /// - Parameters:
    ///   - type: 备份类型（每日/每周/发布）
    ///   - components: 要备份的组件
    func performBackup(type: BackupType, components: [BackupComponent]) async throws {
        // 1. 准备备份
        // 2. 执行备份
        // 3. 验证备份
        // 4. 更新备份记录
    }
    
    /// 恢复备份
    /// - Parameters:
    ///   - backupId: 备份ID
    ///   - components: 要恢复的组件
    func restore(from backupId: String, components: [BackupComponent]) async throws {
        // 1. 验证备份完整性
        // 2. 准备恢复环境
        // 3. 执行恢复
        // 4. 验证恢复结果
    }
}
```

## 5. 质量保证 | Quality Assurance

### 5.1 测试策略
```
Tests/
├── UnitTests/            # 单元测试（90%覆盖率）
├── IntegrationTests/     # 集成测试
└── UITests/              # UI测试（70%覆盖率）
```

### 5.2 性能优化
- **内存管理**：
  - 使用`@StateObject`和`@ObservedObject`管理状态，避免内存泄漏。
  - 在处理大文档时，使用分页加载和懒加载策略。

- **异步处理**：
  - 使用GCD进行后台任务处理：
    ```swift
    DispatchQueue.global(qos: .background).async {
        // 执行耗时操作
        DispatchQueue.main.async {
            // 更新UI
        }
    }
    ```
  - 使用Combine进行数据流处理：
    ```swift
    let publisher = URLSession.shared.dataTaskPublisher(for: url)
        .map { $0.data }
        .decode(type: ResponseType.self, decoder: JSONDecoder())
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { completion in
            // 处理完成
        }, receiveValue: { response in
            // 处理响应
        })
    ```

### 5.3 用户体验
- **响应式设计**：
  - 使用SwiftUI的`GeometryReader`和`@Environment`适配不同设备尺寸。
  - 提供动态字体和颜色方案，支持深色模式。

- **动画和过渡**：
  - 使用SwiftUI的`withAnimation`提升用户体验：
    ```swift
    withAnimation {
        // 状态变化
    }
    ```

### 5.4 安全措施
- **数据加密**：
  - 使用Keychain存储敏感信息：
    ```swift
    let keychain = Keychain(service: "com.example.app")
    keychain["password"] = "user_password"
    ```

- **网络安全**：
  - 使用SSL/TLS保护数据传输，确保所有网络请求使用HTTPS。
  - 实现证书固定，防止中间人攻击。

### 5.5 持续集成和部署
- **CI/CD管道**：
  - 使用GitHub Actions或Jenkins设置自动化构建和测试。
  - 配置自动化部署到TestFlight或App Store。

- **自动化测试**：
  - 编写单元测试和UI测试，确保代码质量。
  - 使用`xcodebuild`进行自动化测试执行。

### 5.6 文档和沟通
- **文档更新**：
  - 使用DocC生成API文档，确保文档与代码同步。
  - 定期更新README和开发指南，记录重要变更。

- **团队沟通**：
  - 使用Slack或Microsoft Teams进行日常沟通。
  - 定期召开Scrum会议，确保团队成员了解项目进展。

## 6. 开发流程 | Development Process

### 6.1 Git工作流
- 分支策略：feature/, bugfix/, release/
- 提交规范：[类型] 简短描述 + 详细说明
- 代码审查：PR模板、审查清单

### 6.2 发布流程
1. 版本规划
2. 功能冻结
3. 测试验证
4. 文档更新
5. 发布部署

### 6.3 监控与维护
- 性能监控
- 错误追踪
- 用户反馈
- 版本更新

## 7. 应急预案 | Contingency Plan

### 7.1 故障处理
1. 本地故障：使用本地备份恢复
2. 远程故障：切换备用服务
3. 系统故障：启动应急预案

### 7.2 数据恢复
1. 快速恢复：最近备份点恢复
2. 选择恢复：指定组件恢复
3. 增量恢复：部分更新恢复

## 8. 更新记录 | Change Log

### Version 1.0.0
- 初始架构设计
- 基础功能实现
- 文档规范建立 

## 9. 开发规则 | Development Rules

### 9.1 代码设计规则
```swift
// MARK: - 设计原则
// 1. 单一职责原则 (SRP)
protocol UserService {
    // ✅ 良好实践：职责单一
    func authenticateUser(credentials: Credentials) async throws -> User
    func updateUserProfile(user: User) async throws
    
    // ❌ 错误实践：混合了不相关的职责
    // func authenticateAndUpdateDatabase(credentials: Credentials, dbConfig: DBConfig)
}

// 2. 依赖注入原则
final class UserViewModel {
    // ✅ 良好实践：通过构造器注入依赖
    private let userService: UserService
    init(userService: UserService) {
        self.userService = userService
    }
    
    // ❌ 错误实践：直接创建依赖
    // private let userService = UserService()
}

// 3. 接口隔离原则
// ✅ 良好实践：小而专注的协议
protocol ContentParser {
    func parse(_ content: String) -> ParsedContent
}

protocol ContentValidator {
    func validate(_ content: ParsedContent) -> Bool
}

// ❌ 错误实践：过于庞大的协议
// protocol ContentProcessor {
//     func parse(_ content: String) -> ParsedContent
//     func validate(_ content: ParsedContent) -> Bool
//     func transform(_ content: ParsedContent) -> TransformedContent
//     func store(_ content: TransformedContent)
// }
```

### 9.2 错误处理规则
```swift
// MARK: - 错误处理最佳实践

// 1. 明确的错误类型
enum ValidationError: Error {
    case invalidInput(String)
    case missingRequiredField(String)
    case invalidFormat(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidInput(let detail):
            return "Invalid input: \(detail)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidFormat(let format):
            return "Invalid format: \(format)"
        }
    }
}

// 2. 错误恢复策略
func handleError(_ error: Error) {
    switch error {
    case let validationError as ValidationError:
        handleValidationError(validationError)
    case let networkError as NetworkError:
        handleNetworkError(networkError)
    default:
        handleUnknownError(error)
    }
}

// 3. 错误传播
func processUserData() throws {
    do {
        let data = try fetchUserData()
        try validateUserData(data)
        try saveUserData(data)
    } catch {
        logger.error("Failed to process user data: \(error)")
        throw error // 明确的错误传播
    }
}
```

### 9.3 异步编程规则
```swift
// MARK: - 异步编程最佳实践

// 1. 使用 async/await
final class DataProcessor {
    // ✅ 良好实践：清晰的异步流程
    func processData() async throws -> ProcessedData {
        let rawData = try await fetchData()
        let validatedData = try await validateData(rawData)
        return try await transformData(validatedData)
    }
    
    // ❌ 错误实践：回调地狱
    // func processData(completion: @escaping (Result<ProcessedData, Error>) -> Void) {
    //     fetchData { result in
    //         switch result {
    //         case .success(let data):
    //             self.validateData(data) { result in
    //                 // 嵌套回调...
    //             }
    //         case .failure(let error):
    //             completion(.failure(error))
    //         }
    //     }
    // }
}

// 2. 任务管理
final class DataManager {
    private var activeTask: Task<Void, Never>?
    
    func startProcessing() {
        // 取消现有任务
        activeTask?.cancel()
        
        // 创建新任务
        activeTask = Task {
            do {
                try await processData()
            } catch is CancellationError {
                // 处理取消
            } catch {
                // 处理其他错误
            }
        }
    }
}
```

### 9.4 内存管理规则
```swift
// MARK: - 内存管理最佳实践

// 1. 避免循环引用
final class ServiceManager {
    private weak var delegate: ServiceDelegate? // 使用 weak 避免循环引用
    
    func performOperation() {
        // ✅ 良好实践：使用 [weak self] 避免闭包中的循环引用
        Task { [weak self] in
            await self?.process()
        }
        
        // ❌ 错误实践：强引用可能导致内存泄漏
        // Task {
        //     await self.process()
        // }
    }
}

// 2. 资源管理
final class ResourceManager {
    private var resources: [Resource] = []
    
    func loadResource() {
        // ✅ 良好实践：使用自动释放池管理临时对象
        autoreleasepool {
            // 处理大量临时对象
        }
    }
    
    deinit {
        // ✅ 良好实践：清理资源
        resources.forEach { $0.cleanup() }
    }
}
```