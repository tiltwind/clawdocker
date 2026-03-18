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

## 文档索引

| 文档 | 说明 |
|------|------|
| [架构](doc/openclaw-architecture.md) | Gateway + Agent 架构说明，与 ZeroClaw 对比 |
| [Debian 安装](doc/openclaw-install.md) | 脚本安装、手动安装步骤 |
| [Docker 部署](doc/openclaw-install-docker.md) | Docker 单实例部署、多实例部署、管理脚本 |
| [配置](doc/openclaw-config.md) | 目录结构、核心配置示例、Workspace 文件说明 |
| [渠道配置](doc/openclaw-channel.md) | 添加消息渠道、DM 访问策略 |
| [飞书渠道配置](doc/openclaw-channel-feishu.md) | 飞书应用创建、权限配置、事件订阅、OpenClaw 对接全流程 |
| [Skills 技能扩展](doc/openclaw-skills.md) | 技能安装与加载优先级 |
| [多 Agent 配置](doc/openclaw-multi-agent.md) | 单 Gateway 多 Agent、路由规则、团队角色示例 |
| [安全加固](doc/openclaw-security.md) | 默认安全机制、安全检查、生产环境建议 |
| [systemd 服务管理](doc/openclaw-systemd.md) | systemd 用户服务管理命令 |
| [自动化与目录监控](doc/openclaw-automation.md) | Cron Jobs、Webhooks、Heartbeat、目录监控方案 |
| [常用命令速查](doc/openclaw-commands.md) | OpenClaw CLI 命令速查表 |

## 工具

- [clawdocker.sh](clawdocker.sh) — OpenClaw Docker 实例管理脚本（创建、启停、飞书渠道配置）

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
