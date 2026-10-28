# -
termux+openclaw 平板改造
termux-pad-agent
> 把一台闲置的 Android 平板，改造成 **7×24 小时在线的个人 AI 智能体 + 文件服务器**。
> 不 root、不刷机、数据全在自己手里。
![Platform](https://img.shields.io/badge/platform-Android%2012%2B-brightgreen)
[![No Root](https://img.shields.io/badge/root-not%20required-blue)]()
![License](https://img.shields.io/badge/license-MIT-green)
---
这是什么
一套跑在 Termux 里的服务编排脚本，把下面这些能力组装成一台「平板服务器」：
能力	说明
🤖 AI 智能体	基于 OpenClaw，默认接 DeepSeek
💬 微信对话	官方微信通道插件，扫码即用（可选）
📱 安卓设备控制	截屏、拍照、剪贴板、电量、通知等 56 个工具（MCP）
🌐 公网访问	Cloudflare Tunnel，无需公网 IP / 端口映射
📁 文件服务	网页 + WebDAV，手机/电脑可挂载
🖥️ Linux 桌面	Xfce 图形界面（可选，proot Debian）
🛡️ 自愈	看门狗每 60 秒巡检，挂了自动拉起
🚀 一键自启	打开 Termux 自动启动全套服务
---
⚠️ 部署前必读
Android 不是服务器系统，有四件事必须先做，否则后面全白费：
关掉电池优化 / 后台限制 —— 不然 App 会被冻结，服务假死
应用启动管理改「手动管理」 —— 华为/荣耀必做
关闭幽灵进程杀手（Android 12+，需 adb）—— 不然 Termux 会被系统杀掉
配套 App 必须同签名 —— Termux:API / Termux:X11 / Termux:Boot 都受此限制
完整清单（含验证方法）见 docs/android-pitfalls.md。
---
硬件要求
项目	最低	推荐
Android	9	12+（12+ 需要处理幽灵进程杀手）
内存	4 GB	8 GB
存储	2 GB 可用	8 GB 可用
网络	能访问 GitHub	同左
> 实测机型：华为 MatePad Pro（Kirin 990 / 8 GB / Android 12）
---
快速开始（5 步）
```bash
# 1. 装 Termux（F-Droid 版，别用 Google Play 版）
#    https://f-droid.org/packages/com.termux/

# 2. 基础依赖
pkg update && pkg install -y git nodejs-lts curl

# 3. 装 OpenClaw
npm install -g openclaw
openclaw --version

# 4. 拉本项目并安装
git clone <YOUR_REPO_URL> pad-agent-src
cd pad-agent-src
bash scripts/install.sh

# 5. 启动
~/pad-agent/start.sh
~/pad-agent/status.sh
```
详细步骤见 docs/quickstart.md，
想按「检查点」一步步复现（推荐首次部署）见 docs/reproduction-guide.md。
---
我想… 看哪篇
你的目标	看这份文档
第一次部署，怕踩坑	docs/android-pitfalls.md ← 先看这个
一步步复现，每步有验收标准	docs/reproduction-guide.md
快速装起来（跳过原理）	docs/quickstart.md
日常怎么用	docs/operations-manual.md
报错了怎么修	docs/troubleshooting.md
想装图形桌面	docs/desktop-setup.md
理解为什么这样设计	docs/architecture.md
完整踩坑复盘	docs/build-log.md
拍视频 / 写文章	docs/media-script.md
> 阅读顺序建议：**pitfalls → reproduction-guide → operations-manual**。
---
目录结构
```
termux-pad-agent/
├── config/
│   └── config.env.example      # 配置模板（装完复制成 ~/pad-agent/config.env）
├── scripts/
│   ├── install.sh              # 一键安装
│   ├── lib.sh                  # 公共函数（配置加载 / 日志 / IP 探测）
│   ├── _run.sh                 # 服务执行器
│   ├── start.sh stop.sh status.sh toggle.sh
│   ├── 00-wakelock.sh … 75-dufs-tunnel.sh   # 每个服务一个脚本
│   ├── openclaw-start.sh       # 启动网关
│   ├── openclaw-watchdog.sh    # 巡检自愈
│   ├── start-desktop.sh        # 英文桌面
│   ├── start-desktop-zh.sh     # 中文桌面（proot Debian）
│   ├── fix-origin.sh           # 隧道地址变了同步白名单
│   ├── full-health.sh          # 全量体检
│   ├── share.sh                # 导出文件到手机 Download
│   └── boot-start.sh           # 开机自启（配合 Termux:Boot）
└── docs/
    ├── android-pitfalls.md     # ⚠️ 安卓十大坑（部署前必读）
    ├── reproduction-guide.md   # 逐步复现（26 个 checkpoint）
    ├── quickstart.md           # 从零到跑通
    ├── architecture.md         # 架构与端口
    ├── desktop-setup.md        # 图形桌面安装（X11 / 中文桌面）
    ├── operations-manual.md    # 日常操作手册
    ├── build-log.md            # 改造记录（踩坑全记录）
    ├── troubleshooting.md      # 故障排查
    └── media-script.md         # 自媒体口播脚本
```
---
服务一览
服务	端口	作用	默认
`wakelock`	—	防 Android 冻结 Termux	开
`sshd`	8022	SSH / SFTP	开
`ollama`	11434	本地 embedding（记忆）	开
`gateway`	18789	OpenClaw 主进程	开
`tunnel`	—	AI 面板公网隧道	开
`origin`	—	同步面板白名单	开
`watchdog`	—	巡检自愈	开
`dufs`	5000	文件服务（网页 + WebDAV）	开
`dufs-tunnel`	—	文件服务公网隧道	开
---
常用命令
```bash
~/pad-agent/status.sh            # 状态
~/pad-agent/start.sh             # 启动全部
~/pad-agent/start.sh gateway     # 启动单个
~/pad-agent/stop.sh              # 停止全部
~/pad-agent/toggle.sh dufs off   # 永久禁用某服务
~/pad-agent/full-health.sh       # 全量体检
```
---
重要提醒
> ⚠️ **本项目的服务如果暴露到公网，等于把你的一台电脑交出去。**
> 默认配置只绑定局域网；开隧道前请务必：
> 1. 改掉 `dufs-users.conf` 里的示例密码
> 2. 网关 token 不要外泄（`openclaw config get gateway.auth.token`）
> 3. 给面板加 Cloudflare Access（见 docs/troubleshooting.md）
---
已知限制（Android 平台）
限制	说明
不能绑定 <1024 端口	所以没有 SMB（445），文件共享用 WebDAV/SFTP
`sqlite-vec` 无 arm64 包	记忆语义检索降级为关键词
无 systemd	用 watchdog + Termux:Boot 代替
OpenClaw 定时任务不可用	需要进程启动标识，Android 拿不到
升级 OpenClaw 会覆盖补丁	插件安装需要重新打 fs-safe 补丁
---
贡献
欢迎提 Issue / PR。尤其欢迎：
更多机型适配记录
更省内存的配置方案
新的服务模块（如 Syncthing、Frp）
---
License
MIT
