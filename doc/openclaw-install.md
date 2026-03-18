<!--
markmeta_author: tiltwind
markmeta_date: 2026-02-25
markmeta_title: OpenClaw Debian 环境安装
markmeta_categories: ai
markmeta_tags: ai,openclaw,agent,node.js
-->

# OpenClaw Debian 环境安装

## 系统要求

| 项目 | 最低要求 | 推荐配置 |
|------|---------|---------|
| OS | Debian 11+ / Ubuntu 22.04+ | Debian 12 (Bookworm) |
| CPU | 1 vCPU | 2+ vCPU |
| RAM | 2 GB | 4 GB |
| 磁盘 | 10 GB | 20 GB |
| Node.js | 22+ | 22 LTS |
| 网络 | 端口 18789（Gateway） | - |

## 方式一：脚本安装（推荐）

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

## 方式二：手动安装

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

## 卸载 OpenClaw

### 一键卸载

```bash
bash clear_openclaw.sh
```

> 如果不再需要 Node.js，可额外执行 `sudo apt remove -y nodejs && sudo apt autoremove -y` 卸载。
