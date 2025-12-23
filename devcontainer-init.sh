#!/bin/bash
# devcontainer-init.sh - 初始化项目的 devcontainer 配置
# 用法: devcontainer-init.sh <language> [with-db]
#
# 示例:
#   devcontainer-init.sh node          # Node.js 项目
#   devcontainer-init.sh node with-db  # Node.js + PostgreSQL
#   devcontainer-init.sh go            # Go 项目
#   devcontainer-init.sh python        # Python 项目

set -e

TEMPLATES_DIR="${HOME}/.devcontainers/templates"
SCRIPTS_DIR="${HOME}/.devcontainers/scripts"

LANG="${1:-node}"
WITH_DB="${2}"

echo "🚀 初始化 devcontainer 配置..."
echo "   语言: $LANG"
echo "   数据库: ${WITH_DB:-none}"

# 创建目录
mkdir -p .devcontainer/scripts

# 复制同步脚本
cp "$SCRIPTS_DIR/sync-config.sh" .devcontainer/scripts/

# 使用 jq 合并 base + 语言模板
if ! command -v jq &> /dev/null; then
  echo "❌ 需要安装 jq: brew install jq"
  exit 1
fi

BASE="$TEMPLATES_DIR/base.json"
LANG_TEMPLATE="$TEMPLATES_DIR/${LANG}.json"

if [ ! -f "$LANG_TEMPLATE" ]; then
  echo "❌ 未找到语言模板: $LANG_TEMPLATE"
  echo "   可用模板: $(ls $TEMPLATES_DIR/*.json | xargs -n1 basename | sed 's/.json//' | tr '\n' ' ')"
  exit 1
fi

# 深度合并 JSON
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

# 如果需要数据库，创建 docker-compose
if [ "$WITH_DB" = "with-db" ]; then
  echo "📦 添加 PostgreSQL 配置..."

  # 修改 devcontainer.json 使用 docker-compose
  jq '. + {
    "dockerComposeFile": "docker-compose.yml",
    "service": "app",
    "workspaceFolder": "/workspace"
  } | del(.image)' .devcontainer/devcontainer.json > .devcontainer/devcontainer.json.tmp
  mv .devcontainer/devcontainer.json.tmp .devcontainer/devcontainer.json

  # 获取镜像名
  IMAGE=$(jq -r '.image // "mcr.microsoft.com/devcontainers/base:ubuntu"' "$LANG_TEMPLATE")

  cat > .devcontainer/docker-compose.yml << EOF
services:
  app:
    image: ${IMAGE}
    volumes:
      - ..:/workspace:cached
    command: sleep infinity
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/app
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
      POSTGRES_DB: app
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
fi

echo "✅ devcontainer 配置已生成"
echo ""
echo "📁 生成的文件:"
ls -la .devcontainer/
echo ""
echo "🎯 下一步:"
echo "   1. VS Code 打开项目"
echo "   2. Cmd+Shift+P -> 'Reopen in Container'"
echo ""
echo "🔧 环境变量（添加到 ~/.bashrc 或 ~/.zshrc）:"
echo "   export ANTHROPIC_API_KEY='your-key'"
echo "   export R2_ENDPOINT='https://xxx.r2.cloudflarestorage.com'"
echo "   export R2_ACCESS_KEY_ID='xxx'"
echo "   export R2_SECRET_ACCESS_KEY='xxx'"
