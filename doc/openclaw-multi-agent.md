<!--
markmeta_author: tiltwind
markmeta_date: 2026-02-25
markmeta_title: OpenClaw 多 Agent 实例配置
markmeta_categories: ai
markmeta_tags: ai,openclaw,agent,multi-agent
-->

# OpenClaw 多 Agent 实例配置

OpenClaw 支持在 **单个 Gateway 进程** 中运行多个完全隔离的 Agent，每个 Agent 拥有独立的 Workspace、会话存储、记忆索引和配置。无需启动多个 Gateway 进程。

## 核心概念

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

## 团队角色配置示例

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

## 各角色 Workspace 配置

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

## CLI 管理命令

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

## 路由匹配规则

路由按 **最具体匹配优先** 原则，评估顺序：

1. 精确 peer 匹配（指定的 DM/群组 ID）
2. 父级 peer 匹配（线程继承）
3. Guild ID + 角色（Discord）
4. Team ID（Slack）
5. Account ID 匹配
6. Channel 级别匹配（`accountId: "*"`）
7. 回退到默认 Agent（`default: true`）

同一 binding 中多个 match 字段为 **AND 逻辑**，所有条件都满足才匹配。

## 单渠道多 Agent 路由

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

## 可覆盖的 Agent 级配置

每个 Agent 可独立覆盖以下全局默认配置（**完全替换，非合并**）：

| 类别 | 可覆盖字段 |
|------|-----------|
| 工作区 | `workspace`、`skipBootstrap` |
| 模型 | `model.primary`、`model.fallbacks` |
| 工具 | `tools.profile`、`tools.allow`、`tools.deny` |
| 沙箱 | `sandbox.mode`、`sandbox.scope`、`sandbox.workspaceAccess` |
| 记忆 | `memorySearch.enabled`、`memorySearch.provider`、`memorySearch.extraPaths` |
| 行为 | `thinkingDefault`、`verboseDefault`、`contextTokens`、`heartbeat` |
