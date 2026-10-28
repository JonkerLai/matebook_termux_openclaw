#!/data/data/com.termux/files/usr/bin/bash
# status.sh — 状态面板（只读，不启动任何服务）
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

printf "%-14s %-8s %-8s %s\n" "SERVICE" "ENABLED" "STATE" "NOTE"
printf "%-14s %-8s %-8s %s\n" "-------" "-------" "-----" "----"

for f in "$SERVICES_DIR"/[0-9][0-9]-*.sh; do
  [ -e "$f" ] || continue
  n=$(basename "$f" .sh); n=${n#*-}
  e=$(enabled "$n")
  [ "$e" = "1" ] && sw="on" || sw="off"

  if [ "$n" = "wakelock" ]; then
    st="n/a"
  else
    if SERVICE_CHECK_ONLY=1 bash "$f" >/dev/null 2>&1; then st="up"; else st="DOWN"; fi
  fi

  note=""
  case "$n" in
    gateway)  note="http $(http "http://127.0.0.1:$OPENCLAW_PORT/")" ;;
    ollama)   note="http $(http http://127.0.0.1:11434/api/tags)" ;;
    tunnel)   note=$(public_url "$HOME/cloudflared.log") ;;
    dufs-tunnel) note=$(public_url "$HOME/dufs-tunnel.log") ;;
    pstatusd) note="http $(http "http://127.0.0.1:$PSTATUS_PORT/api/status")" ;;
  esac

  printf "%-14s %-8s %-8s %s\n" "$n" "$sw" "$st" "$note"
done