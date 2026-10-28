#!/data/data/com.termux/files/usr/bin/bash
# fix-origin.sh — 隧道地址变了以后，同步 Control UI 允许来源（热更新，不重启网关）
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

URL=$(public_url "$HOME/cloudflared.log")
if [ -z "$URL" ]; then
  echo "找不到隧道地址，先启动隧道："
  echo "  ./start.sh tunnel"
  exit 1
fi

echo "当前隧道: $URL"

IP=$(detect_ip)
TMP="$PREFIX/tmp/origins.$$.json5"
cat > "$TMP" <<EOF
{
  gateway: {
    controlUi: {
      allowedOrigins: [
        "$URL",
        "http://127.0.0.1:$OPENCLAW_PORT",
        "http://localhost:$OPENCLAW_PORT"$( [ -n "$IP" ] && printf ',\n        "http://%s:%s"' "$IP" "$OPENCLAW_PORT" )
      ]
    }
  }
}
EOF

openclaw config patch --file "$TMP" 2>&1 | tail -2
rm -f "$TMP"
echo "$URL" > "$PAD_DIR/.origin-synced"
echo "done: $URL"