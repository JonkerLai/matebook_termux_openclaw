#!/data/data/com.termux/files/usr/bin/bash
# openclaw-watchdog.sh — 每 60 秒巡检，异常自动拉起
# 关键点：网关冷启动 55-90 秒，必须给宽限期，否则会把自己的启动过程杀掉
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

GW_FAIL=0
GW_GRACE=0
OLL_FAIL=0

log "watchdog" "started (pid $$)"

while true; do
  now=$(date +%s)

  # ---------- Gateway ----------
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 8 "http://127.0.0.1:$OPENCLAW_PORT/" 2>/dev/null)
  if [ "$code" = "200" ]; then
    [ "$GW_FAIL" -ne 0 ] && log "gateway" "recovered"
    GW_FAIL=0
  elif [ "$now" -lt "$GW_GRACE" ]; then
    :   # 宽限期内忽略
  else
    GW_FAIL=$((GW_FAIL + 1))
    log "gateway" "unhealthy ($GW_FAIL/3, code=$code)"
    if [ "$GW_FAIL" -ge 3 ]; then
      log "gateway" "restarting after 3 failures"
      bash "$PAD_DIR/openclaw-start.sh" >/dev/null 2>&1
      GW_GRACE=$(( $(date +%s) + 180 ))
      GW_FAIL=0
    fi
  fi

  # ---------- Ollama ----------
  if ! curl -s -o /dev/null -m 5 http://127.0.0.1:11434/api/tags 2>/dev/null; then
    OLL_FAIL=$((OLL_FAIL + 1))
    if [ "$OLL_FAIL" -ge 2 ]; then
      log "ollama" "restarting"
      setsid nohup ollama serve >> "$HOME/ollama-serve.log" 2>&1 &
      OLL_FAIL=0
      sleep 8
    fi
  else
    OLL_FAIL=0
  fi

  # ---------- sshd ----------
  pgrep -x sshd >/dev/null 2>&1 || { log "sshd" "restarting"; sshd >/dev/null 2>&1; }

  # ---------- 面板隧道 ----------
  if ! pgrep -f "cloudflared tunne[l].*$OPENCLAW_PORT" >/dev/null 2>&1; then
    log "tunnel" "restarting"
    setsid nohup cloudflared tunnel --no-autoupdate \
      --url "http://127.0.0.1:$OPENCLAW_PORT" > "$HOME/cloudflared.log" 2>&1 &
    sleep 15
    log "tunnel" "url: $(public_url "$HOME/cloudflared.log")"
  fi

  # ---------- 文件服务隧道 ----------
  if ! pgrep -f "cloudflared tunne[l].*$DUFS_PORT" >/dev/null 2>&1; then
    log "dufs-tunnel" "restarting"
    bash "$PAD_DIR/start.sh" dufs-tunnel >/dev/null 2>&1
  fi

  # ---------- dufs ----------
  if ! pgrep -f 'bin/duf[s]' >/dev/null 2>&1; then
    log "dufs" "restarting"
    bash "$PAD_DIR/start.sh" dufs >/dev/null 2>&1
  fi

  termux-wake-lock 2>/dev/null || true

  sleep 60
done