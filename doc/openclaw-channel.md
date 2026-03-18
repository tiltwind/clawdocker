<!--
markmeta_author: tiltwind
markmeta_date: 2026-02-25
markmeta_title: OpenClaw 渠道配置
markmeta_categories: ai
markmeta_tags: ai,openclaw,agent,channel
-->

# OpenClaw 渠道配置

## 添加消息渠道

```bash
# 交互式添加渠道
openclaw channels add

# 直接添加指定渠道
openclaw channels add --channel telegram --token "<BOT_TOKEN>"
openclaw channels add --channel discord --token "<BOT_TOKEN>"

# WhatsApp（QR 码扫描方式）
openclaw channels login    # 扫描终端中的 QR 码
```

## DM 访问策略

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

## 各渠道配置指南

- [飞书（Feishu）渠道配置](openclaw-channel-feishu.md)
