<!--
markmeta_author: tiltwind
markmeta_date: 2026-02-25
markmeta_title: OpenClaw systemd 服务管理
markmeta_categories: ai
markmeta_tags: ai,openclaw,agent,systemd
-->

# OpenClaw systemd 服务管理

`openclaw onboard --install-daemon` 会自动创建 systemd 用户服务。手动管理方式：

```bash
# 查看服务状态
systemctl --user status openclaw

# 启停服务
systemctl --user start openclaw
systemctl --user stop openclaw
systemctl --user restart openclaw

# 查看日志
journalctl --user -u openclaw -f

# 确保用户服务在注销后仍运行（关键）
loginctl enable-linger $USER
```

> `enable-linger` 非常重要，它确保 systemd 用户服务在 SSH 断开后继续运行。
