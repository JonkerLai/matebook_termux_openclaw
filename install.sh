#!/data/data/com.termux/files/usr/bin/bash
# 顶层快捷入口：等同 bash scripts/install.sh
exec bash "$(dirname "$0")/scripts/install.sh" "$@"