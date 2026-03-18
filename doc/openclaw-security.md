<!--
markmeta_author: tiltwind
markmeta_date: 2026-02-25
markmeta_title: OpenClaw 安全加固
markmeta_categories: ai
markmeta_tags: ai,openclaw,agent,security
-->

# OpenClaw 安全加固

## 默认安全机制

- **Gateway 绑定**：默认绑定 `127.0.0.1`，不对外暴露
- **配对认证**：DM 默认需要配对码审批
- **沙箱隔离**：非主会话在 Docker 容器中执行工具
- **只读根文件系统**：沙箱容器 `readOnlyRoot: true`
- **网络隔离**：沙箱默认 `network: "none"`

## 安全检查

```bash
# 运行安全诊断
openclaw doctor
```

`openclaw doctor` 会检查：
- Gateway 运行状态
- Auth Token 配置
- 沙箱镜像是否存在
- 绑定地址安全性
- DM 策略风险

## 生产环境建议

- 使用 Docker 部署，不在本地机器直接运行
- 启用沙箱模式隔离工具执行
- 通过 SSH 隧道或 Tailscale 访问 Gateway，避免公网暴露
- 定期检查 `openclaw doctor` 输出

```bash
# 通过 SSH 隧道从本地访问远程 Gateway
ssh -N -L 18789:127.0.0.1:18789 user@<server-ip>
```
