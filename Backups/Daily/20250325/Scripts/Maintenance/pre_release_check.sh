#!/bin/bash

# 发布前检查脚本 - 用于验证代码质量和编译正确性

# 设置颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 恢复默认颜色

# 记录检查结果
SUCCESS_COUNT=0
WARNING_COUNT=0
ERROR_COUNT=0

# 打印带颜色的消息
print_header() {
    echo -e "\n${BLUE}================ $1 =================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((SUCCESS_COUNT++))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    ((WARNING_COUNT++))
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    ((ERROR_COUNT++))
}

# 创建日志文件夹
mkdir -p logs
LOG_FILE="logs/pre_release_check_$(date +%Y%m%d_%H%M%S).log"
echo "执行发布前检查 - $(date)" > "$LOG_FILE"

# ============================
# 1. 检查重复定义
# ============================
print_header "检查重复定义"

# 检查SyncState
SYNCSTATE_DEFS=$(grep -r "enum SyncState" --include="*.swift" Sources/ | wc -l | xargs)
if [ "$SYNCSTATE_DEFS" -gt 1 ]; then
    print_error "发现多个SyncState定义 ($SYNCSTATE_DEFS 个)"
    grep -r "enum SyncState" --include="*.swift" Sources/ >> "$LOG_FILE"
else
    print_success "SyncState定义正确"
fi

# 检查MigrationResult
MIGRATIONRESULT_DEFS=$(grep -r "enum MigrationResult" --include="*.swift" Sources/ | wc -l | xargs)
if [ "$MIGRATIONRESULT_DEFS" -gt 1 ]; then
    print_error "发现多个MigrationResult定义 ($MIGRATIONRESULT_DEFS 个)"
    grep -r "enum MigrationResult" --include="*.swift" Sources/ >> "$LOG_FILE"
else
    print_success "MigrationResult定义正确"
fi

# 检查ThreadSafe
THREADSAFE_DEFS=$(grep -r "struct ThreadSafe\|class ThreadSafe" --include="*.swift" Sources/ | wc -l | xargs)
if [ "$THREADSAFE_DEFS" -gt 1 ]; then
    print_error "发现多个ThreadSafe定义 ($THREADSAFE_DEFS 个)"
    grep -r "struct ThreadSafe\|class ThreadSafe" --include="*.swift" Sources/ >> "$LOG_FILE"
else
    print_success "ThreadSafe定义正确"
fi

# ============================
# 2. 检查导入语句
# ============================
print_header "检查导入语句"

# 检查循环依赖
print_warning "建议手动检查循环导入，尤其是以下模块之间:"
echo "- CoreDataModule <-> Core"
echo "- CoreDataModule <-> App"
echo "- Core <-> Features"

# 检查未使用的导入
UNUSED_IMPORTS=$(grep -r "^import " --include="*.swift" Sources/ | grep -v "Foundation\|SwiftUI\|CoreData\|Combine\|os" | wc -l | xargs)
if [ "$UNUSED_IMPORTS" -gt 30 ]; then
    print_warning "可能存在过多导入语句 ($UNUSED_IMPORTS 个)"
    echo "可能存在过多导入语句，建议检查优化" >> "$LOG_FILE"
else
    print_success "导入语句数量合理"
fi

# ============================
# 3. 测试构建
# ============================
print_header "执行构建测试"

# 尝试构建项目
echo "正在构建项目..."
BUILD_OUTPUT=$(swift build -c debug 2>&1)
BUILD_RESULT=$?

if [ $BUILD_RESULT -eq 0 ]; then
    print_success "项目构建成功"
else
    print_error "项目构建失败"
    echo "$BUILD_OUTPUT" >> "$LOG_FILE"
    echo "$BUILD_OUTPUT" | grep -i "error:" | head -5
fi

# ============================
# 4. 命名约定检查
# ============================
print_header "检查命名约定"

# 检查非一致性命名
INCONSISTENT_NAMING=0

# 检查方法命名是否使用驼峰式
CAMELCASE_ISSUES=$(grep -r "func [a-z]*_[a-z]*" --include="*.swift" Sources/ | grep -v "//" | wc -l | xargs)
if [ "$CAMELCASE_ISSUES" -gt 0 ]; then
    ((INCONSISTENT_NAMING++))
    print_warning "发现可能的非驼峰式方法命名 ($CAMELCASE_ISSUES 处)"
fi

# 检查类型前缀一致性 (以Enhanced为例)
ENHANCED_PREFIXES=$(grep -r "class Enhanced\|struct Enhanced\|enum Enhanced" --include="*.swift" Sources/ | wc -l | xargs)
ENHANCED_TYPES=$(grep -r "EnhancedSyncManager\|EnhancedMigrationManager\|EnhancedErrorHandler" --include="*.swift" Sources/ | grep -v "class\|struct\|enum" | wc -l | xargs)

if [ "$ENHANCED_TYPES" -gt "$ENHANCED_PREFIXES" ]; then
    ((INCONSISTENT_NAMING++))
    print_warning "增强型组件命名前缀可能不一致"
fi

if [ "$INCONSISTENT_NAMING" -eq 0 ]; then
    print_success "命名约定一致性良好"
fi

# ============================
# 5. 文档检查
# ============================
print_header "文档验证"

# 检查关键文档是否存在
DOCS_NEEDED=(
    "README.md"
    "Docs/ArchitectureDesign.md"
    "Docs/TestCoverageReport.md"
    "Docs/UsageGuide.md"
    "Docs/Installation.md"
)

MISSING_DOCS=0
for doc in "${DOCS_NEEDED[@]}"; do
    if [ ! -f "$doc" ]; then
        print_warning "缺少文档: $doc"
        ((MISSING_DOCS++))
    fi
done

if [ "$MISSING_DOCS" -eq 0 ]; then
    print_success "所有必需文档都存在"
fi

# ============================
# 6. 性能检查
# ============================
print_header "性能注意事项"

# 检查@ThreadSafe的使用
THREADSAFE_USAGES=$(grep -r "@ThreadSafe" --include="*.swift" Sources/ | wc -l | xargs)
if [ "$THREADSAFE_USAGES" -gt 20 ]; then
    print_warning "大量使用@ThreadSafe ($THREADSAFE_USAGES 处)，考虑性能影响"
else
    print_success "@ThreadSafe使用合理"
fi

# 检查强制解包
FORCE_UNWRAP=$(grep -r "!" --include="*.swift" Sources/ | grep -v "if\|guard\|import\|#if" | wc -l | xargs)
if [ "$FORCE_UNWRAP" -gt 50 ]; then
    print_warning "可能过度使用强制解包 ($FORCE_UNWRAP 处)"
else
    print_success "强制解包使用合理"
fi

# ============================
# 7. 总结
# ============================
print_header "检查总结"

echo -e "${GREEN}成功: $SUCCESS_COUNT${NC}"
echo -e "${YELLOW}警告: $WARNING_COUNT${NC}"
echo -e "${RED}错误: $ERROR_COUNT${NC}"

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "\n${RED}检查发现错误，建议在发布前修复。${NC}"
    echo -e "详细日志已保存到: $LOG_FILE"
    exit 1
elif [ "$WARNING_COUNT" -gt 0 ]; then
    echo -e "\n${YELLOW}检查完成，但有警告需要注意。${NC}"
    echo -e "详细日志已保存到: $LOG_FILE"
    exit 0
else
    echo -e "\n${GREEN}所有检查通过！项目可以发布。${NC}"
    echo -e "详细日志已保存到: $LOG_FILE"
    exit 0
fi 