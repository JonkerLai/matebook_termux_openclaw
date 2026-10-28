#!/data/data/com.termux/files/usr/bin/bash
# start.sh — 服务总调度
# 用法：
#   ./start.sh             启动所有「已启用」的服务
#   ./start.sh gateway     只启动某一个
#   ./start.sh --list      列出服务与开关状态
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

TARGET="$1"

if [ "$TARGET" = "--list" ] || [ "$TARGET" = "list" ]; then
  printf "%-14s %-8s %s\n" "SERVICE" "ENABLED" "SCRIPT"
  for f in "$SERVICES_DIR"/[0-9][0-9]-*.sh; do
    [ -e "$f" ] || continue
    n=$(basename "$f" .sh); n=${n#*-}
    e=$(enabled "$n")
    [ "$e" = "1" ] && s="on" || s="off"
    printf "%-14s %-8s %s\n" "$n" "$s" "$(basename "$f")"
  done
  exit 0
fi

# 全量启动时加锁，避免多标签重复执行
if [ -z "$TARGET" ]; then
  LOCK="$SERVICES_DIR/.lock"
  if [ -d "$LOCK" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || echo 0) ))
    [ "$age" -lt 120 ] && exit 0
  fi
  mkdir -p "$LOCK" 2>/dev/null
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT
  log "start-all" "=== begin ==="
fi

FAIL=0
for f in "$SERVICES_DIR"/[0-9][0-9]-*.sh; do
  [ -e "$f" ] || continue
  n=$(basename "$f" .sh); n=${n#*-}

  [ -n "$TARGET" ] && [ "$TARGET" != "$n" ] && continue
  if [ "$(enabled "$n")" != "1" ]; then
    log "$n" "已禁用，跳过"
    continue
  fi

  bash "$f" || FAIL=$((FAIL + 1))
done

if [ -n "$TARGET" ]; then
  exit $FAIL
fi

log "start-all" "=== done (failed: $FAIL) ==="