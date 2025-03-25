#!/bin/bash

# 导入优化脚本 - 用于减少不必要的依赖和统一导入风格

# 设置颜色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 恢复默认颜色

print_header() {
    echo -e "\n${BLUE}================ $1 =================${NC}\n"
}

# 创建备份目录
mkdir -p Backups/ImportOptimization/$(date +%Y%m%d)

# 创建日志目录
mkdir -p logs
LOG_FILE="logs/import_optimization_$(date +%Y%m%d_%H%M%S).log"
echo "执行导入优化 - $(date)" > "$LOG_FILE"

# ============================
# 1. 识别并列出所有Swift文件的导入语句
# ============================
print_header "识别所有导入语句"

TEMP_DIR=$(mktemp -d)
IMPORTS_FILE="${TEMP_DIR}/all_imports.txt"

echo "正在扫描所有Swift文件的导入语句..."
find Sources -name "*.swift" -type f | while read -r file; do
    grep -E "^import " "$file" | sort | uniq >> "$IMPORTS_FILE"
done

# 排序并去重导入语句
sort "$IMPORTS_FILE" | uniq -c | sort -nr > "${TEMP_DIR}/imports_summary.txt"

# 显示导入统计
echo "导入语句统计:"
cat "${TEMP_DIR}/imports_summary.txt" | head -20

# 将完整的导入统计写入日志
cat "${TEMP_DIR}/imports_summary.txt" >> "$LOG_FILE"

# ============================
# 2. 确定可能的过度导入
# ============================
print_header "分析可能的过度导入"

# 检查同一文件中同时导入Foundation和其他基础框架的情况
echo "检查Foundation重复导入..."
find Sources -name "*.swift" -type f | while read -r file; do
    IMPORTS=$(grep -E "^import " "$file" | sort)
    if echo "$IMPORTS" | grep -q "import Foundation" && \
       (echo "$IMPORTS" | grep -q "import UIKit" || echo "$IMPORTS" | grep -q "import SwiftUI"); then
        echo "  $file: 可能不需要单独导入Foundation"
        echo "$file: 可能不需要单独导入Foundation" >> "$LOG_FILE"
    fi
done

# ============================
# 3. 生成导入优化建议
# ============================
print_header "生成优化建议"

# 创建优化报告文件
REPORT_FILE="logs/import_optimization_report.md"
echo "# 导入优化建议" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "生成日期: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 框架导入一致性
echo "## 框架导入一致性" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "为提高代码可读性，建议采用一致的导入顺序:" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "```swift" >> "$REPORT_FILE"
echo "// 1. 标准库和平台框架" >> "$REPORT_FILE"
echo "import Foundation" >> "$REPORT_FILE"
echo "import SwiftUI" >> "$REPORT_FILE"
echo "import Combine" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "// 2. 第三方库" >> "$REPORT_FILE"
echo "import ThirdPartyLibrary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "// 3. 应用内部模块 (按依赖顺序)" >> "$REPORT_FILE"
echo "import Common" >> "$REPORT_FILE"
echo "import Core" >> "$REPORT_FILE"
echo "import CoreDataModule" >> "$REPORT_FILE"
echo "```" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 冗余导入分析
echo "## 潜在的冗余导入" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "以下情况可能存在冗余导入:" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 1. 导入Foundation + UIKit/SwiftUI
echo "### 基础框架重复" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "当同时导入UIKit/SwiftUI和Foundation时，可以移除Foundation导入，因为这些框架已经包含了Foundation。" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 同步和迁移模块优化
echo "## 核心模块优化建议" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "### 同步模块" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "同步模块应规范化使用以下导入:" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "```swift" >> "$REPORT_FILE"
echo "import Foundation" >> "$REPORT_FILE"
echo "import CoreData" >> "$REPORT_FILE"
echo "import Combine  // 如需Combine功能" >> "$REPORT_FILE"
echo "```" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "### 迁移模块" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "迁移模块应规范化使用以下导入:" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "```swift" >> "$REPORT_FILE"
echo "import Foundation" >> "$REPORT_FILE"
echo "import CoreData" >> "$REPORT_FILE"
echo "import Combine  // 如需进度报告" >> "$REPORT_FILE"
echo "```" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# ============================
# 4. 总结
# ============================
print_header "优化总结"

echo -e "${GREEN}✓ 导入分析完成${NC}"
echo -e "${GREEN}✓ 优化报告已生成: $REPORT_FILE${NC}"
echo -e "${YELLOW}⚠ 请注意，这些建议需要手动审查和应用${NC}"
echo -e "${YELLOW}⚠ 修改导入语句后，务必进行充分测试${NC}"

echo -e "\n${BLUE}结束进程，临时文件将被清理${NC}"
rm -rf "$TEMP_DIR"

echo "完整日志已保存到: $LOG_FILE" 