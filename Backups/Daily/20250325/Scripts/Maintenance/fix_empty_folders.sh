#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

echo -e "${BLUE}===== OnlySlide 空文件夹修复工具 =====${NC}"
echo -e "${YELLOW}此脚本将检查项目中的空文件夹并添加占位文件。${NC}"
echo ""

# 检查是否在项目根目录下运行
if [ ! -d "Sources" ] || [ ! -d "Scripts" ]; then
    echo -e "${RED}错误: 请在OnlySlide项目根目录下运行此脚本${NC}"
    exit 1
fi

# 占位文件内容模板
create_readme_content() {
    local dir_name=$(basename "$1")
    local dir_path=$(echo "$1" | sed "s|$(pwd)/||")
    
    echo "# $dir_name 目录
    
此目录是OnlySlide项目的一部分，用于存储${dir_name}相关文件。

## 目录内容

这个目录应包含以下内容：

- 相关的${dir_name}文件
- ${dir_name}资源和配置

## 说明

此README文件是由\`fix_empty_folders.sh\`脚本自动创建的，用于确保Git能正确跟踪所有目录结构。
如果您看到这个文件，可能意味着：

1. 这个目录原本是空的
2. 这个目录需要在版本控制中保留
3. 请根据项目需求在此目录添加相应文件

## 路径

\`$dir_path\`"
}

# 检查iOS资源目录
check_ios_resources() {
    echo -e "${BLUE}检查iOS资源目录...${NC}"
    
    # 检查Resources目录
    if [ ! -d "Resources" ]; then
        echo -e "${YELLOW}创建Resources目录...${NC}"
        mkdir -p Resources
        echo -e "${GREEN}Resources目录已创建${NC}"
    fi
    
    # 检查Assets.xcassets目录
    if [ ! -d "Resources/Assets.xcassets" ]; then
        echo -e "${YELLOW}创建Assets.xcassets目录...${NC}"
        mkdir -p "Resources/Assets.xcassets"
        echo -e "${GREEN}Assets.xcassets目录已创建${NC}"
    fi
    
    # 检查AppIcon.appiconset目录
    if [ ! -d "Resources/Assets.xcassets/AppIcon.appiconset" ]; then
        echo -e "${YELLOW}创建AppIcon.appiconset目录...${NC}"
        mkdir -p "Resources/Assets.xcassets/AppIcon.appiconset"
        echo -e "${GREEN}AppIcon.appiconset目录已创建${NC}"
    fi
    
    # 检查是否有Info.plist
    if [ ! -f "Resources/Info.plist" ]; then
        echo -e "${YELLOW}注意: 未找到Info.plist文件。iOS发布可能需要此文件。${NC}"
        echo -e "${YELLOW}请使用prepare_ios_release.sh脚本创建必要的iOS发布文件。${NC}"
    fi
}

# 查找空目录 (排除.git和其他不需要处理的目录)
echo -e "${BLUE}开始查找空目录...${NC}"
empty_dirs=$(find . -type d -empty -not -path "*/\.*" -not -path "*/build*" -not -path "*/DerivedData*" -not -path "*/Pods*" -not -path "*/Carthage*" -not -path "*/node_modules*")

# 统计空目录数量
empty_dir_count=$(echo "$empty_dirs" | grep -v '^$' | wc -l | tr -d ' ')

if [ "$empty_dir_count" -eq "0" ]; then
    echo -e "${GREEN}未发现空目录！项目结构完整。${NC}"
else
    echo -e "${YELLOW}发现${empty_dir_count}个空目录，正在添加占位文件...${NC}"
    
    # 在每个空目录中添加.gitkeep和README.md文件
    for dir in $empty_dirs; do
        echo -e "处理目录: ${BLUE}$dir${NC}"
        
        # 添加.gitkeep文件
        touch "$dir/.gitkeep"
        
        # 创建README.md文件
        create_readme_content "$dir" > "$dir/README.md"
        
        echo -e "  ${GREEN}✓${NC} 添加了占位文件"
    done
    
    echo -e "${GREEN}所有空目录处理完成！${NC}"
fi

# 检查iOS资源目录
check_ios_resources

echo ""
echo -e "${GREEN}=== 空文件夹修复完成! ===${NC}"
echo -e "${YELLOW}如果您计划发布iOS应用，请运行：${NC}"
echo -e "${BLUE}./Scripts/Build/prepare_ios_release.sh${NC}"
echo "" 