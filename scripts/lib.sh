#!/data/data/com.termux/files/usr/bin/bash
# lib.sh — 公共函数与配置加载（所有脚本都 source 它）

# 本目录（安装后是 ~/pad-agent）
PAD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PAD_DIR

export PATH="$HOME/.local/bin:$PREFIX/bin:$PATH"

# 配置文件
CONF="$PAD_DIR/config.env"
[ -f "$CONF" ] && . "$CONF"

LOG="$PAD_DIR/services.log"
SERVICES_DIR="$PAD_DIR"
CONF_SERVICES="$PAD_DIR/services.conf"

# 默认值兜底
: "${OPENCLAW_PORT:=18789}"
: "${DUFS_PORT:=5000}"
: "${PSTATUS_PORT:=8090}"
: "${SSH_PORT:=8022}"
: "${DUFS_SERVE_DIR:=$HOME/nas}"
: "${DUFS_USERS_FILE:=$PAD_DIR/dufs-users.conf}"

# ---------- 日志 ----------
log() { printf '[%s] %-12s %s\n' "$(date '+%F %T')" "$1" "$2" >> "$LOG"; }

# ---------- HTTP 探测 ----------
http() { curl -s -o /dev/null -w '%{http_code}' -m 4 "$1" 2>/dev/null || echo 000; }

# ---------- 进程计数 ----------
proc() { local n; n=$(pgrep -fc "$1" 2>/dev/null); echo "${n:-0}"; }

# ---------- 服务开关 ----------
# 读 services.conf：<名字> <1|0>
enabled() {
  local v
  v=$(awk -v n="$1" '$1==n {print $2}' "$CONF_SERVICES" 2>/dev/null)
  echo "${v:-1}"
}

# ---------- 探测本机局域网 IP ----------
# 说明：Android 上 `ip addr` 通常被 SELinux 拒绝，
#       `ifconfig` 不带参数反而能列出地址
detect_ip() {
  if [ -n "$TABLET_IP" ]; then
    echo "$TABLET_IP"
    return
  fi
  local all ip
  all=$(ifconfig 2>/dev/null | awk '/inet /{print $2}')
  ip=$(printf '%s\n' "$all" | grep -E '^192\.168\.' | head -1)
  [ -z "$ip" ] && ip=$(printf '%s\n' "$all" | grep -E '^10\.' | head -1)
  [ -z "$ip" ] && ip=$(printf '%s\n' "$all" | grep -E '^172\.(1[6-9]|2[0-9]|3[01])\.' | head -1)
  printf '%s' "$ip"
}

# ---------- 公网地址提取 ----------
public_url() {
  local f="${1:-$HOME/cloudflared.log}"
  grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$f" 2>/dev/null | tail -1
}