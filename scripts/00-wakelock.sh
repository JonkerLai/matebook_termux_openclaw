#!/data/data/com.termux/files/usr/bin/bash
# 00-wakelock — 防止 Android 冻结 Termux（没有查询接口，每次启动都重新申请）
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
NAME=wakelock

termux-wake-lock 2>/dev/null
RC=$?
if [ $RC -eq 0 ]; then
  log "$NAME" "wake-lock acquired ✓"
  exit 0
else
  log "$NAME" "failed (rc=$RC) — 需要安装 termux-api？"
  exit 1
fi