#!/data/data/com.termux/files/usr/bin/bash
# 60-watchdog — 巡检自愈（常驻，每 60 秒）
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
NAME=watchdog
SETTLE=2

check() { pgrep -f 'openclaw[-]watchdog' >/dev/null 2>&1; }

start() {
  setsid nohup bash "$PAD_DIR/openclaw-watchdog.sh" >/dev/null 2>&1 &
}

. "$SERVICES_DIR/_run.sh"