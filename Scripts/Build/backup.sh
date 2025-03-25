#!/bin/bash

# OnlySlide 项目备份脚本
# 用于备份项目代码和工作内容

# 设置颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # 恢复默认颜色

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[信息] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[成功] $1${NC}"
}

print_error() {
    echo -e "${RED}[错误] $1${NC}"
}

# 获取当前日期和时间
CURRENT_DATE=$(date +"%Y%m%d")
CURRENT_TIME=$(date +"%H%M%S")
BACKUP_NAME="OnlySlide_Backup_${CURRENT_DATE}_${CURRENT_TIME}"

# 创建备份目录
BACKUP_DIR="Backups/Daily/${CURRENT_DATE}"
mkdir -p "${BACKUP_DIR}"

print_info "开始备份 OnlySlide 项目 (${CURRENT_DATE}_${CURRENT_TIME})..."

# 备份源代码
print_info "备份源代码..."
SOURCES_BACKUP="${BACKUP_DIR}/${BACKUP_NAME}_Sources.tar.gz"
tar -czf "${SOURCES_BACKUP}" \
    --exclude='.git' \
    --exclude='.build' \
    --exclude='DerivedData' \
    --exclude='*.xcodeproj/xcuserdata' \
    --exclude='*.xcodeproj/project.xcworkspace/xcuserdata' \
    --exclude='Backups' \
    --exclude='build' \
    --exclude='.DS_Store' \
    --exclude='*.swp' \
    --exclude='*.swo' \
    Sources/ Tests/ Package.swift README.md

if [ $? -eq 0 ]; then
    print_success "源代码备份完成: ${SOURCES_BACKUP}"
else
    print_error "源代码备份失败"
    exit 1
fi

# 备份文档和脚本
print_info "备份文档和脚本..."
DOCS_BACKUP="${BACKUP_DIR}/${BACKUP_NAME}_Docs_Scripts.tar.gz"
tar -czf "${DOCS_BACKUP}" \
    --exclude='.DS_Store' \
    Docs/ Scripts/

if [ $? -eq 0 ]; then
    print_success "文档和脚本备份完成: ${DOCS_BACKUP}"
else
    print_error "文档和脚本备份失败"
    exit 1
fi

# 备份项目文件
print_info "备份项目文件..."
PROJECT_BACKUP="${BACKUP_DIR}/${BACKUP_NAME}_Project.tar.gz"
tar -czf "${PROJECT_BACKUP}" \
    --exclude='*.xcodeproj/xcuserdata' \
    --exclude='*.xcodeproj/project.xcworkspace/xcuserdata' \
    --exclude='.DS_Store' \
    *.xcodeproj/ *.xcworkspace/ 2>/dev/null || true

if [ -f "${PROJECT_BACKUP}" ]; then
    print_success "项目文件备份完成: ${PROJECT_BACKUP}"
else
    print_info "无项目文件需要备份或备份失败"
fi

# 备份资源
print_info "备份资源文件..."
RESOURCES_BACKUP="${BACKUP_DIR}/${BACKUP_NAME}_Resources.tar.gz"
tar -czf "${RESOURCES_BACKUP}" \
    --exclude='.DS_Store' \
    Resources/ 2>/dev/null || true

if [ -f "${RESOURCES_BACKUP}" ]; then
    print_success "资源文件备份完成: ${RESOURCES_BACKUP}"
else
    print_info "无资源文件需要备份或备份失败"
fi

# 创建备份清单
print_info "创建备份清单..."
MANIFEST="${BACKUP_DIR}/${BACKUP_NAME}_Manifest.md"

echo "# OnlySlide 项目备份清单" > "${MANIFEST}"
echo "" >> "${MANIFEST}"
echo "**备份日期:** $(date '+%Y-%m-%d %H:%M:%S')" >> "${MANIFEST}"
echo "**备份版本:** ${BACKUP_NAME}" >> "${MANIFEST}"
echo "" >> "${MANIFEST}"
echo "## 备份内容" >> "${MANIFEST}"
echo "" >> "${MANIFEST}"
echo "1. **源代码备份:** ${SOURCES_BACKUP}" >> "${MANIFEST}"
echo "2. **文档和脚本备份:** ${DOCS_BACKUP}" >> "${MANIFEST}"
echo "3. **项目文件备份:** ${PROJECT_BACKUP}" >> "${MANIFEST}"
echo "4. **资源文件备份:** ${RESOURCES_BACKUP}" >> "${MANIFEST}"
echo "" >> "${MANIFEST}"
echo "## Git 状态" >> "${MANIFEST}"
echo "" >> "${MANIFEST}"
echo '```' >> "${MANIFEST}"
git status >> "${MANIFEST}"
echo '```' >> "${MANIFEST}"
echo "" >> "${MANIFEST}"
echo "## 最近提交" >> "${MANIFEST}"
echo "" >> "${MANIFEST}"
echo '```' >> "${MANIFEST}"
git log -5 --oneline >> "${MANIFEST}"
echo '```' >> "${MANIFEST}"

print_success "备份清单创建完成: ${MANIFEST}"

# 生成备份报告
print_info "生成备份报告..."
REPORT="${BACKUP_DIR}/${BACKUP_NAME}_Report.md"

echo "# OnlySlide 项目备份报告" > "${REPORT}"
echo "" >> "${REPORT}"
echo "**备份日期:** $(date '+%Y-%m-%d %H:%M:%S')" >> "${REPORT}"
echo "**备份版本:** ${BACKUP_NAME}" >> "${REPORT}"
echo "" >> "${REPORT}"
echo "## 文件统计" >> "${REPORT}"
echo "" >> "${REPORT}"
echo "### 源代码文件" >> "${REPORT}"
echo "" >> "${REPORT}"
echo '```' >> "${REPORT}"
find Sources -type f -name "*.swift" | wc -l | xargs >> "${REPORT}"
echo '文件总数' >> "${REPORT}"
echo '```' >> "${REPORT}"
echo "" >> "${REPORT}"
echo "### 测试文件" >> "${REPORT}"
echo "" >> "${REPORT}"
echo '```' >> "${REPORT}"
find Tests -type f -name "*.swift" | wc -l | xargs >> "${REPORT}"
echo '文件总数' >> "${REPORT}"
echo '```' >> "${REPORT}"
echo "" >> "${REPORT}"
echo "### 文档文件" >> "${REPORT}"
echo "" >> "${REPORT}"
echo '```' >> "${REPORT}"
find Docs -type f -name "*.md" | wc -l | xargs >> "${REPORT}"
echo '文件总数' >> "${REPORT}"
echo '```' >> "${REPORT}"

print_success "备份报告创建完成: ${REPORT}"

# 创建一个完整备份的压缩文件
print_info "创建完整备份压缩文件..."
FULL_BACKUP="${BACKUP_DIR}/${BACKUP_NAME}_Full.zip"
zip -r "${FULL_BACKUP}" "${BACKUP_DIR}"/* -x "*.zip" 2>/dev/null

if [ $? -eq 0 ]; then
    print_success "完整备份创建成功: ${FULL_BACKUP}"
else
    print_error "完整备份创建失败"
fi

print_success "备份过程完成！所有备份文件位于: ${BACKUP_DIR}"
echo ""
echo "备份文件列表:"
ls -lh "${BACKUP_DIR}"
echo ""
echo "您可以使用以下命令查看备份清单:"
echo "cat ${MANIFEST}" 