#!/data/data/com.termux/files/usr/bin/bash
# 10-sshd — SSH 服务（SFTP 也依赖它）
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
NAME=sshd

check() { pgrep -x sshd >/dev/null 2>&1; }
start() { sshd >/dev/null 2>&1; }

. "$SERVICES_DIR/_run.sh"