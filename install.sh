#!/bin/bash
# 一键安装脚本
# curl -fsSL https://raw.githubusercontent.com/liubiao/devcontainers/main/install.sh | bash

set -e

REPO_URL="${DEVCONTAINERS_REPO:-https://github.com/ourines/devcontainers.git}"
INSTALL_DIR="${HOME}/.devcontainers"

echo "🚀 安装 devcontainers 配置..."

# 如果目录存在，更新；否则克隆
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "📦 更新现有配置..."
  git -C "$INSTALL_DIR" pull --rebase
else
  echo "📦 克隆配置仓库..."
  rm -rf "$INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# 设置可执行权限
chmod +x "$INSTALL_DIR/devcontainer-init.sh"
chmod +x "$INSTALL_DIR/scripts/"*.sh

# 添加 alias 到 shell 配置
SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ]; then
  if ! grep -q "devcontainer-init" "$SHELL_RC"; then
    echo "" >> "$SHELL_RC"
    echo "# Devcontainers" >> "$SHELL_RC"
    echo "alias devcontainer-init=\"~/.devcontainers/devcontainer-init.sh\"" >> "$SHELL_RC"
    echo "alias dc-sync=\"~/.devcontainers/scripts/sync-all.sh\"" >> "$SHELL_RC"
    echo "✅ 已添加 alias 到 $SHELL_RC"
  fi
fi

echo ""
echo "✅ 安装完成！"
echo ""
echo "📋 可用命令："
echo "   devcontainer-init node        # 初始化 Node.js 项目"
echo "   devcontainer-init with-db     # 自动检测 + PostgreSQL"
echo "   dc-sync push                  # 备份数据库+Claude配置到 R2"
echo "   dc-sync pull                  # 从 R2 恢复"
echo "   dc-sync push --db             # 只备份数据库"
echo "   dc-sync list                  # 列出 R2 上的备份"
echo ""
echo "🔧 配置环境变量（~/.bashrc 或 ~/.zshrc）："
echo "   export ANTHROPIC_API_KEY='sk-ant-xxx'"
echo "   export R2_ENDPOINT='https://xxx.r2.cloudflarestorage.com'"
echo "   export R2_ACCESS_KEY_ID='xxx'"
echo "   export R2_SECRET_ACCESS_KEY='xxx'"
echo ""
echo "💡 重新加载 shell: source $SHELL_RC"
