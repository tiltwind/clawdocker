<!--
markmeta_author: tiltwind
markmeta_date: 2026-02-25
markmeta_title: OpenClaw 飞书渠道配置
markmeta_categories: ai
markmeta_tags: ai,openclaw,agent,feishu,lark
-->

# OpenClaw 飞书（Feishu）渠道配置

飞书是 OpenClaw 支持的消息渠道之一，支持私聊和群组两种模式，通过 WebSocket 长连接或 Webhook 回调与飞书开放平台通信。

## STEP 1. 创建飞书应用

1. 打开 [飞书开放平台](https://open.feishu.cn/app)，登录后点击 **「创建企业自建应用」**
2. 填写应用信息：
   - **应用名称**：如 "OpenClaw 助手"
   - **应用描述**：如 "AI 个人助手"
   - **应用图标**：上传一个图标
3. 创建完成后，进入应用详情页，记录以下凭证：
   - **App ID**（应用凭证页面）
   - **App Secret**（应用凭证页面）

> 应用凭证页面路径：应用详情 → 凭证与基础信息 → 应用凭证
> 直达链接：`https://open.feishu.cn/app/<YOUR_APP_ID>/baseinfo`

## STEP 2. 配置应用权限

进入 **权限管理** 页面（路径：应用详情 → 权限管理），搜索并开通以下权限：

> 权限管理直达链接：`https://open.feishu.cn/app/<YOUR_APP_ID>/permission`

**必须开通的权限**：

| 权限名称 | 权限标识 (Scope) | 用途 |
|---------|-----------------|------|
| 获取与发送单聊、群组消息 | `im:message` | 接收和发送消息 |
| 读取用户发给机器人的单聊消息 | `im:message.receive_msg` | 接收私聊消息 |
| 以应用的身份发消息 | `im:message:send_as_bot` | 机器人主动发送消息 |
| 获取群组信息 | `im:chat:readonly` | 读取群组信息 |
| 获取用户基本信息 | `contact:user.base:readonly` | 识别消息发送者 |
| 获取用户 user ID | `contact:user.employee_id:readonly` | 获取用户 Open ID |

**可选权限（增强功能）**：

| 权限名称 | 权限标识 (Scope) | 用途 |
|---------|-----------------|------|
| 获取与上传图片或文件资源 | `im:resource` | 接收和发送图片/文件 |
| 获取用户在群组中@机器人的消息 | `im:message.group_at_msg` | 群组中被 @mention 时接收消息 |
| 读取群成员信息 | `im:chat.member:readonly` | 查询群成员列表 |

开通权限后需要点击页面上方的 **「批量开通」** 按钮确认。

## STEP 3. 配置事件订阅

进入 **事件订阅** 页面（路径：应用详情 → 事件与回调 → 事件配置）：

> 事件订阅直达链接：`https://open.feishu.cn/app/<YOUR_APP_ID>/event`

**3a. 选择连接方式**（二选一）：

| 方式 | 说明 | 适用场景 |
|------|------|---------|
| **WebSocket**（推荐） | 长连接模式，无需公网 IP | 本地部署、内网环境 |
| **Webhook** | HTTP 回调模式，需公网可达的 URL | 有公网域名的生产环境 |

- **WebSocket 模式**：在「事件配置」页面点击「使用长连接接收事件」，无需配置回调 URL
- **Webhook 模式**：在「请求网址 URL」中填入 `https://<YOUR_DOMAIN>/webhook/feishu`（需先确保 Gateway 可从公网访问）

**3b. 添加事件**：

搜索并订阅以下事件：

| 事件名称 | 事件标识 | 用途 |
|---------|---------|------|
| 接收消息 | `im.message.receive_v1` | 接收用户发送的消息 |
| 消息已读 | `im.message.message_read_v1` | 消息已读回执（可选） |

> 事件格式选择 **2.0 版本**（JSON 格式）。

## STEP 4. 启用机器人能力

进入 **应用能力** 页面（路径：应用详情 → 应用能力 → 机器人）：

> 直达链接：`https://open.feishu.cn/app/<YOUR_APP_ID>/bot`

1. 点击 **「启用机器人」**
2. 填写机器人信息：
   - **机器人名称**：如 "OpenClaw"
   - **机器人描述**：如 "AI 个人助手"
3. 配置机器人消息接收：确认事件订阅中已添加 `im.message.receive_v1`

## STEP 5. 发布应用

1. 进入 **版本管理与发布** 页面（路径：应用详情 → 版本管理与发布）
2. 点击 **「创建版本」**，填写版本号和更新说明
3. 点击 **「申请发布」**
4. 等待企业管理员审批通过（如果你是管理员，可以在 [飞书管理后台 → 应用审核](https://feishu.cn/admin/appCenter/audit) 中直接审批）

> 注意：应用必须发布并审批通过后，机器人才能正常接收和发送消息。测试阶段可以先将自己添加到应用的「可用性」范围内。

## STEP 6. 配置 OpenClaw

```bash
# 交互式配置（不带额外参数时，openclaw 进入交互模式）
./clawdocker.sh exec <实例名称> openclaw channels set feishu

# 也可以直接传参
./clawdocker.sh exec <实例名称> openclaw channels set feishu \
  --app-id "<YOUR_APP_ID>" \
  --app-secret "<YOUR_APP_SECRET>"
```

## STEP 7. 重启并验证

```bash
# 重启 OpenClaw 使配置生效
./clawdocker.sh restart <实例名称>

# 检查飞书渠道连接状态
./clawdocker.sh exec <实例名称> openclaw channels status --probe
```

验证步骤：
1. 在飞书中搜索你创建的机器人名称
2. 向机器人发送一条私聊消息（如 "你好"）
3. 如果 `dmPolicy` 为 `pairing`（默认），你需要先完成配对：
   - 机器人会回复一个配对码
   - 在终端执行 `./clawdocker.sh exec <实例名称> openclaw devices list` 查看待审批请求
   - 执行 `./clawdocker.sh exec <实例名称> openclaw devices approve <requestId>` 批准配对
4. 配对完成后，再次发送消息，机器人应正常回复

## 配置参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|-------|------|
| `enabled` | boolean | `true` | 是否启用飞书渠道 |
| `domain` | string | `"feishu"` | `"feishu"` 国内版，`"lark"` 国际版 |
| `connectionMode` | string | `"websocket"` | `"websocket"` 长连接或 `"webhook"` 回调 |
| `dmPolicy` | string | `"pairing"` | 私聊策略：`"pairing"` / `"allowlist"` / `"open"` / `"disabled"` |
| `groupPolicy` | string | `"open"` | 群组策略：`"open"` / `"allowlist"` / `"disabled"` |
| `requireMention` | boolean | `true` | 群组中是否需要 @机器人 才触发响应 |
| `allowFrom` | string[] | `[]` | 私聊白名单（用户 Open ID 列表），`dmPolicy` 为 `"allowlist"` 时生效 |
| `groupAllowFrom` | string[] | `[]` | 群组白名单（Chat ID 列表），`groupPolicy` 为 `"allowlist"` 时生效 |

## 常见问题

**Q: 国际版 Lark 和国内版飞书有什么区别？**

将 `domain` 改为 `"lark"` 即可切换到国际版。两者 API 端点不同，OpenClaw 会根据 `domain` 自动选择正确的端点。开放平台地址也不同：国际版为 [open.larksuite.com](https://open.larksuite.com)。

**Q: WebSocket 连接断开后会自动重连吗？**

会。OpenClaw 内置了断线重连机制，WebSocket 连接断开后会自动尝试重新连接。

**Q: 如何在群组中使用机器人？**

1. 将机器人添加到目标群组
2. 如果 `requireMention` 为 `true`（默认），需要在消息中 @机器人 才会触发响应
3. 如果设为 `false`，机器人会响应群组中的所有消息
