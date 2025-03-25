#!/bin/bash

# 清理项目派生数据
echo "正在清理Xcode派生数据..."
rm -rf ~/Library/Developer/Xcode/DerivedData/OnlySlide-*

# 清理Xcode项目缓存
echo "正在清理项目缓存..."
find . -name "*.xcodeproj" -exec xcodebuild -project {} -alltargets clean \; >/dev/null 2>&1

# 清理构建文件夹
echo "正在清理构建文件夹..."
rm -rf .build
rm -rf build

# 创建新的构建脚本
echo "创建构建脚本..."
cat > rebuild.sh << 'EOF'
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
EOF

chmod +x rebuild.sh

echo "清理完成。现在你可以运行 ./rebuild.sh 来重新构建项目。" 