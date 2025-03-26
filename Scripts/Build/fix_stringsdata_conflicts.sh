#!/bin/bash
# 修复.stringsdata文件冲突
# 处理重复的.stringsdata文件和相关警告

set -e
echo "===== 开始修复.stringsdata文件冲突 ====="

# 备份当前项目状态
BACKUP_DIR="./Backups/StringsDataFix_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r OnlySlide.xcodeproj/project.pbxproj "$BACKUP_DIR"

# 清理派生数据
echo "清理Xcode派生数据..."
rm -rf ~/Library/Developer/Xcode/DerivedData/OnlySlide-*

# 添加构建设置到项目
echo "添加解决方案到项目设置..."

# 使用PlistBuddy添加构建设置（如果你有Info.plist）
if [ -f "OnlySlide/Info.plist" ]; then
  echo "更新Info.plist..."
  /usr/libexec/PlistBuddy -c "Add :StringsDataDeduplication bool true" "OnlySlide/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :StringsDataDeduplication true" "OnlySlide/Info.plist"
fi

# 修复Swift任务不阻塞的问题
echo "配置Swift任务阻塞设置..."
cat > ".xcode.swift.settings" << EOF
SWIFT_ENABLE_BATCH_MODE=YES
SWIFT_COMPILATION_MODE=wholemodule
SWIFT_OPTIMIZATION_LEVEL=-O
EOF

# 处理.stringsdata文件冲突
echo "解决.stringsdata文件冲突..."

# 1. 查找项目文件中定义的重复.stringsdata输出路径
PROBLEMATIC_FILES=("CommonTests.stringsdata" "Document.stringsdata" "XCTestSupport.stringsdata")

# 2. 修改Build Phases中的脚本
if [ -f Scripts/Build/onlyslide_project_fixer.sh ]; then
  echo "修改现有构建修复脚本..."
  cat >> Scripts/Build/onlyslide_project_fixer.sh << EOF

# 添加.stringsdata文件冲突处理
fix_stringsdata_conflicts() {
  echo "处理.stringsdata文件冲突..."
  
  # 重命名冲突的.stringsdata文件标识符
  find \${PROJECT_DIR} -name "*.strings" -o -name "*.stringsdict" | while read -r file; do
    dir=\$(dirname "\$file")
    base=\$(basename "\$file" | sed 's/\.[^.]*$//')
    
    # 添加目录前缀以避免冲突
    dir_prefix=\$(echo "\$dir" | sed 's/[\/.]/_/g')
    if [[ "\$base" == "CommonTests" || "\$base" == "Document" || "\$base" == "XCTestSupport" ]]; then
      echo "处理: \$file"
      mv "\$file" "\${dir}/\${dir_prefix}_\${base}.strings" 2>/dev/null || true
    fi
  done
}

# 调用函数
fix_stringsdata_conflicts
EOF
fi

# 3. 创建新的专用修复脚本（如果需要）
cat > Scripts/Build/fix_swift_blocking.sh << EOF
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
EOF

chmod +x Scripts/Build/fix_swift_blocking.sh

# 提示用户下一步操作
echo ""
echo "===== .stringsdata文件冲突修复步骤 ====="
echo "1. 已创建备份在: $BACKUP_DIR"
echo "2. 已更新或创建相关修复脚本"
echo "3. 下一步操作:"
echo "   a. 运行: ./Scripts/Build/fix_swift_blocking.sh"
echo "   b. 关闭Xcode并重新打开"
echo "   c. 选择'Product > Clean Build Folder'"
echo "   d. 尝试重新构建项目"
echo ""
echo "如果问题持续，可能需要检查目标成员资格(Target Membership)设置"
echo "或考虑运行之前创建的onlyslide_project_fixer.sh脚本"
echo "===== 修复脚本执行完成 =====" 