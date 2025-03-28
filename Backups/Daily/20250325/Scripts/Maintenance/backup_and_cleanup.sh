#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

echo -e "${BLUE}===== OnlySlide 备份与整理工具 =====${NC}"
echo -e "${YELLOW}此脚本将备份今天的工作并整理根目录下的散落文件。${NC}"
echo ""

# 检查是否在项目根目录下运行
if [ ! -d "Sources" ] || [ ! -d "Scripts" ]; then
    echo -e "${RED}错误: 请在OnlySlide项目根目录下运行此脚本${NC}"
    exit 1
fi

# 获取当前日期
DATE=$(date +"%Y%m%d")
BACKUP_DIR="Backups/Daily/$DATE"

# 创建备份目录
echo -e "${BLUE}创建备份目录: $BACKUP_DIR${NC}"
mkdir -p "$BACKUP_DIR"

# 备份今天修改的文件
echo -e "${BLUE}备份今天修改的文件...${NC}"
CHANGED_FILES=$(find Sources Scripts Docs Resources -type f -mtime -1 | grep -v "\.git" | grep -v "\.build" | grep -v "DerivedData")
CHANGED_COUNT=0

for file in $CHANGED_FILES; do
    dir=$(dirname "$file")
    backup_path="$BACKUP_DIR/$dir"
    mkdir -p "$backup_path"
    cp "$file" "$backup_path/"
    echo -e "  ${GREEN}✓${NC} 备份: $file"
    ((CHANGED_COUNT++))
done

echo -e "${GREEN}共备份了 $CHANGED_COUNT 个今天修改的文件${NC}"

# 整理根目录下的散落文件
echo -e "\n${BLUE}整理根目录下的散落文件...${NC}"

# 创建整理目录（如果不存在）
mkdir -p "Organized/Configs"
mkdir -p "Organized/Documentation"
mkdir -p "Organized/Temp"

# 整理规则
# 1. Swift文件移动到Sources/Utility
# 2. MD文件移动到Docs
# 3. JSON配置文件移动到Organized/Configs
# 4. 其他文本文件移动到Organized/Documentation
# 5. 临时文件移动到Organized/Temp
echo -e "${YELLOW}应用整理规则:${NC}"
echo -e "  - Swift文件 → Sources/Utility"
echo -e "  - Markdown文件 → Docs"
echo -e "  - JSON/配置文件 → Organized/Configs"
echo -e "  - 文本文件 → Organized/Documentation"
echo -e "  - 临时文件 → Organized/Temp"

# 确保目标目录存在
mkdir -p "Sources/Utility"

# 找出根目录下的文件（排除目录和特定文件）
ROOT_FILES=$(find . -maxdepth 1 -type f -not -path "*/\.*" -not -name "Package.swift" -not -name "README.md" -not -name "LICENSE")
MOVED_COUNT=0

for file in $ROOT_FILES; do
    filename=$(basename "$file")
    extension="${filename##*.}"
    
    # 为文件创建备份以防意外
    cp "$file" "$BACKUP_DIR/"
    
    # 根据文件类型整理
    if [[ "$extension" == "swift" ]]; then
        # 检查是否已有相同名称的文件
        if [ -f "Sources/Utility/$filename" ]; then
            new_filename="${filename%.*}_$(date +%H%M%S).${extension}"
            mv "$file" "Sources/Utility/$new_filename"
            echo -e "  ${GREEN}✓${NC} 移动: $file → Sources/Utility/$new_filename (重命名)"
        else
            mv "$file" "Sources/Utility/"
            echo -e "  ${GREEN}✓${NC} 移动: $file → Sources/Utility/$filename"
        fi
    elif [[ "$extension" == "md" ]]; then
        # 检查是否已有相同名称的文件
        if [ -f "Docs/$filename" ]; then
            new_filename="${filename%.*}_$(date +%H%M%S).${extension}"
            mv "$file" "Docs/$new_filename"
            echo -e "  ${GREEN}✓${NC} 移动: $file → Docs/$new_filename (重命名)"
        else
            mv "$file" "Docs/"
            echo -e "  ${GREEN}✓${NC} 移动: $file → Docs/$filename"
        fi
    elif [[ "$extension" == "json" || "$extension" == "yml" || "$extension" == "yaml" || "$extension" == "toml" || "$extension" == "xml" || "$extension" == "plist" ]]; then
        mv "$file" "Organized/Configs/"
        echo -e "  ${GREEN}✓${NC} 移动: $file → Organized/Configs/$filename"
    elif [[ "$extension" == "txt" || "$extension" == "rtf" || "$extension" == "doc" || "$extension" == "docx" || "$extension" == "pdf" ]]; then
        mv "$file" "Organized/Documentation/"
        echo -e "  ${GREEN}✓${NC} 移动: $file → Organized/Documentation/$filename"
    else
        mv "$file" "Organized/Temp/"
        echo -e "  ${GREEN}✓${NC} 移动: $file → Organized/Temp/$filename"
    fi
    
    ((MOVED_COUNT++))
done

echo -e "${GREEN}共整理了 $MOVED_COUNT 个散落文件${NC}"

# 为备份创建索引文件
echo -e "\n${BLUE}创建备份索引...${NC}"
INDEX_FILE="$BACKUP_DIR/backup_index.md"

echo "# OnlySlide 备份索引 ($DATE)" > "$INDEX_FILE"
echo "" >> "$INDEX_FILE"
echo "## 1. 备份文件列表" >> "$INDEX_FILE"
echo "" >> "$INDEX_FILE"

# 添加备份文件列表
find "$BACKUP_DIR" -type f -not -name "backup_index.md" | sort | while read -r file; do
    rel_path="${file#$BACKUP_DIR/}"
    echo "- \`$rel_path\`" >> "$INDEX_FILE"
done

# 添加摘要信息
echo "" >> "$INDEX_FILE"
echo "## 2. 备份摘要" >> "$INDEX_FILE"
echo "" >> "$INDEX_FILE"
echo "- 备份日期: $(date '+%Y-%m-%d %H:%M:%S')" >> "$INDEX_FILE"
echo "- 备份文件数: $CHANGED_COUNT" >> "$INDEX_FILE"
echo "- 整理文件数: $MOVED_COUNT" >> "$INDEX_FILE"
echo "" >> "$INDEX_FILE"
echo "## 3. 整理规则" >> "$INDEX_FILE"
echo "" >> "$INDEX_FILE"
echo "- Swift文件移动到 \`Sources/Utility\`" >> "$INDEX_FILE"
echo "- Markdown文件移动到 \`Docs\`" >> "$INDEX_FILE"
echo "- 配置文件移动到 \`Organized/Configs\`" >> "$INDEX_FILE"
echo "- 文档文件移动到 \`Organized/Documentation\`" >> "$INDEX_FILE"
echo "- 其他文件移动到 \`Organized/Temp\`" >> "$INDEX_FILE"

echo -e "${GREEN}备份索引已创建: $INDEX_FILE${NC}"

# 创建备份报告链接
REPORT_LINK="$HOME/Desktop/OnlySlide_Backup_Report_$DATE.md"
cp "$INDEX_FILE" "$REPORT_LINK"
echo -e "${GREEN}备份报告已创建并链接到桌面: OnlySlide_Backup_Report_$DATE.md${NC}"

echo -e "\n${GREEN}=== 备份与整理完成! ===${NC}"
echo -e "${YELLOW}备份位置: $BACKUP_DIR${NC}"
echo -e "${YELLOW}报告位置: $REPORT_LINK${NC}"
echo -e "${BLUE}请检查整理后的文件是否放置正确。${NC}"
echo "" 