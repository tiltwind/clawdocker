#!/usr/bin/env bash
set -euo pipefail

echo "=== 卸载 OpenClaw ==="

# STEP 1. 停止并移除 systemd 服务
echo "[1/4] 停止并移除 systemd 服务..."
systemctl --user stop openclaw-gateway 2>/dev/null && echo "  已停止 openclaw-gateway" || echo "  服务未运行，跳过"
systemctl --user disable openclaw-gateway 2>/dev/null && echo "  已禁用开机自启" || echo "  服务未启用，跳过"
rm -f ~/.config/systemd/user/openclaw-gateway.service
systemctl --user daemon-reload
echo "  systemd 配置已重新加载"

# STEP 2. 卸载 OpenClaw CLI
echo "[2/4] 卸载 OpenClaw CLI..."
if command -v openclaw &>/dev/null; then
    npm uninstall -g openclaw
    echo "  openclaw 已卸载"
else
    echo "  openclaw 未安装，跳过"
fi

# STEP 3. 清理配置文件
echo "[3/4] 清理配置文件..."
rm -rf ~/.openclaw
rm -rf ~/.config/openclaw
echo "  配置文件已清理"

# STEP 4. 验证卸载
echo "[4/4] 验证卸载..."
# 刷新 shell 的命令缓存
hash -r 2>/dev/null
if which openclaw 2>/dev/null | grep -q openclaw; then
    echo "  ⚠ openclaw 命令仍然存在: $(which openclaw)"
else
    echo "  openclaw 命令已移除"
fi

if systemctl --user list-unit-files openclaw-gateway.service 2>/dev/null | grep -q openclaw-gateway; then
    echo "  ⚠ openclaw-gateway 服务仍然存在"
else
    echo "  openclaw-gateway 服务已移除"
fi

echo ""
echo "=== 卸载完成 ==="
echo "如需卸载 Node.js，请执行: sudo apt remove -y nodejs && sudo apt autoremove -y"
