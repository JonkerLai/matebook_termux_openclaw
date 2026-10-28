# 安卓平台十大坑（部署前必读）

> 这些不是 OpenClaw 的问题，也不是 Termux 的问题，是 **Android 作为消费级系统 ≠ 服务器** 带来的系统级限制。
> 不解决这些，后面所有服务都会莫名其妙挂掉。

按「你必须先做什么」排序。

---

## 坑 1：后台被冻结（最常见的「假死」）

### 现象

- 跑一会儿服务就停，SSH 断开
- App 切到后台 30 秒再回来，进度没了
- **X server 卡死、画面不动但 SSH 还活着**

### 根因

Android 的省电策略会**冻结后台 App 的进程**（freeze，不是 kill）。被冻结的进程：
- 不执行任何代码
- 不响应网络
- 但 socket 还在，`ps` 看起来「活着」

**关键认知：Termux:X11 的 X server 是 Termux 的子进程**。Termux 一冻结，X server 跟着停 → 桌面卡死。

### 验证方法（心跳探针）

写一个每 10 秒打点的小脚本，放后台：

```bash
nohup bash -c 'while true; do date +%s >> ~/heartbeat.log; sleep 10; done' &
```

然后切到别的 App / 切到 X11 桌面，5 分钟后回来：

```bash
awk 'NR>1{print $1-prev} {prev=$1}' ~/heartbeat.log | sort -n | tail -5
```

- 间隔都是 **10 秒** → 没被冻结 ✅
- 出现 **13、18、25 秒** 的断档 → 被冻结了 ❌

### 解法（按优先级）

**① 应用启动管理改「手动管理」**（华为/荣耀必做）

```
设置 → 应用和服务 → 应用管理 → Termux → 耗电详情 / 启动管理
  → 关闭「自动管理」
  → 手动勾选：自启动 ✅ 关联启动 ✅ 后台活动 ✅
```

其他品牌路径：

| 品牌 | 关键词 |
|---|---|
| 小米/Redmi | 设置 → 应用设置 → 应用管理 → Termux → 省电策略 → 无限制 |
| OPPO/一加 | 设置 → 电池 → 应用耗电管理 → Termux → 允许后台运行 |
| vivo | 设置 → 电池 → 后台高耗电 → 允许 |
| 三星 | 设置 → 电池 → 后台使用限制 → 从「休眠应用」移除 |

**② 关闭电池优化**

```
设置 → 应用 → Termux → 电池 → 不限制 / 无限制
```

**③ 保持唤醒锁**

```bash
termux-wake-lock        # 本项目脚本已自动执行
```

**④ 充电时不锁屏**（可选，能进一步减少降频）

```
开发者选项 → 充电时不锁定屏幕 / 保持唤醒
```

### 验证

改完再跑一次心跳测试，确认断档消失。

实测：华为平板改完后 132 秒内 3 轮切换 + 60 秒独占，**零断档**。

---

## 坑 2：Termux 自己突然重启（幽灵进程杀手）

### 现象

- 服务跑着跑着整个 Termux 退出
- SSH 断开，重连发现所有服务都没了
- logcat 里没有崩溃日志

### 根因

**Android 12 引入的 phantom process killer**：任何 App 的子进程（含线程组）超过 **32 个**，系统直接杀掉整个进程组。

Termux 里 Node 服务 + worker + 编译进程，轻松超 32。

### 解法（需要 adb）

```bash
adb shell settings put global settings_enable_monitor_phantom_procs false
adb shell device_config put activity_manager max_phantom_processes 2147483647
```

验证：

```bash
adb shell dumpsys activity settings | grep -i phantom
```

看到 `max_phantom_processes=2147483647` 就成功。

### 没有 adb 怎么办

- Android 12L / 13 部分机型可在「开发者选项 → 关闭子进程限制」找到
- 否则只能靠坑 1 的保活手段，并且**减少同时运行的服务数**

### 附：Windows 上 adb 不认设备

华为平板常见：设备管理器显示「未知设备 / 代码 39」。

原因：华为自带的 `ew_usbccgpfilter.inf`（2016 年的老驱动）破坏了 USB 复合设备。

解决：

1. 设备管理器 → 找到该驱动包 → 卸载（勾选「删除驱动程序软件」）
2. 扫描硬件改动
3. 系统回落到 `usbccgp` → 出现「ADB Interface」
4. 平板上确认「允许 USB 调试」

> 另：华为「多屏协同」会抢占 ADB，弹窗时选「取消」。

---

## 坑 3：Termux:X11 装上就打不开 / 卡死

### 现象

- 桌面启动后黑屏
- `X server stalled` 提示
- 鼠标不动，但 Termux 里命令还能跑

### 根因（两个）

1. **坑 1 的冻结**（X server 是 Termux 子进程）
2. Termux:X11 的 App 与 Termux 主程序需要**同签名**（F-Droid 或 GitHub 二选一，不能混）

### 安装步骤

1. Termux 装好后，去 [Termux:X11 Releases](https://github.com/termux/termux-x11/releases) 下载 `termux-x11-universal-debug.apk`
2. 安装（如果报签名冲突，说明 Termux 来源不匹配）
3. 在 Termux 里启动 X server：

```bash
pkg install -y x11-repo
pkg install -y termux-x11-nightly
termux-x11 :0 &
```

4. 打开 **Termux:X11** 应用（不是 Termux）看画面

### 判断 X server 是否真的活着（别只看进程）

socket 文件存在 ≠ 服务可用。用协议握手验证：

```python
import socket, struct
s = socket.create_connection(('127.0.0.1', 6000), timeout=2)
s.sendall(b'l\x00' + struct.pack('<HHHH', 11, 0, 0, 0) + b'\x00\x00')
reply = s.recv(8)
print('status =', reply[0])   # 0 = 成功
```

- 返回 0（几十毫秒内）→ X server 正常
- 超时 → 真挂了

### 桌面卡顿的额外优化

```bash
xfconf-query -c xfwm4 -p /general/use_compositing -s false
```

关掉窗口合成器，省内存、减少撕裂。

### proot 容器里连不上 X（进阶）

在 proot Debian 里跑图形程序会报 `Can't open display`，因为 libxcb 走的是**抽象 unix socket**，proot 下不通。

解法：用 socat 转成本地 TCP：

```bash
socat TCP-LISTEN:6000,bind=127.0.0.1,fork,reuseaddr \
  UNIX-CONNECT:$PREFIX/tmp/.X11-unix/X0 &
# 容器里：export DISPLAY=127.0.0.1:0
```

---

## 坑 4：Termux:API 装不上（签名不一致）

### 现象

```
安装失败
共享同一个用户的应用需要使用相同签名，
安装包的签名与共享用户的应用签名不一致
```

### 根因

Termux 系 App 都声明了 `sharedUserId="com.termux"`，**必须同一把密钥签名**：

| Termux 来自 | 配套 App 必须来自 |
|---|---|
| F-Droid | F-Droid |
| GitHub（`+github.debug`） | GitHub |
| 应用商店改包 | ❌ 基本无解，建议重装 |

### 判断自己的 Termux 是哪个版本

```bash
pm list packages -i com.termux
```

- `installer=org.fdroid.fdroid` → F-Droid 版
- `installer=com.android.packageinstaller` → 侧载（可能是 GitHub 版，也可能被改包）

### 解法

```bash
# 1. 装命令行包
pkg install -y termux-api

# 2. 装 API App（同签名版本）
#    F-Droid 版：https://f-droid.org/packages/com.termux.api/
#    GitHub 版：https://github.com/termux/termux-api/releases

# 3. 打开 App 一次，授权（相机/麦克风/位置/通知按需给）

# 4. 验证
termux-battery-status
termux-toast "hello"
```

### 权限说明

| 权限 | 对应能力 | 建议 |
|---|---|---|
| 相机 | 拍照 | 按需 |
| 麦克风 | 录音 | 按需 |
| 位置 | 定位 | 按需 |
| 通知 | 发通知 | 建议给 |
| 通讯录 / 短信 | 读取 | ⚠️ 谨慎，一般不给 |

---

## 坑 5：Termux:Boot 同样有签名问题

### 现象

装完重启，服务没自启。

### 三个常见原因

1. **签名不匹配**（同坑 4）
2. **装完没打开过一次** → 没注册开机广播接收器
3. **Termux 被「强制停止」过** → 系统禁止它再次自启

### 正确步骤

1. 装同签名的 Termux:Boot
2. **手动打开一次**（很重要）
3. 脚本放对位置：

```bash
mkdir -p ~/.termux/boot
cp ~/pad-agent/boot-start.sh ~/.termux/boot/start.sh
chmod +x ~/.termux/boot/start.sh
```

4. 重启，检查 `~/boot.log`

---

## 坑 6：安卓没有 `/tmp`

### 现象

脚本报 `No such file or directory: /tmp/xxx`，或 `mkdir: cannot create directory '/tmp': Read-only file system`。

### 根因

Android 根文件系统只读，没有可写的 `/tmp`。

### 解法

统一用 `$PREFIX/tmp`（即 `/data/data/com.termux/files/usr/tmp`）：

```bash
export TMPDIR="$PREFIX/tmp"
# 写进 ~/.bashrc 一劳永逸
```

> 本项目所有脚本已经规避了这个问题。但如果你自己写的脚本、或者跑的第三方安装器用了 `/tmp`，就会挂。

---

## 坑 7：Termux 没有 `which` 命令

### 现象

第三方安装器报「未找到 openclaw」，但你明明装了。

### 根因

Termux 默认不带 `which`（bash 内置的 `command -v` 有，但很多脚本调用外部 `which`）。

### 解法

```bash
pkg install -y which
```

---

## 坑 8：绑不了 1024 以下的端口

### 现象

```bash
PermissionError: [Errno 13] Permission denied     # 绑 445
```

### 根因

Linux 规定 <1024 端口需要 root，Termux 没有 root。

**所以：Android 上不可能提供原生 SMB（445）**。

### 替代方案

| 需求 | 方案 | 端口 |
|---|---|---|
| 文件共享 | SFTP（sshd 内置） | 8022 |
| 网页文件管理 | dufs | 5000 |
| WebDAV | dufs | 5000 |
| SSH | sshd | 8022 |

> 这也是为什么 Windows 的「网络邻居」里永远看不到这台平板。

---

## 坑 9：分区存储（/sdcard 只能写不能读）

### 现象

```bash
ls /sdcard/Download      # Permission denied
touch /sdcard/Download/x # 成功
```

能创建文件，却列不出目录。

### 根因

Android 11+ 的分区存储（Scoped Storage）。没有「所有文件访问」权限时，App 只能用自己创建的文件，不能遍历别人的目录。

### 解法

```
设置 → 应用 → Termux → 权限 → 文件和媒体
  → 允许管理所有文件（All files access）
```

或者重新跑：

```bash
termux-setup-storage
```

### 验证

```bash
ls /sdcard | head
termux-battery-status
```

---

## 坑 10：`pkill -f` 会杀掉自己

### 现象

SSH 里执行 `pkill -f 'openclaw-watchdog'`，SSH 直接断开，命令没执行完。

### 根因

`pkill -f` 匹配**完整命令行**。你这条 SSH 命令的命令行里也包含那个字符串 → **匹配到自己** → 自杀。

我在这上面踩了 4 次。

### 三种解法

```bash
# 1. 括号技巧：命令行里不含字面量
pkill -f 'openclaw[-]watchdog'

# 2. 先取 PID 再杀
kill -9 $(pgrep -f 'openclaw[-]watchdog')

# 3. 写成脚本文件执行（最稳）
bash ~/pad-agent/stop.sh watchdog
```

> ⚠️ 注意：括号技巧在「你的命令行里同时出现完整字符串」时依然会自杀。
> 比如 `pgrep -f 'cloufflared tunnel'` 后面又 `pkill -f 'cloudflared tunnel'`，两条都有字面量。
> 最保险还是第 3 种。

---

## 附：环境自检脚本

把下面存成 `~/check-android.sh` 跑一遍，能提前发现大部分问题：

```bash
#!/data/data/com.termux/files/usr/bin/bash
echo "=== 基础 ==="
echo "Android: $(getprop ro.build.version.release) (SDK $(getprop ro.build.version.sdk))"
echo "设备:    $(getprop ro.product.model)"
echo "内存:    $(free -m | awk 'NR==2{print $2" MB"}')"

echo
echo "=== 存储权限 ==="
ls /sdcard >/dev/null 2>&1 && echo "  ✅ 可读 /sdcard" || echo "  ❌ 不能读 /sdcard（坑 9）"

echo
echo "=== 幽灵进程限制 ==="
V=$(getprop persist.sys.phantom_process_max 2>/dev/null)
[ -n "$V" ] && echo "  max_phantom_processes=$V" || echo "  未设置（坑 2，需要 adb）"

echo
echo "=== termux-api ==="
command -v termux-battery-status >/dev/null && echo "  ✅ 命令行已装" || echo "  ❌ pkg install termux-api"
timeout 5 termux-battery-status >/dev/null 2>&1 && echo "  ✅ App 通信正常" || echo "  ❌ App 未装或未授权（坑 4）"

echo
echo "=== X11 ==="
command -v termux-x11 >/dev/null && echo "  ✅ 已装" || echo "  ⚠️ 未装（可选）"

echo
echo "=== 端口占用 ==="
for p in 8022 5000 18789; do
  (echo >/dev/tcp/127.0.0.1/$p) 2>/dev/null && echo "  $p 已占用" || echo "  $p 空闲"
done
```