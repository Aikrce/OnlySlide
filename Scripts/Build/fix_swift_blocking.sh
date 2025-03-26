#!/bin/bash
# 修复Swift任务阻塞问题

# 添加Swift编译设置
defaults write com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks 8
defaults write com.apple.dt.Xcode IDEBuildOperationTimeLimitForThinning 120

# 添加自定义编译标志
if [ -f ".xcode.env" ]; then
  grep -q "SWIFT_ENABLE_BATCH_MODE" .xcode.env || echo "SWIFT_ENABLE_BATCH_MODE=YES" >> .xcode.env
  grep -q "SWIFT_COMPILATION_MODE" .xcode.env || echo "SWIFT_COMPILATION_MODE=wholemodule" >> .xcode.env
fi

echo "Swift任务阻塞问题修复完成"
