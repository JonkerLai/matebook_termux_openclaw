#!/data/data/com.termux/files/usr/bin/bash
# 50-origin — 隧道地址变化后同步 Control UI 白名单（不重启网关）
# 用本地标记文件判断，避免每次都调用 openclaw config（很慢）
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
NAME=origin
SETTLE=1

STAMP="$SERVICES_DIR/.origin-synced"

check() {
  local url
  url=$(public_url "$HOME/cloudflared.log")
  [ -n "$url" ] || return 1
  [ -f "$STAMP" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$url" ]
}

start() {
  [ -x "$PAD_DIR/fix-origin.sh" ] && bash "$PAD_DIR/fix-origin.sh" >/dev/null 2>&1
  return 0
}

. "$SERVICES_DIR/_run.sh"