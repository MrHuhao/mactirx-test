#!/bin/bash
# ============================================
# 停止所有 Matrix 服务
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID_DIR="$PROJECT_ROOT/data/pids"

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_ok() { echo -e "  ${GREEN}✓${NC} $1"; }
print_fail() { echo -e "  ${RED}✗${NC} $1"; }
print_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }

print_header "停止 Matrix 全栈服务"

if [ ! -d "$PID_DIR" ]; then
    echo "  没有运行中的服务"
    exit 0
fi

STOPPED=0
for pid_file in "$PID_DIR"/*.pid; do
    if [ -f "$pid_file" ]; then
        name=$(basename "$pid_file" .pid)
        pid=$(cat "$pid_file")

        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  停止 $name (PID: $pid)..."
            kill "$pid" 2>/dev/null
            # 等待进程退出
            for i in $(seq 1 10); do
                if ! kill -0 "$pid" 2>/dev/null; then
                    break
                fi
                sleep 1
            done
            # 如果还没退出，强制 kill
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null
                print_warn "$name 被强制终止"
            else
                print_ok "$name 已停止"
            fi
            STOPPED=$((STOPPED + 1))
        else
            print_warn "$name 已经不在运行"
        fi
        rm -f "$pid_file"
    fi
done

if [ $STOPPED -eq 0 ]; then
    echo "  没有需要停止的服务"
else
    echo ""
    echo -e "${GREEN}  已停止 $STOPPED 个服务${NC}"
fi
