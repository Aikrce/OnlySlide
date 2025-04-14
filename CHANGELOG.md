# 变更日志

本文件记录OnlySlide项目所有值得注意的变更。

## [未发布]

### 2023-04-15

#### 项目结构优化
- 创建标准模块化项目结构，包括src/OnlySlideCore、src/OnlySlideUI等核心目录
- 重组目录结构以符合模块化设计要求
- 将所有子模块按功能分组，如Models、Services、Protocols等

#### 依赖管理
- 选择Xcode嵌入式框架(Framework)方案作为项目依赖管理方式
- 编写Framework创建与配置指南
- 准备框架间依赖关系设置

#### 文档更新
- 更新README.md，添加项目结构说明和框架实施指南
- 更新开发工作清单，标记已完成项目初始化任务
- 创建项目结构迁移计划，设定分阶段迁移策略

### 2023-04-13

#### 项目初始化
- 创建Xcode项目，配置为同时支持iOS和macOS平台
- 设置最低版本要求：iOS 18.0，macOS 15.0
- 创建项目基础目录结构，包括src、Tests等主要目录

#### 代码质量管理
- 配置SwiftLint规则（本地规则文件）
- 创建.swiftlint.yml配置文件，定义代码风格规范
- 设置了特定于OnlySlide的自定义规则

#### 版本控制设置
- 初始化Git仓库
- 创建.gitignore和.gitattributes配置文件
- 设置main和develop分支
- 配置GitHub Actions CI工作流
- 成功连接并推送代码到GitHub远程仓库

#### 文档更新
- 创建基础README.md，包含代码规范说明
- 创建CHANGELOG.md（本文件）
- 更新开发工作清单，标记已完成任务
