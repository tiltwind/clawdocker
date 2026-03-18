<!--
markmeta_author: tiltwind
markmeta_date: 2026-02-25
markmeta_title: OpenClaw 常用命令速查
markmeta_categories: ai
markmeta_tags: ai,openclaw,agent
-->

# OpenClaw 常用命令速查

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
