#!/data/data/com.termux/files/usr/bin/bash
# install.sh — 一键安装到当前用户家目录
# 用法（在仓库根目录）：
#   bash scripts/install.sh
set -e

SRC="$(cd "$(dirname "$0")" && pwd)"
DST="$HOME/pad-agent"

say() { printf '\033[36m[pad-agent]\033[0m %s\n' "$*"; }

say "安装到 $DST"
mkdir -p "$DST"

# 1) 复制脚本
cp -f "$SRC"/*.sh "$DST"/ 2>/dev/null || true
chmod +x "$DST"/*.sh 2>/dev/null || true

# 2) 配置文件（不覆盖已有）
if [ ! -f "$DST/config.env" ]; then
  cp "$SRC/../config/config.env.example" "$DST/config.env"
  say "已生成 config.env（可用编辑器修改）"
fi

# 3) 服务开关
if [ ! -f "$DST/services.conf" ]; then
  cp "$DST/services.conf.example" "$DST/services.conf"
  say "已生成 services.conf"
fi

# 4) dufs 用户表
if [ ! -f "$DST/dufs-users.conf" ]; then
  cp "$DST/dufs-users.conf.example" "$DST/dufs-users.conf"
  chmod 600 "$DST/dufs-users.conf"
  say "已生成 dufs-users.conf（请修改密码！）"
fi

# 5) 可选脚本
[ -f "$DST/80-pstatusd.sh.example" ] && rm -f "$DST/80-pstatusd.sh.example"

# 6) bashrc 钩子
if ! grep -q 'pad-agent autostart' "$HOME/.bashrc" 2>/dev/null; then
  cp -a "$HOME/.bashrc" "$HOME/.bashrc.bak.$(date +%s)" 2>/dev/null || true
  cat >> "$HOME/.bashrc" <<'EOF'

# pad-agent autostart — 打开 Termux 自动拉起全部服务
if [ -x "$HOME/pad-agent/start.sh" ]; then
  case "$-" in
    *i*) setsid nohup "$HOME/pad-agent/start.sh" >/dev/null 2>&1 < /dev/null & ;;
  esac
fi
EOF
  say "已写入 .bashrc 自启钩子"
fi

# 7) 目录
mkdir -p "$HOME/nas"/{backups,documents,media,photos,shared}

cat <<EOF

$(say "安装完成")

下一步：
  1. 编辑配置      nano $DST/config.env
  2. 改 dufs 密码   nano $DST/dufs-users.conf
  3. 看状态         $DST/status.sh
  4. 启动全部       $DST/start.sh

可选：
  · 装 termux-api（安卓工具能力）  pkg install termux-api
  · 装 Termux:Boot（开机自启）     见 docs/quickstart.md
  · 装 dufs（文件服务）            见 docs/quickstart.md

EOF