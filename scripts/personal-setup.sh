#!/bin/bash
# personal-setup.sh - 个人环境配置（会从 R2 同步）
# 放在 ~/.devcontainers/scripts/personal-setup.sh
# 用法: 在容器内运行 personal-setup.sh

set -e

echo "🔧 Personal setup starting..."

# 额外的 CLI 工具（按需添加）
EXTRA_TOOLS=(
  # "htop"
  # "ncdu"
  # "jq"
)

if [ ${#EXTRA_TOOLS[@]} -gt 0 ]; then
  echo "📦 Installing extra tools..."
  apt-get update -qq
  for tool in "${EXTRA_TOOLS[@]}"; do
    apt-get install -y -qq "$tool" 2>/dev/null || echo "   ⚠️ $tool install failed"
  done
fi

# 额外的 npm 全局包
EXTRA_NPM_PACKAGES=(
  # "typescript"
  # "ts-node"
)

if [ ${#EXTRA_NPM_PACKAGES[@]} -gt 0 ]; then
  echo "📦 Installing extra npm packages..."
  for pkg in "${EXTRA_NPM_PACKAGES[@]}"; do
    npm install -g "$pkg" 2>/dev/null || echo "   ⚠️ $pkg install failed"
  done
fi

# 个人 shell 配置
cat >> ~/.zshrc << 'EOF'

# === Personal Config ===
# 在这里添加个人配置

# 示例: 自定义 alias
# alias ll="ls -la"

# 示例: 自定义环境变量
# export EDITOR=vim
EOF

echo "✅ Personal setup complete!"
echo ""
echo "💡 编辑此文件添加个人配置:"
echo "   ~/.devcontainers/scripts/personal-setup.sh"
