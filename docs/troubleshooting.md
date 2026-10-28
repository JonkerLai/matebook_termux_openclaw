# 故障排查

> 按「你看到的报错」索引。所有命令在 Termux 里跑。

---

## 启动 / 自启

### 打开 Termux 后服务没起来

```bash
cat ~/pad-agent/services.log | tail -30
~/pad-agent/start.sh
```

常见原因：

| 原因 | 检查 |
|---|---|
| 脚本没执行权限 | `ls -l ~/pad-agent/*.sh`，缺就 `chmod +x ~/pad-agent/*.sh` |
| `.bashrc` 钩子没写 | `grep pad-agent ~/.bashrc` |
| config.env 语法错 | `bash -n ~/pad-agent/config.env` |
| 服务被 toggle 关了 | `~/pad-agent/start.sh --list` |

### 网关起不来，日志显示 `different PID namespace`

说明你在 proot 容器里跑。**OpenClaw 必须跑在原生 Termux**，不能在 proot Debian 里。

### `Could not read the active Gateway model catalog`

网关还没完全启动。等 60 秒再试。

---

## 网关

### 起来 10 秒就死 / 反复重启

两个经典原因：

**① 看门狗把它杀了**

网关冷启动 55–90 秒，如果看门狗判定过急会杀掉正在启动的进程。
本项目已加 180 秒宽限期 + 连续 3 次失败才重启。如果你的版本没有：

```bash
grep GW_GRACE ~/pad-agent/openclaw-watchdog.sh
```

**② 有残留进程占着锁**

```bash
pgrep -af 'openclaw'
```

如果有一个 `openclaw`（没有 `-gateway` 后缀）在跑，它可能在抢状态库：

```bash
kill -9 <那个 PID>
```

### `Refusing to run gateway state preparation because the selected config changed during startup`

启动过程中配置文件被改了（通常是两个进程同时启动，或你正在编辑配置）。

解决：

```bash
~/pad-agent/stop.sh watchdog
~/pad-agent/stop.sh gateway
sleep 3
~/pad-agent/start.sh gateway
```

### 网关 CPU 长期 80%+（单核）

先看是不是 cron：

```bash
grep -c 'timer tick failed' $PREFIX/tmp/openclaw-*/openclaw-*.log
```

**大于 1000 就是 cron 死循环**：

```bash
openclaw config set cron.enabled false
~/pad-agent/start.sh gateway
```

不是 cron 的话，看会话大小：

```bash
openclaw sessions list
```

Token 用到 80% 以上会明显变慢，开新会话或 `/reset`。

### 回复失败：`couldn't finish this reply`

通常是事件循环被占满。按顺序查：

```bash
tail -50 ~/oc-gw.log
grep -c ERROR $PREFIX/tmp/openclaw-*/openclaw-*.log
```

日志文件 > 30 MB 或 ERROR 上千条 → 有东西在刷屏，参考上面 cron 的处理。

---

## 面板

### 「浏览器来源不被允许」

隧道地址变了，白名单没跟上：

```bash
~/pad-agent/fix-origin.sh
```

### 「批准此浏览器」

新设备需要审批：

```bash
openclaw devices list
openclaw devices approve <ID>
```

### 「expects its token」

网关没按新配置重启：

```bash
~/pad-agent/stop.sh gateway && ~/pad-agent/start.sh gateway
```

### 面板一直转圈

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:18789/
```

- `000` → 网关没跑
- `200` → 网关正常，可能是浏览器缓存，硬刷新

---

## 文件服务

### dufs 起不来：`Failed to get local interface addresses`

`--bind 0.0.0.0` 在 Android 上会枚举网卡失败。必须绑具体 IP：

```bash
grep -n 'bind' ~/pad-agent/70-dufs.sh
```

本项目已用 `detect_ip()` 自动探测，如仍失败：

```bash
ifconfig | grep 'inet '
```

把 IP 写进 `~/pad-agent/config.env` 的 `TABLET_IP=`。

### IP 探测到 172.x 而不是 192.168.x

说明有 VPN / 热点接口。手动指定：

```bash
echo 'TABLET_IP="192.168.1.100"   # 换成你自己的' >> ~/pad-agent/config.env
```

### dufs 报 `Invalid auth value`

权限后缀只能是 `rw`，只读用**不带后缀**：

```
admin:pass@/:rw      ✅ 读写
guest:pass@/         ✅ 只读
guest:pass@/:r       ❌ 非法
```

### Windows 挂 WebDAV 报错误 1244 / 67

WebDAV 在 Windows 上很挑剔，推荐改用 SFTP + SSHFS。

非要 WebDAV 的话，管理员执行：

```powershell
$p = 'HKLM:\SYSTEM\CurrentControlSet\Services\WebClient\Parameters'
Set-ItemProperty $p -Name BasicAuthLevel -Value 2 -Type DWord
New-ItemProperty $p -Name AuthForwardServerList -PropertyType MultiString `
  -Value @('http://<平板IP>','http://<平板IP>:5000') -Force
Set-Service WebClient -StartupType Automatic
Restart-Service WebClient -Force
```

然后：

```cmd
net use Z: \\<平板IP>@5000\DavWWWRoot /user:admin <密码> /persistent:yes
```

### 盘符「本地设备名已在使用中」（错误 85）

有个残留映射占着盘符，换个字母，或重启电脑。

### `Y:\storage\pictures` 位置不可用

`~/storage/*` 是指向 home 外的软链接，SSHFS 不跟随。
改用 `\\sshfs.r\` 那套，直接挂 `/storage/emulated/0`。

### Termux 能读 /sdcard 吗？

不能的话（`ls /sdcard` 报 Permission denied）：

```
设置 → 应用 → Termux → 权限 → 文件和媒体 → 允许管理所有文件
```

---

## 微信

### 装插件报 `spawn git ENOENT`

```bash
pkg install -y git
```

### 装插件报 `未找到 openclaw`

Termux 默认没有 `which` 命令，安装器依赖它：

```bash
pkg install -y which
```

### 扫码后连不上：`Subscribe returned incomplete Connect envelope`

插件版本和 OpenClaw 版本不匹配。查兼容性：

```bash
openclaw --version
npx -y @tencent-weixin/openclaw-weixin-cli@latest install
```

### 装完配置失效：`Unrecognized key: "plugins.installs"`

旧版安装器写了废弃的键：

```bash
openclaw config validate
# 如果报这个，手工删除该键
python3 - <<'PY'
import json, os
p = os.path.expanduser('~/.openclaw/openclaw.json')
d = json.load(open(p))
d.get('plugins', {}).pop('installs', None)
json.dump(d, open(p, 'w'), ensure_ascii=False, indent=2)
PY
openclaw config validate
```

---

## 安卓能力（MCP）

### `spawn git` / `npm install` 失败

```bash
pkg install -y git
```

### 工具用不了（电量/相机）

```bash
pkg install -y termux-api
```

还要装 **Termux:API App** 并打开一次授权。

### APK 装不上：签名不一致

Termux 和配套 App 必须同签名：

| Termux 来源 | 配套 App 也要用 |
|---|---|
| F-Droid | F-Droid |
| GitHub | GitHub（`+github.debug` 版本） |

---

## 系统级

### Termux 被系统杀掉

按顺序检查：

1. 电池优化 → 不限制
2. 自启动 / 后台活动 → 允许
3. phantom process killer → 关闭（Android 12+）
4. `termux-wake-lock`（本项目脚本已含）

### 手机连不上平板

```bash
# 平板上
ifconfig | grep 'inet '
```

确认两边在同一网段，且平板没开 AP 隔离（路由器设置）。

### 公网地址打不开

```bash
pgrep -af cloudflared
tail -20 ~/cloudflared.log
```

看有没有 `Registered tunnel connection`。

---

## 万能三连

```bash
~/pad-agent/status.sh
~/pad-agent/full-health.sh
tail -30 ~/pad-agent/services.log
```

还不行就全量重启：

```bash
~/pad-agent/stop.sh
sleep 5
~/pad-agent/start.sh
```