# OnlySlide iOS发布指南

本文档提供了将OnlySlide项目发布到iOS App Store的完整指南。

## 准备工作

在开始iOS发布流程前，您需要完成以下准备工作：

### 1. 修复空文件夹问题

OnlySlide项目中存在空文件夹问题，需要先修复：

```bash
# 执行修复空文件夹脚本
./Scripts/Maintenance/fix_empty_folders.sh
```

此脚本将：
- 检测项目中的所有空文件夹
- 在空文件夹中添加`.gitkeep`和描述性的`README.md`文件
- 确保Git能正确跟踪所有文件夹结构

### 2. 准备iOS发布资源

执行iOS发布准备脚本：

```bash
# 执行iOS发布准备脚本
./Scripts/Build/prepare_ios_release.sh
```

此脚本将：
- 创建iOS应用所需的资源和配置文件（图标模板、启动屏幕等）
- 创建发布配置文件
- 创建App Store元数据模板
- 生成发布检查清单

## iOS发布流程

完成准备工作后，您需要按照以下步骤发布应用：

### 1. 申请Apple开发者账号

如果您还没有Apple开发者账号，需要先申请：
- 访问 [Apple Developer Program](https://developer.apple.com/programs/)
- 按照指引完成个人或组织账号注册（年费99美元）
- 等待Apple审核并激活您的账号

### 2. 配置开发证书和标识符

1. 登录 [Apple Developer Portal](https://developer.apple.com/account/)
2. 创建App ID（Bundle Identifier）
   - 导航到"Certificates, IDs & Profiles"
   - 在"Identifiers"中创建新的App ID
   - 输入应用的Bundle ID（如`com.yourcompany.onlyslide`）
   - 配置所需的服务和功能
3. 创建发布证书
   - 在"Certificates"中创建"Apple Distribution"证书
   - 按照指引完成证书创建并下载
4. 创建配置文件
   - 在"Profiles"中创建"App Store"类型的配置文件
   - 关联之前创建的App ID和证书
   - 下载配置文件并双击安装

### 3. 配置Xcode项目

1. 打开Xcode项目
2. 在"Signing & Capabilities"中：
   - 选择您的开发团队
   - 确保Bundle Identifier匹配您创建的App ID
   - 确保"Automatically manage signing"已启用
3. 更新`configs/release.xcconfig`文件：
   - 设置正确的DEVELOPMENT_TEAM值（团队ID）
   - 检查其他配置是否符合您的需求

### 4. 添加必要的iOS资源

1. 应用图标
   - 使用Xcode的Asset Catalog编辑器
   - 添加所有尺寸的应用图标（可使用[App Icon Generator](https://appicon.co/)等工具生成）
2. 启动屏幕
   - 使用Xcode的Interface Builder编辑`LaunchScreen.storyboard`
   - 添加您的品牌元素和启动画面

### 5. 配置App Store Connect

1. 登录 [App Store Connect](https://appstoreconnect.apple.com/)
2. 创建新应用
   - 点击"我的App" > "+"
   - 输入应用信息（名称、Bundle ID、SKU等）
3. 配置应用信息
   - 上传截图和预览视频
   - 填写应用描述（可使用`metadata/AppStore/AppDescription.md`中的内容）
   - 设置关键词和URL
   - 设置年龄分级
   - 配置价格和可用区域
4. 回答隐私政策问题
   - 声明应用使用的数据类型
   - 提供隐私政策URL

### 6. 构建和上传应用

1. 在Xcode中构建发布版本
   - 选择"Generic iOS Device"作为目标设备
   - 选择"Product" > "Archive"创建归档
2. 上传到App Store
   - 在Organizer中选择创建的归档
   - 点击"Distribute App"
   - 选择"App Store Connect"
   - 按照指引完成上传流程

### 7. 提交审核

1. 在App Store Connect中：
   - 导航到刚上传的版本
   - 确保所有必需信息已填写完整
   - 点击"提交审核"
2. 等待Apple审核
   - 审核通常需要1-3天
   - 可以在App Store Connect中查看审核状态

### 8. 发布应用

审核通过后：
- 设置发布日期（可选择立即发布或预定日期）
- 确认发布
- 应用将在所有已选择的区域中上架App Store

## 常见问题及解决方案

### 1. 编译错误

如果遇到编译错误，可以使用以下工具修复：

```bash
# 修复Xcode构建错误
./Scripts/Build/fix_build_errors.sh

# 修复Swift任务阻塞问题
./Scripts/Build/fix_swift_blocking.sh
```

### 2. 代码签名问题

如果遇到代码签名问题：
- 确保开发者账号已激活
- 检查证书和配置文件是否已正确安装
- 在Xcode的"Signing & Capabilities"中重新选择团队
- 尝试使用"Automatically manage signing"选项

### 3. 上传失败

如果应用上传失败：
- 检查网络连接
- 确保应用版本号递增（不能上传相同版本号的应用）
- 验证Info.plist中的设置
- 使用Application Loader作为替代上传工具

### 4. 审核被拒

如果应用被拒：
- 仔细阅读拒绝原因
- 修复所有问题
- 提供充分的说明（在回复中）
- 重新提交审核

## 发布后维护

应用发布后：
- 监控崩溃报告
- 收集用户反馈
- 规划功能更新
- 准备新版本

## 参考资源

- [Apple App Store审核指南](https://developer.apple.com/app-store/review/guidelines/)
- [发布应用到App Store](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [应用元数据规范](https://developer.apple.com/app-store/product-page/)
- [应用内购买](https://developer.apple.com/in-app-purchase/)

## 检查清单

使用`metadata/iOS_Release_Checklist.md`文件作为发布前的最终检查工具，确保所有必要的步骤都已完成。 