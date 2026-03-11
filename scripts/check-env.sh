#!/bin/bash
# ============================================
# Matrix 全栈环境检查脚本 (Conduwuit + Bridges)
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_ok() { echo -e "  ${GREEN}✓${NC} $1"; }
print_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
print_fail() { echo -e "  ${RED}✗${NC} $1"; }

check_command() {
    if command -v "$1" &> /dev/null; then
        local version=$($1 --version 2>&1 | head -1)
        print_ok "$1 已安装: $version"
        return 0
    else
        print_fail "$1 未安装"
        return 1
    fi
}

print_header "Matrix 全栈环境检查 (Conduwuit Edition)"
echo "项目目录: $PROJECT_ROOT"
echo "操作系统: $(uname -s) $(uname -m)"

MISSING=()

# ---- Homebrew ----
print_header "1. 包管理器"
if ! check_command brew; then
    MISSING+=("brew")
fi

# ---- Rust ----
print_header "2. Rust 工具链 (Conduwuit 构建需要)"
if check_command rustc; then
    RUST_VERSION=$(rustc --version | awk '{print $2}')
    print_ok "Rust 版本: $RUST_VERSION"
else
    MISSING+=("rust")
    echo "  安装: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
fi
check_command cargo || MISSING+=("cargo")

# ---- Python ----
print_header "3. Python (mautrix-telegram 需要)"
if check_command python3; then
    PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    PY_MAJOR=$(echo $PY_VERSION | cut -d. -f1)
    PY_MINOR=$(echo $PY_VERSION | cut -d. -f2)
    if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 11 ]; then
        print_ok "Python $PY_VERSION >= 3.11 ✓"
    else
        print_warn "Python $PY_VERSION < 3.11, 建议升级"
        MISSING+=("python3.11+")
    fi
else
    MISSING+=("python3")
fi

# ---- Go ----
print_header "4. Go (mautrix Go bridges 需要)"
if check_command go; then
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    GO_MINOR=$(echo $GO_VERSION | cut -d. -f2)
    if [ "$GO_MINOR" -ge 21 ]; then
        print_ok "Go $GO_VERSION >= 1.21 ✓"
    else
        print_warn "Go $GO_VERSION < 1.21, 建议升级"
        MISSING+=("go1.21+")
    fi
else
    MISSING+=("go")
fi

# ---- Node.js ----
print_header "5. Node.js (Element Web 构建需要)"
if check_command node; then
    NODE_VERSION=$(node -v | sed 's/v//')
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d. -f1)
    if [ "$NODE_MAJOR" -ge 18 ]; then
        print_ok "Node.js $NODE_VERSION >= 18 ✓"
    else
        print_warn "Node.js $NODE_VERSION < 18, 建议升级"
        MISSING+=("node18+")
    fi
else
    MISSING+=("node")
fi
check_command yarn || MISSING+=("yarn")

# ---- Nginx ----
print_header "6. Nginx"
check_command nginx || MISSING+=("nginx")

# ---- Git ----
print_header "7. Git"
check_command git || MISSING+=("git")

# ---- libolm ----
print_header "8. libolm (端对端加密)"
if pkg-config --exists olm 2>/dev/null || [ -f /opt/homebrew/lib/libolm.dylib ] || [ -f /usr/local/lib/libolm.dylib ]; then
    print_ok "libolm 已安装"
else
    print_warn "libolm 未安装"
    MISSING+=("libolm")
fi

# ---- ffmpeg ----
print_header "9. ffmpeg (可选)"
check_command ffmpeg || print_warn "可选依赖, 跳过"

# ---- 结果 ----
print_header "检查结果"

if [ ${#MISSING[@]} -eq 0 ]; then
    echo -e "\n${GREEN}  所有依赖已满足！可以开始构建。${NC}"
    echo "  下一步: bash scripts/clone-sources.sh"
else
    echo -e "\n${YELLOW}  缺少以下依赖:${NC}"
    for dep in "${MISSING[@]}"; do
        echo -e "    ${RED}•${NC} $dep"
    done
    echo ""
    echo -e "${BLUE}  一键安装 (macOS):${NC}"
    echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo "  brew install python@3.12 go node yarn nginx libolm ffmpeg"
    echo ""
    echo "  安装完成后重新运行: bash scripts/check-env.sh"
fi
