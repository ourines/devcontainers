#!/bin/bash
# 快速配置环境变量
# 用法: ~/.devcontainers/scripts/setup-env.sh
# 或:   curl -fsSL https://raw.githubusercontent.com/ourines/devcontainers/main/scripts/setup-env.sh | bash

set -e

# 检测 shell 配置文件
SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_RC="$HOME/.bashrc"
else
  echo "❌ 未找到 .zshrc 或 .bashrc"
  exit 1
fi

echo "🔧 配置环境变量..."
echo "   配置文件: $SHELL_RC"
echo ""

# 显示当前配置状态
echo "当前配置状态:"
grep -q "ANTHROPIC_API_KEY" "$SHELL_RC" 2>/dev/null && echo "   ✅ ANTHROPIC_API_KEY 已配置" || echo "   ❌ ANTHROPIC_API_KEY 未配置"
grep -q "OPENAI_API_KEY" "$SHELL_RC" 2>/dev/null && echo "   ✅ OPENAI_API_KEY 已配置" || echo "   ❌ OPENAI_API_KEY 未配置"
grep -q "R2_ENDPOINT" "$SHELL_RC" 2>/dev/null && echo "   ✅ R2 已配置" || echo "   ❌ R2 未配置"
echo ""

read -p "是否重新配置? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "取消配置"
  exit 0
fi

echo ""
echo "请输入以下环境变量（直接回车跳过，保留现有值）："
echo ""

# Claude/Anthropic
read -p "ANTHROPIC_API_KEY (Claude): " ANTHROPIC_KEY

# OpenAI
read -p "OPENAI_API_KEY (Codex): " OPENAI_KEY

# R2/S3
read -p "R2_ENDPOINT: " R2_ENDPOINT
read -p "R2_ACCESS_KEY_ID: " R2_ACCESS_KEY
read -p "R2_SECRET_ACCESS_KEY: " R2_SECRET_KEY

# 删除旧配置（如果存在）
sed -i.bak '/# API Keys (added by devcontainers)/,/^$/d' "$SHELL_RC" 2>/dev/null || true
sed -i.bak '/ANTHROPIC_API_KEY/d' "$SHELL_RC" 2>/dev/null || true
sed -i.bak '/OPENAI_API_KEY/d' "$SHELL_RC" 2>/dev/null || true
sed -i.bak '/R2_ENDPOINT/d' "$SHELL_RC" 2>/dev/null || true
sed -i.bak '/R2_ACCESS_KEY_ID/d' "$SHELL_RC" 2>/dev/null || true
sed -i.bak '/R2_SECRET_ACCESS_KEY/d' "$SHELL_RC" 2>/dev/null || true
rm -f "${SHELL_RC}.bak"

# 写入新配置
echo "" >> "$SHELL_RC"
echo "# API Keys (added by devcontainers)" >> "$SHELL_RC"

[ -n "$ANTHROPIC_KEY" ] && echo "export ANTHROPIC_API_KEY='$ANTHROPIC_KEY'" >> "$SHELL_RC"
[ -n "$OPENAI_KEY" ] && echo "export OPENAI_API_KEY='$OPENAI_KEY'" >> "$SHELL_RC"
[ -n "$R2_ENDPOINT" ] && echo "export R2_ENDPOINT='$R2_ENDPOINT'" >> "$SHELL_RC"
[ -n "$R2_ACCESS_KEY" ] && echo "export R2_ACCESS_KEY_ID='$R2_ACCESS_KEY'" >> "$SHELL_RC"
[ -n "$R2_SECRET_KEY" ] && echo "export R2_SECRET_ACCESS_KEY='$R2_SECRET_KEY'" >> "$SHELL_RC"

echo ""
echo "✅ 环境变量已保存到 $SHELL_RC"
echo ""
echo "💡 执行以下命令使配置生效:"
echo "   source $SHELL_RC"
