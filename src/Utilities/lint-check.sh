#!/bin/bash
# 在项目根目录创建一个简单的检查脚本

echo "正在执行SwiftLint检查..."
if which swiftlint > /dev/null; then
  swiftlint
  exit_code=$?
  if [ $exit_code -eq 0 ]; then
    echo "✅ 代码检查通过"
  else
    echo "❌ 代码检查发现问题，请修复后再提交"
  fi
else
  echo "⚠️ SwiftLint未安装，请通过brew install swiftlint安装"
fi