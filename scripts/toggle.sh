#!/data/data/com.termux/files/usr/bin/bash
# toggle.sh — 开关某个服务
#   ./toggle.sh <service> on|off
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

if [ $# -ne 2 ]; then
  echo "usage: toggle.sh <service> on|off"
  echo "services: $(ls "$SERVICES_DIR"/[0-9][0-9]-*.sh 2>/dev/null | xargs -n1 basename | sed 's/^[0-9]*-//;s/\.sh$//' | tr '\n' ' ')"
  exit 1
fi

NAME_ARG="$1"
case "$2" in
  on|1|enable)   VAL=1 ;;
  off|0|disable) VAL=0 ;;
  *) echo "second arg must be on|off"; exit 1 ;;
esac

if ! grep -qE "^$NAME_ARG[[:space:]]" "$CONF_SERVICES" 2>/dev/null; then
  echo "unknown service: $NAME_ARG"
  exit 1
fi

sed -i -E "s/^($NAME_ARG)[[:space:]]+[01]/\1 $VAL/" "$CONF_SERVICES"
log "toggle" "$NAME_ARG -> $VAL"

if [ "$VAL" = "1" ]; then
  echo "enabled: $NAME_ARG (run ./start.sh $NAME_ARG to start now)"
else
  echo "disabled: $NAME_ARG (running process is NOT stopped; use ./stop.sh $NAME_ARG)"
fi