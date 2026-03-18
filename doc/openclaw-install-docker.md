<!--
markmeta_author: tiltwind
markmeta_date: 2026-02-25
markmeta_title: OpenClaw Docker 部署
markmeta_categories: ai
markmeta_tags: ai,openclaw,agent,docker
-->

# OpenClaw Docker 部署

Docker 部署提供更好的隔离性和安全性，推荐用于生产环境。

## 单实例部署

### STEP 1. 安装 Docker

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

### STEP 2. 克隆仓库并启动

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# 自动化安装（构建镜像 + onboard + 启动 compose）
./docker-setup.sh
```

`docker-setup.sh` 会完成：构建 Gateway 镜像、运行 onboard、生成 `.env`（含 Gateway Token）、启动 Docker Compose

### STEP 3. 常用操作

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

### STEP 4. 更新 OpenClaw 版本

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

### 环境变量配置

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

## 多实例部署

当需要运行多个完全独立的 OpenClaw 实例（不同 LLM Provider、不同用途等）时，可以通过独立目录 + 独立 Compose 项目实现。

> **与[多 Agent 配置](openclaw-multi-agent.md)的区别**：多 Agent 是单个 Gateway 进程内运行多个 Agent（共享进程，配置级隔离）；多实例是启动多个独立的 Gateway 进程（进程级隔离，各自独立的端口、配置和数据）。

### STEP 1. 创建各实例目录

```bash
# 实例 1：工作助手（使用 Kimi / Moonshot AI）
mkdir -p /opt/openclaw-instances/kimi
# 实例 2：学习助手（使用 MiniMax）
mkdir -p /opt/openclaw-instances/minimax
# 实例 3：代码助手（使用 DeepSeek）
mkdir -p /opt/openclaw-instances/deepseek
```

### STEP 2. 为每个实例准备 Docker Compose 文件

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

### STEP 3. 配置各实例

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

### STEP 4. 启动和管理

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

### STEP 5. 为各实例绑定不同渠道

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

### 多实例目录结构总览

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

### 管理脚本（可选）

`/opt/openclaw-instances/manage.sh`：

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
