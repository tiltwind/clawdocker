<!--
markmeta_author: tiltwind
markmeta_date: 2026-02-25
markmeta_title: OpenClaw 个人 AI Agent 助手快速搭建指南
markmeta_categories: ai
markmeta_tags: ai,openclaw,agent,node.js
-->

# OpenClaw 个人 AI Agent 助手快速搭建指南

OpenClaw 是一个开源的个人 AI 助手框架（MIT 许可证），运行在自有设备上，通过 WhatsApp、Telegram、Slack、Discord、Signal、Google Chat、Microsoft Teams 等消息渠道与用户交互。核心是一个基于 Node.js 的长期运行服务，连接 LLM（Anthropic、OpenAI、本地模型等）与本地机器和消息应用。

项目由 Peter Steinberger（PSPDFKit 创始人）创建，前身为 Clawdbot / Moltbot，官方仓库位于 `github.com/openclaw/openclaw`。

## 1. 架构

### 1.1 核心组件

OpenClaw 采用 **Gateway + Agent** 架构：

- **Gateway**：中央控制平面，基于 WebSocket（`ws://127.0.0.1:18789`），管理会话、渠道、工具和事件，是所有客户端的统一连接点
- **Agent Runtime（Pi Agent）**：RPC 模式运行，负责 LLM 调用、工具流式执行和任务编排
- **Workspace**：Agent 的工作主目录，存储身份定义、行为准则、记忆和技能

```
┌──────────────────────────────────────────────────────────────┐
│                      Channel Layer                            │
│  ┌─────────┐ ┌──────────┐ ┌───────┐ ┌───────┐ ┌──────────┐  │
│  │WhatsApp │ │ Telegram │ │ Slack │ │Discord│ │ Signal.. │  │
│  └────┬────┘ └────┬─────┘ └───┬───┘ └───┬───┘ └────┬─────┘  │
│       └───────────┴───────────┴─────────┴──────────┘         │
│                           │                                   │
├───────────────────────────▼───────────────────────────────────┤
│                   Gateway (WebSocket)                          │
│              ws://127.0.0.1:18789                              │
│   ┌────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│   │ 会话管理    │  │ 渠道路由      │  │ 设备配对 & 认证      │  │
│   └────────────┘  └──────────────┘  └──────────────────────┘  │
├───────────────────────────────────────────────────────────────┤
│                   Agent Runtime (Pi Agent)                     │
│   ┌────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│   │ LLM 调用   │  │ 工具执行      │  │ 记忆 & 上下文管理    │  │
│   │ (Provider) │  │ (Tools)      │  │ (Memory)            │  │
│   └────────────┘  └──────────────┘  └──────────────────────┘  │
├───────────────────────────────────────────────────────────────┤
│                     Workspace                                  │
│   AGENTS.md │ SOUL.md │ USER.md │ IDENTITY.md │ skills/       │
└───────────────────────────────────────────────────────────────┘
```

### 1.2 与 ZeroClaw 的对比

| 指标 | OpenClaw | ZeroClaw |
|------|----------|----------|
| 语言 | Node.js (TypeScript) | Rust |
| 二进制大小 | 数百 MB | ~8.8 MB |
| 运行内存 | 1+ GB | < 5 MB |
| 冷启动 | 500+ ms | < 10 ms |
| 最低 RAM | 2 GB（推荐 4 GB） | < 5 MB |
| 生态成熟度 | 高（社区活跃、文档完善） | 新兴 |
| Channel 支持 | 13+ 原生渠道 | 20+ 渠道 |
| 部署复杂度 | 中（npm/Docker） | 低（单二进制） |

OpenClaw 适合需要丰富生态和完善文档的场景；ZeroClaw 适合资源受限的边缘部署。

## 2. Debian 环境快速搭建

### 2.1 系统要求

| 项目 | 最低要求 | 推荐配置 |
|------|---------|---------|
| OS | Debian 11+ / Ubuntu 22.04+ | Debian 12 (Bookworm) |
| CPU | 1 vCPU | 2+ vCPU |
| RAM | 2 GB | 4 GB |
| 磁盘 | 10 GB | 20 GB |
| Node.js | 22+ | 22 LTS |
| 网络 | 端口 18789（Gateway） | - |

### 2.2 方式一：脚本安装（推荐）

```bash
# 安装依赖
sudo apt update && sudo apt install -y git curl

# 一键安装（自动检测 OS，安装 Node.js 22，运行 onboard）
curl -fsSL https://openclaw.ai/install.sh | bash
```

安装脚本会自动完成：
1. 检测操作系统并安装必要依赖
2. 安装 Node.js 22
3. 安装 OpenClaw CLI
4. 启动交互式引导（onboard）

### 2.3 方式二：手动安装

**STEP 1. 安装 Node.js 22**

```bash
# 使用 NodeSource 仓库
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt install -y nodejs

# 验证
node -v   # 应输出 v22.x.x
npm -v
```

**STEP 2. 安装 OpenClaw**

```bash
npm install -g openclaw@latest

# 验证
openclaw --version
```

**STEP 3. 运行引导向导**

```bash
openclaw onboard --install-daemon
```

引导向导会依次配置：
- **Gateway**：选择 Local Gateway，绑定 `127.0.0.1:18789`
- **AI Provider**：选择 LLM 提供商（OpenAI、Anthropic、DeepSeek 等），输入 API Key
- **Auth Token**：自动生成认证令牌
- **Daemon**：注册为 systemd 用户服务，开机自启

> `--install-daemon` 会将 OpenClaw 注册为 systemd user service，确保重启后自动运行。

**STEP 4. 验证安装**

```bash
# 检查配置和安全状态
openclaw doctor

# 查看 Gateway 状态
openclaw status

# 打开控制面板（会输出 token URL）
openclaw dashboard
```

### 2.4 方式三：Docker 部署（生产推荐）

Docker 部署提供更好的隔离性和安全性，推荐用于生产环境。

**STEP 1. 安装 Docker**

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
```

**STEP 2. 克隆仓库并启动**

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# 自动化安装（构建镜像 + onboard + 启动 compose）
./docker-setup.sh
```

`docker-setup.sh` 会完成：构建 Gateway 镜像、运行 onboard、生成 `.env`（含 Gateway Token）、启动 Docker Compose

**STEP 3. 常用操作**

```bash
# 查看运行状态
docker compose ps

# 查看日志
docker compose logs -f openclaw-gateway

# 添加消息渠道
docker compose run --rm openclaw-cli channels add

# 健康检查
docker compose exec openclaw-gateway node dist/index.js health --token "$OPENCLAW_GATEWAY_TOKEN"
```

**STEP 4. 更新 OpenClaw 版本**

```bash
cd openclaw

# 拉取最新代码
git pull

# 重新构建镜像并重启（保留数据卷）
./docker-setup.sh

# 或手动分步操作：
docker compose build --no-cache
docker compose up -d
```

> 数据卷（`OPENCLAW_HOME_VOLUME`）在重建容器时会保留，配置和会话记录不会丢失。

**环境变量配置**：

| 变量 | 说明 | 示例 |
|------|------|------|
| `OPENCLAW_DOCKER_APT_PACKAGES` | 构建时额外安装的系统包 | `"ffmpeg build-essential"` |
| `OPENCLAW_EXTRA_MOUNTS` | 额外挂载目录 | `"$HOME/projects:/home/node/projects:rw"` |
| `OPENCLAW_HOME_VOLUME` | 持久化 `/home/node` | `"openclaw_home"` |

```bash
# 示例：挂载项目目录并安装额外工具
export OPENCLAW_EXTRA_MOUNTS="$HOME/workspaces:/home/node/workspaces:rw"
export OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg git"
./docker-setup.sh
```

### 2.5 Docker 多实例部署

当需要运行多个完全独立的 OpenClaw 实例（不同 LLM Provider、不同用途等）时，可以通过独立目录 + 独立 Compose 项目实现。

> **与第 6 节"多 Agent"的区别**：第 6 节是单个 Gateway 进程内运行多个 Agent（共享进程，配置级隔离）；本节是启动多个独立的 Gateway 进程（进程级隔离，各自独立的端口、配置和数据）。

**STEP 1. 创建各实例目录**

```bash
# 实例 1：工作助手（使用 Kimi / Moonshot AI）
mkdir -p /opt/openclaw-instances/kimi
# 实例 2：学习助手（使用 MiniMax）
mkdir -p /opt/openclaw-instances/minimax
# 实例 3：代码助手（使用 DeepSeek）
mkdir -p /opt/openclaw-instances/deepseek
```

**STEP 2. 为每个实例准备 Docker Compose 文件**

每个实例需要独立的端口、数据卷和配置目录。以下以三个实例为例：

**实例 1** —— `/opt/openclaw-instances/kimi/docker-compose.yml`：

```yaml
services:
  openclaw-gateway:
    image: openclaw-gateway:latest
    container_name: openclaw-kimi
    restart: unless-stopped
    ports:
      - "18789:18789"
    volumes:
      - ./config:/home/node/.openclaw:rw
      - kimi_home:/home/node
    env_file:
      - .env

volumes:
  kimi_home:
```

**实例 2** —— `/opt/openclaw-instances/minimax/docker-compose.yml`：

```yaml
services:
  openclaw-gateway:
    image: openclaw-gateway:latest
    container_name: openclaw-minimax
    restart: unless-stopped
    ports:
      - "18790:18789"
    volumes:
      - ./config:/home/node/.openclaw:rw
      - minimax_home:/home/node
    env_file:
      - .env

volumes:
  minimax_home:
```

**实例 3** —— `/opt/openclaw-instances/deepseek/docker-compose.yml`：

```yaml
services:
  openclaw-gateway:
    image: openclaw-gateway:latest
    container_name: openclaw-deepseek
    restart: unless-stopped
    ports:
      - "18791:18789"
    volumes:
      - ./config:/home/node/.openclaw:rw
      - deepseek_home:/home/node
    env_file:
      - .env

volumes:
  deepseek_home:
```

> 关键差异：每个实例使用不同的 **宿主机端口**（18789、18790、18791）、不同的 **container_name**、不同的 **数据卷名** 和独立的 **config 目录**。

**STEP 3. 配置各实例**

为每个实例创建独立的配置文件和 `.env`：

```bash
# 实例 1：Kimi（Moonshot AI）
mkdir -p /opt/openclaw-instances/kimi/config/workspace
cat > /opt/openclaw-instances/kimi/config/openclaw.json << 'EOF'
{
  "agent": {
    "model": "openai-compatible:moonshot-v1-auto",
    "providers": {
      "openai-compatible": {
        "baseUrl": "https://api.moonshot.cn/v1"
      }
    },
    "workspace": "~/.openclaw/workspace"
  },
  "gateway": {
    "host": "0.0.0.0",
    "port": 18789
  }
}
EOF

cat > /opt/openclaw-instances/kimi/.env << 'EOF'
OPENAI_API_KEY=sk-kimi-xxx
OPENCLAW_GATEWAY_TOKEN=your-kimi-token
EOF

# 实例 2：MiniMax
mkdir -p /opt/openclaw-instances/minimax/config/workspace
cat > /opt/openclaw-instances/minimax/config/openclaw.json << 'EOF'
{
  "agent": {
    "model": "openai-compatible:MiniMax-Text-01",
    "providers": {
      "openai-compatible": {
        "baseUrl": "https://api.minimax.chat/v1"
      }
    },
    "workspace": "~/.openclaw/workspace"
  },
  "gateway": {
    "host": "0.0.0.0",
    "port": 18789
  }
}
EOF

cat > /opt/openclaw-instances/minimax/.env << 'EOF'
OPENAI_API_KEY=eyJhbGci-minimax-xxx
OPENCLAW_GATEWAY_TOKEN=your-minimax-token
EOF

# 实例 3：DeepSeek
mkdir -p /opt/openclaw-instances/deepseek/config/workspace
cat > /opt/openclaw-instances/deepseek/config/openclaw.json << 'EOF'
{
  "agent": {
    "model": "openai-compatible:deepseek-chat",
    "providers": {
      "openai-compatible": {
        "baseUrl": "https://api.deepseek.com/v1"
      }
    },
    "workspace": "~/.openclaw/workspace"
  },
  "gateway": {
    "host": "0.0.0.0",
    "port": 18789
  }
}
EOF

cat > /opt/openclaw-instances/deepseek/.env << 'EOF'
OPENAI_API_KEY=sk-deepseek-xxx
OPENCLAW_GATEWAY_TOKEN=your-deepseek-token
EOF
```

> 每个实例的 Workspace 文件（`SOUL.md`、`AGENTS.md` 等）放在各自的 `config/workspace/` 目录下，互不影响。

**STEP 4. 启动和管理**

```bash
# 启动各实例（-p 指定项目名，避免冲突）
cd /opt/openclaw-instances/kimi     && docker compose -p openclaw-kimi     up -d
cd /opt/openclaw-instances/minimax  && docker compose -p openclaw-minimax  up -d
cd /opt/openclaw-instances/deepseek && docker compose -p openclaw-deepseek up -d

# 查看所有实例状态
docker ps --filter "name=openclaw-"

# 查看指定实例日志
docker compose -p openclaw-kimi     logs -f
docker compose -p openclaw-minimax  logs -f
docker compose -p openclaw-deepseek logs -f

# 停止指定实例
docker compose -p openclaw-kimi stop

# 重启指定实例
docker compose -p openclaw-deepseek restart
```

**STEP 5. 为各实例绑定不同渠道**

```bash
# Kimi 实例绑定 Telegram
cd /opt/openclaw-instances/kimi
docker compose -p openclaw-kimi run --rm openclaw-gateway \
  openclaw channels add --channel telegram --token "<KIMI_BOT_TOKEN>"

# MiniMax 实例绑定 Discord
cd /opt/openclaw-instances/minimax
docker compose -p openclaw-minimax run --rm openclaw-gateway \
  openclaw channels add --channel discord --token "<MINIMAX_BOT_TOKEN>"

# DeepSeek 实例绑定 Slack
cd /opt/openclaw-instances/deepseek
docker compose -p openclaw-deepseek run --rm openclaw-gateway \
  openclaw channels add --channel slack --token "<DEEPSEEK_BOT_TOKEN>"
```

**多实例目录结构总览**：

```
/opt/openclaw-instances/
├── kimi/                              # 实例 1：Kimi (Moonshot AI)
│   ├── docker-compose.yml
│   ├── .env                           # OPENAI_API_KEY (Kimi), GATEWAY_TOKEN
│   └── config/                        # 挂载为容器内 ~/.openclaw/
│       ├── openclaw.json
│       ├── credentials/
│       ├── sessions/
│       └── workspace/
│           ├── AGENTS.md
│           ├── SOUL.md
│           └── skills/
├── minimax/                           # 实例 2：MiniMax
│   ├── docker-compose.yml
│   ├── .env                           # OPENAI_API_KEY (MiniMax), GATEWAY_TOKEN
│   └── config/
│       ├── openclaw.json
│       └── workspace/
└── deepseek/                          # 实例 3：DeepSeek
    ├── docker-compose.yml
    ├── .env                           # OPENAI_API_KEY (DeepSeek), GATEWAY_TOKEN
    └── config/
        ├── openclaw.json
        └── workspace/
```

**管理脚本**（可选）—— `/opt/openclaw-instances/manage.sh`：

```bash
#!/bin/bash
# 批量管理所有 OpenClaw 实例
ACTION=${1:-status}
INSTANCES_DIR=/opt/openclaw-instances

for dir in "$INSTANCES_DIR"/*/; do
    name=$(basename "$dir")
    echo "=== $name ==="
    case $ACTION in
        start)   cd "$dir" && docker compose -p "openclaw-$name" up -d ;;
        stop)    cd "$dir" && docker compose -p "openclaw-$name" stop ;;
        restart) cd "$dir" && docker compose -p "openclaw-$name" restart ;;
        status)  cd "$dir" && docker compose -p "openclaw-$name" ps ;;
        logs)    cd "$dir" && docker compose -p "openclaw-$name" logs --tail=20 ;;
    esac
done
```

```bash
chmod +x /opt/openclaw-instances/manage.sh

# 用法
/opt/openclaw-instances/manage.sh start    # 启动所有实例
/opt/openclaw-instances/manage.sh status   # 查看所有状态
/opt/openclaw-instances/manage.sh stop     # 停止所有实例
```

## 3. 配置

配置文件位于 `~/.openclaw/openclaw.json`，采用 JSON 格式（支持注释）。

### 3.1 目录结构

```
~/.openclaw/
├── openclaw.json              # 主配置文件
├── credentials/               # 凭证存储
├── sessions/                  # 会话记录
└── workspace/                 # Agent 工作目录
    ├── AGENTS.md              # Agent 操作指令（每次会话加载）
    ├── SOUL.md                # 人格、语气和行为边界
    ├── USER.md                # 用户信息和偏好
    ├── IDENTITY.md            # Agent 名称和特征（引导时自动生成）
    ├── TOOLS.md               # 本地工具说明（仅指导性）
    ├── HEARTBEAT.md           # 心跳定时任务清单
    ├── BOOT.md                # Gateway 重启时执行的启动仪式
    ├── MEMORY.md              # 长期记忆（仅私聊加载）
    ├── memory/                # 日记忆文件 (YYYY-MM-DD.md)
    ├── skills/                # 工作区技能（覆盖内置版本）
    └── canvas/                # UI 文件
```

### 3.2 核心配置示例

```json5
{
  // AI Provider 配置
  "agent": {
    "model": "anthropic:claude-sonnet-4-20250514",
    "workspace": "~/.openclaw/workspace"
  },

  // Gateway 配置
  "gateway": {
    "host": "127.0.0.1",
    "port": 18789
  },

  // 沙箱配置（Docker 隔离执行）
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main",
        "docker": {
          "image": "openclaw-sandbox:bookworm-slim",
          "readOnlyRoot": true,
          "network": "none",
          "memory": "1g",
          "cpus": 1
        }
      }
    }
  }
}
```

### 3.3 Workspace 核心文件说明

**AGENTS.md** —— Agent 操作指令，每次会话加载：

```markdown
## 规则

- 执行命令前先确认
- 涉及文件删除或系统操作时请求授权
- 回复使用中文，技术术语保留英文

## 优先级

1. 安全性 > 效率 > 便利性
2. 优先使用已有工具，避免安装新依赖
```

**SOUL.md** —— 人格和行为边界：

```markdown
## 性格

你是一个高效、专业的技术助手。回复简洁直接，避免冗余。

## 边界

- 不执行破坏性操作（rm -rf、drop database 等）
- 不访问或传输敏感数据
- 不确定时主动询问确认
```

**HEARTBEAT.md** —— 定时任务：

```markdown
## 每日巡检（每天 09:00）

- 检查服务器磁盘使用率，超过 85% 告警
- 检查关键服务状态（docker, nginx）
- 汇总结果发送到 Telegram
```

## 4. 渠道配置

### 4.1 添加消息渠道

```bash
# 交互式添加渠道
openclaw channels add

# 直接添加指定渠道
openclaw channels add --channel telegram --token "<BOT_TOKEN>"
openclaw channels add --channel discord --token "<BOT_TOKEN>"

# WhatsApp（QR 码扫描方式）
openclaw channels login    # 扫描终端中的 QR 码
```

### 4.2 DM 访问策略

OpenClaw 默认使用 **配对模式**（Pairing Mode）：

| 策略 | 说明 |
|------|------|
| **pairing**（默认） | 未知发送者收到配对码，需审批后才处理消息 |
| **open** | 允许所有用户（需显式配置 `*`） |

```bash
# 查看待审批的设备请求
openclaw devices list

# 批准配对
openclaw devices approve <requestId>
```

## 5. Skills 技能扩展

Skills 是 OpenClaw 的能力扩展机制，通过 `SKILL.md` 文件定义。

### 5.1 安装社区技能

```bash
# 从 ClawHub 安装
openclaw skills install <skill-name>

# 手动安装：克隆到 workspace/skills/
git clone <skill-repo> ~/.openclaw/workspace/skills/<skill-name>
```

### 5.2 技能目录

技能按三个层级加载（优先级从高到低）：
1. **workspace skills**（`~/.openclaw/workspace/skills/`）—— 用户自定义，优先级最高
2. **managed skills** —— 通过 ClawHub 安装的社区技能
3. **bundled skills** —— 内置技能

## 6. 多 Agent 实例配置

OpenClaw 支持在 **单个 Gateway 进程** 中运行多个完全隔离的 Agent，每个 Agent 拥有独立的 Workspace、会话存储、记忆索引和配置。无需启动多个 Gateway 进程。

### 6.1 核心概念

| 概念 | 说明 |
|------|------|
| **agentId** | Agent 唯一标识（如 `"analyst"`、`"architect"`） |
| **accountId** | 渠道账号实例（如 WhatsApp "personal" vs "biz"） |
| **binding** | 路由规则，将入站消息匹配到指定 agentId |

**隔离机制**：

```
~/.openclaw/
├── openclaw.json                          # 全局配置（所有 Agent 共享）
├── workspace-analyst/                     # 需求分析师工作区
│   ├── AGENTS.md / SOUL.md / USER.md
│   ├── skills/ / memory/
├── workspace-architect/                   # 技术架构师工作区
│   ├── AGENTS.md / SOUL.md / USER.md
│   ├── skills/ / memory/
├── workspace-developer/                   # 开发工程师工作区
├── workspace-tester/                      # 测试工程师工作区
└── agents/
    ├── analyst/
    │   ├── agent/auth-profiles.json       # 独立认证
    │   └── sessions/*.jsonl               # 独立会话记录
    ├── architect/
    ├── developer/
    └── tester/
```

> 重要：**不要跨 Agent 复用 `agentDir`**，否则会导致认证和会话冲突。

### 6.2 团队角色配置示例

以下示例配置四个角色 Agent，通过不同的 Telegram Bot 接入：

**`~/.openclaw/openclaw.json`**：

```json5
{
  // 全局默认配置
  agents: {
    defaults: {
      model: { primary: "anthropic/claude-sonnet-4-5" },
      sandbox: { mode: "non-main" }
    },

    // 定义四个 Agent
    list: [
      {
        id: "analyst",
        default: true,
        workspace: "~/.openclaw/workspace-analyst",
        model: { primary: "anthropic/claude-sonnet-4-5" }
      },
      {
        id: "architect",
        workspace: "~/.openclaw/workspace-architect",
        model: { primary: "anthropic/claude-opus-4-6" }
      },
      {
        id: "developer",
        workspace: "~/.openclaw/workspace-developer",
        model: { primary: "anthropic/claude-sonnet-4-5" },
        tools: {
          profile: "coding",
          allow: ["exec", "write", "edit", "apply_patch", "read"]
        }
      },
      {
        id: "tester",
        workspace: "~/.openclaw/workspace-tester",
        model: { primary: "anthropic/claude-sonnet-4-5" },
        sandbox: {
          mode: "all",
          scope: "agent",
          docker: {
            setupCommand: "apt-get update && apt-get install -y git curl jq"
          }
        }
      }
    ]
  },

  // 路由规则：将不同渠道/账号路由到不同 Agent
  bindings: [
    { agentId: "analyst",   match: { channel: "telegram", accountId: "analyst-bot" } },
    { agentId: "architect", match: { channel: "telegram", accountId: "architect-bot" } },
    { agentId: "developer", match: { channel: "telegram", accountId: "developer-bot" } },
    { agentId: "tester",    match: { channel: "telegram", accountId: "tester-bot" } }
  ],

  // 四个 Telegram Bot，各自独立 Token
  channels: {
    telegram: {
      accounts: {
        "analyst-bot":   { botToken: "111111:AAA...", dmPolicy: "pairing" },
        "architect-bot": { botToken: "222222:BBB...", dmPolicy: "pairing" },
        "developer-bot": { botToken: "333333:CCC...", dmPolicy: "pairing" },
        "tester-bot":    { botToken: "444444:DDD...", dmPolicy: "pairing" }
      }
    }
  }
}
```

### 6.3 各角色 Workspace 配置

为每个角色创建独立的 Workspace 并定义专属的身份和行为准则。

**创建工作区目录**：

```bash
for role in analyst architect developer tester; do
  mkdir -p ~/.openclaw/workspace-$role/{skills,memory}
done
```

**需求分析师** —— `~/.openclaw/workspace-analyst/SOUL.md`：

```markdown
## 角色

你是一名资深需求分析师，擅长业务需求梳理、用户故事编写和需求文档管理。

## 职责

- 分析和拆解业务需求，输出结构化的需求文档
- 编写用户故事（User Story）和验收标准（Acceptance Criteria）
- 识别需求中的模糊点和风险，主动提出澄清问题
- 维护需求变更记录

## 工作风格

- 使用中文编写文档，技术术语保留英文
- 输出格式统一：用户故事使用 "作为..., 我希望..., 以便..." 模板
- 每个需求附带优先级标注（P0/P1/P2）
- 复杂需求附流程图或状态图说明
```

**技术架构师** —— `~/.openclaw/workspace-architect/SOUL.md`：

```markdown
## 角色

你是一名技术架构师，负责系统设计、技术选型和架构评审。

## 职责

- 根据需求设计系统架构，输出架构设计文档
- 评估技术方案的可行性、可扩展性和安全性
- 定义 API 接口规范和数据模型
- 进行技术选型并给出对比分析

## 工作风格

- 架构图使用 Mermaid 或 ASCII 绘制
- 技术决策附带 ADR（Architecture Decision Record）
- 关注非功能性需求：性能、可用性、安全性、可观测性
- 方案对比使用表格，列出优劣和适用场景
```

**开发工程师** —— `~/.openclaw/workspace-developer/SOUL.md`：

```markdown
## 角色

你是一名全栈开发工程师，负责功能实现、代码编写和代码审查。

## 职责

- 根据需求和架构设计实现功能代码
- 遵循项目代码规范和最佳实践
- 进行代码自审，确保代码质量
- 编写必要的单元测试

## 工作风格

- 代码优先：给出完整可运行的代码，而非伪代码
- 遵循 SOLID 原则，避免过度设计
- 提交信息使用 Conventional Commits 规范
- 修改代码前先理解现有代码结构
```

**测试工程师** —— `~/.openclaw/workspace-tester/SOUL.md`：

```markdown
## 角色

你是一名测试工程师，负责测试策略制定、测试用例编写和质量保障。

## 职责

- 根据需求编写测试用例（功能测试、边界测试、异常测试）
- 设计自动化测试脚本
- 执行测试并输出测试报告
- 发现缺陷时详细记录复现步骤

## 工作风格

- 测试用例使用表格格式：编号、前置条件、操作步骤、预期结果
- 关注边界条件和异常场景
- 自动化脚本优先使用项目已有的测试框架
- 缺陷报告包含：环境、步骤、实际结果、预期结果、严重程度
```

### 6.4 CLI 管理命令

```bash
# 添加新 Agent
openclaw agents add analyst

# 列出所有 Agent 及路由绑定
openclaw agents list --bindings

# 指定 Agent 执行操作
openclaw memory search "API 设计" --agent architect

# 查看指定 Agent 状态
openclaw status --agent developer

# 重启 Gateway 使配置生效
openclaw gateway restart

# 检查各渠道连接状态
openclaw channels status --probe
```

### 6.5 路由匹配规则

路由按 **最具体匹配优先** 原则，评估顺序：

1. 精确 peer 匹配（指定的 DM/群组 ID）
2. 父级 peer 匹配（线程继承）
3. Guild ID + 角色（Discord）
4. Team ID（Slack）
5. Account ID 匹配
6. Channel 级别匹配（`accountId: "*"`）
7. 回退到默认 Agent（`default: true`）

同一 binding 中多个 match 字段为 **AND 逻辑**，所有条件都满足才匹配。

### 6.6 单渠道多 Agent 路由

如果只有一个 Telegram Bot，可通过群组 ID 路由到不同 Agent：

```json5
{
  bindings: [
    // 需求讨论群 → 需求分析师
    {
      agentId: "analyst",
      match: {
        channel: "telegram",
        peer: { kind: "group", id: "-1001234567001" }
      }
    },
    // 架构评审群 → 技术架构师
    {
      agentId: "architect",
      match: {
        channel: "telegram",
        peer: { kind: "group", id: "-1001234567002" }
      }
    },
    // 开发群 → 开发工程师
    {
      agentId: "developer",
      match: {
        channel: "telegram",
        peer: { kind: "group", id: "-1001234567003" }
      }
    },
    // 其他消息 → 默认 Agent
    { agentId: "analyst" }
  ]
}
```

### 6.7 可覆盖的 Agent 级配置

每个 Agent 可独立覆盖以下全局默认配置（**完全替换，非合并**）：

| 类别 | 可覆盖字段 |
|------|-----------|
| 工作区 | `workspace`、`skipBootstrap` |
| 模型 | `model.primary`、`model.fallbacks` |
| 工具 | `tools.profile`、`tools.allow`、`tools.deny` |
| 沙箱 | `sandbox.mode`、`sandbox.scope`、`sandbox.workspaceAccess` |
| 记忆 | `memorySearch.enabled`、`memorySearch.provider`、`memorySearch.extraPaths` |
| 行为 | `thinkingDefault`、`verboseDefault`、`contextTokens`、`heartbeat` |

## 7. 安全加固

### 7.1 默认安全机制

- **Gateway 绑定**：默认绑定 `127.0.0.1`，不对外暴露
- **配对认证**：DM 默认需要配对码审批
- **沙箱隔离**：非主会话在 Docker 容器中执行工具
- **只读根文件系统**：沙箱容器 `readOnlyRoot: true`
- **网络隔离**：沙箱默认 `network: "none"`

### 7.2 安全检查

```bash
# 运行安全诊断
openclaw doctor
```

`openclaw doctor` 会检查：
- Gateway 运行状态
- Auth Token 配置
- 沙箱镜像是否存在
- 绑定地址安全性
- DM 策略风险

### 7.3 生产环境建议

- 使用 Docker 部署，不在本地机器直接运行
- 启用沙箱模式隔离工具执行
- 通过 SSH 隧道或 Tailscale 访问 Gateway，避免公网暴露
- 定期检查 `openclaw doctor` 输出

```bash
# 通过 SSH 隧道从本地访问远程 Gateway
ssh -N -L 18789:127.0.0.1:18789 user@<server-ip>
```

## 8. systemd 服务管理

`openclaw onboard --install-daemon` 会自动创建 systemd 用户服务。手动管理方式：

```bash
# 查看服务状态
systemctl --user status openclaw

# 启停服务
systemctl --user start openclaw
systemctl --user stop openclaw
systemctl --user restart openclaw

# 查看日志
journalctl --user -u openclaw -f

# 确保用户服务在注销后仍运行（关键）
loginctl enable-linger $USER
```

> `enable-linger` 非常重要，它确保 systemd 用户服务在 SSH 断开后继续运行。

## 9. 自动化与目录监控

OpenClaw 提供三种自动化机制：**Cron Jobs**（定时任务）、**Webhooks**（外部事件触发）和 **Heartbeat**（空闲巡检）。结合 Linux 系统工具，可以实现目录文件监控并触发 Agent 任务。

### 9.1 自动化机制概览

| 机制 | 触发方式 | 适用场景 |
|------|---------|---------|
| **Cron Jobs** | 定时调度（cron 表达式 / 固定间隔） | 定时报告、定期检查、周期性任务 |
| **Webhooks** | 外部 HTTP POST | GitHub 推送、监控告警、外部事件 |
| **Heartbeat** | Agent 空闲时自动执行 | 邮件检查、状态巡检、主动关怀 |

### 9.2 Cron Jobs 配置

**CLI 创建定时任务**：

```bash
# 创建每日定时任务（隔离会话，结果推送到 Telegram）
openclaw cron add \
  --name "每日巡检" \
  --cron "0 9 * * *" \
  --tz "Asia/Shanghai" \
  --session isolated \
  --message "检查 /data/inbox 目录下的新文件，汇总文件名和大小" \
  --announce --channel telegram

# 创建高频轮询任务（每 5 分钟）
openclaw cron add \
  --name "文件监控" \
  --cron "*/5 * * * *" \
  --session isolated \
  --message "检查 /data/inbox 是否有最近5分钟内新增的文件，如有则分析文件内容并汇总"

# 列出所有定时任务
openclaw cron list

# 手动触发执行
openclaw cron run <job-id>

# 查看执行历史
openclaw cron runs --id <job-id> --limit 10

# 删除任务
openclaw cron remove <job-id>
```

**JSON 配置方式**（在 `openclaw.json` 中）：

```json5
{
  cron: {
    enabled: true,
    maxConcurrentRuns: 1
  }
}
```

**Cron 任务的两种执行模式**：

| 模式 | 说明 |
|------|------|
| **Main Session** | 在主对话会话中触发，共享上下文 |
| **Isolated** | 在独立的 `cron:<jobId>` 会话中执行，每次从零开始 |

### 9.3 Heartbeat 空闲巡检

通过 `HEARTBEAT.md` 定义 Agent 空闲时的巡检清单，适合不需要精确定时的监控场景。

**`~/.openclaw/workspace/HEARTBEAT.md`**：

```markdown
## 文件目录监控

- 检查 /data/inbox 目录是否有新文件
- 如果有新文件，读取文件内容并生成摘要
- 将新文件信息和摘要通过 Telegram 通知我
- 处理完成后将文件移动到 /data/processed

## 服务健康检查

- 检查关键服务进程是否在运行
- 磁盘使用率超过 85% 时告警
```

Agent 在每次心跳唤醒时读取此清单，判断是否需要执行，执行后回复结果或返回 `HEARTBEAT_OK`（Gateway 静默丢弃）。

### 9.4 目录监控方案

OpenClaw 没有内置的文件系统监听（inotify），以下是三种实现方案，按推荐顺序排列。

#### 方案一：inotifywait + Webhook（推荐，实时性最好）

利用 Linux 原生 `inotifywait` 监听目录变化，通过 Webhook 实时触发 Agent。

**STEP 1. 安装 inotify-tools**

```bash
# Debian / Ubuntu
sudo apt install -y inotify-tools
```

**STEP 2. 创建监控脚本**

```bash
cat > ~/.openclaw/workspace/cron/watch-inbox.sh << 'SCRIPT'
#!/bin/bash
# 监控目录，新文件创建时通过 Gateway API 触发 Agent
WATCH_DIR="/data/inbox"
GATEWAY="http://127.0.0.1:18789"
TOKEN="${OPENCLAW_GATEWAY_TOKEN}"

mkdir -p "$WATCH_DIR"

inotifywait -m -e create -e moved_to --format '%f' "$WATCH_DIR" | while read FILENAME; do
    FILEPATH="$WATCH_DIR/$FILENAME"
    # 等待文件写入完成
    sleep 2

    # 通过 Gateway API 发送消息给 Agent
    curl -s -X POST "$GATEWAY/v1/message" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "{
        \"message\": \"目录 $WATCH_DIR 检测到新文件: $FILENAME ($(stat -c%s "$FILEPATH" 2>/dev/null || echo '未知') 字节)。请分析文件内容并生成处理报告。\",
        \"agentId\": \"analyst\"
      }"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 触发: $FILENAME"
done
SCRIPT

chmod +x ~/.openclaw/workspace/cron/watch-inbox.sh
```

**STEP 3. 注册为 systemd 服务**

```bash
cat > ~/.config/systemd/user/openclaw-watch-inbox.service << 'EOF'
[Unit]
Description=OpenClaw Inbox File Watcher
After=openclaw.service

[Service]
Type=simple
Environment=OPENCLAW_GATEWAY_TOKEN=<your-token>
ExecStart=%h/.openclaw/workspace/cron/watch-inbox.sh
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now openclaw-watch-inbox
```

**STEP 4. 验证**

```bash
# 查看监控服务状态
systemctl --user status openclaw-watch-inbox

# 测试：创建文件触发
echo "测试内容" > /data/inbox/test-$(date +%s).txt

# 查看监控日志
journalctl --user -u openclaw-watch-inbox -f
```

#### 方案二：Cron 轮询（简单，适合低频场景）

使用 OpenClaw 内置 Cron 定期扫描目录，无需额外组件。

**创建 Cron 任务**：

```bash
openclaw cron add \
  --name "inbox-monitor" \
  --cron "*/2 * * * *" \
  --tz "Asia/Shanghai" \
  --session isolated \
  --message "执行以下检查：
1. 运行 find /data/inbox -maxdepth 1 -type f -newer /tmp/.openclaw-inbox-marker 查找新文件
2. 如果有新文件，逐个读取并生成内容摘要
3. 将处理结果通过 Telegram 通知我
4. 最后执行 touch /tmp/.openclaw-inbox-marker 更新标记时间戳"
```

> 此方案通过 marker 文件记录上次检查时间，`find -newer` 筛选新文件。延迟取决于 cron 间隔（示例为 2 分钟）。

#### 方案三：Heartbeat + Agent 自主检查

最简单的方式，利用 Heartbeat 让 Agent 在空闲时自动检查。

**`~/.openclaw/workspace/HEARTBEAT.md`** 中添加：

```markdown
## 文件目录监控（每次心跳检查）

- 运行 ls -lt /data/inbox/ | head -20 查看最新文件
- 对比记忆中上次检查时记录的文件列表
- 如果发现新文件：
  1. 读取文件内容
  2. 根据文件类型执行对应处理（.csv 做数据分析, .md 做内容摘要, .json 做格式校验）
  3. 将处理结果通知我
  4. 更新记忆中的文件列表
```

### 9.5 三种方案对比

| 维度 | inotifywait + Webhook | Cron 轮询 | Heartbeat |
|------|----------------------|----------|-----------|
| 实时性 | 秒级（文件创建即触发） | 分钟级（取决于 cron 间隔） | 不确定（取决于心跳频率） |
| 额外依赖 | inotify-tools + systemd 服务 | 无 | 无 |
| 配置复杂度 | 中等 | 低 | 最低 |
| 可靠性 | 高（系统级监听） | 高（cron 持久化） | 中（依赖 Agent 理解力） |
| 资源消耗 | 极低（内核事件驱动） | 低（周期执行） | 低 |
| 适用场景 | 高频文件到达、实时处理 | 定期批量处理 | 低频、非关键任务 |
| 多目录监控 | 支持（多个 inotifywait 实例） | 支持（多个 cron 任务） | 支持（HEARTBEAT.md 中列出） |

**推荐选择**：
- 需要实时响应 → **方案一**（inotifywait + Webhook）
- 简单定期检查 → **方案二**（Cron 轮询）
- 快速试验 → **方案三**（Heartbeat）

### 9.6 Webhook 接收外部事件

除了文件监控，还可以通过 Webhook 接收外部系统的事件触发：

```json5
// openclaw.json 中配置 Webhook
{
  webhooks: {
    "deploy-notify": {
      prompt: "收到部署通知: {{author}} 在 {{repo}} 提交了 '{{message}}'，请检查部署状态",
      channel: "telegram",
      secret: "${WEBHOOK_SECRET}"
    }
  }
}
```

外部系统通过 HTTP POST 触发：

```bash
curl -X POST http://127.0.0.1:18789/webhook/deploy-notify \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Secret: $WEBHOOK_SECRET" \
  -d '{"author": "zhangsan", "repo": "myapp", "message": "fix: 修复登录bug"}'
```

## 10. 常用命令速查

| 命令 | 说明 |
|------|------|
| `openclaw onboard` | 交互式引导配置 |
| `openclaw onboard --install-daemon` | 引导并注册 systemd 服务 |
| `openclaw doctor` | 安全诊断和配置检查 |
| `openclaw status` | 查看 Gateway 状态 |
| `openclaw dashboard` | 打开控制面板（Web UI） |
| `openclaw channels add` | 添加消息渠道 |
| `openclaw channels login` | 登录渠道（如 WhatsApp QR） |
| `openclaw devices list` | 查看待配对设备 |
| `openclaw devices approve <id>` | 批准设备配对 |
| `openclaw skills install <name>` | 安装技能 |
| `openclaw gateway status` | 查看 Gateway 详细状态 |
| `openclaw agents add <id>` | 添加新 Agent |
| `openclaw agents list --bindings` | 列出所有 Agent 及路由绑定 |
| `openclaw gateway restart` | 重启 Gateway |
| `openclaw cron add` | 创建定时任务 |
| `openclaw cron list` | 列出所有定时任务 |
| `openclaw cron run <id>` | 手动触发执行 |
| `openclaw cron remove <id>` | 删除定时任务 |

## 参考

- [OpenClaw GitHub 仓库](https://github.com/openclaw/openclaw)
- [OpenClaw 官方文档 - 安装](https://docs.openclaw.ai/install)
- [OpenClaw 官方文档 - Docker](https://docs.openclaw.ai/install/docker)
- [OpenClaw 官方文档 - Agent Workspace](https://docs.openclaw.ai/concepts/agent-workspace)
- [Cherry Servers - Linux VPS 部署指南](https://www.cherryservers.com/blog/install-openclaw-on-linux-vps)
- [DigitalOcean - OpenClaw 部署教程](https://www.digitalocean.com/community/tutorials/how-to-run-openclaw)
- [Docker 官方博客 - OpenClaw 安全沙箱](https://www.docker.com/blog/run-openclaw-securely-in-docker-sandboxes/)
- [OpenClaw 官方文档 - 多 Agent 路由](https://docs.openclaw.ai/concepts/multi-agent)
- [OpenClaw 多 Agent 配置详解 - DeepWiki](https://deepwiki.com/openclaw/openclaw/4.3-multi-agent-configuration)
- [OpenClaw 官方文档 - Cron Jobs](https://docs.openclaw.ai/automation/cron-jobs)
- [OpenClaw 架构深度解析](https://deepwiki.com/openclaw/openclaw/15.1-architecture-deep-dive)
