#!/bin/bash
# db-sync.sh - 数据库备份与同步到 R2
# 用法: db-sync.sh [push|pull|backup|restore]

set -e

BACKUP_DIR="${BACKUP_DIR:-.devcontainer/init-db}"
BACKUP_FILE="backup.sql.gz"
DB_NAME="${POSTGRES_DB:-github_org_manager}"
DB_HOST="${DB_HOST:-db}"
DB_USER="${POSTGRES_USER:-postgres}"
BUCKET="${R2_BUCKET:-devcontainer-sync}"
SYNC_PREFIX="db-backup"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}$1${NC}"; }
warn() { echo -e "${YELLOW}$1${NC}"; }

# 检查 R2 环境变量
check_r2_env() {
  if [ -z "$R2_ENDPOINT" ] || [ -z "$R2_ACCESS_KEY_ID" ] || [ -z "$R2_SECRET_ACCESS_KEY" ]; then
    return 1
  fi
  return 0
}

# 安装 rclone（如果需要）
install_rclone() {
  if ! command -v rclone &> /dev/null; then
    log "📦 Installing rclone..."
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

# 等待数据库就绪
wait_for_db() {
  log "⏳ Waiting for database..."
  local max_attempts=30
  local attempt=0

  while [ $attempt -lt $max_attempts ]; do
    if pg_isready -h "$DB_HOST" -U "$DB_USER" -q 2>/dev/null; then
      log "✅ Database ready"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  warn "⚠️  Database not ready after ${max_attempts}s"
  return 1
}

# 本地备份
backup() {
  log "💾 Backing up database..."
  mkdir -p "$BACKUP_DIR"

  wait_for_db || return 1

  PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" pg_dump \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    --clean \
    --if-exists \
    | gzip > "$BACKUP_DIR/$BACKUP_FILE"

  local size=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
  log "✅ Backup complete: $BACKUP_DIR/$BACKUP_FILE ($size)"
}

# 本地恢复
restore() {
  local backup_path="$BACKUP_DIR/$BACKUP_FILE"

  if [ ! -f "$backup_path" ]; then
    warn "⚠️  No backup found: $backup_path"
    return 1
  fi

  log "📥 Restoring database from $backup_path..."
  wait_for_db || return 1

  gunzip -c "$backup_path" | PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" psql \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -q

  log "✅ Restore complete"
}

# 推送到 R2
push() {
  if ! check_r2_env; then
    warn "⚠️  R2 not configured, only local backup"
    backup
    return 0
  fi

  backup || return 1

  log "⬆️  Pushing to R2..."
  install_rclone
  configure_rclone

  rclone copy "$BACKUP_DIR/$BACKUP_FILE" "r2:${BUCKET}/${SYNC_PREFIX}/" --progress

  log "✅ Pushed to R2: ${BUCKET}/${SYNC_PREFIX}/$BACKUP_FILE"
}

# 从 R2 拉取
pull() {
  if ! check_r2_env; then
    warn "⚠️  R2 not configured, trying local restore"
    restore
    return $?
  fi

  log "⬇️  Pulling from R2..."
  install_rclone
  configure_rclone

  mkdir -p "$BACKUP_DIR"

  if rclone copy "r2:${BUCKET}/${SYNC_PREFIX}/$BACKUP_FILE" "$BACKUP_DIR/" --progress 2>/dev/null; then
    log "✅ Downloaded from R2"
    restore
  else
    warn "⚠️  No backup found on R2"
    return 1
  fi
}

# 自动恢复（容器启动时调用）
auto_restore() {
  # 检查数据库是否为空
  wait_for_db || return 1

  local table_count=$(PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" psql \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')

  if [ "$table_count" -gt 0 ]; then
    log "ℹ️  Database has $table_count tables, skipping auto-restore"
    return 0
  fi

  log "📦 Empty database detected, attempting restore..."

  # 优先从 R2 恢复，失败则尝试本地
  if check_r2_env; then
    pull && return 0
  fi

  # 尝试本地恢复
  if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    restore && return 0
  fi

  warn "ℹ️  No backup available, starting fresh"
}

# 显示帮助
help() {
  cat << EOF
Database Sync Tool

Usage: db-sync.sh <command>

Commands:
  push      Backup and push to R2
  pull      Pull from R2 and restore
  backup    Local backup only
  restore   Restore from local backup
  auto      Auto-restore on container start

Environment:
  R2_ENDPOINT, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY  - R2 credentials
  R2_BUCKET (default: devcontainer-sync)              - R2 bucket name
  DB_HOST (default: db)                               - Database host
  POSTGRES_DB (default: github_org_manager)           - Database name
EOF
}

# 主逻辑
case "${1:-help}" in
  push)    push ;;
  pull)    pull ;;
  backup)  backup ;;
  restore) restore ;;
  auto)    auto_restore ;;
  *)       help ;;
esac
