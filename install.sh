#!/bin/bash
# 一键安装脚本
# curl -fsSL https://raw.githubusercontent.com/ourines/devcontainers/main/install.sh | bash

set -e

REPO_URL="${DEVCONTAINERS_REPO:-https://github.com/ourines/devcontainers.git}"
INSTALL_DIR="${HOME}/.devcontainers"

echo "🚀 安装 devcontainers 配置..."

# 检测是否在容器内
is_container() {
  [ -f /.dockerenv ] || grep -q 'docker\|lxc\|containerd' /proc/1/cgroup 2>/dev/null
}

# 检测系统类型
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

# 安装 tmux
install_tmux() {
  if command -v tmux &> /dev/null; then
    echo "✅ tmux 已安装: $(tmux -V)"
    return 0
  fi

  echo "📦 安装 tmux..."
  OS=$(detect_os)

  case "$OS" in
    ubuntu|debian)
      sudo apt-get update
      sudo apt-get install -y tmux
      ;;
    fedora|centos|rhel)
      sudo dnf install -y tmux
      ;;
    darwin)
      brew install tmux
      ;;
    *)
      echo "⚠️  请手动安装 tmux"
      return 1
      ;;
  esac

  echo "✅ tmux 安装完成"
}

# 检测并安装 Docker
install_docker() {
  if command -v docker &> /dev/null; then
    echo "✅ Docker 已安装: $(docker --version)"
    return 0
  fi

  echo "📦 检测到未安装 Docker，正在安装..."
  OS=$(detect_os)

  case "$OS" in
    ubuntu|debian)
      # 安装依赖
      sudo apt-get update
      sudo apt-get install -y ca-certificates curl gnupg

      # 添加 Docker GPG key
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg

      # 添加 Docker 仓库
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

      # 安装 Docker
      sudo apt-get update
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;
    fedora|centos|rhel)
      sudo dnf -y install dnf-plugins-core
      sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
      sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      sudo systemctl start docker
      sudo systemctl enable docker
      ;;
    *)
      echo "❌ 不支持的系统: $OS"
      echo "请手动安装 Docker: https://docs.docker.com/engine/install/"
      return 1
      ;;
  esac

  # 将当前用户加入 docker 组
  if [ -n "$SUDO_USER" ]; then
    sudo usermod -aG docker "$SUDO_USER"
  else
    sudo usermod -aG docker "$USER"
  fi

  echo "✅ Docker 安装完成"
  echo "⚠️  请重新登录以使 docker 组权限生效"
}

# 安装依赖（跳过容器内的 Docker 安装）
install_tmux

if is_container; then
  echo "📦 检测到容器环境，跳过 Docker 安装"
else
  install_docker
fi

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
    echo "alias setup-env=\"~/.devcontainers/scripts/setup-env.sh\"" >> "$SHELL_RC"
    echo "✅ 已添加 alias 到 $SHELL_RC"
  fi
fi

# 配置环境变量
setup_env() {
  echo ""
  echo "🔧 配置环境变量..."

  # 检查是否已配置
  local need_config=false
  grep -q "ANTHROPIC_API_KEY" "$SHELL_RC" 2>/dev/null || need_config=true

  if [ "$need_config" = false ]; then
    echo "✅ 环境变量已配置"
    read -p "是否重新配置? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      return 0
    fi
  fi

  echo ""
  echo "请输入以下环境变量（直接回车跳过）："
  echo ""

  # Claude/Anthropic
  echo "── Claude Code ──"
  read -p "ANTHROPIC_API_KEY: " ANTHROPIC_KEY
  read -p "ANTHROPIC_BASE_URL (直接回车使用官方): " ANTHROPIC_BASE

  # OpenAI/Codex
  echo ""
  echo "── OpenAI Codex ──"
  read -p "OPENAI_API_KEY: " OPENAI_KEY
  read -p "OPENAI_BASE_URL (直接回车使用官方): " OPENAI_BASE

  # R2/S3
  echo ""
  echo "── R2/S3 存储 ──"
  read -p "R2_ENDPOINT: " R2_ENDPOINT
  read -p "R2_ACCESS_KEY_ID: " R2_ACCESS_KEY
  read -p "R2_SECRET_ACCESS_KEY: " R2_SECRET_KEY

  # 写入配置
  echo "" >> "$SHELL_RC"
  echo "# API Keys (added by devcontainers)" >> "$SHELL_RC"

  [ -n "$ANTHROPIC_KEY" ] && echo "export ANTHROPIC_API_KEY='$ANTHROPIC_KEY'" >> "$SHELL_RC"
  [ -n "$ANTHROPIC_BASE" ] && echo "export ANTHROPIC_BASE_URL='$ANTHROPIC_BASE'" >> "$SHELL_RC"
  [ -n "$OPENAI_KEY" ] && echo "export OPENAI_API_KEY='$OPENAI_KEY'" >> "$SHELL_RC"
  [ -n "$OPENAI_BASE" ] && echo "export OPENAI_BASE_URL='$OPENAI_BASE'" >> "$SHELL_RC"
  [ -n "$R2_ENDPOINT" ] && echo "export R2_ENDPOINT='$R2_ENDPOINT'" >> "$SHELL_RC"
  [ -n "$R2_ACCESS_KEY" ] && echo "export R2_ACCESS_KEY_ID='$R2_ACCESS_KEY'" >> "$SHELL_RC"
  [ -n "$R2_SECRET_KEY" ] && echo "export R2_SECRET_ACCESS_KEY='$R2_SECRET_KEY'" >> "$SHELL_RC"

  echo "✅ 环境变量已保存到 $SHELL_RC"
}

# 询问是否配置环境变量
read -p "是否配置 API Keys? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  setup_env
fi

echo ""
echo "✅ 安装完成！"
echo ""
echo "📋 使用方法："
echo "   cd your-project"
echo "   devcontainer-init             # 自动检测语言"
echo "   devcontainer-init with-db     # 自动检测 + PostgreSQL"
echo ""
echo "   setup-env                     # 重新配置 API Keys"
echo ""
echo "💡 重新加载 shell: source $SHELL_RC"
