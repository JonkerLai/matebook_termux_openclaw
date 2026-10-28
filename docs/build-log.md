# 改造记录：从一台闲置平板到 7×24 在线智能体

> 完整踩坑记录。时间跨度约 22 小时，其中大半时间花在排障上。
> 如果你要复现，建议先看 [quickstart.md](quickstart.md)，这份文档告诉你**为什么这么做**。
> 只想快速避坑，直接看 **[android-pitfalls.md](android-pitfalls.md)**。

---

## 起点

一台华为 MatePad Pro（Kirin 990 / 8 GB / Android 12），闲置中。
目标：**把它变成一台随时能访问的个人 AI 服务器**。

约束条件：

- 不能 root
- 不能刷机
- 数据要留在自己手里
- 要能在外网访问

---

## 阶段 1：图形界面（Termux:X11）

### 做了什么

1. 下载 Termux:X11 的 nightly 构建（GitHub 直连不通，用镜像代理 + 断点续传）
2. 校验 SHA-256，推到平板安装
3. 启动 Xfce 桌面

### 遇到的坑

| 现象 | 原因 |
|---|---|
| `X server stalled`，画面卡死 | 见阶段 2 |
| 菜单里没有终端 | `.desktop` 文件是空壳，需要装 `xfce4-terminal` |
| Firefox 启动崩溃 | `libc++` 版本与构建不匹配 → `pkg upgrade` 升级 72 个包 |

---

## 阶段 2：诊断「画面卡死」

### 现象

桌面用一会就卡住，鼠标不动，但 SSH 还活着。

### 排查过程

写了个脚本，每秒探测一次 X11 协议握手（发 12 字节 setup 请求看响应）：

```python
# 简化版：能不能连上 X server
s = socket.create_connection(('127.0.0.1', 6000), timeout=2)
s.sendall(b'l\x00' + struct.pack('<HHHH', 11, 0, 0, 0) + b'\x00\x00')
reply = s.recv(8)   # 0 = 成功
```

结果：**握手 0 ms 返回**，说明 X server 本身活着。

再看 logcat，发现同一个窗口尺寸事件每 12 秒重复一次 → 渲染线程停了。

### 真正的原因

关键认知：**Termux:X11 的 X server 是 Termux 的子进程**。

```
Termux (App)
 └─ termux-x11 (X server)
     └─ Xfce
```

Android 的省电机制会**冻结后台 App**，Termux 一冻结，X server 跟着停。

### 验证方法

写了个心跳脚本，每 10 秒写一次时间戳。
切到 X11 前台 → 心跳断档 3–8 秒 → 证明被冻结。

### 解决

1. 系统设置 → 应用启动管理 → 手动管理（自启动 + 关联启动 + 后台活动全开）
2. `termux-wake-lock` 保持唤醒

复测：132 秒内 3 轮切换 + 60 秒独占，**零断档**。

---

## 阶段 3：Termux 自己会突然重启

### 现象

跑着跑着 Termux 退出，SSH 断开，服务全没。

### 原因

Android 12 的 **phantom process killer**：任何 App 的子进程超过 32 个，系统直接杀掉整个进程组。

Termux 里跑 Node + 一堆 worker，轻松超 32。

### 解决（需要 adb）

```bash
adb shell settings put global settings_enable_monitor_phantom_procs false
adb shell device_config put activity_manager max_phantom_processes 2147483647
```

### 插曲：adb 不认设备

华为平板在 Windows 上驱动异常（Code 39）。查下来是华为自带的 `ew_usbccgpfilter.inf`（2016 年的老驱动）把 USB 复合设备搞坏了。
删掉该驱动包，重新扫描硬件，回落系统 `usbccgp` 驱动 → 正常。

---

## 阶段 4：桌面环境打磨

写了 `start-desktop.sh`，做了三件对的事：

1. **真连一次 X11 协议**判断就绪（而不是只看 socket 文件存在）
2. 关掉 xfwm4 合成器（省内存、避免撕裂）
3. 日志落盘，方便排障

修掉的三个 bug（都是坑）：

| bug | 教训 |
|---|---|
| 进程匹配写 `termux-x11`，实际 cmdline 是 `termux-x11 com.termux.x11 :0` | 用 `pgrep -f` 前先 `ps` 看一眼真实命令行 |
| 看到 socket 文件存在就认为服务好了 | 文件存在 ≠ 已 listen，必须真连一次 |
| `pkill -f` 匹配到自己的 SSH 命令，把自己杀了 | **`pkill -f` 会匹配自己的命令行**，见下方 |

### ⚠️ pkill 自杀陷阱（踩了 4 次）

```bash
pkill -f 'openclaw-watchdog'
```

如果你的 shell 命令行里也含这个字符串，**它会把你自己杀掉**。

三种解法：

```bash
# 1. 括号技巧（命令本身不含字面量）
pkill -f 'openclaw[-]watchdog'

# 2. 先取 PID 再 kill
kill -9 $(pgrep -f 'openclaw[-]watchdog')

# 3. 写成脚本文件执行（最稳）
bash ~/pad-agent/stop.sh watchdog
```

---

## 阶段 5：中文界面

### 第一次尝试（失败）

Termux 的包编译时加了 `--disable-nls`，`share/locale` 里一个中文翻译都没有。
改 `LANG=zh_CN.UTF-8` 完全无效。

### 第二次尝试（成功）

用 `proot-distro` 装 Debian 12 + Xfce 4.18 + Noto CJK 字体。

又遇到坑：proot 下 `libxcb` 连不上 X socket（抽象命名空间问题）。

**解法**：用 socat 把 unix socket 转成本地 TCP：

```bash
socat TCP-LISTEN:6000,bind=127.0.0.1,fork,reuseaddr \
  UNIX-CONNECT:$PREFIX/tmp/.X11-unix/X0
# 容器里用 DISPLAY=127.0.0.1:0
```

---

## 阶段 6：OpenClaw 落地

### 错误的路线

先在 proot Debian 里装 Node 24 + OpenClaw → 网关启动失败：

```
different PID namespace
Gateway lock owner identity could not be verified
```

OpenClaw 用「PID 命名空间 + 进程标识」做单实例锁，proot 下拿不到。

### 正确的路线

**Termux 原生 Node 26 + OpenClaw** → 网关 33 秒启动成功。

### 又一个坑：插件装不了

```
temp workspace directory "/data" has an untrusted owner uid 1000
```

OpenClaw 的 `fs-safe` 安全检查认为 `/data`（Android 系统目录）不可信，拒绝安装插件。

**解法**：打补丁 —— 让 uid 1000（Android system）被视为可信祖先：

```javascript
// 修改 assertTrustedTempWorkspaceDirectory
if (Number(stat.uid) === 1000) return; // Android system-owned ancestors
```

同时把目录权限收紧：

```bash
chmod 700 /data/data/com.termux/files
```

> ⚠️ 这个补丁会被 `npm update` 覆盖，升级后要重打。

---

## 阶段 7：能力扩展

| 能力 | 方案 | 坑 |
|---|---|---|
| 联网搜索 | DuckDuckGo 插件 | 需要能访问 duckduckgo.com |
| 长期记忆 | Ollama + `nomic-embed-text` | `sqlite-vec` 没有 android-arm64 包 → 向量检索降级为 FTS |
| 多模型 | DeepSeek chat + reasoner | 向导走不通，用 `config patch` 直接写 |

---

## 阶段 8：Kimi 通道（失败案例）

装了官方的 Kimi 安装器，踩了两个坑：

1. Termux 没有 `which` 命令 → 安装器报「未找到 openclaw」
2. 安装器写了**旧版配置键** `plugins.installs` → OpenClaw 判定配置非法 → **整个网关起不来**

手工把插件装上了，但服务端握手失败：

```
Subscribe returned incomplete Connect envelope
```

原因：该通道只支持 OpenClaw ≤ 2026.4.14，而设备是 2026.10.7。

**结论**：放弃，但留下了一个教训 ——
**装插件前先看它支持的 OpenClaw 版本范围**。

---

## 阶段 9：安卓设备能力

### Termux:API 装不上

```
安装包签名与共享用户的应用签名不一致
```

Termux 系 App 声明了 `sharedUserId`，必须同签名：
F-Droid 版 Termux 只能配 F-Droid 版插件；混装必败。

**解法**：改用 GitHub 的 `+github.debug` 版本。

### MCP 接入

```bash
git clone https://github.com/YSCodex/termux-mcp
openclaw mcp add termux --command node --arg .../termux-mcp.mjs --arg=--stdio
openclaw mcp probe termux     # 56 个工具
```

用 **stdio 传输**，不额外开端口，避免再暴露一个服务面。

---

## 阶段 10：7×24 在线

### 看门狗

每 60 秒巡检 ollama / gateway / sshd / cloudflared / dufs。

**第一版是错的**：每 60 秒检查一次，但网关冷启动要 60–65 秒，
结果看门狗每次都把**刚启动的网关杀掉**，形成死循环：

```
stopped after SIGTERM 3 times in 5 min:
another supervisor may be managing this Gateway
```

**修正**：180 秒启动宽限 + 连续 3 次失败才重启。

### 公网访问

Cloudflare 快速隧道（免费、无需账号）：

```bash
cloudflared tunnel --url http://127.0.0.1:18789
```

遇到的三个问题：

| 问题 | 解法 |
|---|---|
| 网关拒绝代理来源 | `gateway.trustedProxies = ["127.0.0.1/32"]` |
| 面板报「来源不被允许」 | `gateway.controlUi.allowedOrigins` 加隧道域名 |
| 隧道地址每次变 | 写脚本自动同步白名单 |

### 自启

`.bashrc` 挂钩子 → 打开 Termux 自动 `start.sh`（带 120 秒并发锁）。

实测：全部杀掉后模拟打开 Termux，**130 秒后所有服务恢复**。

---

## 阶段 11：微信通道

腾讯官方插件（`@tencent-weixin/openclaw-weixin`）：

```bash
npx -y @tencent-weixin/openclaw-weixin-cli@latest install
```

- 扫码登录成功
- 配了白名单 `dmPolicy=allowlist`
- 出站消息实测能收到

> 目前只验证了出站；入站需要有人给 bot 发消息才会触发。

---

## 阶段 12：文件服务

### SMB 走不通

445 端口 < 1024，需要 root → **Android 上不可能提供原生 SMB**。

### dufs 的坑

| 现象 | 原因 | 解法 |
|---|---|---|
| `Failed to get local interface addresses` | `--bind 0.0.0.0` 要枚举网卡，被拒 | 绑具体 IP |
| 探测 IP 拿到 172.x | `ip addr` 被禁，备用逻辑选中了 VPN 接口 | 用 `ifconfig` + 优先 192.168 |
| `Invalid auth value` | 只读权限写成 `:r` | 只读用**不带后缀** |
| Windows 挂载报 1244 | WebClient 不允许 http 基础认证 | 改注册表 + 加 AuthForwardServerList |

### 最后选了 SFTP

Windows 用 SSHFS-Win 挂成 `Y:` 盘，比 WebDAV 快得多，而且不用改注册表。

```
Y: → Termux 家目录（\\sshfs\...）
S: → 手机存储      （\\sshfs.r\...\storage\emulated\0）
```

> `sshfs.r` 的 `.r` 表示「从根目录开始」，能跳出 home 目录。

---

## 阶段 13：重构与清理

### 模块化

从一个大脚本拆成：

```
lib.sh（公共）+ _run.sh（执行器）+ 9 个服务脚本 + 4 个调度器
```

好处：加服务 = 加一个文件；开关 = 改一行配置。

### 清理

| 项目 | 节省 |
|---|---|
| npm 缓存 | 754 MB |
| 废弃插件残留 | 24 MB |
| 已安装的 APK | 19 MB |
| 一次性脚本（105 个） | 420 KB |
| 日志截断 | 2 MB |
| **合计** | **约 800 MB** |

### 清理引发的两个故障

| 故障 | 原因 | 教训 |
|---|---|---|
| 网关起不来 | 删了 `~/.openclaw/tmp`，里面有运行锁 | **删目录前先看有没有运行态** |
| 配置校验失败 | 删了插件目录，配置里还引用它 | 删插件要走 uninstall 或同步清配置 |

---

## 最后一次事故：cron 死循环

### 现象

AI 回复失败（`couldn't finish this reply`），CPU 100%+，日志 38 MB。

### 排查

日志里 35,830 条同样的错误：

```
cron: timer tick failed
Error: cron run cannot acquire a durable fence without process start identity
```

### 原因

OpenClaw 的 cron 调度器需要「进程启动标识」做锁，函数读 `/proc/<pid>/stat`，
Android 的 SELinux 限制导致返回 null → 每 2 秒抛异常 → 事件循环被占满。

### 解决

```bash
openclaw config set cron.enabled false
```

结果：cron 报错归零，日志 38 MB → 112 KB，回复恢复正常。

---

## 最终形态

```
9 个常驻服务
56 个安卓工具
4 个访问入口（微信 / 网页 / 文件 / 桌面）
2 条公网隧道
1 个看门狗
约 500 MB 磁盘占用
```

## 如果重来一次，我会这样优化顺序

1. **先关电池优化和 phantom killer**（不做这个，后面全是白费）
2. **OpenClaw 只用原生 Termux**（别试 proot，浪费 2 小时）
3. **文件服务直接上 SFTP**（WebDAV 在 Windows 上太难搞）
4. **看门狗第一版就要加宽限期**（否则会把好的服务杀成坏的）
5. **每个新服务都先写 check() 再写 start()**（可观测性优先）