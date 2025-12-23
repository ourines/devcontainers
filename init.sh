#!/bin/bash
# 新项目一键初始化
# curl -fsSL https://raw.githubusercontent.com/ourines/devcontainers/main/init.sh | bash
# 或: curl -fsSL https://raw.githubusercontent.com/ourines/devcontainers/main/init.sh | bash -s -- with-db

set -e

# 1. 安装工具（如果没有）
if [ ! -d "$HOME/.devcontainers" ]; then
  git clone https://github.com/ourines/devcontainers.git ~/.devcontainers
  chmod +x ~/.devcontainers/*.sh ~/.devcontainers/scripts/*.sh
fi

# 2. 初始化当前项目
~/.devcontainers/devcontainer-init.sh "$@"
