#!/data/data/com.termux/files/usr/bin/bash
# 70-dufs — 文件服务（网页 + WebDAV）
# 用户与权限维护在 dufs-users.conf：每行 用户名:密码:rw|ro
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
NAME=dufs
SETTLE=3

check() { pgrep -f 'bin/duf[s]' >/dev/null 2>&1; }

start() {
  [ -x "$HOME/bin/dufs" ] || { log "$NAME" "missing ~/bin/dufs"; return 1; }
  [ -f "$DUFS_USERS_FILE" ] || { log "$NAME" "missing $DUFS_USERS_FILE"; return 1; }

  local ip
  ip=$(detect_ip)
  [ -z "$ip" ] && ip=127.0.0.1

  mkdir -p "$DUFS_SERVE_DIR"

  local -a AUTH_ARGS=()
  local u p perm
  while IFS=: read -r u p perm; do
    case "$u" in ''|\#*) continue ;; esac
    [ -z "$p" ] && continue
    case "$perm" in
      rw|RW|write) AUTH_ARGS+=("--auth" "$u:$p@/:rw") ;;
      *)           AUTH_ARGS+=("--auth" "$u:$p@/") ;;
    esac
  done < "$DUFS_USERS_FILE"

  if [ ${#AUTH_ARGS[@]} -eq 0 ]; then
    log "$NAME" "no valid user in $DUFS_USERS_FILE, refuse to start"
    return 1
  fi

  log "$NAME" "bind $ip:$DUFS_PORT serve=$DUFS_SERVE_DIR users=$((${#AUTH_ARGS[@]} / 2))"
  setsid nohup "$HOME/bin/dufs" "$DUFS_SERVE_DIR" \
    --bind "$ip" --port "$DUFS_PORT" \
    "${AUTH_ARGS[@]}" \
    --hidden ".ssh,.gnupg,.openclaw,.termux_authinfo,*.key,*.pem,.bash_history" \
    --allow-upload --allow-search --allow-archive \
    > "$HOME/dufs.log" 2>&1 &
}

. "$SERVICES_DIR/_run.sh"