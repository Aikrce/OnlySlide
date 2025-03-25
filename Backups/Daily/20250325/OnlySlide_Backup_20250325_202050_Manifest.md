# OnlySlide 项目备份清单

**备份日期:** 2025-03-25 20:20:51
**备份版本:** OnlySlide_Backup_20250325_202050

## 备份内容

1. **源代码备份:** Backups/Daily/20250325/OnlySlide_Backup_20250325_202050_Sources.tar.gz
2. **文档和脚本备份:** Backups/Daily/20250325/OnlySlide_Backup_20250325_202050_Docs_Scripts.tar.gz
3. **项目文件备份:** Backups/Daily/20250325/OnlySlide_Backup_20250325_202050_Project.tar.gz
4. **资源文件备份:** Backups/Daily/20250325/OnlySlide_Backup_20250325_202050_Resources.tar.gz

## Git 状态

```
On branch main
Changes not staged for commit:
  (use "git add/rm <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   Docs/development-log.md
	modified:   LocalPackages/OnlySlideUI/Tests/OnlySlideUITests/OnlySlideUITests.swift
	modified:   OnlySlide.xcodeproj/project.pbxproj
	deleted:    Package.resolved
	modified:   Package.swift
	modified:   README.md
	modified:   Sources/Core/Data/Persistence/CoreData/OnlySlide.xcdatamodeld/OnlySlide.xcdatamodel/contents
	modified:   Sources/Core/Data/Services/Repository/CoreDataDocumentRepository.swift
	modified:   Sources/Core/Data/Services/Repository/CoreDataRepository.swift
	modified:   Sources/Core/Data/Services/Repository/DocumentRepository.swift
	modified:   Sources/Core/Data/Services/Repository/TemplateRepository.swift
	modified:   Sources/Core/Domain/Models/ValueObjects/DocumentMetadata.swift
	modified:   Sources/CoreDataModule/AppStartup/MigrationStartupHandler.swift
	modified:   Sources/CoreDataModule/Error/CoreDataError.swift
	modified:   Sources/CoreDataModule/Manager/CoreDataManager.swift
	modified:   Sources/CoreDataModule/Manager/CoreDataStack.swift
	modified:   Sources/CoreDataModule/Migration/CoreDataMigrationManager.swift
	modified:   Sources/CoreDataModule/Migration/CoreDataModelVersionManager.swift
	modified:   Sources/CoreDataModule/Migration/CustomMappingModels/SlideToSlideV2MappingModel.swift
	modified:   Sources/CoreDataModule/Migration/EntityMigrationPolicy.swift
	modified:   Sources/CoreDataModule/Migration/MappingModelFinder.swift
	modified:   Sources/CoreDataModule/Migration/ModelVersion.swift
	modified:   Sources/CoreDataModule/Performance/CoreDataPerformanceMonitor.swift
	modified:   Sources/CoreDataModule/README.md
	modified:   Sources/CoreDataModule/Sync/CoreDataConflictResolver.swift
	modified:   Sources/CoreDataModule/Sync/CoreDataSyncManager.swift
	modified:   Sources/CoreDataModule/Sync/SyncState.swift
	modified:   Sources/CoreDataModule/UI/MigrationProgressView.swift
	modified:   Sources/Logging/Logger.swift
	deleted:    Sources/OnlySlide/Info.plist.bak
	deleted:    Sources/OnlySlide/Resources/Info.plist
	modified:   Tests/CommonTests/CommonTests.swift
	modified:   Tests/CoreDataTests/Migration/MigrationTests.swift
	modified:   Tests/LoggingTests/LoggingTests.swift

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	Backups/
	CommonTests/
	Demo/
	Docs/Architecture/CoreDataMigrationArchitecture.md
	Docs/Architecture/CoreDataMigrationDiagram.md
	Docs/ArchitectureDesign.md
	Docs/BugfixIntegrationGuide.md
	Docs/Examples/
	Docs/Images/
	Docs/Implementation/
	Docs/Installation.md
	Docs/Logs/DailyLogs/2025-03-24-ConcurrencySafetyIssues.md
	Docs/Logs/DailyLogs/2025-03-26-BundleHandlingImprovements.md
	Docs/Logs/DailyLogs/Summary-2025-03-26-WorkComplete.md
	Docs/Modules/ArchitectureOptimizationGuide.md
	Docs/Performance/
	Docs/ProjectPlans/
	Docs/TestCoverageReport.md
	Docs/UsageGuide.md
	MigrationGuide.md
	Sources/App/MigrationDemoApp.swift
	Sources/App/UI/
	Sources/CoreDataModule/Concurrency/
	Sources/CoreDataModule/Error/CoreDataErrorManager.swift
	Sources/CoreDataModule/Error/CoreDataRecoveryStrategies.swift
	Sources/CoreDataModule/Error/EnhancedErrorHandling.swift
	Sources/CoreDataModule/Manager/CoreDataManager+Migration.swift
	Sources/CoreDataModule/Manager/DependencyProvider.swift
	Sources/CoreDataModule/Migration/BackupManager.swift
	Sources/CoreDataModule/Migration/EnhancedMigrationManager.swift
	Sources/CoreDataModule/Migration/EnhancedMigrationManager.swift.bak2
	Sources/CoreDataModule/Migration/EnhancedModelVersionManager.swift
	Sources/CoreDataModule/Migration/MigrationDomainTypes.swift
	Sources/CoreDataModule/Migration/MigrationExecutor.swift
	Sources/CoreDataModule/Migration/MigrationPlanner.swift
	Sources/CoreDataModule/Migration/MigrationProgressReporter.swift
	Sources/CoreDataModule/Migration/MigrationResult.swift
	Sources/CoreDataModule/Migration/ModelVersionDefinition.swift
	Sources/CoreDataModule/Migration/Models/
	Sources/CoreDataModule/Models/
	Sources/CoreDataModule/Resources/
	Sources/CoreDataModule/Sync/EnhancedSyncManager.swift
	Sources/CoreDataModule/Sync/EnhancedSyncManager.swift.bak
	Sources/CoreDataModule/Sync/EnhancedSyncManagerImproved.swift
	Sources/Documentation/
	Sources/Examples/
	Sources/Testing/
	Tests/CoreDataTests/EdgeCases/
	Tests/CoreDataTests/Error/
	Tests/CoreDataTests/Integration/
	Tests/CoreDataTests/Manager/
	Tests/CoreDataTests/Migration/CoreDataMigrationIntegrationTests.swift
	Tests/CoreDataTests/Migration/CoreDataMigrationTests.swift
	Tests/CoreDataTests/Migration/CoreDataModelVersionManagerTests.swift
	Tests/CoreDataTests/Migration/EnhancedMigrationManagerTests.swift
	Tests/CoreDataTests/Migration/EnhancedModelVersionManagerTests.swift
	Tests/CoreDataTests/Migration/MigrationProgressReporterTests.swift
	Tests/CoreDataTests/Migration/ModelVersionDefinitionTests.swift
	Tests/CoreDataTests/Migration/ModelVersionTests.swift
	Tests/CoreDataTests/Resources/
	Tests/CoreDataTests/Standalone/
	Tests/CoreDataTests/Sync/
	XCTestSupport.swift

no changes added to commit (use "git add" and/or "git commit -a")
```

## 最近提交

```
906af72 添加项目备份脚本，用于备份今天的工作和所有代码
a9b63ed 重组脚本目录结构，按功能分类整理脚本文件
1deb72f 添加项目维护脚本，包括代码清理、命名规范检查和导入优化工具
aed382f 完整项目重构: 模块化架构、测试目录整理、命名冲突解决、Info.plist问题修复
86a1435 Remove physical backup directory, will use Git for version control
```
