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

## 多实例部署

当需要运行多个完全独立的 OpenClaw 实例（不同 LLM Provider、不同用途等）时，可以通过独立目录 + 独立 Compose 项目实现。

> **与[多 Agent 配置](openclaw-multi-agent.md)的区别**：多 Agent 是单个 Gateway 进程内运行多个 Agent（共享进程，配置级隔离）；多实例是启动多个独立的 Gateway 进程（进程级隔离，各自独立的端口、配置和数据）。


### STEP 1. 使用 clawdocker.sh 创建实例

使用 `clawdocker.sh` 交互式创建实例，只需输入名称、目录和端口：

```bash
cd /opt/openclaw-instances

# 交互式创建实例
./clawdocker.sh create
# Instance name: deep
# Instance path: /opt/clawdocker/deep
# Host port: 18001

```

### STEP 2. 启动并配置

```bash
# 启动实例
./clawdocker.sh start deep
# [INFO]  Starting instance at: /opt/clawdocker/deep (project: openclaw-deep)
# [+] up 3/3
#  ✔ Network openclaw-deep_default  Created   0.2s
#  ✔ Volume openclaw-deep_deep_home Created   0.1s
#  ✔ Container openclaw-deep        Started   1.4s
# [INFO]  Instance started. Gateway port: 18001 

# 进入容器内交互式完成基本配置（Provider、API Key、Model 等）
./clawdocker.sh exec deep openclaw dashboard
# Dashboard URL: http://127.0.0.1:18789/#token=69360a4af148744137678cbf95174a9d
# Copy to clipboard unavailable.
# No GUI detected. Open from your computer:
# ssh -N -L 18789:127.0.0.1:18789 user@<host>
# Then open:
# http://localhost:18789/
# http://localhost:18789/#token=69360a4af148744137678cbf95174a9d
# Docs:
# https://docs.openclaw.ai/gateway/remote
# https://docs.openclaw.ai/web/control-ui

# 本地端口转发（将本地 18789 端口映射到远程 18001
ssh -N -L 18789:127.0.0.1:18001 root@10.225.32.180

```

### STEP 3. 常用管理命令

```bash
# 查看实例状态
./clawdocker.sh status deepseek

# 查看日志
./clawdocker.sh logs deepseek

# 停止 / 重启 / 删除实例
./clawdocker.sh stop deepseek
./clawdocker.sh restart deepseek
./clawdocker.sh remove deepseek

# 列出所有已注册的实例
./clawdocker.sh list

# 在容器内执行命令（如添加消息渠道）
./clawdocker.sh exec deepseek openclaw channels add
```

> 创建多个实例时，为每个实例指定不同的端口号即可（如 18789、18790、18791）。
