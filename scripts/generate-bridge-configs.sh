#!/bin/bash
# ============================================
# 生成所有 Bridge 的配置文件
# 基于各 mautrix bridge 的默认配置模板修改
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_ROOT/.env"

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

# ============================================
# 通用: 生成 Go bridge 配置 (mautrix v2 格式)
# 适用于: discord, whatsapp, slack, signal, gmessages
# ============================================
generate_go_bridge_config() {
    local bridge_name="$1"
    local appservice_port="$2"
    local db_name="$3"
    local config_dir="$PROJECT_ROOT/bridges/mautrix-${bridge_name}"
    local data_dir="$PROJECT_ROOT/data/bridges/${bridge_name}"
    local config_file="$config_dir/config.yaml"

    mkdir -p "$config_dir" "$data_dir"

    cat > "$config_file" << YAML
# mautrix-${bridge_name} 配置文件
# 自动生成于 $(date +%Y-%m-%d)

# Homeserver 设置
homeserver:
    address: http://localhost:${CONDUWUIT_PORT}
    domain: ${MATRIX_SERVER_NAME}
    software: standard
    # 本地开发使用 http
    async_media: false

# Appservice 设置
appservice:
    address: http://localhost:${appservice_port}
    hostname: 127.0.0.1
    port: ${appservice_port}
    database:
        type: sqlite3-fk-wal
        uri: file:${data_dir}/${bridge_name}.db?_txlock=immediate
    id: ${bridge_name}
    bot:
        username: ${bridge_name}bot
        displayname: "${bridge_name^} Bridge Bot"
    as_token: $(openssl rand -hex 32)
    hs_token: $(openssl rand -hex 32)

# Bridge 设置
bridge:
    # 允许哪些用户使用 bridge
    permissions:
        "*": relay
        "${MATRIX_DOMAIN}": user
        "@admin:${MATRIX_DOMAIN}": admin

    # 消息处理设置
    message_handling_timeout:
        error_after: 5s
        deadline: 120s

    # 端到端加密
    encryption:
        allow: false
        default: false

# 日志设置
logging:
    min_level: debug
    writers:
        - type: stdout
          format: pretty-colored
YAML

    echo -e "  ${GREEN}✓${NC} mautrix-${bridge_name} 配置已生成: $config_file"
}

# ============================================
# mautrix-telegram (Python bridge, 配置格式不同)
# ============================================
generate_telegram_config() {
    local config_dir="$PROJECT_ROOT/bridges/mautrix-telegram"
    local data_dir="$PROJECT_ROOT/data/bridges/telegram"
    local config_file="$config_dir/config.yaml"

    mkdir -p "$config_dir" "$data_dir"

    cat > "$config_file" << YAML
# mautrix-telegram 配置文件
# 自动生成于 $(date +%Y-%m-%d)

# Homeserver 设置
homeserver:
    address: http://localhost:${CONDUWUIT_PORT}
    domain: ${MATRIX_SERVER_NAME}
    verify_ssl: false
    software: standard

# Appservice 设置
appservice:
    address: http://localhost:${TELEGRAM_APPSERVICE_PORT}
    hostname: 127.0.0.1
    port: ${TELEGRAM_APPSERVICE_PORT}
    database: sqlite:///${data_dir}/telegram.db
    id: telegram
    bot_username: telegrambot
    bot_displayname: Telegram Bridge Bot
    as_token: $(openssl rand -hex 32)
    hs_token: $(openssl rand -hex 32)

# Telegram API 设置
telegram:
    api_id: ${TELEGRAM_API_ID}
    api_hash: ${TELEGRAM_API_HASH}
    # device_info 可选
    device_model: mautrix-telegram
    system_version: local-dev
    app_version: source

# Bridge 设置
bridge:
    # 用户权限
    permissions:
        "*": relaybot
        "${MATRIX_DOMAIN}": full
        "@admin:${MATRIX_DOMAIN}": admin

    # 命令前缀
    command_prefix: "!tg"

    # relay 模式
    relay_user_distinguishers: []

    # 端到端加密
    encryption:
        allow: false
        default: false

# 日志设置
logging:
    version: 1
    formatters:
        colored:
            (): mautrix.util.logging.color.ColorFormatter
            format: "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s"
    handlers:
        console:
            class: logging.StreamHandler
            formatter: colored
    loggers:
        mau:
            level: DEBUG
        telethon:
            level: INFO
        aiohttp:
            level: INFO
    root:
        level: DEBUG
        handlers: [console]
YAML

    echo -e "  ${GREEN}✓${NC} mautrix-telegram 配置已生成: $config_file"
}

# ============================================
# 执行生成
# ============================================
print_header "生成 Bridge 配置文件"

echo "Homeserver: Conduwuit @ localhost:${CONDUWUIT_PORT}"
echo "数据库: SQLite (本地开发)"
echo ""

generate_telegram_config
generate_go_bridge_config "discord"   "$DISCORD_APPSERVICE_PORT"   "discord"
generate_go_bridge_config "whatsapp"  "$WHATSAPP_APPSERVICE_PORT"  "whatsapp"
generate_go_bridge_config "slack"     "$SLACK_APPSERVICE_PORT"     "slack"
generate_go_bridge_config "signal"    "$SIGNAL_APPSERVICE_PORT"    "signal"
generate_go_bridge_config "gmessages" "$GMESSAGES_APPSERVICE_PORT" "gmessages"

# ============================================
# 生成 Appservice 注册文件
# ============================================
print_header "生成 Appservice 注册文件"

generate_registration() {
    local bridge_name="$1"
    local config_file="$PROJECT_ROOT/bridges/mautrix-${bridge_name}/config.yaml"
    local reg_file="$PROJECT_ROOT/bridges/mautrix-${bridge_name}/registration.yaml"
    local source_dir="$PROJECT_ROOT/source/mautrix-${bridge_name}"

    # 如果源码已克隆并且已编译，可以用 bridge 二进制生成 registration
    # 这里先生成一个基础模板，后续 build 阶段会自动覆盖
    local as_token=$(grep 'as_token:' "$config_file" | awk '{print $2}')
    local hs_token=$(grep 'hs_token:' "$config_file" | awk '{print $2}')
    local appservice_id=$(grep '^    id:' "$config_file" | head -1 | awk '{print $2}')

    cat > "$reg_file" << YAML
id: ${appservice_id:-$bridge_name}
as_token: ${as_token}
hs_token: ${hs_token}
namespaces:
    users:
        - exclusive: true
          regex: "@${bridge_name}_.*:${MATRIX_SERVER_NAME}"
    aliases:
        - exclusive: true
          regex: "#${bridge_name}_.*:${MATRIX_SERVER_NAME}"
url: http://localhost:$(grep 'port:' "$config_file" | head -2 | tail -1 | awk '{print $2}')
sender_localpart: ${bridge_name}bot
rate_limited: false
YAML

    echo -e "  ${GREEN}✓${NC} ${bridge_name} registration.yaml 已生成"
}

generate_registration "telegram"
generate_registration "discord"
generate_registration "whatsapp"
generate_registration "slack"
generate_registration "signal"
generate_registration "gmessages"

print_header "配置生成完成"
echo ""
echo "Bridge 配置目录:"
ls -la "$PROJECT_ROOT/bridges/"
echo ""
echo "注意: 请根据需要编辑各 bridge 配置中的 API 密钥等信息"
echo "  - Telegram: bridges/mautrix-telegram/config.yaml (api_id, api_hash)"
echo "  - Discord:  bridges/mautrix-discord/config.yaml (额外: bot token)"
echo ""
echo "下一步: bash scripts/build-all.sh"
