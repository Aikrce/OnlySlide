#!/bin/bash

# 命名规范检查脚本 - 用于确保项目中的命名一致性

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

# 创建日志目录
mkdir -p logs
LOG_FILE="logs/naming_check_$(date +%Y%m%d_%H%M%S).log"
echo "执行命名规范检查 - $(date)" > "$LOG_FILE"

# ============================
# 1. 检查类型名称规范
# ============================
print_header "检查类型命名"

# 检查带下划线的类型名
TYPES_WITH_UNDERSCORES=$(grep -r "class [a-zA-Z]*_[a-zA-Z]*\|struct [a-zA-Z]*_[a-zA-Z]*\|enum [a-zA-Z]*_[a-zA-Z]*" --include="*.swift" Sources/ | grep -v "//" | wc -l | xargs)

if [ "$TYPES_WITH_UNDERSCORES" -gt 0 ]; then
    print_error "类型名称中包含下划线 ($TYPES_WITH_UNDERSCORES 处)"
    grep -r "class [a-zA-Z]*_[a-zA-Z]*\|struct [a-zA-Z]*_[a-zA-Z]*\|enum [a-zA-Z]*_[a-zA-Z]*" --include="*.swift" Sources/ | grep -v "//" >> "$LOG_FILE"
else
    print_success "类型名称不包含下划线"
fi

# 检查前缀规范
print_header "检查类型前缀规范"

# 检查"Enhanced"前缀的一致性
ENHANCED_CLASSES=$(grep -r "class Enhanced" --include="*.swift" Sources/ | wc -l | xargs)
ENHANCED_STRUCTS=$(grep -r "struct Enhanced" --include="*.swift" Sources/ | wc -l | xargs)
ENHANCED_ENUMS=$(grep -r "enum Enhanced" --include="*.swift" Sources/ | wc -l | xargs)
ENHANCED_TOTAL=$((ENHANCED_CLASSES + ENHANCED_STRUCTS + ENHANCED_ENUMS))

ENHANCED_REFERENCES=$(grep -r "EnhancedSyncManager\|EnhancedMigrationManager\|EnhancedErrorHandler" --include="*.swift" Sources/ | grep -v "class\|struct\|enum\|import" | wc -l | xargs)

if [ "$ENHANCED_REFERENCES" -gt "$ENHANCED_TOTAL" ]; then
    print_warning "可能有'Enhanced'前缀不一致的地方 (定义: $ENHANCED_TOTAL, 引用: $ENHANCED_REFERENCES)"
else
    print_success "'Enhanced'前缀使用一致"
fi

# 检查"CoreData"前缀一致性
COREDATA_CLASSES=$(grep -r "class CoreData" --include="*.swift" Sources/ | wc -l | xargs)
COREDATA_REFERENCES=$(grep -r "CoreDataManager\|CoreDataStack\|CoreDataStore" --include="*.swift" Sources/ | grep -v "class\|struct\|enum\|import" | wc -l | xargs)

if [ "$COREDATA_REFERENCES" -gt $((COREDATA_CLASSES*3)) ]; then
    print_warning "可能有'CoreData'前缀不一致的地方 (类: $COREDATA_CLASSES, 引用: $COREDATA_REFERENCES)"
else
    print_success "'CoreData'前缀使用一致"
fi

# ============================
# 2. 检查方法命名规范
# ============================
print_header "检查方法命名"

# 检查非驼峰式方法命名
NON_CAMELCASE=$(grep -r "func [a-z]*_[a-z]*" --include="*.swift" Sources/ | grep -v "//" | wc -l | xargs)

if [ "$NON_CAMELCASE" -gt 0 ]; then
    print_warning "可能存在非驼峰式方法命名 ($NON_CAMELCASE 处)"
    grep -r "func [a-z]*_[a-z]*" --include="*.swift" Sources/ | grep -v "//" | head -5 >> "$LOG_FILE"
    echo "..." >> "$LOG_FILE"
else
    print_success "方法命名使用驼峰式"
fi

# 检查方法名和参数一致性
print_header "检查方法名和参数一致性"

# "get"开头的方法检查
GET_METHODS=$(grep -r "func get[A-Z]" --include="*.swift" Sources/ | grep -v "//" | wc -l | xargs)

if [ "$GET_METHODS" -gt 5 ]; then
    print_warning "有较多'get'前缀的方法 ($GET_METHODS 处)，Swift推荐省略'get'"
    grep -r "func get[A-Z]" --include="*.swift" Sources/ | grep -v "//" | head -5 >> "$LOG_FILE"
    echo "..." >> "$LOG_FILE"
else
    print_success "'get'前缀使用合理"
fi

# ============================
# 3. 检查变量和属性命名
# ============================
print_header "检查变量和属性命名"

# 检查下划线前缀的变量 (常用于指示私有但在Swift中不推荐)
UNDERSCORE_PREFIXED=$(grep -r "_[a-zA-Z]* =" --include="*.swift" Sources/ | grep -v "//" | wc -l | xargs)

if [ "$UNDERSCORE_PREFIXED" -gt 10 ]; then
    print_warning "大量使用下划线前缀的变量 ($UNDERSCORE_PREFIXED 处)，不符合Swift风格指南"
    grep -r "_[a-zA-Z]* =" --include="*.swift" Sources/ | grep -v "//" | head -5 >> "$LOG_FILE"
    echo "..." >> "$LOG_FILE"
else
    print_success "下划线前缀使用合理"
fi

# 检查匈牙利命名法 (如strName, intCount)
HUNGARIAN=$(grep -r "let [a-z][a-z][a-z][A-Z]\|var [a-z][a-z][a-z][A-Z]" --include="*.swift" Sources/ | grep -v "//" | wc -l | xargs)

if [ "$HUNGARIAN" -gt 5 ]; then
    print_warning "可能使用匈牙利命名法 ($HUNGARIAN 处)，不符合Swift风格"
else
    print_success "没有明显的匈牙利命名法"
fi

# ============================
# 4. 检查属性包装器命名
# ============================
print_header "检查属性包装器命名"

# 检查属性包装器前缀一致性
PROPERTY_WRAPPERS_WITH_AT=$(grep -r "@propertyWrapper" --include="*.swift" Sources/ | wc -l | xargs)
PROPERTY_WRAPPERS_CLASSES=$(grep -r "@propertyWrapper\s*\nstruct\|@propertyWrapper\s*\nclass" --include="*.swift" Sources/ | wc -l | xargs)

if [ "$PROPERTY_WRAPPERS_WITH_AT" -gt "$PROPERTY_WRAPPERS_CLASSES" ]; then
    print_warning "属性包装器定义和使用可能不一致"
else
    print_success "属性包装器定义和使用一致"
fi

# ============================
# 5. 生成命名规范指南
# ============================
print_header "生成命名规范指南"

# 创建命名规范文件
GUIDELINES_FILE="logs/naming_guidelines.md"
echo "# OnlySlide项目命名规范指南" > "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"
echo "生成日期: $(date)" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"

echo "## 一般原则" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"
echo "* 使用描述性命名，避免缩写" >> "$GUIDELINES_FILE"
echo "* 遵循Swift官方风格指南" >> "$GUIDELINES_FILE"
echo "* 保持项目内部命名一致性" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"

echo "## 类型命名" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"
echo "* 使用大驼峰命名法(UpperCamelCase)" >> "$GUIDELINES_FILE"
echo "* 类型名称应该是名词" >> "$GUIDELINES_FILE"
echo "* 协议名称应该是名词或形容词" >> "$GUIDELINES_FILE"
echo "* 避免在名称中使用下划线" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"

echo "### 前缀规范" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"
echo "* `Enhanced` - 用于增强型组件，如 `EnhancedMigrationManager`" >> "$GUIDELINES_FILE"
echo "* `CoreData` - 用于Core Data相关组件，如 `CoreDataManager`" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"

echo "## 方法命名" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"
echo "* 使用小驼峰命名法(lowerCamelCase)" >> "$GUIDELINES_FILE"
echo "* 方法名应该表达其行为" >> "$GUIDELINES_FILE"
echo "* 避免使用`get`前缀" >> "$GUIDELINES_FILE"
echo "* 对于返回布尔值的方法，使用`is`, `has`, `should`等前缀" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"

echo "## 变量和属性命名" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"
echo "* 使用小驼峰命名法(lowerCamelCase)" >> "$GUIDELINES_FILE"
echo "* 避免使用下划线前缀表示私有性" >> "$GUIDELINES_FILE"
echo "* 不使用匈牙利命名法" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"

echo "## 枚举命名" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"
echo "* 枚举类型使用大驼峰命名法" >> "$GUIDELINES_FILE"
echo "* 枚举case使用小驼峰命名法" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"

echo "## 属性包装器" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"
echo "* 属性包装器使用描述性名称" >> "$GUIDELINES_FILE"
echo "* 例如: `@ThreadSafe`, `@MainActor`" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"

echo "## 遵循协议例子" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"
echo "```swift" >> "$GUIDELINES_FILE"
echo "// 类型命名 - 大驼峰命名法" >> "$GUIDELINES_FILE"
echo "struct ResourceManager {" >> "$GUIDELINES_FILE"
echo "    // 属性命名 - 小驼峰命名法" >> "$GUIDELINES_FILE"
echo "    private let cacheManager: CacheManaging" >> "$GUIDELINES_FILE"
echo "    " >> "$GUIDELINES_FILE"
echo "    // 方法命名 - 小驼峰命名法，无get前缀" >> "$GUIDELINES_FILE"
echo "    func resource(for identifier: String) -> Resource? {" >> "$GUIDELINES_FILE"
echo "        // 实现..." >> "$GUIDELINES_FILE"
echo "    }" >> "$GUIDELINES_FILE"
echo "    " >> "$GUIDELINES_FILE"
echo "    // 布尔方法使用is前缀" >> "$GUIDELINES_FILE"
echo "    func isResourceAvailable(for identifier: String) -> Bool {" >> "$GUIDELINES_FILE"
echo "        // 实现..." >> "$GUIDELINES_FILE"
echo "    }" >> "$GUIDELINES_FILE"
echo "}" >> "$GUIDELINES_FILE"
echo "```" >> "$GUIDELINES_FILE"
echo "" >> "$GUIDELINES_FILE"

# ============================
# 6. 总结
# ============================
print_header "命名规范检查总结"

echo -e "${GREEN}成功: $SUCCESS_COUNT${NC}"
echo -e "${YELLOW}警告: $WARNING_COUNT${NC}"
echo -e "${RED}错误: $ERROR_COUNT${NC}"

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "\n${RED}命名规范检查发现错误，建议修复。${NC}"
    echo -e "详细日志已保存到: $LOG_FILE"
    echo -e "命名规范指南已生成到: $GUIDELINES_FILE"
elif [ "$WARNING_COUNT" -gt 0 ]; then
    echo -e "\n${YELLOW}命名规范检查发现警告，建议进一步审查。${NC}"
    echo -e "详细日志已保存到: $LOG_FILE"
    echo -e "命名规范指南已生成到: $GUIDELINES_FILE"
else
    echo -e "\n${GREEN}命名规范检查通过！${NC}"
    echo -e "命名规范指南已生成到: $GUIDELINES_FILE"
fi 