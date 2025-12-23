#!/bin/bash
# pkg-manager.sh - 容器内包管理器（持久化到 R2）
# 用法:
#   pkg install btop ss    # 安装并记录
#   pkg remove btop        # 卸载并移除记录
#   pkg list               # 列出已安装
#   pkg restore            # 从记录恢复所有包

set -e

PKG_LIST_FILE="$HOME/.installed-packages"
BUCKET="${R2_BUCKET:-devcontainer-sync}"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}$1${NC}"; }
warn() { echo -e "${YELLOW}$1${NC}"; }

# 检查 R2 配置
check_r2() {
  [ -n "$R2_ENDPOINT" ] && [ -n "$R2_ACCESS_KEY_ID" ] && [ -n "$R2_SECRET_ACCESS_KEY" ]
}

# 配置 rclone
setup_rclone() {
  if ! command -v rclone &> /dev/null; then
    log "📦 Installing rclone..."
    curl -fsSL https://rclone.org/install.sh | bash
  fi

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

# 同步包列表到 R2
sync_to_r2() {
  if check_r2; then
    setup_rclone
    rclone copy "$PKG_LIST_FILE" "r2:${BUCKET}/profile/" 2>/dev/null || true
  fi
}

# 从 R2 拉取包列表
pull_from_r2() {
  if check_r2; then
    setup_rclone
    rclone copy "r2:${BUCKET}/profile/.installed-packages" "$HOME/" 2>/dev/null || true
  fi
}

# 安装包
install_pkg() {
  local packages=("$@")

  if [ ${#packages[@]} -eq 0 ]; then
    echo "用法: pkg install <package1> [package2] ..."
    return 1
  fi

  log "📦 Installing: ${packages[*]}"

  # 检测包管理器并安装
  if command -v apt-get &> /dev/null; then
    apt-get update -qq
    apt-get install -y -qq "${packages[@]}"
  elif command -v apk &> /dev/null; then
    apk add --no-cache "${packages[@]}"
  elif command -v yum &> /dev/null; then
    yum install -y "${packages[@]}"
  else
    warn "Unknown package manager"
    return 1
  fi

  # 记录已安装的包
  touch "$PKG_LIST_FILE"
  for pkg in "${packages[@]}"; do
    if ! grep -q "^${pkg}$" "$PKG_LIST_FILE" 2>/dev/null; then
      echo "$pkg" >> "$PKG_LIST_FILE"
    fi
  done

  # 同步到 R2
  sync_to_r2

  log "✅ Installed and recorded: ${packages[*]}"
}

# 安装 npm 全局包
install_npm() {
  local packages=("$@")

  if [ ${#packages[@]} -eq 0 ]; then
    echo "用法: pkg npm <package1> [package2] ..."
    return 1
  fi

  log "📦 Installing npm packages: ${packages[*]}"
  npm install -g "${packages[@]}"

  # 记录
  touch "$PKG_LIST_FILE"
  for pkg in "${packages[@]}"; do
    local entry="npm:${pkg}"
    if ! grep -q "^${entry}$" "$PKG_LIST_FILE" 2>/dev/null; then
      echo "$entry" >> "$PKG_LIST_FILE"
    fi
  done

  sync_to_r2
  log "✅ Installed npm packages: ${packages[*]}"
}

# 卸载包
remove_pkg() {
  local packages=("$@")

  if [ ${#packages[@]} -eq 0 ]; then
    echo "用法: pkg remove <package1> [package2] ..."
    return 1
  fi

  log "🗑️ Removing: ${packages[*]}"

  if command -v apt-get &> /dev/null; then
    apt-get remove -y "${packages[@]}" 2>/dev/null || true
  fi

  # 从记录中移除
  for pkg in "${packages[@]}"; do
    sed -i "/^${pkg}$/d" "$PKG_LIST_FILE" 2>/dev/null || true
  done

  sync_to_r2
  log "✅ Removed: ${packages[*]}"
}

# 列出已安装包
list_pkg() {
  if [ -f "$PKG_LIST_FILE" ]; then
    log "📋 Installed packages:"
    cat "$PKG_LIST_FILE"
  else
    warn "No packages recorded"
  fi
}

# 恢复所有包
restore_pkg() {
  log "🔄 Restoring packages..."

  # 先从 R2 拉取最新列表
  pull_from_r2

  if [ ! -f "$PKG_LIST_FILE" ]; then
    warn "No package list found"
    return 0
  fi

  local apt_packages=()
  local npm_packages=()

  while IFS= read -r line; do
    if [[ "$line" == npm:* ]]; then
      npm_packages+=("${line#npm:}")
    else
      apt_packages+=("$line")
    fi
  done < "$PKG_LIST_FILE"

  # 安装 apt 包
  if [ ${#apt_packages[@]} -gt 0 ]; then
    log "📦 Installing apt packages: ${apt_packages[*]}"
    apt-get update -qq
    apt-get install -y -qq "${apt_packages[@]}" || warn "Some apt packages failed"
  fi

  # 安装 npm 包
  if [ ${#npm_packages[@]} -gt 0 ]; then
    log "📦 Installing npm packages: ${npm_packages[*]}"
    npm install -g "${npm_packages[@]}" || warn "Some npm packages failed"
  fi

  log "✅ Restore complete"
}

# 主逻辑
case "${1:-help}" in
  install|i)
    shift
    install_pkg "$@"
    ;;
  npm|n)
    shift
    install_npm "$@"
    ;;
  remove|rm)
    shift
    remove_pkg "$@"
    ;;
  list|ls)
    list_pkg
    ;;
  restore|r)
    restore_pkg
    ;;
  sync)
    sync_to_r2
    log "✅ Synced to R2"
    ;;
  *)
    echo "pkg - 容器包管理器（持久化到 R2）"
    echo ""
    echo "用法:"
    echo "  pkg install <packages...>  安装系统包"
    echo "  pkg npm <packages...>      安装 npm 全局包"
    echo "  pkg remove <packages...>   卸载包"
    echo "  pkg list                   列出已记录的包"
    echo "  pkg restore                恢复所有已记录的包"
    echo "  pkg sync                   同步列表到 R2"
    echo ""
    echo "示例:"
    echo "  pkg install btop htop      # 安装 btop 和 htop"
    echo "  pkg npm typescript         # 安装 typescript"
    echo "  pkg restore                # 容器重建后恢复所有包"
    ;;
esac
