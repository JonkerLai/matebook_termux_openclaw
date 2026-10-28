# 图形桌面（Termux:X11 + Xfce）

> 可选模块。想要「平板打开就是 Linux 桌面」就装，只用 AI/文件服务可以跳过。
> 装之前请先做完 **[android-pitfalls.md](android-pitfalls.md)** 的坑 1（后台冻结），否则桌面必卡死。

---

## 两种桌面，先选一个

| 方案 | 体积 | 中文化 | 稳定性 | 适合 |
|---|---|---|---|---|
| **A. Termux 原生 Xfce** | ~600 MB | ❌ 英文 | ⭐⭐⭐⭐ | 只要能跑图形程序 |
| **B. proot Debian + Xfce** | ~1.2 GB | ✅ 中文 | ⭐⭐⭐ | 需要中文界面 |

A 更稳更省资源；B 好看但多一层 proot。

---

## 第一部分：装 Termux:X11

### 1. 装 App（签名要和 Termux 一致）

| Termux 来源 | 下哪个 |
|---|---|
| F-Droid | F-Droid 的 Termux:X11 |
| GitHub | [termux-x11 Releases](https://github.com/termux/termux-x11/releases) 的 `universal-debug.apk` |

> 签名不匹配会装不上，见 pitfalls 坑 4。

### 2. 装 X server 和桌面

```bash
pkg install -y x11-repo
pkg install -y termux-x11-nightly xfce4 xfce4-terminal
```

### 3. 启动

```bash
# 手动跑（前台，方便看报错）
termux-x11 :0 -dpi 96 &
export DISPLAY=:0
startxfce4 &
```

然后**切到 Termux:X11 应用**看画面。

### 4. 用脚本启动（推荐）

项目自带 `start-desktop.sh`：

```bash
cp ~/pad-agent-src/scripts/start-desktop.sh ~/pad-agent/
chmod +x ~/pad-agent/start-desktop.sh
~/pad-agent/start-desktop.sh restart
```

脚本做了三件对的事：

1. **真连一次 X11 协议**判断就绪（不是只看进程在不在）
2. 关闭窗口合成器（省内存、减少撕裂）
3. 日志写 `~/x11-session.log`，出问题有据可查

---

## 第二部分：中文桌面（proot Debian）

### 1. 装 proot-distro 和 Debian

```bash
pkg install -y proot-distro
proot-distro install debian
```

### 2. 进容器装桌面

```bash
proot-distro login debian -- bash -c "
  apt update &&
  apt install -y --no-install-recommends \
    xfce4 xfce4-terminal dbus-x11 \
    fonts-noto-cjk locales &&
  sed -i 's/^# *zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen &&
  locale-gen
"
```

> 容器里没有 `ca-certificates` 时 https 源会失败，可以先换 http 源。

### 3. 关键坑：proot 里连不上 X socket

容器里的 libxcb 走**抽象 unix socket**，proot 下不通，会报：

```
xrdb: Can't open display ':0'
```

**解法**：用 socat 把 socket 转成本地 TCP。

```bash
pkg install -y socat
socat TCP-LISTEN:6000,bind=127.0.0.1,fork,reuseaddr \
  UNIX-CONNECT:$PREFIX/tmp/.X11-unix/X0 &
```

容器里用 `DISPLAY=127.0.0.1:0` 而不是 `:0`。

项目脚本 `start-desktop-zh.sh` 已经内置这一步：

```bash
~/pad-agent/start-desktop-zh.sh start
~/pad-agent/start-desktop-zh.sh stop
```

### 4. 中文显示不生效？

Termux 原生的包**编译时加了 `--disable-nls`**，`share/locale` 里没有任何中文翻译 ——
改 `LANG=zh_CN.UTF-8` 完全无效。这就是为什么要用 proot Debian。

验证容器里是否有中文：

```bash
proot-distro login debian -- ls /usr/share/locale/zh_CN/LC_MESSAGES | head
```

---

## 桌面卡死怎么排查

按顺序：

### 1. X server 还活着吗（协议握手，不是看进程）

```python
import socket, struct
s = socket.create_connection(('127.0.0.1', 6000), timeout=2)
s.sendall(b'l\x00' + struct.pack('<HHHH', 11, 0, 0, 0) + b'\x00\x00')
print('status =', s.recv(8)[0])   # 0 = 正常
```

- 几十毫秒返回 0 → X server 正常，是渲染/冻结问题
- 超时 → X server 真的挂了

### 2. 看是不是被冻结了

```bash
tail -20 ~/x11-session.log
```

再加心跳探针验证（见 pitfalls 坑 1）。

### 3. 内存是不是爆了

```bash
free -m
```

桌面 + 浏览器在 4 GB 机型上很容易 OOM。

### 4. 关掉合成器

```bash
xfconf-query -c xfwm4 -p /general/use_compositing -s false
```

### 5. 重来一遍

```bash
~/pad-agent/start-desktop.sh stop
pkill -f 'termux-x11'
~/pad-agent/start-desktop.sh restart
```

---

## 省资源建议

| 做法 | 效果 |
|---|---|
| 不用就 `stop` 掉桌面 | 释放 300–600 MB |
| 关合成器 | 省显存和 CPU |
| 用英文桌面代替中文 | 少 600 MB（不用 proot） |
| 浏览器别开太多标签 | 每个标签 100 MB 起 |

> 我个人用法：**日常靠 AI 面板和文件服务，需要图形界面时才开桌面，用完就关。**