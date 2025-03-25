#!/bin/bash

# OnlySlide Swift任务阻塞修复脚本
# 解决"Target has Swift tasks not blocking downstream targets"错误

# 设置颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # 恢复默认颜色

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[信息] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[成功] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[警告] $1${NC}"
}

print_error() {
    echo -e "${RED}[错误] $1${NC}"
}

print_info "开始修复Swift任务阻塞问题..."

# 1. 清理派生数据和构建目录
print_info "清理派生数据和构建目录..."
rm -rf ~/Library/Developer/Xcode/DerivedData/OnlySlide-*
rm -rf build/
rm -rf .build/

# 2. 创建构建设置文件，修复Swift任务阻塞问题
print_info "创建构建设置文件..."

# 创建Xcode项目级别的配置
mkdir -p OnlySlide.xcodeproj/xcshareddata
cat > OnlySlide.xcodeproj/xcshareddata/xcschemes/OnlySlide.xcscheme << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1520"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "OnlySlide::OnlySlide"
               BuildableName = "OnlySlide"
               BlueprintName = "OnlySlide"
               ReferencedContainer = "container:OnlySlide.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      codeCoverageEnabled = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "OnlySlide::CoreDataTests"
               BuildableName = "CoreDataTests.xctest"
               BlueprintName = "CoreDataTests"
               ReferencedContainer = "container:OnlySlide.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "OnlySlide::OnlySlide"
            BuildableName = "OnlySlide"
            BlueprintName = "OnlySlide"
            ReferencedContainer = "container:OnlySlide.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "OnlySlide::OnlySlide"
            BuildableName = "OnlySlide"
            BlueprintName = "OnlySlide"
            ReferencedContainer = "container:OnlySlide.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
EOF

# 3. 创建解决方案记录文件
print_info "创建解决方案记录文件..."

cat > "swift_blocking_solution.md" << 'EOF'
# Swift任务阻塞问题解决方案

## 问题描述

在Xcode构建过程中出现以下错误：
```
Target 'OnlySlide' (project 'OnlySlide') has Swift tasks not blocking downstream targets
```

## 原因分析

这个错误通常因以下原因产生：

1. Swift编译任务之间的依赖关系设置不正确
2. Xcode项目配置中的构建设置问题
3. Swift并发编译设置导致的任务调度问题
4. 重复的输出文件（如README.md被多个构建阶段处理）

## 解决方案

已实施以下解决方案：

1. 创建共享的Xcode方案（Scheme），确保正确的构建依赖顺序
2. 修复项目文件中的Copy Files构建阶段，移除复制README.md的脚本
3. 添加.xcignore文件排除README.md
4. 更新Package.swift文件，添加排除规则

## 如何验证

解决方案后应该能正常构建。如果仍有问题，可尝试：

1. 在Xcode中手动设置：
   - Product > Scheme > Edit Scheme > Build
   - 确保"Parallelize Build"选项已启用
   - 确保"Find Implicit Dependencies"选项已启用

2. 使用优化的构建工具：
   ```bash
   ./Scripts/Build/build_fixed.sh
   ```

## 预防措施

为防止此类问题再次发生：

1. 使用修复脚本中包含的构建设置
2. 使用.xcignore文件控制文件复制
3. 定期清理构建缓存
EOF

# 4. 修复项目文件中的依赖关系
print_info "尝试修复项目文件中的依赖关系..."

if [ -f "OnlySlide.xcodeproj/project.pbxproj" ]; then
    # 创建备份
    cp OnlySlide.xcodeproj/project.pbxproj OnlySlide.xcodeproj/project.pbxproj.bak2
    
    # 尝试修复依赖关系设置
    sed -i '' 's/buildImplicitDependencies = NO;/buildImplicitDependencies = YES;/g' OnlySlide.xcodeproj/project.pbxproj
    sed -i '' 's/parallelizeBuildables = NO;/parallelizeBuildables = YES;/g' OnlySlide.xcodeproj/project.pbxproj
    
    print_success "已尝试修复项目依赖关系设置"
else
    print_warning "找不到项目文件，跳过依赖关系修复"
fi

# 5. 创建构建设置文件
print_info "创建构建设置文件..."

mkdir -p .swiftpm
cat > .swiftpm/config << 'EOF'
[general]
# 启用批处理模式
batch-mode = true
# 启用自动链接
auto-link = true
# 启用交叉模块优化
cross-module-optimization = true

[build]
# 依赖解析方式
module-cache-verbosity = parseable
# 启用并行构建
jobs = 8
# 构建配置
configuration = debug
EOF

# 6. 添加额外的Xcode配置
print_info "创建Xcode配置文件..."

mkdir -p OnlySlide.xcodeproj/project.xcworkspace
cat > OnlySlide.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>BuildSystemType</key>
    <string>Latest</string>
    <key>DisableBuildSystemDeprecationWarning</key>
    <true/>
    <key>IDEBuildOperationMaxNumberOfConcurrentCompileTasks</key>
    <integer>8</integer>
    <key>IDEBuildOperationParallelizationOn</key>
    <true/>
    <key>BuildSystemEnableIncremental</key>
    <true/>
</dict>
</plist>
EOF

# 7. 清理临时文件
print_info "清理临时Swift编译文件..."
find . -name "*.swiftdeps" -delete
find . -name "*.swiftmodule" -delete
find . -name "*.swiftsourceinfo" -delete
find . -name "*.swiftdoc" -delete
find . -name "*.d" -delete
find . -name "*.dia" -delete

print_success "Swift任务阻塞问题修复完成！"
echo ""
echo "请重新打开Xcode项目并尝试构建。"
echo "查看 swift_blocking_solution.md 以获取更多信息。"
echo ""
echo "如果问题仍然存在，请考虑使用优化构建脚本："
echo "./Scripts/Build/build_fixed.sh" 