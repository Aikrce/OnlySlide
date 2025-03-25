#!/bin/bash

# OnlySlide 构建错误修复脚本
# 用于解决Xcode编译过程中的常见问题

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

# 1. 解决README文件冲突
print_info "检查并解决README文件冲突..."

# 创建.xcignore文件，用于告诉Xcode忽略某些文件
cat > .xcignore << 'EOF'
# 忽略所有脚本和文档README.md，防止它们被复制到产品中
Scripts/README.md
Scripts/*/README.md
EOF

if [ -f ".xcignore" ]; then
    print_success "创建.xcignore文件成功"
else
    print_error "创建.xcignore文件失败"
fi

# 2. 清理派生数据
print_info "清理Xcode派生数据..."

# 清理派生数据
rm -rf ~/Library/Developer/Xcode/DerivedData/OnlySlide-*
print_success "派生数据清理完成"

# 3. 修复复制脚本冲突
print_info "修复复制脚本冲突..."

# 检查项目文件中的复制脚本
if [ -f "OnlySlide.xcodeproj/project.pbxproj" ]; then
    # 创建备份
    cp OnlySlide.xcodeproj/project.pbxproj OnlySlide.xcodeproj/project.pbxproj.bak
    
    # 移除重复的README.md复制脚本
    sed -i '' '/shellScript = "cp.*\/README.md/d' OnlySlide.xcodeproj/project.pbxproj
    
    print_success "已移除重复的README.md复制脚本"
else
    print_warning "找不到项目文件，无法修复复制脚本冲突"
fi

# 4. 清理构建文件夹
print_info "清理构建文件夹..."

# 清理构建文件夹
rm -rf build/
rm -rf .build/

print_success "构建文件夹清理完成"

# 5. 在包文件中添加排除规则
print_info "更新Package.swift文件的资源规则..."

if [ -f "Package.swift" ]; then
    # 创建备份
    cp Package.swift Package.swift.bak
    
    # 检查是否已有资源排除规则
    if ! grep -q "\.exclude(\[" Package.swift; then
        # 如果找到资源部分但没有排除规则，添加排除规则
        sed -i '' 's/\.process("Resources")/\.process("Resources").exclude(["README.md"])/g' Package.swift
        print_success "已添加资源排除规则"
    else
        print_info "资源排除规则已存在"
    fi
else
    print_warning "找不到Package.swift文件，无法更新资源规则"
fi

# 6. 修复Swift任务阻塞问题
print_info "添加构建设置以解决Swift任务阻塞问题..."

# 创建或更新.xcode.env文件
cat > .xcode.env << 'EOF'
// 优化Swift编译设置
OTHER_SWIFT_FLAGS = -enable-batch-mode
SWIFT_COMPILATION_MODE = wholemodule
SWIFT_OPTIMIZATION_LEVEL = -O
EOF

if [ -f ".xcode.env" ]; then
    print_success "创建.xcode.env文件成功"
else
    print_error "创建.xcode.env文件失败"
fi

# 7. 更新gitignore以忽略生成的文件
print_info "更新.gitignore文件..."

if [ -f ".gitignore" ]; then
    # 检查是否已包含需要忽略的条目
    NEEDS_UPDATE=false
    
    if ! grep -q "DerivedData" .gitignore; then
        echo "DerivedData/" >> .gitignore
        NEEDS_UPDATE=true
    fi
    
    if ! grep -q "build/" .gitignore; then
        echo "build/" >> .gitignore
        NEEDS_UPDATE=true
    fi
    
    if ! grep -q "\.build/" .gitignore; then
        echo ".build/" >> .gitignore
        NEEDS_UPDATE=true
    fi
    
    if ! grep -q "\.xcignore" .gitignore; then
        echo ".xcignore" >> .gitignore
        NEEDS_UPDATE=true
    fi
    
    if ! grep -q "\.xcode\.env" .gitignore; then
        echo ".xcode.env" >> .gitignore
        NEEDS_UPDATE=true
    fi
    
    if [ "$NEEDS_UPDATE" = true ]; then
        print_success ".gitignore文件已更新"
    else
        print_info ".gitignore文件已包含所有必要的忽略条目"
    fi
else
    # 创建新的.gitignore文件
    cat > .gitignore << 'EOF'
# Xcode
DerivedData/
build/
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3
xcuserdata/
*.xccheckout
*.moved-aside
*.xcuserstate
*.xcscmblueprint
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcodeproj/xcshareddata/

# Swift Package Manager
.build/
.swiftpm/

# 构建设置和临时文件
.xcignore
.xcode.env

# macOS
.DS_Store
.AppleDouble
.LSOverride
._*
EOF
    print_success "已创建新的.gitignore文件"
fi

# 完成
print_success "构建错误修复完成！请重新打开Xcode项目并尝试构建。"
echo ""
echo "如果问题仍然存在，请尝试以下步骤："
echo "1. 在Xcode中选择 Product > Clean Build Folder"
echo "2. 关闭并重新打开Xcode"
echo "3. 运行 ./Scripts/Build/clean_xcode.sh 脚本进行更彻底的清理"
echo "4. 或考虑删除并重新克隆项目" 