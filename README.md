# Devcontainers 配置模板

个人专属的 devcontainer 配置模板，支持一键初始化各种语言项目。

## 一键安装

```bash
# 从 GitHub 安装（需要先创建仓库）
curl -fsSL https://raw.githubusercontent.com/liubiao/devcontainers/main/install.sh | bash

# 或者从本地安装
git clone git@github.com:liubiao/devcontainers.git ~/.devcontainers
chmod +x ~/.devcontainers/*.sh ~/.devcontainers/scripts/*.sh
```

## 使用方法

```bash
# 初始化项目
cd your-project
devcontainer-init node          # Node.js 项目
devcontainer-init node with-db  # Node.js + PostgreSQL
devcontainer-init go            # Go 项目
devcontainer-init python        # Python 项目

# 同步 Claude 配置
dc-sync push   # 推送到 R2
dc-sync pull   # 从 R2 拉取
```

## 支持的语言模板

| 模板 | 镜像 | 特性 |
|------|------|------|
| node | typescript-node:22 | pnpm, Biome, Playwright |
| go | go:1.22 | golangci-lint |
| python | python:3.12 | Black, Ruff |

## 环境变量

```bash
# ~/.bashrc 或 ~/.zshrc
export ANTHROPIC_API_KEY="sk-ant-xxx"
export R2_ENDPOINT="https://xxx.r2.cloudflarestorage.com"
export R2_ACCESS_KEY_ID="xxx"
export R2_SECRET_ACCESS_KEY="xxx"
export R2_BUCKET="devcontainer-sync"  # 可选
```

## 目录结构

```
~/.devcontainers/
├── templates/
│   ├── base.json      # 通用配置（Git, Zsh, Claude, R2 同步）
│   ├── node.json      # Node.js
│   ├── go.json        # Go
│   └── python.json    # Python
├── scripts/
│   └── sync-config.sh # R2 配置同步脚本
├── devcontainer-init.sh  # 初始化工具
└── install.sh            # 一键安装脚本
```
