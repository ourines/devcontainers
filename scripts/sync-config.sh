#!/bin/bash
# sync-config.sh - 同步 Claude 配置到 R2
# 用法: sync-config.sh [pull|push]

set -e

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
BUCKET="${R2_BUCKET:-devcontainer-sync}"
SYNC_PREFIX="claude-config"

# 检查必要的环境变量
check_env() {
  if [ -z "$R2_ENDPOINT" ] || [ -z "$R2_ACCESS_KEY_ID" ] || [ -z "$R2_SECRET_ACCESS_KEY" ]; then
    echo "⚠️  R2 环境变量未配置，跳过同步"
    echo "   需要: R2_ENDPOINT, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY"
    exit 0
  fi
}

# 安装 rclone（如果需要）
install_rclone() {
  if ! command -v rclone &> /dev/null; then
    echo "📦 安装 rclone..."
    curl -fsSL https://rclone.org/install.sh | sudo bash
  fi
}

# 配置 rclone
configure_rclone() {
  mkdir -p ~/.config/rclone
  cat > ~/.config/rclone/rclone.conf << EOF
[r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY_ID}
secret_access_key = ${R2_SECRET_ACCESS_KEY}
endpoint = ${R2_ENDPOINT}
acl = private
EOF
}

# 从 R2 拉取配置
pull() {
  echo "⬇️  从 R2 拉取 Claude 配置..."

  # 确保目录存在
  mkdir -p "$CONFIG_DIR"

  # 同步（不删除本地多余文件）
  rclone copy "r2:${BUCKET}/${SYNC_PREFIX}/" "$CONFIG_DIR/" --progress 2>/dev/null || {
    echo "ℹ️  R2 上没有配置或拉取失败，使用本地配置"
  }

  echo "✅ 拉取完成"
}

# 推送配置到 R2
push() {
  echo "⬆️  推送 Claude 配置到 R2..."

  if [ ! -d "$CONFIG_DIR" ]; then
    echo "⚠️  配置目录不存在: $CONFIG_DIR"
    exit 1
  fi

  # 排除敏感文件和缓存
  rclone sync "$CONFIG_DIR/" "r2:${BUCKET}/${SYNC_PREFIX}/" \
    --exclude "*.log" \
    --exclude "cache/**" \
    --exclude "*.tmp" \
    --progress

  echo "✅ 推送完成"
}

# 主逻辑
main() {
  check_env
  install_rclone
  configure_rclone

  case "${1:-pull}" in
    pull)
      pull
      ;;
    push)
      push
      ;;
    *)
      echo "用法: $0 [pull|push]"
      exit 1
      ;;
  esac
}

main "$@"
