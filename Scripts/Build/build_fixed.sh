#!/bin/bash

# OnlySlide 优化构建脚本
# 使用优化的构建选项来解决Swift任务阻塞和重复文件问题

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

# 清理之前的构建
print_info "清理之前的构建..."
rm -rf .build/
rm -rf build/
rm -rf DerivedData/
print_success "清理完成"

# 创建构建目录
print_info "创建构建目录..."
mkdir -p build
print_success "构建目录已创建"

# 设置构建环境变量
print_info "设置构建环境变量..."
export SWIFT_DETERMINISTIC_HASHING=1
export SWIFT_ENABLE_INCREMENTAL_DEPENDENCIES=1
export SWIFT_ENABLE_BATCH_MODE=1
export SWIFT_DISABLE_TYPECHECKER_DIAGNOSTICS_LIMIT=1
print_success "环境变量已设置"

# 执行Swift构建，使用优化选项
print_info "开始构建项目..."
print_info "这可能需要一些时间，请耐心等待..."

swift build \
    -c debug \
    --build-path build \
    -Xswiftc -enable-batch-mode \
    -Xswiftc -enforce-exclusivity=checked \
    -Xswiftc -D \
    -Xswiftc SWIFT_STRICT_CONCURRENCY=complete \
    -Xswiftc -cross-module-optimization \
    -Xcc -I/usr/local/include \
    -Xcc -O2 \
    -Xlinker -rpath \
    -Xlinker @executable_path

BUILD_RESULT=$?

if [ $BUILD_RESULT -eq 0 ]; then
    print_success "项目构建成功！🎉"
    
    # 创建Xcode项目
    print_info "生成Xcode项目..."
    swift package generate-xcodeproj --skip-extra-files
    
    if [ $? -eq 0 ]; then
        print_success "Xcode项目生成成功"
        echo ""
        echo "您现在可以打开OnlySlide.xcodeproj并运行项目。"
    else
        print_warning "Xcode项目生成失败，但构建成功。您仍然可以使用.build目录中的产品。"
    fi
else
    print_error "构建失败，错误代码: $BUILD_RESULT"
    echo ""
    echo "尝试以下步骤："
    echo "1. 运行 ./Scripts/Build/fix_build_errors.sh 修复构建错误"
    echo "2. 检查日志以了解具体错误信息"
    echo "3. 修复代码中的任何编译错误"
    exit $BUILD_RESULT
fi

# 提供有用的信息
echo ""
echo "构建产品位于: ./build/debug/"
echo "要运行应用程序: ./build/debug/OnlySlide" 