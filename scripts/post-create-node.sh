#!/bin/bash
# Node.js post-create script - 智能检测，按需安装
set -e

echo "🚀 Post-create setup starting..."

# 0. 修复目录权限（从 Mac 挂载时 UID 不匹配）
echo "🔧 Fixing directory permissions..."
chown -R $(whoami):$(whoami) "$HOME/.claude" 2>/dev/null || true
chown -R $(whoami):$(whoami) /workspace 2>/dev/null || true

# 0.1 Git safe directory（避免 ownership 警告）
git config --global --add safe.directory /workspace 2>/dev/null || true

# 0.2 安装 btop（系统监控）
echo "📊 Installing btop..."
apt-get update -qq && apt-get install -y -qq btop 2>/dev/null || \
  echo "   ⚠️ btop install failed, skip"

# 1. 检测包管理器并安装依赖
echo "📦 Setting up package manager..."
if [ -f "pnpm-lock.yaml" ]; then
  corepack enable
  corepack prepare pnpm@latest --activate
  # 配置 pnpm store 到全局目录（避免污染项目目录）
  pnpm config set store-dir ~/.local/share/pnpm/store
  echo "   Using pnpm"
  PKG_MGR="pnpm"
  pnpm install
elif [ -f "yarn.lock" ]; then
  corepack enable
  echo "   Using yarn"
  PKG_MGR="yarn"
  yarn install
elif [ -f "package-lock.json" ]; then
  echo "   Using npm"
  PKG_MGR="npm"
  npm install
elif [ -f "package.json" ]; then
  # 默认用 pnpm
  corepack enable
  corepack prepare pnpm@latest --activate
  pnpm config set store-dir ~/.local/share/pnpm/store
  echo "   Using pnpm (default)"
  PKG_MGR="pnpm"
  pnpm install
fi

# 2. Install CLI tools
echo "🤖 Installing CLI tools..."
npm install -g @anthropic-ai/claude-code @openai/codex 2>/dev/null || \
  echo "   ⚠️ CLI tools install failed, run manually: npm install -g @anthropic-ai/claude-code @openai/codex"

# 3. Playwright - 仅当项目使用时安装
if grep -q '"playwright"' package.json 2>/dev/null || \
   grep -q '"@playwright/test"' package.json 2>/dev/null; then
  echo "🎭 Installing Playwright browsers..."
  $PKG_MGR exec playwright install --with-deps chromium 2>/dev/null || \
  npx playwright install --with-deps chromium 2>/dev/null || \
  echo "   ⚠️ Playwright install failed, run manually: npx playwright install"
else
  echo "🎭 Playwright not detected, skipping browser install"
fi

# 4. 数据库迁移 - 仅当使用 drizzle 且有 db 服务时
if [ -f "drizzle.config.ts" ] || [ -f "drizzle.config.js" ]; then
  echo "🗄️ Drizzle detected, checking database..."

  # 检查是否有 db 服务（docker-compose 环境）
  if getent hosts db >/dev/null 2>&1; then
    MAX_RETRIES=30
    RETRY_COUNT=0

    until pg_isready -h db -U postgres -q 2>/dev/null || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
      echo "   Waiting for database... ($RETRY_COUNT/$MAX_RETRIES)"
      sleep 1
      RETRY_COUNT=$((RETRY_COUNT + 1))
    done

    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
      echo "   Database ready, running migrations..."
      $PKG_MGR drizzle-kit push --force 2>/dev/null || \
      npx drizzle-kit push --force 2>/dev/null || \
      echo "   ⚠️ Migration failed, run manually: pnpm drizzle-kit push"
    else
      echo "   ⚠️ Database not ready after ${MAX_RETRIES}s"
    fi
  else
    echo "   No database service detected, skipping migration"
    echo "   💡 Set DATABASE_URL and run: pnpm drizzle-kit push"
  fi
else
  echo "🗄️ No Drizzle config found, skipping database setup"
fi

# 5. Prisma - 仅当项目使用时
if [ -f "prisma/schema.prisma" ]; then
  echo "🗄️ Prisma detected, generating client..."
  $PKG_MGR prisma generate 2>/dev/null || npx prisma generate 2>/dev/null || true

  if getent hosts db >/dev/null 2>&1; then
    echo "   Running Prisma migrations..."
    $PKG_MGR prisma migrate deploy 2>/dev/null || npx prisma migrate deploy 2>/dev/null || \
    echo "   ⚠️ Migration failed, run manually: pnpm prisma migrate deploy"
  fi
fi

# 6. Setup git config
echo "⚙️ Configuring git..."
git config --global init.defaultBranch main
git config --global core.editor "code --wait"

# 7. Create shell aliases (基于检测到的工具)
echo "📝 Setting up shell aliases..."
cat >> ~/.zshrc << EOF

# Package manager: $PKG_MGR
alias dev="$PKG_MGR dev"
alias build="$PKG_MGR build"
alias test="$PKG_MGR test"
alias lint="$PKG_MGR lint"
EOF

# 条件性添加 alias
if [ -f "drizzle.config.ts" ] || [ -f "drizzle.config.js" ]; then
  cat >> ~/.zshrc << EOF
alias db:push="$PKG_MGR drizzle-kit push"
alias db:studio="$PKG_MGR drizzle-kit studio"
EOF
fi

if [ -f "prisma/schema.prisma" ]; then
  cat >> ~/.zshrc << EOF
alias db:push="$PKG_MGR prisma db push"
alias db:studio="$PKG_MGR prisma studio"
EOF
fi

# 数据库同步 aliases
cat >> ~/.zshrc << 'EOF'

# Database sync (R2)
alias db:backup=".devcontainer/scripts/db-sync.sh backup"
alias db:restore=".devcontainer/scripts/db-sync.sh restore"
alias db:pull=".devcontainer/scripts/db-sync.sh pull"
alias db:sync=".devcontainer/scripts/db-sync.sh push"
EOF

cat >> ~/.zshrc << 'EOF'

# Git aliases
alias gs="git status"
alias gp="git pull"
alias gc="git commit"
alias gco="git checkout"

# Claude Code
alias cc="claude"
EOF

echo ""
echo "✅ Post-create setup complete!"
echo ""
echo "📋 Detected features:"
[ -n "$PKG_MGR" ] && echo "   • Package manager: $PKG_MGR"
grep -q '"playwright"' package.json 2>/dev/null && echo "   • Playwright: installed"
[ -f "drizzle.config.ts" ] && echo "   • Drizzle ORM: configured"
[ -f "prisma/schema.prisma" ] && echo "   • Prisma: configured"
echo ""
echo "🚀 Run 'dev' to start development server"
echo "📊 Run 'btop' for system monitoring"
