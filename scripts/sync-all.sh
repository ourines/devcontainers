#!/bin/bash
# sync-all.sh - 同步所有开发环境数据到 R2
# 用法: sync-all.sh [push|pull] [--db] [--claude] [--all]

set -e

# 配置
BUCKET="${R2_BUCKET:-devcontainer-sync}"
PROJECT_NAME=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr '-' '_')

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查环境变量
check_r2_env() {
  if [ -z "$R2_ENDPOINT" ] || [ -z "$R2_ACCESS_KEY_ID" ] || [ -z "$R2_SECRET_ACCESS_KEY" ]; then
    log_error "R2 环境变量未配置"
    echo "需要设置:"
    echo "  export R2_ENDPOINT='https://xxx.r2.cloudflarestorage.com'"
    echo "  export R2_ACCESS_KEY_ID='xxx'"
    echo "  export R2_SECRET_ACCESS_KEY='xxx'"
    exit 1
  fi
}

# 安装/配置 rclone
setup_rclone() {
  if ! command -v rclone &> /dev/null; then
    log_info "安装 rclone..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew install rclone
    else
      curl -fsSL https://rclone.org/install.sh | sudo bash
    fi
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

# 数据库备份
db_push() {
  log_info "备份数据库到 R2..."

  local db_url="${DATABASE_URL:-postgresql://postgres:postgres@localhost:5432/${PROJECT_NAME}}"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file="/tmp/db_${PROJECT_NAME}_${timestamp}.sql"

  # 解析 DATABASE_URL
  if [[ "$db_url" =~ postgresql://([^:]+):([^@]+)@([^:]+):([0-9]+)/(.+) ]]; then
    local user="${BASH_REMATCH[1]}"
    local pass="${BASH_REMATCH[2]}"
    local host="${BASH_REMATCH[3]}"
    local port="${BASH_REMATCH[4]}"
    local dbname="${BASH_REMATCH[5]}"

    PGPASSWORD="$pass" pg_dump -h "$host" -p "$port" -U "$user" -d "$dbname" \
      --no-owner --no-acl -f "$backup_file" 2>/dev/null || {
      log_error "数据库备份失败"
      return 1
    }
  else
    log_error "无法解析 DATABASE_URL"
    return 1
  fi

  # 压缩
  gzip -f "$backup_file"
  backup_file="${backup_file}.gz"

  # 上传到 R2
  rclone copy "$backup_file" "r2:${BUCKET}/databases/${PROJECT_NAME}/" --progress

  # 保留最新的也叫 latest
  rclone copyto "$backup_file" "r2:${BUCKET}/databases/${PROJECT_NAME}/latest.sql.gz"

  log_info "备份完成: databases/${PROJECT_NAME}/$(basename $backup_file)"
  rm -f "$backup_file"
}

db_pull() {
  log_info "从 R2 恢复数据库..."

  local db_url="${DATABASE_URL:-postgresql://postgres:postgres@localhost:5432/${PROJECT_NAME}}"
  local backup_file="/tmp/db_restore.sql.gz"

  # 下载最新备份
  rclone copy "r2:${BUCKET}/databases/${PROJECT_NAME}/latest.sql.gz" /tmp/ --progress 2>/dev/null || {
    log_warn "没有找到数据库备份"
    return 0
  }

  if [ ! -f "/tmp/latest.sql.gz" ]; then
    log_warn "没有找到数据库备份"
    return 0
  fi

  mv /tmp/latest.sql.gz "$backup_file"
  gunzip -f "$backup_file"
  backup_file="/tmp/db_restore.sql"

  # 解析 DATABASE_URL 并恢复
  if [[ "$db_url" =~ postgresql://([^:]+):([^@]+)@([^:]+):([0-9]+)/(.+) ]]; then
    local user="${BASH_REMATCH[1]}"
    local pass="${BASH_REMATCH[2]}"
    local host="${BASH_REMATCH[3]}"
    local port="${BASH_REMATCH[4]}"
    local dbname="${BASH_REMATCH[5]}"

    log_info "恢复到 $dbname@$host..."
    PGPASSWORD="$pass" psql -h "$host" -p "$port" -U "$user" -d "$dbname" \
      -f "$backup_file" 2>/dev/null || {
      log_error "数据库恢复失败"
      return 1
    }
  fi

  log_info "数据库恢复完成"
  rm -f "$backup_file"
}

# Claude 配置同步
claude_push() {
  log_info "同步 Claude 配置到 R2..."

  local claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

  if [ ! -d "$claude_dir" ]; then
    log_warn "Claude 配置目录不存在: $claude_dir"
    return 0
  fi

  rclone sync "$claude_dir/" "r2:${BUCKET}/claude-config/" \
    --exclude "*.log" \
    --exclude "cache/**" \
    --exclude "*.tmp" \
    --progress

  # 同步 claude.json
  if [ -f "$HOME/.claude.json" ]; then
    rclone copy "$HOME/.claude.json" "r2:${BUCKET}/claude-config/"
  fi

  log_info "Claude 配置同步完成"
}

claude_pull() {
  log_info "从 R2 拉取 Claude 配置..."

  local claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  mkdir -p "$claude_dir"

  rclone copy "r2:${BUCKET}/claude-config/" "$claude_dir/" \
    --exclude ".claude.json" \
    --progress 2>/dev/null || {
    log_warn "R2 上没有 Claude 配置"
    return 0
  }

  # 单独处理 claude.json
  rclone copy "r2:${BUCKET}/claude-config/.claude.json" "$HOME/" 2>/dev/null || true

  log_info "Claude 配置拉取完成"
}

# 列出备份
list_backups() {
  log_info "R2 上的备份:"
  echo ""
  echo "📦 数据库备份:"
  rclone ls "r2:${BUCKET}/databases/" 2>/dev/null || echo "  (空)"
  echo ""
  echo "⚙️ Claude 配置:"
  rclone ls "r2:${BUCKET}/claude-config/" 2>/dev/null | head -10 || echo "  (空)"
}

# 主逻辑
main() {
  local action="${1:-help}"
  shift || true

  local sync_db=""
  local sync_claude=""

  # 解析选项
  for arg in "$@"; do
    case $arg in
      --db) sync_db="true" ;;
      --claude) sync_claude="true" ;;
      --all) sync_db="true"; sync_claude="true" ;;
    esac
  done

  # 默认同步所有
  if [ -z "$sync_db" ] && [ -z "$sync_claude" ]; then
    sync_db="true"
    sync_claude="true"
  fi

  case $action in
    push)
      check_r2_env
      setup_rclone
      [ "$sync_db" = "true" ] && db_push
      [ "$sync_claude" = "true" ] && claude_push
      ;;
    pull)
      check_r2_env
      setup_rclone
      [ "$sync_claude" = "true" ] && claude_pull
      [ "$sync_db" = "true" ] && db_pull
      ;;
    list)
      check_r2_env
      setup_rclone
      list_backups
      ;;
    *)
      echo "用法: $0 [push|pull|list] [--db] [--claude] [--all]"
      echo ""
      echo "命令:"
      echo "  push    上传到 R2"
      echo "  pull    从 R2 下载"
      echo "  list    列出 R2 上的备份"
      echo ""
      echo "选项:"
      echo "  --db      只同步数据库"
      echo "  --claude  只同步 Claude 配置"
      echo "  --all     同步所有（默认）"
      echo ""
      echo "示例:"
      echo "  $0 push              # 备份所有到 R2"
      echo "  $0 pull --db         # 只恢复数据库"
      echo "  $0 push --claude     # 只备份 Claude 配置"
      ;;
  esac
}

main "$@"
