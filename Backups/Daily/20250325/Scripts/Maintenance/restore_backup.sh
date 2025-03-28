#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

echo -e "${BLUE}===== OnlySlide 备份恢复工具 =====${NC}"

# 检查参数
if [ "$#" -lt 1 ]; then
    echo -e "${YELLOW}用法:${NC}"
    echo -e "  $0 [备份日期YYYYMMDD] [可选:要恢复的文件路径]"
    echo -e "  $0 list  # 列出所有可用备份"
    echo -e "例如:"
    echo -e "  $0 20250325                 # 恢复2025年3月25日的整个备份"
    echo -e "  $0 20250325 Sources/Core    # 只恢复Core目录"
    echo -e "  $0 20250325 --interactive   # 交互式恢复（选择文件）"
    exit 1
fi

# 检查是否在项目根目录下运行
if [ ! -d "Sources" ] || [ ! -d "Scripts" ]; then
    echo -e "${RED}错误: 请在OnlySlide项目根目录下运行此脚本${NC}"
    exit 1
fi

# 如果参数是"list"，则列出所有备份
if [ "$1" == "list" ]; then
    echo -e "${BLUE}可用的备份:${NC}"
    if [ -d "Backups/Daily" ]; then
        echo -e "${YELLOW}每日备份:${NC}"
        ls -1 Backups/Daily | sort -r | while read -r backup; do
            file_count=$(find "Backups/Daily/$backup" -type f | wc -l | xargs)
            echo -e "  ${GREEN}$backup${NC} ($file_count 个文件)"
        done
    fi
    
    if [ -d "Backups/Release" ]; then
        echo -e "\n${YELLOW}发布备份:${NC}"
        ls -1 Backups/Release | sort -r | while read -r backup; do
            file_count=$(find "Backups/Release/$backup" -type f | wc -l | xargs)
            echo -e "  ${GREEN}$backup${NC} ($file_count 个文件)"
        done
    fi
    
    if [ -d "Backups/Special" ]; then
        echo -e "\n${YELLOW}特殊备份:${NC}"
        ls -1 Backups/Special | sort -r | while read -r backup; do
            file_count=$(find "Backups/Special/$backup" -type f | wc -l | xargs)
            echo -e "  ${GREEN}$backup${NC} ($file_count 个文件)"
        done
    fi
    exit 0
fi

# 获取指定的备份日期
BACKUP_DATE="$1"
BACKUP_DIR="Backups/Daily/$BACKUP_DATE"

# 检查备份是否存在
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}错误: 找不到指定日期的备份目录: $BACKUP_DIR${NC}"
    echo -e "${YELLOW}可用的备份日期:${NC}"
    ls -1 Backups/Daily | sort -r | head -5
    exit 1
fi

# 交互式恢复
if [ "$2" == "--interactive" ]; then
    echo -e "${BLUE}交互式恢复模式${NC}"
    echo -e "${YELLOW}以下是 $BACKUP_DATE 备份中的文件:${NC}"
    
    # 生成文件列表并编号
    TEMP_FILE_LIST=$(mktemp)
    find "$BACKUP_DIR" -type f | sort > "$TEMP_FILE_LIST"
    
    # 显示带编号的文件列表
    cat -n "$TEMP_FILE_LIST"
    
    echo -e "\n${YELLOW}请输入要恢复的文件编号（用空格分隔多个编号，输入'all'恢复所有文件）:${NC}"
    read -r selection
    
    if [ "$selection" == "all" ]; then
        # 恢复所有文件
        echo -e "${BLUE}正在恢复所有文件...${NC}"
        
        while IFS= read -r file; do
            # 从备份路径转换为目标路径
            target="${file#$BACKUP_DIR/}"
            target_dir=$(dirname "$target")
            
            # 确保目标目录存在
            mkdir -p "$target_dir"
            
            # 复制文件
            cp "$file" "$target"
            echo -e "  ${GREEN}✓${NC} 恢复: $target"
        done < "$TEMP_FILE_LIST"
    else
        # 恢复选定的文件
        for num in $selection; do
            file=$(sed -n "${num}p" "$TEMP_FILE_LIST")
            if [ -n "$file" ]; then
                # 从备份路径转换为目标路径
                target="${file#$BACKUP_DIR/}"
                target_dir=$(dirname "$target")
                
                # 确保目标目录存在
                mkdir -p "$target_dir"
                
                # 复制文件
                cp "$file" "$target"
                echo -e "  ${GREEN}✓${NC} 恢复: $target"
            else
                echo -e "  ${RED}✗${NC} 无效编号: $num"
            fi
        done
    fi
    
    # 删除临时文件
    rm "$TEMP_FILE_LIST"
    
    echo -e "${GREEN}交互式恢复完成!${NC}"
    exit 0
fi

# 获取要恢复的文件路径（如果指定）
RESTORE_PATH="$2"

if [ -n "$RESTORE_PATH" ]; then
    # 恢复指定路径
    if [ ! -d "$BACKUP_DIR/$RESTORE_PATH" ] && [ ! -f "$BACKUP_DIR/$RESTORE_PATH" ]; then
        echo -e "${RED}错误: 备份中不存在指定的路径: $RESTORE_PATH${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}正在恢复 $RESTORE_PATH...${NC}"
    
    # 确保目标目录存在
    mkdir -p "$RESTORE_PATH"
    
    # 使用rsync恢复，保持目录结构
    rsync -av "$BACKUP_DIR/$RESTORE_PATH/" "$RESTORE_PATH/"
    
    echo -e "${GREEN}恢复完成!${NC}"
else
    # 恢复整个备份
    echo -e "${YELLOW}您将恢复整个备份。这可能会覆盖当前文件。${NC}"
    echo -e "${YELLOW}是否继续? (y/n)${NC}"
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${BLUE}恢复已取消${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}正在恢复整个备份...${NC}"
    
    # 使用rsync恢复，保持目录结构
    rsync -av --exclude="backup_index.md" "$BACKUP_DIR/" "./"
    
    echo -e "${GREEN}恢复完成!${NC}"
fi

echo -e "${YELLOW}请注意: 如果您恢复了部分文件，可能需要重新构建项目。${NC}"
echo -e "${BLUE}建议运行:${NC} ./Scripts/Build/rebuild.sh" 