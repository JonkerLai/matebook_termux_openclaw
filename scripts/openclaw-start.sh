#!/data/data/com.termux/files/usr/bin/bash
# openclaw-start.sh — 启动 Ollama + OpenClaw Gateway，并等待就绪
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

IP=$(detect_ip)
PORT="$OPENCLAW_PORT"
LOG="$HOME/oc-gw.log"

# 1) Ollama（记忆后端，没有也能跑，只是记忆降级）
if ! curl -s -o /dev/null -m 2 http://127.0.0.1:11434/api/tags 2>/dev/null; then
  echo "Ollama: 启动中…"
  setsid nohup ollama serve >> "$HOME/ollama-serve.log" 2>&1 &
  for _ in $(seq 1 15); do
    sleep 1
    curl -s -o /dev/null -m 2 http://127.0.0.1:11434/api/tags 2>/dev/null && break
  done
fi
curl -s -o /dev/null -m 2 http://127.0.0.1:11434/api/tags 2>/dev/null \
  && echo "Ollama: 就绪" || echo "Ollama: 未就绪（记忆会降级）"

# 2) 清掉残留网关（注意 pkill 模式用 [x] 避免匹配到自己）
pkill -f 'openclaw[-]gateway' 2>/dev/null
sleep 2

# 3) 后台启动
: > "$LOG"
setsid nohup openclaw gateway --allow-unconfigured --port "$PORT" --bind lan \
  >> "$LOG" 2>&1 &

# 4) 等就绪（冷启动通常 30–90 秒）
echo "等待 Gateway 就绪…"
for i in $(seq 1 40); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 3 "http://127.0.0.1:$PORT/" 2>/dev/null)
  if [ "$code" = "200" ]; then
    echo "网关就绪：HTTP 200（约 $((i * 3)) 秒）"
    echo "本机：http://127.0.0.1:$PORT"
    [ -n "$IP" ] && echo "局域网：http://$IP:$PORT"
    echo "实例数：$(pgrep -fc 'openclaw[-]gateway' 2>/dev/null || echo 0)"
    exit 0
  fi
  sleep 3
done

echo "网关启动超时（120 秒），请检查 $LOG"
tail -5 "$LOG"
exit 1