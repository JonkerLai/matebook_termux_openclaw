#!/data/data/com.termux/files/usr/bin/bash
# share.sh — 把文件复制到共享存储 Download（文件管理器可见）
# 用法: ./share.sh <路径> [...]
[ $# -eq 0 ] && { echo "usage: share.sh <file|dir> [...]"; exit 1; }

DEST="$HOME/storage/downloads"
mkdir -p "$DEST" 2>/dev/null

for src in "$@"; do
  [ -e "$src" ] || { echo "skip (not found): $src"; continue; }
  cp -r "$src" "$DEST/" 2>/dev/null \
    && echo "copied: $(basename "$src") -> Download/" \
    || echo "failed: $src (run termux-setup-storage first)"
done