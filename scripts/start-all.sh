#!/bin/bash
# ============================================
# 启动所有 Matrix 服务
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$PROJECT_ROOT/source"
LOGS_DIR="$PROJECT_ROOT/logs"

source "$PROJECT_ROOT/.env"

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_ok() { echo -e "  ${GREEN}✓${NC} $1"; }
print_fail() { echo -e "  ${RED}✗${NC} $1"; }
print_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }

# PID 文件目录
PID_DIR="$PROJECT_ROOT/data/pids"
mkdir -p "$PID_DIR" "$LOGS_DIR"

# ============================================
# 启动函数
# ============================================
start_service() {
    local name="$1"
    local command="$2"
    local log_file="$LOGS_DIR/${name}.log"
    local pid_file="$PID_DIR/${name}.pid"

    # 检查是否已在运行
    if [ -f "$pid_file" ]; then
        local old_pid=$(cat "$pid_file")
        if kill -0 "$old_pid" 2>/dev/null; then
            print_warn "$name 已在运行 (PID: $old_pid)"
            return 0
        else
            rm -f "$pid_file"
        fi
    fi

    echo -e "  启动 $name..."
    eval "nohup $command > '$log_file' 2>&1 &"
    local pid=$!
    echo $pid > "$pid_file"

    # 等待并检查
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        print_ok "$name 已启动 (PID: $pid, 日志: logs/${name}.log)"
        return 0
    else
        print_fail "$name 启动失败, 查看日志: $log_file"
        tail -10 "$log_file" 2>/dev/null
        return 1
    fi
}

# ============================================
print_header "启动 Matrix 全栈服务"
echo "项目目录: $PROJECT_ROOT"
echo ""

# ---- 1. Conduwuit ----
print_header "1. 启动 Conduwuit"

# 生成实际配置 (替换变量)
CONDUWUIT_CONFIG="$PROJECT_ROOT/conduwuit/conduwuit.toml"
CONDUWUIT_RUNTIME_CONFIG="$PROJECT_ROOT/data/conduwuit/conduwuit.toml"
mkdir -p "$PROJECT_ROOT/data/conduwuit"

sed "s|\${PROJECT_ROOT}|${PROJECT_ROOT}|g" "$CONDUWUIT_CONFIG" > "$CONDUWUIT_RUNTIME_CONFIG"

# 查找 conduwuit 二进制
CONDUWUIT_BIN=""
for candidate in \
    "$SOURCE_DIR/conduwuit/target/release/conduit" \
    "$SOURCE_DIR/conduwuit/target/release/conduwuit" \
    "$SOURCE_DIR/conduwuit/target/release/conduwuit-server"; do
    if [ -x "$candidate" ]; then
        CONDUWUIT_BIN="$candidate"
        break
    fi
done

# 如果上面都没找到，搜索可执行文件
if [ -z "$CONDUWUIT_BIN" ]; then
    CONDUWUIT_BIN=$(find "$SOURCE_DIR/conduwuit/target/release" -maxdepth 1 -type f -perm +111 ! -name "*.d" ! -name "*.so" ! -name "*.dylib" ! -name "build-*" 2>/dev/null | head -1)
fi

if [ -n "$CONDUWUIT_BIN" ]; then
    export CONDUWUIT_CONFIG="$CONDUWUIT_RUNTIME_CONFIG"
    start_service "conduwuit" "CONDUWUIT_CONFIG='$CONDUWUIT_RUNTIME_CONFIG' '$CONDUWUIT_BIN'"
else
    print_fail "Conduwuit 二进制未找到, 请先运行 build-all.sh"
fi

# ---- 2. Go Bridges ----
print_header "2. 启动 Go Bridges"

start_go_bridge() {
    local bridge_name="$1"
    local bin_path="$SOURCE_DIR/mautrix-${bridge_name}/mautrix-${bridge_name}"
    local config_path="$PROJECT_ROOT/bridges/mautrix-${bridge_name}/config.yaml"

    if [ -x "$bin_path" ] && [ -f "$config_path" ]; then
        start_service "mautrix-${bridge_name}" "'$bin_path' -c '$config_path'"
    else
        if [ ! -x "$bin_path" ]; then
            print_warn "mautrix-${bridge_name} 二进制未找到, 跳过"
        else
            print_warn "mautrix-${bridge_name} 配置未找到, 跳过"
        fi
    fi
}

start_go_bridge "discord"
start_go_bridge "whatsapp"
start_go_bridge "slack"
start_go_bridge "signal"
start_go_bridge "gmessages"

# ---- 3. mautrix-telegram ----
print_header "3. 启动 mautrix-telegram"

TELEGRAM_VENV="$SOURCE_DIR/mautrix-telegram/venv"
TELEGRAM_CONFIG="$PROJECT_ROOT/bridges/mautrix-telegram/config.yaml"

if [ -d "$TELEGRAM_VENV" ] && [ -f "$TELEGRAM_CONFIG" ]; then
    start_service "mautrix-telegram" "'$TELEGRAM_VENV/bin/python' -m mautrix_telegram -c '$TELEGRAM_CONFIG'"
else
    print_warn "mautrix-telegram 未构建或配置缺失, 跳过"
fi

# ---- 4. Nginx ----
print_header "4. 配置 Nginx"

NGINX_CONF="$PROJECT_ROOT/nginx/matrix.conf"
# 替换模板中的占位符
sed -i '' "s|__PROJECT_ROOT__|${PROJECT_ROOT}|g" "$NGINX_CONF" 2>/dev/null || true

echo "  Nginx 配置文件: $NGINX_CONF"
echo "  请将此配置链接到 Nginx:"
echo ""
echo "  # macOS (Homebrew Nginx)"
echo "  sudo ln -sf $NGINX_CONF /opt/homebrew/etc/nginx/servers/matrix.conf"
echo "  sudo nginx -s reload"
echo ""
echo "  或直接使用 Conduwuit + Element dev server"

# ============================================
print_header "服务状态"
echo ""

echo "运行中的服务:"
for pid_file in "$PID_DIR"/*.pid; do
    if [ -f "$pid_file" ]; then
        name=$(basename "$pid_file" .pid)
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  ${GREEN}●${NC} $name (PID: $pid)"
        else
            echo -e "  ${RED}●${NC} $name (已停止)"
        fi
    fi
done

echo ""
print_header "访问地址"
echo ""
echo "  Conduwuit API:  http://localhost:${CONDUWUIT_PORT}"
echo "  Element Web:    http://localhost:${ELEMENT_PORT}"
echo "  (需要启动 Nginx 或用 Element 的 dev server)"
echo ""
echo "  查看日志: tail -f logs/<服务名>.log"
echo "  停止服务: bash scripts/stop-all.sh"
