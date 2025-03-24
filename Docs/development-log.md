# 开发日志

## 2024-03-24

### 测试框架完善
- 重组了测试目录结构，建立了统一的测试文档规范
- 创建了主要测试类别的详细文档：
  - `FEATURES_TESTING.md`: 功能模块测试指南
  - `UNIT_TESTING.md`: 单元测试指南
  - `APP_TESTING.md`: 应用测试指南
- 更新了主测试README文件，提供了清晰的目录结构和测试运行指南
- 统一了文档命名规范，使用 `_TESTING.md` 和 `_GUIDE.md` 后缀

### 构建系统问题
- 发现代码签名问题：`OnlySlide.entitlements` 文件无法打开
- 需要解决的问题：
  1. 验证 `CODE_SIGN_ENTITLEMENTS` 构建设置
  2. 确认 entitlements 文件位置
  3. 检查 iOS 和 macOS 的签名证书配置

### Bundle Resources 配置问题
- 发现测试文档被错误地包含在应用程序包中
- 问题文件：
  - 所有 `*_TESTING.md` 文档
  - `ARCHIVE_GUIDE.md`
  - `CoreDataTests-legacy` 目录
- 需要从 "Copy Bundle Resources" 构建阶段移除这些文件
- 只保留必要的资源文件（如 Info.plist）

### 依赖和测试配置问题
- 发现重复的测试目标：两个 'CoreDataTests' 产品
  - 一个在主测试目录
  - 一个在 legacy 归档目录
- 依赖项问题解决：
  - 移除了 swift-log 远程依赖
  - 创建了本地日志模块 (Logging)
  - 更新了所有模块的依赖关系
- 修复了测试路径：
  - 将 `Tests/App` 改为 `Tests/AppTests`
  - 将 `Tests/Features` 改为 `Tests/FeaturesTests`

### 本地日志模块实现
- 创建了新的 Logging 模块，包含以下功能：
  - 定义了 LogLevel 枚举（debug、info、warning、error）
  - 实现了 Logging 协议和扩展方法
  - 创建了 Logger 单例类
  - 支持日志时间戳和文件信息
  - 为调试模式添加了控制台输出
  - 预留了文件日志记录扩展点

### 测试框架扩展
- 删除了旧的测试目录：
  - 移除 `Tests/archive/CoreDataTests-legacy`
  - 移除 `Tests/archive/CoreDataModuleTests`
- 添加了新的测试目标：
  - `CommonTests`: 测试公共模块
  - `LoggingTests`: 测试日志模块
- 创建了基本的测试文件：
  - `CommonTests.swift`: 包含基础测试框架
  - `LoggingTests.swift`: 包含日志功能测试

### Bundle Resources 清理
- 更新了 Package.swift 的资源配置：
  - 添加了 exclude 规则，排除所有测试文档
  - 修改了 Resources 处理规则，排除 .md 文件
  - 确保只有必要的资源文件被打包

### 代码签名配置
- 创建了完整的 entitlements 文件，包含以下权限：
  - 基本沙盒权限
  - 文件访问权限（用户选择的文件和下载）
  - 网络访问权限
  - 应用间通信权限
  - iCloud 相关权限
  - 硬件访问权限（相机、麦克风）
  - macOS 特定权限（JIT、内存执行等）
- 将 entitlements 文件放置在正确的位置：`Sources/OnlySlide/OnlySlide.entitlements`

### 解决命名冲突和文件重复问题
- 删除了重复的日志实现：
  - 移除 `Sources/Core/Common/Logging/Logger.swift`
  - 将 `Logger` 类重命名为 `OSLogger`，避免命名冲突
- 删除了重复的迁移测试文件：
  - 移除 `Tests/CoreDataTests/MigrationTests.swift`
  - 保留了更完整的 `Tests/CoreDataTests/Migration/MigrationTests.swift`
- 修复了构建时的重复输出文件错误：
  - `Logger.stringsdata` 文件重复
  - `MigrationTests.stringsdata` 文件重复

### 解决 Info.plist 文件问题
- 发现构建错误：找不到 `OnlySlide/Info.plist` 文件
- 解决方案：
  - 从 `Info.plist.bak` 备份文件恢复 Info.plist
  - 创建符号链接，将 `OnlySlide/Info.plist` 指向 `Sources/OnlySlide/Info.plist`
  - 更新 Package.swift，正确引用 Info.plist 资源
- 这确保了 Xcode 能在期望的位置找到这个必要的配置文件

### 下一步计划
1. 验证构建是否成功
2. 测试各项权限是否正常工作
3. 完善新增测试模块：
   - 实现 Common 模块的具体测试用例
   - 完善 Logging 模块的格式测试
   - 添加更多边界条件测试
4. 完善日志模块功能：
   - 添加文件日志记录
   - 实现日志级别控制
   - 添加日志轮转功能
5. 实现测试覆盖率报告生成机制
6. 建立自动化测试流程 