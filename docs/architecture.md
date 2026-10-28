# 架构说明

## 全景

```
                    ┌──────────────────────────────────────────┐
   微信 / 浏览器 ───▶│  cloudflared（两条隧道）                  │
   SFTP 客户端  ───▶│            │                             │
                    │            ▼                             │
                    │  ┌──────────────────────────┐            │
                    │  │  OpenClaw Gateway :18789 │            │
                    │  │  · 会话 / 上下文          │            │
                    │  │  · 调模型（DeepSeek）     │            │
                    │  │  · 工具执行（MCP）        │            │
                    │  └──────────┬───────────────┘            │
                    │             │                            │
                    │   ┌─────────┴─────────┐                  │
                    │   ▼                   ▼                  │
                    │ sshd :8022        dufs :5000             │
                    │ (SFTP)            (网页 + WebDAV)        │
                    │   │                   │                  │
                    │   ▼                   ▼                  │
                    │ $HOME              ~/nas                 │
                    └──────────────────────────────────────────┘
                                   Android / Termux
```

## 进程模型

| 进程 | 常驻 | 作用 | 挂了会怎样 |
|---|---|---|---|
| `openclaw-gateway` | ✅ | AI 主服务 | 所有 AI 入口失效 |
| `openclaw-watchdog` | ✅ | 每 60 秒巡检 | 服务不会自愈 |
| `cloudflared` ×2 | ✅ | 公网隧道 | 外网访问失效 |
| `dufs` | ✅ | 文件服务 | 文件网页/WebDAV 失效 |
| `sshd` | ✅ | SSH/SFTP | 无法远程登录 |
| `ollama serve` | ✅ | 本地 embedding | 记忆降级为关键词 |

## 端口

| 端口 | 服务 | 绑定 | 说明 |
|---|---|---|---|
| 8022 | sshd | 0.0.0.0 | 非标准端口，避开系统占用 |
| 18789 | gateway | lan | WebSocket + HTTP |
| 5000 | dufs | lan IP | 必须绑具体 IP（见下） |
| 11434 | ollama | 127.0.0.1 | 只本机 |

## 为什么有些端口不按常规来

### 445（SMB）绑不了

Linux 规定 <1024 的端口需要 root，Termux 没有 root → **无法提供原生 SMB**。
替代：SFTP（SSH 内置）+ WebDAV（dufs）。

### dufs 必须绑具体 IP

```bash
dufs -b 0.0.0.0     # ❌ Android 上会报 Failed to get local interface addresses
dufs -b 192.168.1.100 # ✅ 可以
```

因为枚举网卡需要权限，Android 拒绝了。所以脚本里用 `ifconfig` 探测本机 IP 再绑定。

### 定时任务（cron）不可用

OpenClaw 的 cron 需要「进程启动标识」做分布式锁，Android 的 `/proc` 限制导致拿不到，会每 2 秒抛异常。必须关闭：

```bash
openclaw config set cron.enabled false
```

## 自启层级

```
Android 开机
   └─ Termux:Boot（需安装）
        └─ ~/.termux/boot/start.sh
             └─ ~/pad-agent/start.sh
                  └─ 依次启动 9 个服务

用户手动打开 Termux（没装 Boot 时）
   └─ .bashrc 钩子
        └─ ~/pad-agent/start.sh
```

## 配置来源

```
~/pad-agent/config.env         ← 端口 / 路径 / IP
~/pad-agent/services.conf      ← 服务开关
~/pad-agent/dufs-users.conf    ← 文件服务账号
~/.openclaw/openclaw.json      ← OpenClaw 自身配置（模型 / 渠道 / 插件）
```

## 依赖关系

```
gateway  依赖 → ollama（可选，影响记忆）
tunnel   依赖 → gateway（否则隧道指向空端口）
origin   依赖 → tunnel（要读隧道地址）
dufs-tunnel 依赖 → dufs
watchdog 依赖 → 以上全部（负责拉起）
```

启动顺序即脚本编号：`00 → 10 → 20 → 30 → 40 → 50 → 60 → 70 → 75`。