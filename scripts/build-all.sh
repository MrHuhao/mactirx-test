#!/bin/bash
# ============================================
# 一键构建所有 Matrix 组件
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$PROJECT_ROOT/source"

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

FAILED=()
SUCCEEDED=()

# ============================================
# 1. 构建 Conduwuit
# ============================================
print_header "1/4 构建 Conduwuit (Rust Homeserver)"

if [ -d "$SOURCE_DIR/conduwuit" ]; then
    cd "$SOURCE_DIR/conduwuit"
    
    # 确保 cargo 使用系统 git CLI (避免认证问题)
    mkdir -p .cargo
    if [ ! -f .cargo/config.toml ] || ! grep -q 'git-fetch-with-cli' .cargo/config.toml 2>/dev/null; then
        echo -e '[net]\ngit-fetch-with-cli = true' > .cargo/config.toml
    fi
    
    echo "  编译中... (首次编译可能需要 5-15 分钟)"
    if cargo build --release 2>&1 | tail -5; then
        CONDUWUIT_BIN="$SOURCE_DIR/conduwuit/target/release/conduwuit"
        if [ -f "$CONDUWUIT_BIN" ]; then
            print_ok "Conduwuit 构建成功: $CONDUWUIT_BIN"
            SUCCEEDED+=("conduwuit")
        else
            # 二进制名可能不同，查找一下
            CONDUWUIT_BIN=$(find "$SOURCE_DIR/conduwuit/target/release" -maxdepth 1 -type f -perm +111 ! -name "*.d" ! -name "*.so" ! -name "*.dylib" | head -1)
            if [ -n "$CONDUWUIT_BIN" ]; then
                print_ok "Conduwuit 构建成功: $CONDUWUIT_BIN"
                SUCCEEDED+=("conduwuit")
            else
                print_fail "Conduwuit 构建失败: 找不到二进制文件"
                FAILED+=("conduwuit")
            fi
        fi
    else
        print_fail "Conduwuit 编译失败"
        FAILED+=("conduwuit")
    fi
else
    print_warn "Conduwuit 源码不存在, 跳过 (先运行 clone-sources.sh)"
    FAILED+=("conduwuit")
fi

# ============================================
# 2. 构建 Go Bridges
# ============================================
print_header "2/4 构建 Go Bridges"

# 设置 CGO 环境变量让 Go 找到 libolm (Homebrew)
if [ -d "/opt/homebrew/include" ]; then
    export CGO_CFLAGS="-I/opt/homebrew/include"
    export CGO_LDFLAGS="-L/opt/homebrew/lib"
elif [ -d "/usr/local/include" ]; then
    export CGO_CFLAGS="-I/usr/local/include"
    export CGO_LDFLAGS="-L/usr/local/lib"
fi

build_go_bridge() {
    local bridge_name="$1"
    local source_path="$SOURCE_DIR/mautrix-${bridge_name}"

    if [ -d "$source_path" ]; then
        echo -e "  构建 mautrix-${bridge_name}..."
        cd "$source_path"
        if go build -o "mautrix-${bridge_name}" ./cmd/mautrix-${bridge_name} 2>&1 || go build -o "mautrix-${bridge_name}" . 2>&1; then
            if [ -f "mautrix-${bridge_name}" ]; then
                print_ok "mautrix-${bridge_name} 构建成功"
                SUCCEEDED+=("mautrix-${bridge_name}")
            else
                # 尝试其他方式查找
                local bin=$(find . -maxdepth 1 -type f -perm +111 ! -name "*.go" ! -name "*.mod" ! -name "*.sum" | head -1)
                if [ -n "$bin" ]; then
                    print_ok "mautrix-${bridge_name} 构建成功: $bin"
                    SUCCEEDED+=("mautrix-${bridge_name}")
                else
                    print_fail "mautrix-${bridge_name} 构建失败"
                    FAILED+=("mautrix-${bridge_name}")
                fi
            fi
        else
            print_fail "mautrix-${bridge_name} 编译失败"
            FAILED+=("mautrix-${bridge_name}")
        fi
    else
        print_warn "mautrix-${bridge_name} 源码不存在, 跳过"
        FAILED+=("mautrix-${bridge_name}")
    fi
}

build_go_bridge "discord"
build_go_bridge "whatsapp"
build_go_bridge "slack"
build_go_bridge "signal"
build_go_bridge "gmessages"

# ============================================
# 3. 构建 mautrix-telegram (Python)
# ============================================
print_header "3/4 设置 mautrix-telegram (Python)"

TELEGRAM_DIR="$SOURCE_DIR/mautrix-telegram"
if [ -d "$TELEGRAM_DIR" ]; then
    cd "$TELEGRAM_DIR"

    # 创建虚拟环境
    if [ ! -d "venv" ]; then
        echo "  创建 Python 虚拟环境..."
        python3 -m venv venv
    fi

    echo "  安装依赖..."
    source venv/bin/activate
    pip install --upgrade pip 2>&1 | tail -1
    
    # 先安装 cmake (python-olm 需要)
    pip install cmake 2>&1 | tail -1
    
    if pip install -e ".[all]" 2>&1 | tail -5; then
        print_ok "mautrix-telegram 依赖安装成功"
        SUCCEEDED+=("mautrix-telegram")
    else
        # 尝试不带 [all]
        if pip install -e . 2>&1 | tail -5; then
            print_ok "mautrix-telegram 基础安装成功 (部分可选依赖未装)"
            SUCCEEDED+=("mautrix-telegram")
        else
            print_fail "mautrix-telegram 安装失败"
            FAILED+=("mautrix-telegram")
        fi
    fi
    deactivate
else
    print_warn "mautrix-telegram 源码不存在, 跳过"
    FAILED+=("mautrix-telegram")
fi

# ============================================
# 4. 构建 Element Web
# ============================================
print_header "4/4 构建 Element Web"

ELEMENT_DIR="$SOURCE_DIR/element-web"
if [ -d "$ELEMENT_DIR" ]; then
    cd "$ELEMENT_DIR"

    # Element Web 现在使用 pnpm，通过 corepack 管理
    echo "  启用 corepack & 安装依赖..."
    corepack enable 2>/dev/null || true
    
    # 检查 package.json 中的 packageManager 来决定用什么
    if grep -q '"pnpm@' package.json 2>/dev/null; then
        PKG_MGR="pnpm"
        # 确保 pnpm 可用
        corepack prepare pnpm@latest --activate 2>/dev/null || npm install -g pnpm 2>/dev/null || true
    elif grep -q '"yarn@' package.json 2>/dev/null; then
        PKG_MGR="yarn"
    else
        PKG_MGR="yarn"
    fi
    
    echo "  使用 $PKG_MGR 安装依赖..."
    if $PKG_MGR install 2>&1 | tail -5; then
        # 复制自定义配置
        cp "$PROJECT_ROOT/element-web/config.json" "$ELEMENT_DIR/config.json"

        echo "  构建中... (可能需要 2-5 分钟)"
        if $PKG_MGR run build 2>&1 | tail -5; then
            print_ok "Element Web 构建成功"
            SUCCEEDED+=("element-web")
        else
            print_warn "Element Web 构建失败, 尝试 dev 模式可用"
            FAILED+=("element-web")
        fi
    else
        print_fail "Element Web 依赖安装失败"
        FAILED+=("element-web")
    fi
else
    print_warn "Element Web 源码不存在, 跳过"
    FAILED+=("element-web")
fi

# ============================================
# 结果汇总
# ============================================
print_header "构建结果汇总"

echo ""
if [ ${#SUCCEEDED[@]} -gt 0 ]; then
    echo -e "${GREEN}  成功 (${#SUCCEEDED[@]}):${NC}"
    for s in "${SUCCEEDED[@]}"; do
        echo -e "    ${GREEN}✓${NC} $s"
    done
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}  失败 (${#FAILED[@]}):${NC}"
    for f in "${FAILED[@]}"; do
        echo -e "    ${RED}✗${NC} $f"
    done
fi

echo ""
if [ ${#FAILED[@]} -eq 0 ]; then
    echo -e "${GREEN}  全部构建成功！${NC}"
    echo "  下一步: bash scripts/generate-bridge-configs.sh"
    echo "  然后:   bash scripts/start-all.sh"
else
    echo -e "${YELLOW}  部分失败, 请检查日志并修复后重新运行${NC}"
fi

cd "$PROJECT_ROOT"
