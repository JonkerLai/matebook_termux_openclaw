#!/data/data/com.termux/files/usr/bin/bash
# full-health.sh — 一次看全：服务 / 端口 / 进程 / 渠道 / 资源
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

IP=$(detect_ip)

echo "========== 服务 =========="
bash "$PAD_DIR/status.sh"

echo
echo "========== 端口 =========="
printf "%-22s %s\n" "gateway ($OPENCLAW_PORT)" "$(http "http://127.0.0.1:$OPENCLAW_PORT/")"
printf "%-22s %s\n" "ollama (11434)"           "$(http http://127.0.0.1:11434/api/tags)"
[ -n "$IP" ] && printf "%-22s %s\n" "dufs ($DUFS_PORT)" "$(http "http://$IP:$DUFS_PORT/")"
printf "%-22s %s\n" "sshd ($SSH_PORT)"         "$(pgrep -x sshd >/dev/null && echo up || echo down)"

echo
echo "========== 资源 =========="
free -m | head -2
df -h /data | tail -1

echo
echo "========== 公网地址 =========="
echo "  panel: $(public_url "$HOME/cloudflared.log")"
echo "  files: $(public_url "$HOME/dufs-tunnel.log")"

echo
echo "========== 最近日志 =========="
tail -4 "$LOG" 2>/dev/null