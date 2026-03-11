#!/bin/bash
# ============================================
# 查看所有服务状态
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID_DIR="$PROJECT_ROOT/data/pids"

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE} Matrix 服务状态${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

if [ ! -d "$PID_DIR" ] || [ -z "$(ls -A "$PID_DIR" 2>/dev/null)" ]; then
    echo "  没有运行中的服务"
    echo "  启动: bash scripts/start-all.sh"
    exit 0
fi

for pid_file in "$PID_DIR"/*.pid; do
    if [ -f "$pid_file" ]; then
        name=$(basename "$pid_file" .pid)
        pid=$(cat "$pid_file")

        if kill -0 "$pid" 2>/dev/null; then
            # 获取内存使用
            mem=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.1fMB", $1/1024}')
            cpu=$(ps -o %cpu= -p "$pid" 2>/dev/null | awk '{printf "%.1f%%", $1}')
            echo -e "  ${GREEN}●${NC} $name"
            echo -e "    PID: $pid | 内存: $mem | CPU: $cpu"
            echo -e "    日志: logs/${name}.log"
        else
            echo -e "  ${RED}●${NC} $name (已停止)"
        fi
        echo ""
    fi
done

source "$PROJECT_ROOT/.env" 2>/dev/null

echo -e "${BLUE}  访问地址:${NC}"
echo "    Conduwuit:  http://localhost:${CONDUWUIT_PORT:-6167}"
echo "    Element:    http://localhost:${ELEMENT_PORT:-8080}"
echo ""
echo "  查看日志:  tail -f logs/<服务名>.log"
echo "  停止服务:  bash scripts/stop-all.sh"
