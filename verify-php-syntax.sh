#!/bin/bash

# PHP 语法验证脚本
# 使用 Docker 验证 PHP 文件语法

# 注意：不使用 set -e，避免在发现语法错误时退出 shell
set -o pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
CONTAINER_NAME="wordpress"
TARGET_DIR="${1:-.}"
EXCLUDE_DIRS="vendor|node_modules|cache|uploads|upgrade"
VERBOSE="${VERBOSE:-0}"  # 设置 VERBOSE=1 显示详细信息

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  PHP 语法验证工具 (使用 Docker)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查 Docker 容器是否运行
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}错误: Docker 容器 '${CONTAINER_NAME}' 未运行${NC}"
    echo "请先启动容器: docker-compose up -d"
    # 检测是否被 source，如果是则使用 return 而不是 exit
    (return 0 2>/dev/null) && return 1 || exit 1
fi

echo -e "${GREEN}✓${NC} Docker 容器 '${CONTAINER_NAME}' 正在运行"
echo -e "${BLUE}扫描目录:${NC} ${TARGET_DIR}"
echo -e "${BLUE}排除目录:${NC} ${EXCLUDE_DIRS}"
echo ""

# 查找所有 PHP 文件
echo -e "${YELLOW}正在查找 PHP 文件...${NC}"

# 使用容器内的 find 命令
PHP_FILES=$(docker exec ${CONTAINER_NAME} find /var/www/html/${TARGET_DIR} -type f -name "*.php" 2>/dev/null | \
    grep -vE "(${EXCLUDE_DIRS})" || true)

if [ -z "$PHP_FILES" ]; then
    echo -e "${YELLOW}警告: 未找到 PHP 文件${NC}"
    # 检测是否被 source，如果是则使用 return 而不是 exit
    (return 0 2>/dev/null) && return 0 || exit 0
fi

# 统计文件数量
FILE_COUNT=$(echo "$PHP_FILES" | wc -l)
echo -e "${GREEN}找到 ${FILE_COUNT} 个 PHP 文件${NC}"
echo ""

# 验证语法
echo -e "${YELLOW}开始验证 PHP 语法...${NC}"
echo ""

ERROR_COUNT=0
SUCCESS_COUNT=0
ERROR_FILES=()

while IFS= read -r file; do
    if [ -n "$file" ]; then
        # 获取相对路径显示
        DISPLAY_PATH=${file#/var/www/html/}
        
        # 使用 php -l 检查语法
        if docker exec ${CONTAINER_NAME} php -l "$file" > /dev/null 2>&1; then
            if [ "$VERBOSE" = "1" ]; then
                echo -e "${GREEN}✓${NC} ${DISPLAY_PATH}"
            fi
            ((SUCCESS_COUNT++))
        else
            echo -e "${RED}✗${NC} ${DISPLAY_PATH}"
            # 获取详细错误信息
            ERROR_MSG=$(docker exec ${CONTAINER_NAME} php -l "$file" 2>&1)
            echo -e "  ${RED}${ERROR_MSG}${NC}"
            echo ""
            ERROR_FILES+=("$DISPLAY_PATH")
            ((ERROR_COUNT++))
        fi
    fi
done <<< "$PHP_FILES"

# 显示总结
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  验证完成${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}成功:${NC} ${SUCCESS_COUNT} 个文件"
echo -e "${RED}失败:${NC} ${ERROR_COUNT} 个文件"
echo ""

# 如果有错误，列出所有错误文件
if [ ${ERROR_COUNT} -gt 0 ]; then
    echo -e "${RED}以下文件存在语法错误:${NC}"
    for file in "${ERROR_FILES[@]}"; do
        echo -e "  - ${file}"
    done
    echo ""
    # 检测是否被 source，如果是则使用 return 而不是 exit
    (return 0 2>/dev/null) && return 1 || exit 1
else
    echo -e "${GREEN}所有 PHP 文件语法正确！${NC}"
    # 检测是否被 source，如果是则使用 return 而不是 exit
    (return 0 2>/dev/null) && return 0 || exit 0
fi

