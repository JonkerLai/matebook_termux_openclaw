#!/data/data/com.termux/files/usr/bin/bash
# 20-ollama — 本地 embedding 服务（OpenClaw 记忆检索依赖）
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
NAME=ollama
SETTLE=2

check() { [ "$(http http://127.0.0.1:11434/api/tags)" = "200" ]; }

start() {
  setsid nohup ollama serve >> "$HOME/ollama-serve.log" 2>&1 &
  for _ in $(seq 1 25); do
    sleep 1
    [ "$(http http://127.0.0.1:11434/api/tags)" = "200" ] && return 0
  done
  return 1
}

. "$SERVICES_DIR/_run.sh"