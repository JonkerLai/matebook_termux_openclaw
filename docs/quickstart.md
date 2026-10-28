# 快速开始：从一台空平板到跑通

> 全程约 1–2 小时，其中 OpenClaw 网关首次启动要等 60 秒左右。

---

## 0. 准备

| 项目 | 要求 |
|---|---|
| Android | 9 以上（12+ 体验最好） |
| 内存 | 4 GB 起，8 GB 推荐 |
| 网络 | 能访问 GitHub / npm |
| 电脑 | 可选，用于 SSH 调试 |

---

## 1. 装 Termux（务必用 F-Droid 版）

1. 打开 https://f-droid.org/packages/com.termux/ 下载 APK
2. 安装后**打开一次**，让它初始化

> ❌ 不要用 Google Play 版（已停止更新，签名也不兼容 Termux:API）
> ❌ 不要用国内应用商店的改包版（签名不同，装不了配套插件）

### 可选配套 App

| App | 用途 | 必须 |
|---|---|---|
| [Termux:API](https://f-droid.org/packages/com.termux.api/) | 安卓能力（电量/通知/相机） | 想要设备控制就装 |
| [Termux:Boot](https://f-droid.org/packages/com.termux.boot/) | 开机自启 | 想要无人值守就装 |
| [Termux:X11](https://github.com/termux/termux-x11/releases) | 图形桌面 | 想要桌面就装 |

> ⚠️ 如果 APK 装不上提示「签名不一致」，说明你的 Termux 不是 F-Droid 版。
> 解决办法：卸载重装 F-Droid 版，或者配套 App 也换成同来源的 GitHub 版。

---

## 2. 系统级设置（关键，不做会反复掉线）

### 2.1 关闭电池优化

```
设置 → 应用 → Termux → 电池 → 不限制 / 允许后台活动
```

各家 ROM 路径不同，关键词是「电池优化 / 后台限制 / 自启动」。

### 2.2 允许自启动和后台活动

```
设置 → 应用 → Termux → 权限 / 启动管理
  ✅ 自启动
  ✅ 关联启动
  ✅ 后台活动
```

### 2.3 关闭「幽灵进程杀手」（Android 12+）

有 adb 的话最省事：

```bash
adb shell settings put global settings_enable_monitor_phantom_procs false
adb shell device_config put activity_manager max_phantom_processes 2147483647
```

没有 adb 就只能靠 2.1 / 2.2 尽量保住进程。

### 2.4 保持 WLAN 连接

```
设置 → WLAN → 高级 → 休眠时保持 WLAN 连接 → 始终
```

### 2.5 验证「冻结」是否真的解决了（很重要）

光改设置不算数，要实测。跑个心跳探针：

```bash
nohup bash -c 'while true; do date +%s >> ~/heartbeat.log; sleep 10; done' &
```

然后**切到别的 App、锁屏、再切回来**，5 分钟后：

```bash
awk 'NR>1{print $1-prev} {prev=$1}' ~/heartbeat.log | sort -n | tail -5
```

| 输出 | 判断 |
|---|---|
| 都是 10 左右 | ✅ 没被冻结 |
| 出现 15、30、120 | ❌ 还在冻结，回去检查 2.1–2.3 |

清理探针：

```bash
pkill -f 'heartbeat[.]log'
```

### 2.6 不同品牌的设置路径

| 品牌 | 路径关键词 |
|---|---|
| 华为 / 荣耀 | 设置 → 应用和服务 → 应用管理 → Termux → 启动管理 → 关闭「自动管理」，勾选自启动/关联启动/后台活动 |
| 小米 / Redmi | 设置 → 应用设置 → Termux → 省电策略 → 无限制；右上角「其他权限 → 后台弹出界面」允许 |
| OPPO / 一加 | 设置 → 电池 → 应用耗电管理 → Termux → 允许后台运行 |
| vivo / iQOO | 设置 → 电池 → 后台高耗电 → 允许 |
| 三星 | 设置 → 电池 → 后台使用限制 → 从休眠列表中移除 |

> 各版本 ROM 措辞会变，**认准「自启动」「后台运行」「不受限制」这几个词**。

> ⚠️ 这里只列了最容易踩的几项。完整清单（含 Termux:X11、Termux:API、Termux:Boot
> 的签名问题、/tmp、端口限制、分区存储等）见 **[android-pitfalls.md](android-pitfalls.md)**。

---

## 3. 装基础环境

打开 Termux：

```bash
pkg update && pkg upgrade -y
pkg install -y git nodejs-lts curl openssh
```

验证：

```bash
node -v      # 需要 >= 22
git --version
```

### 开启 SSH（方便电脑操作，可选）

```bash
sshd
# 默认监听 8022
passwd       # 设置一个密码
ifconfig     # 看本机 IP
```

电脑上：

```bash
ssh -p 8022 <Termux用户名>@<平板IP>
```

---

## 4. 装 OpenClaw

```bash
npm install -g openclaw
openclaw --version
```

> 国内网络慢的话先换源：
> `npm config set registry https://registry.npmmirror.com`

### 第一次初始化

```bash
openclaw doctor
```

按提示走完向导（选模型、填 API key）。

### 配 DeepSeek（如果向导没配成功）

```bash
cat > /tmp/ds.json5 <<'EOF'
{
  models: {
    providers: {
      deepseek: {
        baseUrl: "https://api.deepseek.com",
        api: "openai-completions",
        apiKey: "sk-你的key",
        models: [
          { id: "deepseek-chat", name: "DeepSeek Chat" },
          { id: "deepseek-reasoner", name: "DeepSeek Reasoner", reasoning: true }
        ]
      }
    }
  },
  agents: { defaults: { model: "deepseek/deepseek-chat" } }
}
EOF
openclaw config patch --file /tmp/ds.json5
openclaw config validate
```

### 关闭 cron（Android 上会死循环）

```bash
openclaw config set cron.enabled false
```

> 原因：cron 调度器需要「进程启动标识」，Android 拿不到，会每 2 秒报错一次。

### 启动网关

```bash
openclaw gateway --port 18789 --bind lan
```

浏览器打开 `http://<平板IP>:18789`，输入 token：

```bash
openclaw gateway auth-token --show
```

能看到界面就说明 AI 通了。

---

## 5. 安装本项目

```bash
git clone <YOUR_REPO_URL> pad-agent-src
cd pad-agent-src
bash scripts/install.sh
```

安装脚本会：

- 复制脚本到 `~/pad-agent/`
- 生成 `config.env` / `services.conf` / `dufs-users.conf`
- 写入 `.bashrc` 自启钩子
- 创建 `~/nas/{backups,documents,media,photos,shared}`

然后：

```bash
nano ~/pad-agent/config.env        # 一般不用改（IP 会自动探测）
nano ~/pad-agent/dufs-users.conf   # 改掉示例密码！
~/pad-agent/status.sh
~/pad-agent/start.sh
```

---

## 6. 文件服务（dufs）

### 装 dufs

```bash
mkdir -p ~/bin
# 从 GitHub Releases 下载 aarch64 版本
curl -L -o ~/bin/dufs https://github.com/sigoden/dufs/releases/latest/download/dufs-aarch64-unknown-linux-musl
chmod +x ~/bin/dufs
~/bin/dufs --version
```

### 启动

```bash
~/pad-agent/start.sh dufs
```

访问 `http://<平板IP>:5000`，用 `dufs-users.conf` 里的账号登录。

### 挂载到 Windows（SFTP，推荐）

```cmd
net use Y: \\sshfs\<用户名>@<平板IP>!8022 /user:<用户名> <密码> /persistent:yes
net use S: \\sshfs.r\<用户名>@<平板IP>!8022\storage\emulated\0 /user:<用户名> <密码> /persistent:yes
```

需要先安装 [WinFsp](https://github.com/winfsp/winfsp/releases) 和 [SSHFS-Win](https://github.com/winfsp/sshfs-win/releases)。

| 盘 | 内容 |
|---|---|
| `Y:` | Termux 家目录 |
| `S:` | 手机存储（照片/下载） |

---

## 7. 微信通道（可选）

```bash
npx -y @tencent-weixin/openclaw-weixin-cli@latest install
```

会弹出二维码，用手机微信扫码即可。

装完建议设白名单：

```bash
openclaw config set channels.openclaw-weixin.dmPolicy allowlist
openclaw config set channels.openclaw-weixin.allowFrom '["你的微信ID@im.wechat"]'
```

> 微信 ID 从日志里看：`openclaw channels logs --channel openclaw-weixin`

---

## 8. 公网访问

```bash
pkg install -y cloudflared
cloudflared tunnel --url http://127.0.0.1:18789
```

几秒后会打印一个 `https://xxx.trycloudflare.com`，外网就能打开面板。

> 地址每次重启会变。想固定要自备域名 + Cloudflare 命名隧道。

---

## 9. 安卓设备控制（可选）

```bash
pkg install -y termux-api
# 再装 Termux:API App，打开一次并授权
```

然后接 MCP：

```bash
git clone https://github.com/YSCodex/termux-mcp.git ~/termux-mcp
cd ~/termux-mcp && npm install --omit=dev
openclaw mcp add termux \
  --command "$(command -v node)" \
  --arg "$HOME/termux-mcp/bin/termux-mcp.mjs" \
  --arg=--stdio
openclaw mcp probe termux      # 应该看到几十个工具
```

---

## 10. 开机自启（可选）

1. 装 **Termux:Boot**（F-Droid）并**打开一次**
2. 复制开机脚本：

```bash
mkdir -p ~/.termux/boot
cp ~/pad-agent/boot-start.sh ~/.termux/boot/start.sh
chmod +x ~/.termux/boot/start.sh
```

重启平板后，看 `~/boot.log` 确认是否自动跑起来了。

---

## 完成检查清单

```bash
~/pad-agent/status.sh      # 服务应该全部 up
~/pad-agent/full-health.sh # 端口 / 内存 / 公网地址
```

- [ ] 面板能打开（局域网）
- [ ] 面板能打开（公网）
- [ ] dufs 网页能登录
- [ ] Windows 挂上了 Y: / S:
- [ ] 微信能对话（可选）
- [ ] 重启后服务自动恢复（需 Termux:Boot）

有问题看 **[troubleshooting.md](troubleshooting.md)**。