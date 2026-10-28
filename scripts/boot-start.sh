#!/data/data/com.termux/files/usr/bin/bash
# ~/.termux/boot/start.sh — 开机自启（Termux:Boot 会执行这个目录下的所有脚本）
# 实际逻辑复用 ~/services/start.sh，保持单一入口
export PATH="$HOME/.local/bin:$PREFIX/bin:$PATH"
LOG="$HOME/boot.log"

{
  echo "======================================"
  echo "[$(date '+%F %T')] boot start"

  termux-wake-lock 2>/dev/null

  # 等网络真正就绪（最多 60 秒）
  for i in $(seq 1 30); do
    if ping -c 1 -W 1 223.5.5.5 >/dev/null 2>&1; then
      echo "[$(date '+%F %T')] network ready (${i}x2s)"
      break
    fi
    sleep 2
  done

  bash "$HOME/pad-agent/start.sh"
  echo "[$(date '+%F %T')] services start finished"
  bash "$HOME/pad-agent/status.sh"
} >> "$LOG" 2>&1
