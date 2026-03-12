#!/bin/bash
# ============================================
# 克隆所有 Matrix 源码仓库
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$PROJECT_ROOT/source"

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

clone_repo() {
    local repo_url="$1"
    local target_dir="$2"
    local repo_name=$(basename "$target_dir")

    if [ -d "$target_dir/.git" ]; then
        echo -e "  ${YELLOW}⚠${NC} $repo_name 已存在, 拉取最新代码..."
        cd "$target_dir"
        git pull --ff-only 2>/dev/null || echo -e "  ${YELLOW}⚠${NC} pull 失败, 保持现有代码"
        cd "$PROJECT_ROOT"
    else
        echo -e "  ${GREEN}↓${NC} 克隆 $repo_name ..."
        git clone --depth 1 "$repo_url" "$target_dir"
    fi
}

print_header "克隆 Matrix 全栈源码"
echo "源码目录: $SOURCE_DIR"
echo ""

# ---- Conduwuit (Rust Homeserver) ----
print_header "1. Conduwuit - Rust Matrix Homeserver"
clone_repo "https://github.com/girlbossceo/conduwuit.git" "$SOURCE_DIR/conduwuit"

# ---- Element Web (客户端) ----
print_header "2. Element Web - Matrix 网页客户端"
clone_repo "https://github.com/element-hq/element-web.git" "$SOURCE_DIR/element-web"

# ---- mautrix-telegram (Python bridge) ----
print_header "3. mautrix-telegram - Telegram Bridge"
clone_repo "https://github.com/mautrix/telegram.git" "$SOURCE_DIR/mautrix-telegram"

# ---- mautrix-discord (Go bridge) ----
print_header "4. mautrix-discord - Discord Bridge"
clone_repo "https://github.com/mautrix/discord.git" "$SOURCE_DIR/mautrix-discord"

# ---- mautrix-whatsapp (Go bridge) ----
print_header "5. mautrix-whatsapp - WhatsApp Bridge"
clone_repo "https://github.com/mautrix/whatsapp.git" "$SOURCE_DIR/mautrix-whatsapp"

# ---- mautrix-slack (Go bridge) ----
print_header "6. mautrix-slack - Slack Bridge"
clone_repo "https://github.com/mautrix/slack.git" "$SOURCE_DIR/mautrix-slack"

# ---- mautrix-signal (Go bridge) ----
print_header "7. mautrix-signal - Signal Bridge"
clone_repo "https://github.com/mautrix/signal.git" "$SOURCE_DIR/mautrix-signal"

# ---- mautrix-gmessages (Go bridge) ----
print_header "8. mautrix-gmessages - Google Messages Bridge"
clone_repo "https://github.com/mautrix/gmessages.git" "$SOURCE_DIR/mautrix-gmessages"

# ---- Chatwoot (客服系统) ----
print_header "9. Chatwoot - 开源客服平台"
clone_repo "https://github.com/chatwoot/chatwoot.git" "$SOURCE_DIR/chatwoot"

# ---- 完成 ----
print_header "克隆完成"
echo ""
echo "已克隆的仓库:"
ls -1 "$SOURCE_DIR" | while read dir; do
    if [ -d "$SOURCE_DIR/$dir/.git" ]; then
        cd "$SOURCE_DIR/$dir"
        local_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        local_commit=$(git log --oneline -1 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}•${NC} $dir ($local_branch) - $local_commit"
    fi
done
echo ""
echo "下一步: bash scripts/build-all.sh"
