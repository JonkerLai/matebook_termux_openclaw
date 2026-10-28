#!/data/data/com.termux/files/usr/bin/bash
# _run.sh — 通用执行器
# 约定：调用它的服务脚本必须先定义 NAME / check() / start()

if [ "${SERVICE_CHECK_ONLY:-0}" = "1" ]; then
  check
  exit $?
fi

if check; then
  log "$NAME" "已经是运行状态"
  exit 0
fi

log "$NAME" "未运行，正在启动…"
start
sleep "${SETTLE:-3}"

if check; then
  log "$NAME" "启动成功 ✓"
  exit 0
else
  log "$NAME" "启动失败 ✗"
  exit 1
fi