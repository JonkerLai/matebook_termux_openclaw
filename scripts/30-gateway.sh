#!/data/data/com.termux/files/usr/bin/bash
# 30-gateway — OpenClaw Gateway（核心进程）
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
NAME=gateway
SETTLE=2

check() {
  # 必须「有进程」且「HTTP 200」：旧进程 drain 期间也会应答，只看端口会误判
  [ "$(proc 'openclaw[-]gateway')" -ge 1 ] && [ "$(http "http://127.0.0.1:$OPENCLAW_PORT/")" = "200" ]
}

start() {
  bash "$PAD_DIR/openclaw-start.sh" >/dev/null 2>&1
}

. "$SERVICES_DIR/_run.sh"