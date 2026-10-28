#!/data/data/com.termux/files/usr/bin/bash
# start-desktop.sh — 启动 / 停止 Termux:X11 + Xfce4 桌面
# 用法: ./start-desktop.sh [start|stop|restart]
set -u

export DISPLAY=:0
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
XSOCK="$PREFIX/tmp/.X11-unix/X0"
LOG="$HOME/x11-session.log"

# 这些进程的 comm 都是 main，只能按 cmdline 匹配
X11_PAT='termux-x11 com\.termux\.x11'
XFCE_PAT='^xfce4-session'

log() {
  local msg="[$(date +%H:%M:%S)] $*"
  printf '%s\n' "$msg"
  printf '%s\n' "$msg" >> "$LOG" 2>/dev/null
}

running() { pgrep -f "$1" >/dev/null 2>&1; }

# 真正能连上 X server 才算就绪（socket 文件出现 ≠ 已经 listen）
x_ready() {
  [ -S "$XSOCK" ] || return 1
  python3 - "$XSOCK" <<'PY' 2>/dev/null
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(1)
try:
    s.connect(sys.argv[1])
    s.sendall(b'l\x00' + b'\x0b\x00\x00\x00' + b'\x00\x00\x00\x00' + b'\x00\x00')
    sys.exit(0 if s.recv(1) else 1)
except Exception:
    sys.exit(1)
PY
}

wait_x() {
  for _ in $(seq 1 60); do
    x_ready && return 0
    sleep 0.5
  done
  return 1
}

stop_all() {
  log "停止旧会话..."
  pkill -f "$X11_PAT" 2>/dev/null
  pkill -f "$XFCE_PAT" 2>/dev/null
  for _ in $(seq 1 20); do
    running "$X11_PAT" || running "$XFCE_PAT" || break
    sleep 0.3
  done
  rm -f "$PREFIX/tmp/.X0-lock" 2>/dev/null
  return 0
}

start_all() {
  # Termux 被 EMUI 冻结会连带停掉 X server，wake-lock 必须挂着
  termux-wake-lock 2>/dev/null || true

  if x_ready && running "$X11_PAT"; then
    log "X server 已在 :0 运行，复用"
  else
    log "启动 X server :0"
    nohup termux-x11 :0 -dpi 96 >>"$LOG" 2>&1 &
    if ! wait_x; then
      log "错误: X server 未就绪（60 次探测失败），见 $LOG"
      return 1
    fi
    log "X server 就绪"
  fi

  # 关掉 Xfce 合成器，明显减少卡顿/闪屏
  xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true

  if running "$XFCE_PAT"; then
    log "Xfce 桌面已在运行"
  else
    log "启动 Xfce4 桌面"
    nohup startxfce4 >>"$LOG" 2>&1 &
    for _ in $(seq 1 30); do
      running "$XFCE_PAT" && break
      sleep 0.5
    done
    if ! running "$XFCE_PAT"; then
      log "首次启动失败，改用 dbus-launch 重试"
      nohup dbus-launch --exit-with-session startxfce4 >>"$LOG" 2>&1 &
      for _ in $(seq 1 30); do
        running "$XFCE_PAT" && break
        sleep 0.5
      done
    fi
    running "$XFCE_PAT" && log "桌面已启动" || log "警告: xfce4-session 未起来，见 $LOG"
  fi

  log "完成 — 切到 Termux:X11 app 查看桌面"
}

case "${1:-start}" in
  start)   start_all ;;
  restart) stop_all; start_all ;;
  stop)    stop_all; termux-wake-unlock 2>/dev/null || true; log "已停止" ;;
  *)       echo "用法: $0 [start|stop|restart]"; exit 1 ;;
esac
