<!--
markmeta_author: tiltwind
markmeta_date: 2026-02-25
markmeta_title: OpenClaw Skills 技能扩展
markmeta_categories: ai
markmeta_tags: ai,openclaw,agent,skills
-->

# OpenClaw Skills 技能扩展

Skills 是 OpenClaw 的能力扩展机制，通过 `SKILL.md` 文件定义。

## 安装社区技能

```bash
# 从 ClawHub 安装
openclaw skills install <skill-name>

# 手动安装：克隆到 workspace/skills/
git clone <skill-repo> ~/.openclaw/workspace/skills/<skill-name>
```

## 技能目录

技能按三个层级加载（优先级从高到低）：
1. **workspace skills**（`~/.openclaw/workspace/skills/`）—— 用户自定义，优先级最高
2. **managed skills** —— 通过 ClawHub 安装的社区技能
3. **bundled skills** —— 内置技能
