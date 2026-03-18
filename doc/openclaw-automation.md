<!--
markmeta_author: tiltwind
markmeta_date: 2026-02-25
markmeta_title: OpenClaw 自动化与目录监控
markmeta_categories: ai
markmeta_tags: ai,openclaw,agent,cron,webhook,automation
-->

# OpenClaw 自动化与目录监控

OpenClaw 提供三种自动化机制：**Cron Jobs**（定时任务）、**Webhooks**（外部事件触发）和 **Heartbeat**（空闲巡检）。结合 Linux 系统工具，可以实现目录文件监控并触发 Agent 任务。

## 自动化机制概览

| 机制 | 触发方式 | 适用场景 |
|------|---------|---------|
| **Cron Jobs** | 定时调度（cron 表达式 / 固定间隔） | 定时报告、定期检查、周期性任务 |
| **Webhooks** | 外部 HTTP POST | GitHub 推送、监控告警、外部事件 |
| **Heartbeat** | Agent 空闲时自动执行 | 邮件检查、状态巡检、主动关怀 |

## Cron Jobs 配置

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

## Heartbeat 空闲巡检

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

## 目录监控方案

OpenClaw 没有内置的文件系统监听（inotify），以下是三种实现方案，按推荐顺序排列。

### 方案一：inotifywait + Webhook（推荐，实时性最好）

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

### 方案二：Cron 轮询（简单，适合低频场景）

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

### 方案三：Heartbeat + Agent 自主检查

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

## 三种方案对比

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

## Webhook 接收外部事件

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
