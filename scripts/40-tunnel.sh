#!/data/data/com.termux/files/usr/bin/bash
# 40-tunnel — OpenClaw 面板的公网隧道
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
NAME=tunnel
SETTLE=15

CFLOG="$HOME/cloudflared.log"

check() { pgrep -f "cloudflared tunne[l].*$OPENCLAW_PORT" >/dev/null 2>&1; }

start() {
  setsid nohup cloudflared tunnel --no-autoupdate \
    --url "http://127.0.0.1:$OPENCLAW_PORT" > "$CFLOG" 2>&1 &
}

. "$SERVICES_DIR/_run.sh"
echo "public url: $(public_url "$CFLOG")"