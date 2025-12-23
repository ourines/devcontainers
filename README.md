# Devcontainers 配置模板

个人专属的 devcontainer 配置模板，支持一键初始化各种语言项目。

## 一键安装（新设备）

```bash
curl -fsSL https://raw.githubusercontent.com/ourines/devcontainers/main/install.sh | bash
source ~/.bashrc  # 或 source ~/.zshrc
```

## 完整工作流

### 场景 1：初始化新项目（首次配置）

```bash
# 1. 克隆项目
git clone git@github.com:yourname/moduleship.git
cd moduleship

# 2. 初始化 devcontainer（自动检测语言）
devcontainer-init              # 自动检测
devcontainer-init with-db      # 自动检测 + PostgreSQL
devcontainer-init node with-db # 强制 Node.js + PostgreSQL

# 3. 提交到仓库（其他设备克隆后直接能用）
git commit -m "Add devcontainer config"
git push

# 4. VS Code 打开
code .  # 会提示 "Reopen in Container"
```

### 场景 2：在新设备开发已配置项目

```bash
# 项目已包含 .devcontainer/，克隆后直接用
git clone git@github.com:yourname/moduleship.git
cd moduleship
code .  # VS Code 会自动检测并提示 "Reopen in Container"
```

### 场景 3：更新 devcontainer 模板

```bash
# 更新本地模板
git -C ~/.devcontainers pull

# 重新生成项目配置（覆盖现有）
cd your-project
devcontainer-init
```

## 语言自动检测

| 检测文件 | 语言 |
|---------|------|
| `package.json` | node |
| `go.mod` | go |
| `pyproject.toml` / `requirements.txt` | python |
| `Cargo.toml` | rust |

## 支持的模板

| 模板 | 镜像 | 特性 |
|------|------|------|
| node | typescript-node:22 | pnpm, Biome, Playwright |
| go | go:1.22 | golangci-lint |
| python | python:3.12 | Black, Ruff |

## 命令参考

```bash
# 初始化
devcontainer-init              # 自动检测语言
devcontainer-init node         # 强制 Node.js
devcontainer-init with-db      # 自动检测 + PostgreSQL
devcontainer-init node with-db # Node.js + PostgreSQL
devcontainer-init --no-commit  # 不自动 git add

# Claude 配置同步
dc-sync push   # 推送到 R2
dc-sync pull   # 从 R2 拉取

# 更新模板
git -C ~/.devcontainers pull
```

## 环境变量配置

在 `~/.bashrc` 或 `~/.zshrc` 中添加：

```bash
# Claude Code
export ANTHROPIC_API_KEY="sk-ant-xxx"

# R2 同步（可选）
export R2_ENDPOINT="https://xxx.r2.cloudflarestorage.com"
export R2_ACCESS_KEY_ID="xxx"
export R2_SECRET_ACCESS_KEY="xxx"
export R2_BUCKET="devcontainer-sync"
```

## 目录结构

```
~/.devcontainers/
├── templates/
│   ├── base.json      # 通用：Git, Zsh, Claude, Copilot
│   ├── node.json      # Node.js 22 + pnpm
│   ├── go.json        # Go 1.22
│   └── python.json    # Python 3.12
├── scripts/
│   └── sync-config.sh # R2 配置同步
├── devcontainer-init.sh
└── install.sh
```

## 项目生成的文件

```
your-project/
└── .devcontainer/
    ├── devcontainer.json    # 主配置
    ├── docker-compose.yml   # 有数据库时生成
    ├── scripts/
    │   └── sync-config.sh   # Claude 配置同步
    ├── init-db/             # 数据库初始化脚本
    └── .gitignore
```
