#!/bin/bash
# devcontainer-init.sh - 初始化项目的 devcontainer 配置
#
# 用法:
#   devcontainer-init.sh [language] [options]
#
# 语言自动检测（按优先级）:
#   - package.json → node
#   - go.mod → go
#   - pyproject.toml/requirements.txt → python
#   - Cargo.toml → rust
#
# 选项:
#   with-db      添加 PostgreSQL
#   --no-commit  不提交到 git
#
# 示例:
#   devcontainer-init.sh              # 自动检测语言
#   devcontainer-init.sh node         # 强制 Node.js
#   devcontainer-init.sh with-db      # 自动检测 + PostgreSQL
#   devcontainer-init.sh node with-db # Node.js + PostgreSQL

set -e

TEMPLATES_DIR="${HOME}/.devcontainers/templates"
SCRIPTS_DIR="${HOME}/.devcontainers/scripts"

# 解析参数
LANG=""
WITH_DB=""
NO_COMMIT=""

for arg in "$@"; do
  case $arg in
    with-db)
      WITH_DB="with-db"
      ;;
    --no-commit)
      NO_COMMIT="true"
      ;;
    node|go|python|rust)
      LANG="$arg"
      ;;
  esac
done

# 自动检测语言
detect_language() {
  if [ -f "package.json" ]; then
    echo "node"
  elif [ -f "go.mod" ]; then
    echo "go"
  elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
    echo "python"
  elif [ -f "Cargo.toml" ]; then
    echo "rust"
  else
    echo "node"  # 默认
  fi
}

if [ -z "$LANG" ]; then
  LANG=$(detect_language)
  echo "🔍 自动检测语言: $LANG"
fi

echo "🚀 初始化 devcontainer 配置..."
echo "   语言: $LANG"
echo "   数据库: ${WITH_DB:-none}"

# 检查是否已存在配置
if [ -d ".devcontainer" ]; then
  echo ""
  echo "⚠️  发现已有 .devcontainer/ 配置"
  read -p "   覆盖现有配置? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "   取消操作"
    exit 0
  fi
  echo "   将覆盖现有配置..."
fi

# 检查 jq
if ! command -v jq &> /dev/null; then
  echo "❌ 需要安装 jq"
  echo "   macOS: brew install jq"
  echo "   Ubuntu: apt install jq"
  exit 1
fi

# 检查模板
BASE="$TEMPLATES_DIR/base.json"
LANG_TEMPLATE="$TEMPLATES_DIR/${LANG}.json"

if [ ! -f "$LANG_TEMPLATE" ]; then
  echo "❌ 未找到语言模板: $LANG"
  echo "   可用: $(ls $TEMPLATES_DIR/*.json 2>/dev/null | xargs -n1 basename | sed 's/.json//' | tr '\n' ' ')"
  exit 1
fi

# 创建目录
mkdir -p .devcontainer/scripts

# 复制脚本
cp "$SCRIPTS_DIR/sync-config.sh" .devcontainer/scripts/

# 复制语言专属的 post-create 脚本
if [ -f "$SCRIPTS_DIR/post-create-${LANG}.sh" ]; then
  cp "$SCRIPTS_DIR/post-create-${LANG}.sh" .devcontainer/scripts/post-create.sh
else
  # 创建通用的 post-create 脚本
  cat > .devcontainer/scripts/post-create.sh << 'SCRIPT'
#!/bin/bash
set -e
echo "🚀 Post-create setup..."
npm install -g @anthropic-ai/claude-code
git config --global init.defaultBranch main
echo "alias cc='claude'" >> ~/.zshrc
echo "✅ Setup complete!"
SCRIPT
fi

chmod +x .devcontainer/scripts/*.sh

# 深度合并 base + 语言模板
jq -s '
  def deepmerge:
    reduce .[] as $item ({};
      . * $item |
      if .features then .features = ([.features] | add) else . end |
      if .customizations.vscode.extensions then
        .customizations.vscode.extensions = ([.customizations.vscode.extensions] | add | unique)
      else . end |
      if .customizations.vscode.settings then
        .customizations.vscode.settings = ([.customizations.vscode.settings] | add)
      else . end |
      if .mounts then .mounts = ([.mounts] | add | unique) else . end |
      if .remoteEnv then .remoteEnv = ([.remoteEnv] | add) else . end
    );
  [.[0], .[1]] | deepmerge
' "$BASE" "$LANG_TEMPLATE" > .devcontainer/devcontainer.json

# 获取项目名（用于数据库名）
PROJECT_NAME=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr '-' '_')

# 如果需要数据库
if [ "$WITH_DB" = "with-db" ]; then
  echo "📦 添加 PostgreSQL 配置..."

  IMAGE=$(jq -r '.image // "mcr.microsoft.com/devcontainers/base:ubuntu"' "$LANG_TEMPLATE")

  jq --arg name "$PROJECT_NAME" '. + {
    "dockerComposeFile": "docker-compose.yml",
    "service": "app",
    "workspaceFolder": "/workspace"
  } | del(.image)' .devcontainer/devcontainer.json > .devcontainer/devcontainer.json.tmp
  mv .devcontainer/devcontainer.json.tmp .devcontainer/devcontainer.json

  cat > .devcontainer/docker-compose.yml << EOF
services:
  app:
    image: ${IMAGE}
    volumes:
      - ..:/workspace:cached
    command: sleep infinity
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/${PROJECT_NAME}
    depends_on:
      - db
    networks:
      - devnet

  db:
    image: postgres:16-alpine
    restart: unless-stopped
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./init-db:/docker-entrypoint-initdb.d
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: ${PROJECT_NAME}
    ports:
      - "5432:5432"
    networks:
      - devnet

volumes:
  postgres-data:

networks:
  devnet:
EOF

  mkdir -p .devcontainer/init-db
  touch .devcontainer/init-db/.gitkeep
fi

# 创建 .gitignore
cat > .devcontainer/.gitignore << 'EOF'
# 本地数据库备份
init-db/*.sql
init-db/*.dump
!init-db/.gitkeep

# 临时文件
*.tmp
*.log
EOF

echo ""
echo "✅ devcontainer 配置已生成"
echo ""
echo "📁 生成的文件:"
find .devcontainer -type f | sort
echo ""

# 自动 git add
if [ -z "$NO_COMMIT" ] && [ -d ".git" ]; then
  echo "📦 添加到 git..."
  git add .devcontainer/
  echo "   已添加 .devcontainer/ 到暂存区"
fi

echo ""
echo "🎯 下一步:"
echo "   1. 提交: git commit -m 'Add devcontainer config'"
echo "   2. VS Code: code . → Reopen in Container"
echo ""
echo "📋 容器启动后自动执行:"
echo "   • 安装依赖 (pnpm/npm/yarn)"
echo "   • 安装 Claude Code CLI"
[ "$LANG" = "node" ] && echo "   • Playwright 浏览器 (如果项目使用)"
[ "$WITH_DB" = "with-db" ] && echo "   • 数据库迁移 (Drizzle/Prisma)"
