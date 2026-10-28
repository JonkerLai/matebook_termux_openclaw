# 操作手册（完整版）

> 装好之后日常怎么用。
> `<平板IP>` = 你的平板局域网地址（`ifconfig | grep 192.168` 或 `~/pad-agent/status.sh` 查）。

---

## 目录

1. [每天怎么开始](#一每天怎么开始)
2. [四个入口](#二四个入口)
3. [微信怎么用](#三微信怎么用)
4. [网页面板怎么用](#四网页面板怎么用)
5. [OpenClaw 常用命令](#五openclaw-常用命令)
6. [文件服务怎么用](#六文件服务怎么用)
7. [图形桌面怎么用](#七图形桌面怎么用)
8. [服务管理](#八服务管理)
9. [账号与凭据（自己生成）](#九账号与凭据自己生成)
10. [常见问题](#十常见问题)
11. [维护](#十一维护)

---

## 一、每天怎么开始

### 没关机

什么都不用做，服务一直在跑。

### 重启过 / Termux 被关掉

```
1. 打开 Termux
2. 什么都不用敲
3. 等 90 秒
```

**启动耗时**（知道为什么等）：

| 阶段 | 耗时 |
|---|---|
| wakelock / sshd | < 1 秒 |
| ollama | 3 秒 |
| **gateway** | **55–90 秒**（加载插件，最慢） |
| tunnel | 15 秒 |
| dufs | 3 秒 |
| **合计** | **约 90 秒** |

### 确认

```bash
~/pad-agent/status.sh
```

全部 `up` 就绪。

---

## 二、四个入口

| 入口 | 地址 | 适合 | 依赖 |
|---|---|---|---|
| **微信** | 微信里的 bot | 手机随时用 | 微信插件 + 网关 |
| **AI 面板** | `http://<平板IP>:18789` | 电脑，功能最全 | 网关 |
| **文件服务** | `http://<平板IP>:5000` | 传文件 | dufs |
| **图形桌面** | Termux 敲 `deskzh` / `desk` | 要图形界面 | Termux:X11 + Xfce |

### 查公网地址（出门用）

```bash
echo "面板: $(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' ~/cloudflared.log | tail -1)"
echo "文件: $(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' ~/dufs-tunnel.log | tail -1)"
```

> Cloudflare 快速隧道的地址**每次重启都会变**。
> 想固定：自备域名 + `cloudflared tunnel create`（命名隧道）。

---

## 三、微信怎么用

### 发消息

微信里找到绑定过的 bot，像聊天一样发消息。

### 只有白名单能用

```
dmPolicy: allowlist
allowFrom: [<你的微信ID>@im.wechat]
```

陌生人发消息**直接忽略**，不会触发任何操作。

### 加人

```bash
openclaw config set channels.openclaw-weixin.allowFrom \
  '["<你的ID>@im.wechat","<新ID>@im.wechat"]'
~/pad-agent/start.sh gateway
```

> 微信 ID 从日志看：
> `openclaw channels logs --channel openclaw-weixin`

### 渠道状态

```bash
openclaw channels status | grep weixin
openclaw channels logs --channel openclaw-weixin
```

### 临时关掉

```bash
openclaw config set plugins.entries.openclaw-weixin.enabled false
~/pad-agent/start.sh gateway
```

### 重新扫码登录

```bash
openclaw channels login --channel openclaw-weixin
```

---

## 四、网页面板怎么用

### 地址

| 场景 | 地址 |
|---|---|
| 局域网 | `http://<平板IP>:18789` |
| 公网 | 见上面「查公网地址」 |
| 平板本机 | `http://127.0.0.1:18789` |

### 首次登录

1. 打开地址
2. 粘贴 token（见[第九章](#九账号与凭据自己生成)）
3. 点 Connect

### 三种常见拦截

| 提示 | 处理 |
|---|---|
| 浏览器来源不被允许 | `~/pad-agent/fix-origin.sh` |
| 批准此浏览器 | `openclaw devices list` → `openclaw devices approve <ID>` |
| expects its token | 重启网关后重贴 token |

### 面板能做什么

| 功能 | 说明 |
|---|---|
| 聊天 | 底部输入框，回车发送 |
| 会话列表 | 左侧，可切换/新建 |
| 模型切换 | 设置里选 provider/model |
| 工具调用可视化 | 消息里显示调用了哪个工具、参数、返回 |
| 日志 | Settings → Logs（排障用） |

---

## 五、OpenClaw 常用命令

### 5.1 聊天

| 命令 | 作用 |
|---|---|
| `openclaw tui` | 终端对话（连网关，最常用） |
| `openclaw agent -m "你好"` | 发一句、取一次回复（脚本友好） |
| `openclaw chat` | 本地模式，需先停网关（否则抢锁） |

### 5.2 状态

```bash
openclaw status
openclaw gateway status
openclaw gateway status --deep
openclaw channels status
openclaw sessions list
```

### 5.3 会话与上下文

```bash
openclaw sessions list          # 看 token 占用
```

> Token 到 80%（如 `102k/128k`）会明显变慢 → 开新会话或 `/reset`。

### 5.4 记忆

```bash
openclaw memory search "关键词"
openclaw memory stats
```

### 5.5 安卓工具（MCP）

```bash
openclaw mcp list
openclaw mcp probe termux       # 看有哪些工具
openclaw mcp reload             # 改配置后重载
openclaw mcp doctor
```

### 5.6 配置

```bash
openclaw config validate                  # 改完必跑
openclaw config get gateway.auth.token
openclaw config set <路径> <值>
openclaw config patch --file x.json5
openclaw config schema
```

### 5.7 插件

```bash
openclaw plugins list
openclaw plugins install <包名>
openclaw plugins uninstall <ID>
openclaw plugins update <ID>
openclaw plugins inspect <ID> --runtime
```

### 5.8 设备

```bash
openclaw devices list
openclaw devices approve <ID>
```

### 5.9 日志与诊断

```bash
openclaw logs --follow          # 实时日志（排障首选）
openclaw doctor
openclaw doctor --fix --non-interactive
openclaw infer model run --model deepseek/deepseek-chat --prompt "测试"
```

### 5.10 聊天里的斜杠命令

| 命令 | 作用 |
|---|---|
| `/stop` | 停止当前这一轮（不停服务） |
| `/new` | 新会话 |
| `/reset` | 重置会话 |

### 5.11 别用 / 慎用

| 命令 | 原因 |
|---|---|
| `openclaw gateway restart` | Android 无 systemd，不支持 |
| `openclaw gateway stop` | 能停，但看门狗 3 分钟内拉起 |
| `openclaw cron ...` | Android 上会死循环，已全局关闭 |
| `npm update -g openclaw` | 会覆盖 fs-safe 补丁 |

---

## 六、文件服务怎么用

### 共享的是什么

`~/nas` 目录（五个分类文件夹）：

```
backups / documents / media / photos / shared
```

> `.openclaw`、脚本等敏感目录**已隔离**（实测返回 404）。

### 浏览器

`http://<平板IP>:5000`，账号见 `dufs-users.conf`。

| 操作 | 怎么做 |
|---|---|
| 进目录 | 点文件夹 |
| 下载 / 上传 | 点文件 / 拖进窗口 |
| 新建 / 重命名 / 删除 | 行内菜单 |
| 在线预览 | 图片、视频、PDF、文本 |
| 搜索 | 顶部搜索框 |
| 整目录打包 | 目录菜单 → zip |

### 用户管理

```bash
nano ~/pad-agent/dufs-users.conf
```

格式：

```
用户名:密码:rw      # 读写
用户名:密码:ro      # 只读
```

改完：

```bash
~/pad-agent/start.sh dufs
```

验证：

```bash
curl -s -o /dev/null -w "%{http_code}\n" -u admin:<密码> http://<平板IP>:5000/   # 200
curl -s -o /dev/null -w "%{http_code}\n" http://<平板IP>:5000/                    # 401
```

> 密码里不要有 `:` 和 `@`。

### Windows 挂成盘（SFTP，推荐）

先装 [WinFsp](https://github.com/winfsp/winfsp/releases) + [SSHFS-Win](https://github.com/winfsp/sshfs-win/releases)：

```cmd
net use Y: \\sshfs\<用户>@<平板IP>!8022 /user:<用户> <SSH密码> /persistent:yes
net use S: \\sshfs.r\<用户>@<平板IP>!8022\storage\emulated\0 /user:<用户> <SSH密码> /persistent:yes
```

| 盘 | 内容 |
|---|---|
| `Y:` | Termux 家目录 |
| `S:` | 手机存储（照片/下载/DCIM） |

> **端口前是 `!` 不是 `:`**。
> `sshfs.r` 的 `.r` 表示「从根目录开始」，才能跳出 home。

### 手机（iOS / Android）

装支持 SFTP 的 App（猫头鹰文件 / Documents / MiXplorer）：

```
主机：<平板IP>
端口：8022
用户：<Termux 用户名>
密码：<SSH 密码>
路径：/storage/emulated/0     （手机存储）
     或留空                （Termux 家目录）
```

> iOS 自带「文件」App 只支持 SMB，而 Android 开不了 SMB（445 需 root），所以必须用第三方 App。

---

## 七、图形桌面怎么用

### 打开

```
1. Termux 敲：deskzh    （中文桌面，需 proot Debian）
             desk      （英文桌面，Termux 原生）
2. 切到 Termux:X11 应用   ← 桌面显示在这里
```

### 关闭

```bash
deskzh-stop
~/pad-agent/start-desktop.sh stop
```

### 桌面里推荐

开浏览器访问：

- `http://127.0.0.1:5000` → 文件服务
- `http://127.0.0.1:18789` → AI 面板

> ⚠️ 桌面吃 300–600 MB 内存，不用就关。

---

## 八、服务管理

### 状态 / 启停

```bash
~/pad-agent/status.sh
~/pad-agent/start.sh                 # 全部起
~/pad-agent/start.sh gateway         # 单个起
~/pad-agent/stop.sh gateway          # 单个停
~/pad-agent/stop.sh                  # 全部停（逆序）
~/pad-agent/toggle.sh dufs off       # 永久禁用
~/pad-agent/start.sh --list          # 看开关状态
```

### 彻底停 AI（不被自动拉起）

```bash
~/pad-agent/stop.sh watchdog     # 必须先停看门狗
~/pad-agent/stop.sh gateway
```

### 服务清单

| 服务 | 端口 | 作用 | 关了会怎样 |
|---|---|---|---|
| `wakelock` | — | 防冻结 | 后台久了 Termux 可能被杀 |
| `sshd` | 8022 | SSH / SFTP | 电脑/手机连不上 |
| `ollama` | 11434 | 本地 embedding | 记忆降级为关键词检索 |
| `gateway` | 18789 | AI 主进程 | 所有 AI 入口失效 |
| `tunnel` | — | 面板公网隧道 | 只能局域网访问 |
| `origin` | — | 同步面板白名单 | 换地址后进不去面板 |
| `watchdog` | — | 每 60 秒巡检 | 服务挂了不自愈 |
| `dufs` | 5000 | 文件服务 | 文件网页/Z盘失效 |
| `dufs-tunnel` | — | 文件服务公网隧道 | 文件只能局域网访问 |

### 日志

```bash
tail -f ~/pad-agent/services.log     # 服务启停
tail -f ~/watchdog.log               # 巡检记录
openclaw logs --follow               # OpenClaw 运行日志
```

---

## 九、账号与凭据（自己生成）

> ⚠️ 本项目**不附带任何默认凭据**，安装后请自己生成并保管。

| 凭据 | 在哪 | 怎么设置 |
|---|---|---|
| **SSH 密码** | Termux 用户 | `passwd` |
| **面板 token** | `~/.openclaw/openclaw.json` | `openclaw config get gateway.auth.token`（首次由 OpenClaw 生成） |
| **dufs 账号** | `~/pad-agent/dufs-users.conf` | 手工编写，`chmod 600` |
| **模型 API Key** | `~/.openclaw/openclaw.json` | `openclaw config patch` 写入 |
| **微信 bot** | `~/.openclaw/openclaw.json` | 扫码登录后自动生成 |

### 安全建议

```bash
chmod 600 ~/pad-agent/dufs-users.conf
chmod 600 ~/.openclaw/openclaw.json
```

- Token / Key **永远不要截图、不要提交到 Git**
- 公网暴露前至少改掉所有默认密码
- 更稳的做法：给面板套 Cloudflare Access（需域名）

---

## 十、常见问题

### 卡 / 慢 / 不回复

| 现象 | 原因 | 处理 |
|---|---|---|
| 面板一直转圈 | 网关冷启动 55–90 秒 | 等；`curl http://127.0.0.1:18789/` |
| 回复失败 `couldn't finish this reply` | 事件循环被占满（曾因 cron 死循环） | 确认 `cron.enabled=false`；看日志 ERROR 数 |
| CPU 长期 80%+（单核） | 会话过大 / 插件多 | `openclaw sessions list` 看 token，开新会话 |
| 内存不够 | 桌面 + 浏览器 + AI 同时开 | `deskzh-stop`；`free -m` |
| 有杂音/占 CPU | 外部播放器进程 | `ps -A -o pid,%cpu,args \| sort -k2 -rn \| head` |

> `%CPU` 是**单核百分比**：80% ≈ 0.8 个核心，8 核机器上约整机 10%。

### 打不开

| 现象 | 处理 |
|---|---|
| 微信不回 | 打开 Termux 等 90 秒；`openclaw channels status` |
| 面板打不开 | `~/pad-agent/start.sh gateway` |
| 文件服务打不开 | `~/pad-agent/start.sh dufs` |
| Z/Y 盘连不上 | `ifconfig` 看 IP 是否变了 |
| SSH 连不上 | 打开 Termux；或手动 `sshd` |

### 全挂了

```bash
~/pad-agent/full-health.sh
~/pad-agent/stop.sh && ~/pad-agent/start.sh
```

详细对照见 **[troubleshooting.md](troubleshooting.md)**。

---

## 十一、维护

### 每周检查

```bash
~/pad-agent/full-health.sh
tail -20 ~/watchdog.log
df -h /data | tail -1
free -m | head -2
```

### 备份配置

```bash
cp ~/.openclaw/openclaw.json ~/storage/downloads/openclaw-$(date +%F).json
cp ~/pad-agent/dufs-users.conf ~/storage/downloads/dufs-users-$(date +%F).conf
```

> 先 `termux-setup-storage` 才有 `~/storage`。

### 清理空间

```bash
bash ~/pad-agent/cleanup.sh          # 预演
bash ~/pad-agent/cleanup.sh --run    # 执行
```

常见大头：`~/.npm`（npm 缓存，可能几百 MB）、`~/.openclaw/tmp`、日志。

### 升级 OpenClaw（谨慎）

```bash
npm update -g openclaw
openclaw doctor --fix --non-interactive
openclaw config validate
```

> ⚠️ 升级会覆盖 fs-safe 补丁（如果你打过）→ 插件安装可能失效。
> 升级后建议跑一次 `~/pad-agent/full-health.sh`。

### 迁移到新设备

1. 新设备装 Termux + 依赖
2. 复制 `~/.openclaw/openclaw.json` 和 `~/pad-agent/`（含 config.env / dufs-users.conf）
3. 装 dufs 二进制
4. `~/pad-agent/start.sh`
5. 重新扫码微信（凭证绑定设备）

---

## 一句话备忘

```
要 AI      → 微信发消息 / 浏览器 <平板IP>:18789
要文件     → <平板IP>:5000
要桌面     → Termux 敲 deskzh，切 Termux:X11
要命令行   → openclaw tui
看日志     → openclaw logs --follow
出问题     → ~/pad-agent/full-health.sh
全挂了     → ~/pad-agent/stop.sh && ~/pad-agent/start.sh
没反应     → 打开 Termux 等 90 秒
```