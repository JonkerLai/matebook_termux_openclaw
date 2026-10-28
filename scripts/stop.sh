#!/data/data/com.termux/files/usr/bin/bash
# stop.sh — 停止服务
#   ./stop.sh          停止全部（逆序）
#   ./stop.sh gateway  只停某一个
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

stop_one() {
  local n="$1"
  case "$n" in
    wakelock)    termux-wake-unlock 2>/dev/null; log "$n" "wake-lock released" ;;
    sshd)        pkill -x sshd 2>/dev/null; log "$n" "stopped" ;;
    ollama)      pkill -x ollama 2>/dev/null; log "$n" "stopped" ;;
    gateway)     pkill -f 'openclaw[-]gateway' 2>/dev/null; log "$n" "stopped" ;;
    tunnel)      pkill -f 'cloudflared tunne[l].*18789' 2>/dev/null; log "$n" "stopped" ;;
    origin)      rm -f "$SERVICES_DIR/.origin-synced"; log "$n" "cleared" ;;
    watchdog)    pkill -f 'openclaw[-]watchdog' 2>/dev/null; log "$n" "stopped" ;;
    dufs)        pkill -f 'bin/duf[s]' 2>/dev/null; log "$n" "stopped" ;;
    dufs-tunnel) pkill -f 'cloudflared tunne[l].*'"$DUFS_PORT" 2>/dev/null; log "$n" "stopped" ;;
    pstatusd)    pkill -f 'bin/pstatus[d]' 2>/dev/null; log "$n" "stopped" ;;
    *)           log "$n" "unknown service"; return 1 ;;
  esac
  return 0
}

TARGET="$1"
if [ -n "$TARGET" ]; then
  stop_one "$TARGET"
  echo "done: $TARGET"
  exit 0
fi

# 逆序：先停看门狗，否则它会把服务拉回来
for n in watchdog origin dufs-tunnel tunnel gateway dufs pstatusd ollama sshd wakelock; do
  stop_one "$n"
  echo "stopped: $n"
done