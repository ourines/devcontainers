#!/bin/bash
# 快速配置环境变量
# 用法: ~/.devcontainers/scripts/setup-env.sh
# 或:   setup-env (如果已设置 alias)

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
grep -q "ANTHROPIC_API_KEY" "$SHELL_RC" 2>/dev/null && echo "   ✅ ANTHROPIC_API_KEY" || echo "   ❌ ANTHROPIC_API_KEY"
grep -q "ANTHROPIC_BASE_URL" "$SHELL_RC" 2>/dev/null && echo "   ✅ ANTHROPIC_BASE_URL" || echo "   ❌ ANTHROPIC_BASE_URL"
grep -q "OPENAI_API_KEY" "$SHELL_RC" 2>/dev/null && echo "   ✅ OPENAI_API_KEY" || echo "   ❌ OPENAI_API_KEY"
grep -q "OPENAI_BASE_URL" "$SHELL_RC" 2>/dev/null && echo "   ✅ OPENAI_BASE_URL" || echo "   ❌ OPENAI_BASE_URL"
grep -q "R2_ENDPOINT" "$SHELL_RC" 2>/dev/null && echo "   ✅ R2" || echo "   ❌ R2"
echo ""

read -p "是否重新配置? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "取消配置"
  exit 0
fi

echo ""
echo "请输入以下环境变量（直接回车跳过）："
echo ""

# Claude/Anthropic
echo "── Claude Code ──"
read -p "ANTHROPIC_API_KEY: " ANTHROPIC_KEY
read -p "ANTHROPIC_BASE_URL (默认官方，自定义如 https://ai.example.com/api): " ANTHROPIC_BASE

# OpenAI/Codex
echo ""
echo "── OpenAI Codex ──"
read -p "OPENAI_API_KEY: " OPENAI_KEY
read -p "OPENAI_BASE_URL (默认官方，自定义如 https://api.example.com/v1): " OPENAI_BASE

# R2/S3
echo ""
echo "── R2/S3 存储 ──"
read -p "R2_ENDPOINT: " R2_ENDPOINT
read -p "R2_ACCESS_KEY_ID: " R2_ACCESS_KEY
read -p "R2_SECRET_ACCESS_KEY: " R2_SECRET_KEY

# 删除旧配置
remove_old_config() {
  local file=$1
  # macOS 和 Linux sed 兼容
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' '/# API Keys (added by devcontainers)/d' "$file" 2>/dev/null || true
    sed -i '' '/ANTHROPIC_API_KEY/d' "$file" 2>/dev/null || true
    sed -i '' '/ANTHROPIC_BASE_URL/d' "$file" 2>/dev/null || true
    sed -i '' '/ANTHROPIC_AUTH_TOKEN/d' "$file" 2>/dev/null || true
    sed -i '' '/OPENAI_API_KEY/d' "$file" 2>/dev/null || true
    sed -i '' '/OPENAI_BASE_URL/d' "$file" 2>/dev/null || true
    sed -i '' '/R2_ENDPOINT/d' "$file" 2>/dev/null || true
    sed -i '' '/R2_ACCESS_KEY_ID/d' "$file" 2>/dev/null || true
    sed -i '' '/R2_SECRET_ACCESS_KEY/d' "$file" 2>/dev/null || true
  else
    sed -i '/# API Keys (added by devcontainers)/d' "$file" 2>/dev/null || true
    sed -i '/ANTHROPIC_API_KEY/d' "$file" 2>/dev/null || true
    sed -i '/ANTHROPIC_BASE_URL/d' "$file" 2>/dev/null || true
    sed -i '/ANTHROPIC_AUTH_TOKEN/d' "$file" 2>/dev/null || true
    sed -i '/OPENAI_API_KEY/d' "$file" 2>/dev/null || true
    sed -i '/OPENAI_BASE_URL/d' "$file" 2>/dev/null || true
    sed -i '/R2_ENDPOINT/d' "$file" 2>/dev/null || true
    sed -i '/R2_ACCESS_KEY_ID/d' "$file" 2>/dev/null || true
    sed -i '/R2_SECRET_ACCESS_KEY/d' "$file" 2>/dev/null || true
  fi
}

remove_old_config "$SHELL_RC"

# 写入新配置
echo "" >> "$SHELL_RC"
echo "# API Keys (added by devcontainers)" >> "$SHELL_RC"

# Claude
[ -n "$ANTHROPIC_KEY" ] && echo "export ANTHROPIC_API_KEY='$ANTHROPIC_KEY'" >> "$SHELL_RC"
[ -n "$ANTHROPIC_BASE" ] && echo "export ANTHROPIC_BASE_URL='$ANTHROPIC_BASE'" >> "$SHELL_RC"

# OpenAI
[ -n "$OPENAI_KEY" ] && echo "export OPENAI_API_KEY='$OPENAI_KEY'" >> "$SHELL_RC"
[ -n "$OPENAI_BASE" ] && echo "export OPENAI_BASE_URL='$OPENAI_BASE'" >> "$SHELL_RC"

# R2
[ -n "$R2_ENDPOINT" ] && echo "export R2_ENDPOINT='$R2_ENDPOINT'" >> "$SHELL_RC"
[ -n "$R2_ACCESS_KEY" ] && echo "export R2_ACCESS_KEY_ID='$R2_ACCESS_KEY'" >> "$SHELL_RC"
[ -n "$R2_SECRET_KEY" ] && echo "export R2_SECRET_ACCESS_KEY='$R2_SECRET_KEY'" >> "$SHELL_RC"

echo ""
echo "✅ 环境变量已保存到 $SHELL_RC"
echo ""
echo "💡 执行以下命令使配置生效:"
echo "   source $SHELL_RC"
