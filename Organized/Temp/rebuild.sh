#!/bin/bash
# 重新构建项目

# 清理项目
echo "正在清理项目..."
swift package clean

# 更新包依赖
echo "正在更新依赖..."
swift package update

# 重新生成Xcode项目
echo "正在生成Xcode项目..."
swift package generate-xcodeproj 2>/dev/null || echo "使用现有Xcode项目"

# 构建项目
echo "正在构建项目..."
swift build -c debug
