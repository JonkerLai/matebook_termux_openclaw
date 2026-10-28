#!/data/data/com.termux/files/usr/bin/bash
# start-desktop-zh.sh — 启动 proot Debian 里的中文 Xfce 桌面
# 用法: ./start-desktop-zh.sh [start|stop]
set -u

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
XSOCK="$PREFIX/tmp/.X11-unix/X0"
LOG="$HOME/zh-session.log"
DISP_PORT=6000

log() {
  local msg="[$(date +%H:%M:%S)] $*"
  printf '%s\n' "$msg"
  printf '%s\n' "$msg" >> "$LOG" 2>/dev/null
}

x_ready() {
  [ -S "$XSOCK" ] || return 1
  python3 - "$XSOCK" <<'PY' 2>/dev/null
import socket, struct, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(2)
try:
    s.connect(sys.argv[1])
    s.sendall(b'l\x00' + struct.pack('<HHHH', 11, 0, 0, 0) + b'\x00\x00')
    sys.exit(0 if s.recv(1) else 1)
except Exception:
    sys.exit(1)
PY
}

ensure_socat() {
  if pgrep -f "[s]ocat TCP-LISTEN:$DISP_PORT" >/dev/null 2>&1; then
    return 0
  fi
  pkill -f "[s]ocat TCP-LISTEN:$DISP_PORT" 2>/dev/null
  setsid nohup socat "TCP-LISTEN:$DISP_PORT,bind=127.0.0.1,fork,reuseaddr" \
        "UNIX-CONNECT:$XSOCK" >/dev/null 2>&1 &
  sleep 2
  pgrep -f "[s]ocat TCP-LISTEN:$DISP_PORT" >/dev/null 2>&1
}

start_all() {
  termux-wake-lock 2>/dev/null || true

  if x_ready; then
    log "X server 已在 :0"
  else
    log "启动 X server :0"
    nohup termux-x11 :0 -dpi 96 >>"$LOG" 2>&1 &
    for _ in $(seq 1 60); do x_ready && break; sleep 0.5; done
    x_ready || { log "错误: X server 未就绪，见 $LOG"; return 1; }
    log "X server 就绪"
  fi

  # 关掉 Termux 侧英文 Xfce
  pkill -f '[x]fce4-session' 2>/dev/null
  pkill -f '[x]fwm4' 2>/dev/null
  pkill -f '[x]fdesktop' 2>/dev/null
  pkill -f '[x]fce4-panel' 2>/dev/null
  sleep 2

  if ensure_socat; then
    log "X 转发端口 127.0.0.1:$DISP_PORT 就绪"
  else
    log "警告: socat 未能启动"
  fi

  log "启动 Debian 中文 Xfce..."
  nohup proot-distro login debian \
        -e "DISPLAY=127.0.0.1:0" \
        -e LANG=zh_CN.UTF-8 \
        -e LANGUAGE=zh_CN:zh \
        -e XMODIFIERS=@im=none \
        -- dbus-launch --exit-with-session startxfce4 >>"$LOG" 2>&1 &

  for _ in $(seq 1 40); do
    pgrep -f '[x]fce4-session' >/dev/null 2>&1 && break
    sleep 1
  done
  if pgrep -f '[x]fce4-session' >/dev/null 2>&1; then
    log "桌面已启动（中文）"
  else
    log "警告: 桌面未起来，见 $LOG"
  fi
}

case "${1:-start}" in
  start) start_all ;;
  stop)
    pkill -f '[x]fce4-session' 2>/dev/null
    pkill -f '[x]fwm4' 2>/dev/null
    pkill -f '[x]fdesktop' 2>/dev/null
    pkill -f '[x]fce4-panel' 2>/dev/null
    pkill -f "[s]ocat TCP-LISTEN:$DISP_PORT" 2>/dev/null
    termux-wake-unlock 2>/dev/null || true
    log "已停止"
    ;;
  *) echo "用法: $0 [start|stop]"; exit 1 ;;
esac
