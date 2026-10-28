#!/data/data/com.termux/files/usr/bin/bash
# 75-dufs-tunnel — 文件服务的公网隧道
# 注意：QUIC 在部分网络注册失败，用 http2 更稳
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
NAME=dufs-tunnel
SETTLE=18

CFLOG="$HOME/dufs-tunnel.log"

check() { pgrep -f "cloudflared tunne[l].*$DUFS_PORT" >/dev/null 2>&1 && grep -q 'Registered tunnel connection' "$CFLOG" 2>/dev/null; }

start() {
  local ip
  ip=$(detect_ip)
  [ -z "$ip" ] && { log "$NAME" "no lan ip"; return 1; }
  : > "$CFLOG"
  setsid nohup cloudflared tunnel --no-autoupdate --protocol http2 \
    --url "http://$ip:$DUFS_PORT" > "$CFLOG" 2>&1 &
}

. "$SERVICES_DIR/_run.sh"
echo "public url: $(public_url "$CFLOG")"