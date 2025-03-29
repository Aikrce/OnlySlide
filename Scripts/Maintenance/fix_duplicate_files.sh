#!/bin/bash
# fix_duplicate_files.sh
# 脚本用于修复OnlySlide项目中的重复文件错误

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}开始修复OnlySlide项目中的重复文件错误...${NC}"

# 1. 清理LaunchScreen相关文件冲突
echo -e "${YELLOW}检查并修复LaunchScreen冲突...${NC}"
LAUNCH_SCREEN_COUNT=$(find . -name "LaunchScreen.storyboard" | wc -l)
if [ $LAUNCH_SCREEN_COUNT -gt 1 ]; then
    echo -e "${RED}发现多个LaunchScreen.storyboard文件，请手动检查以下位置:${NC}"
    find . -name "LaunchScreen.storyboard"
else
    echo -e "${GREEN}LaunchScreen.storyboard文件数量正常.${NC}"
fi

# 2. 清理.gitkeep文件
echo -e "${YELLOW}移除构建中不必要的.gitkeep文件...${NC}"
find . -name ".gitkeep" -exec echo "Found .gitkeep: {}" \;

# 使用xcode-build-tool检查项目中的Copy Bundle Resources部分
echo -e "${YELLOW}正在生成项目构建信息...${NC}"
TEMP_BUILD_FILE=$(mktemp)
xcodebuild -project OnlySlide.xcodeproj -target OnlySlide -showBuildSettings > $TEMP_BUILD_FILE 2>/dev/null

# 3. 检查项目中可能的重复输出
echo -e "${YELLOW}分析项目中潜在的重复输出...${NC}"
PROJ_FILE="OnlySlide.xcodeproj/project.pbxproj"
if [ -f "$PROJ_FILE" ]; then
    # 分析dstPath设置
    echo "分析目标路径配置..."
    grep "dstPath" "$PROJ_FILE" | sort | uniq -c | sort -nr
    
    # 检查Copy Files构建阶段
    echo "分析Copy Files构建阶段..."
    grep -A 3 "PBXCopyFilesBuildPhase" "$PROJ_FILE" | grep -v "^--$"
else
    echo -e "${RED}找不到项目文件: $PROJ_FILE${NC}"
fi

# 4. 提供修复建议
echo -e "\n${GREEN}===== 修复建议 =====${NC}"
echo -e "${YELLOW}1. 在Xcode中，选择项目 > Target > Build Phases > Copy Bundle Resources${NC}"
echo -e "${YELLOW}   移除所有.gitkeep文件和重复的资源文件${NC}"
echo -e "${YELLOW}2. 检查是否有多个Target使用相同的输出路径${NC}"
echo -e "${YELLOW}3. 清理项目并删除派生数据:${NC}"
echo -e "${YELLOW}   rm -rf ~/Library/Developer/Xcode/DerivedData/*${NC}"
echo -e "${YELLOW}4. 确保Info.plist文件没有重复${NC}"

echo -e "\n${GREEN}脚本执行完成。请根据上述分析手动修复问题，然后重新构建项目。${NC}"

# 清理临时文件
rm -f $TEMP_BUILD_FILE 