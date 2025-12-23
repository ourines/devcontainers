#!/bin/bash
# 一键安装脚本
# curl -fsSL https://raw.githubusercontent.com/ourines/devcontainers/main/install.sh | bash

set -e

REPO_URL="${DEVCONTAINERS_REPO:-https://github.com/ourines/devcontainers.git}"
INSTALL_DIR="${HOME}/.devcontainers"

echo "🚀 安装 devcontainers 配置..."

# 检测并安装 Docker
install_docker() {
  if command -v docker &> /dev/null; then
    echo "✅ Docker 已安装: $(docker --version)"
    return 0
  fi

  echo "📦 检测到未安装 Docker，正在安装..."

  # 检测系统类型
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
  else
    echo "❌ 无法检测操作系统"
    return 1
  fi

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

# 安装 Docker
install_docker

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
    echo "✅ 已添加 alias 到 $SHELL_RC"
  fi
fi

echo ""
echo "✅ 安装完成！"
echo ""
echo "📋 使用方法："
echo "   cd your-project"
echo "   devcontainer-init             # 自动检测语言"
echo "   devcontainer-init with-db     # 自动检测 + PostgreSQL"
echo "   devcontainer-init node        # 指定 Node.js"
echo "   devcontainer-init go          # 指定 Go"
echo "   devcontainer-init python      # 指定 Python"
echo ""
echo "🔧 环境变量（~/.bashrc 或 ~/.zshrc）："
echo "   export ANTHROPIC_API_KEY='sk-ant-xxx'  # Claude Code"
echo ""
echo "💡 重新加载 shell: source $SHELL_RC"
