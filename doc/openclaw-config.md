<!--
markmeta_author: tiltwind
markmeta_date: 2026-02-25
markmeta_title: OpenClaw 配置
markmeta_categories: ai
markmeta_tags: ai,openclaw,agent,node.js
-->

# OpenClaw 配置

配置文件位于 `~/.openclaw/openclaw.json`，采用 JSON 格式（支持注释）。

## 目录结构

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

## 核心配置示例

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

## Workspace 核心文件说明

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
