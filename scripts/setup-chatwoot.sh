#!/bin/bash
# ============================================
# Chatwoot 源码编译开发环境搭建
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHATWOOT_DIR="$PROJECT_ROOT/source/chatwoot"

print_step() {
    echo ""
    echo -e "${BLUE}==== $1 ====${NC}"
}

# Step 1: 安装 Ruby 3.4.4
print_step "1. 安装 Ruby 3.4.4 (rbenv)"
export PATH="/opt/homebrew/bin:/opt/homebrew/opt/postgresql@16/bin:$PATH"
eval "$(rbenv init - bash)"

if rbenv versions 2>/dev/null | grep -q "3.4.4"; then
    echo -e "${GREEN}✓${NC} Ruby 3.4.4 已安装"
else
    echo "正在编译安装 Ruby 3.4.4（约 3-5 分钟）..."
    rbenv install 3.4.4
    echo -e "${GREEN}✓${NC} Ruby 3.4.4 安装完成"
fi

# Step 2: 设置项目 Ruby 版本
print_step "2. 配置项目 Ruby 版本"
cd "$CHATWOOT_DIR"
rbenv local 3.4.4
rbenv rehash
ruby --version
echo -e "${GREEN}✓${NC} Ruby 版本已设置"

# Step 3: 安装 Bundler
print_step "3. 安装 Bundler"
gem install bundler --no-document
echo -e "${GREEN}✓${NC} Bundler 安装完成"

# Step 4: 安装 Ruby 依赖
print_step "4. 安装 Ruby 依赖 (bundle install)"
bundle config set --local without 'production'
bundle install
echo -e "${GREEN}✓${NC} Ruby 依赖安装完成"

# Step 5: 安装 Node 依赖
print_step "5. 安装 Node 依赖 (pnpm)"
pnpm install
echo -e "${GREEN}✓${NC} Node 依赖安装完成"

# Step 6: 配置 .env
print_step "6. 配置环境变量"
if [ ! -f .env ]; then
    cp .env.example .env
    # 生成 SECRET_KEY_BASE
    SECRET=$(ruby -rsecurerandom -e "puts SecureRandom.hex(64)")
    sed -i '' "s/SECRET_KEY_BASE=replace_with_lengthy_secure_hex/SECRET_KEY_BASE=$SECRET/" .env
    # 配置 PostgreSQL 为本地开发
    sed -i '' 's/POSTGRES_HOST=postgres/POSTGRES_HOST=localhost/' .env
    sed -i '' 's/REDIS_URL=redis:\/\/redis:6379/REDIS_URL=redis:\/\/localhost:6379/' .env
    echo -e "${GREEN}✓${NC} .env 已生成"
else
    echo -e "${YELLOW}⚠${NC} .env 已存在，更新数据库连接..."
    sed -i '' 's/POSTGRES_HOST=postgres/POSTGRES_HOST=localhost/' .env
    sed -i '' 's/REDIS_URL=redis:\/\/redis:6379/REDIS_URL=redis:\/\/localhost:6379/' .env
fi

# Step 7: 确保 PostgreSQL 和 Redis 运行
print_step "7. 检查 PostgreSQL & Redis"
brew services start postgresql@16 2>/dev/null || true
brew services start redis 2>/dev/null || true
sleep 2
pg_isready && echo -e "${GREEN}✓${NC} PostgreSQL 运行中" || echo -e "${RED}✗${NC} PostgreSQL 未运行"
redis-cli ping > /dev/null 2>&1 && echo -e "${GREEN}✓${NC} Redis 运行中" || echo -e "${RED}✗${NC} Redis 未运行"

# Step 8: 创建数据库
print_step "8. 创建数据库 & 运行迁移"
createdb chatwoot_development 2>/dev/null || echo "数据库可能已存在"
bundle exec rails db:prepare
echo -e "${GREEN}✓${NC} 数据库就绪"

# Step 9: 编译前端
print_step "9. 编译前端资源"
pnpm exec vite build
echo -e "${GREEN}✓${NC} 前端编译完成"

# 完成提示
print_step "安装完成！"
echo ""
echo "启动开发服务器："
echo "  cd $CHATWOOT_DIR"
echo "  eval \"\$(rbenv init - zsh)\""
echo "  bin/dev"
echo ""
echo "或分别启动："
echo "  bundle exec rails s -p 3000    # Rails 后端"
echo "  pnpm exec vite dev             # Vite 前端"
echo "  bundle exec sidekiq            # 后台任务"
echo ""
echo "访问: http://localhost:3000"
