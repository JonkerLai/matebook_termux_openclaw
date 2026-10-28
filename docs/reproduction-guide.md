# 复现指南（按 checkpoint 走）

> 这份文档把整个搭建过程拆成 **9 个阶段 / 26 个检查点**。
> 每个检查点都有 **✅ 验收标准**，不通过就别往下走 —— 这是避免“后面全崩但不知道哪步错”的关键。

预计耗时：**1.5–2 小时**（不含下载等待）。

---

## 阶段 0：环境确认（5 分钟）

### CP-0.1 确认机型信息

```bash
getprop ro.product.model
getprop ro.build.version.release
getprop ro.build.version.sdk
free -m | head -2
df -h /data | tail -1
```

**✅ 验收**

| 项 | 要求 |
|---|---|
| Android | ≥ 9，推荐 12+ |
| 内存 | ≥ 4 GB（8 GB 更稳） |
| 可用存储 | ≥ 4 GB |

**❌ 不满足怎么办**
- 内存 4 GB：跳过桌面 + Ollama（省 1 GB）
- Android 11 以下：省掉「幽灵进程杀手」那步（系统没有该机制）

---

## 阶段 1：Termux 基础（15 分钟）

### CP-1.1 装 Termux

从 **F-Droid** 安装，不要用 Google Play 版。

**✅ 验收**

```bash
echo $PREFIX        # 应输出 /data/data/com.termux/files/usr
```

### CP-1.2 装依赖

```bash
pkg update -y && pkg upgrade -y
pkg install -y git nodejs-lts curl openssh which
```

**✅ 验收**

```bash
node -v            # ≥ 22
git --version
which node         # 能输出路径（Termux 默认没有 which）
```

> ⚠️ 如果 `which` 报 command not found，说明上一条没装成功。

### CP-1.3 开 SSH

```bash
passwd            # 设密码
sshd
ifconfig | grep 'inet '
```

**✅ 验收**：电脑上 `ssh -p 8022 <用户名>@<平板IP>` 能登录。

```bash
# 用户名怎么查
whoami            # 形如 u0_a***（数字随机）
```

---

## 阶段 2：系统设置（20 分钟，最关键）

> 这一步不做完，后面所有服务都会「莫名其妙假死」。
> 详细原理见 [android-pitfalls.md](android-pitfalls.md)。

### CP-2.1 关电池优化

设置路径见 pitfalls 坑 1。

### CP-2.2 应用启动管理改手动

华为/荣耀：`设置 → 应用 → Termux → 启动管理 → 关闭自动管理 → 三个开关全开`

### CP-2.3 关幽灵进程杀手（Android 12+，需 adb）

```bash
adb shell settings put global settings_enable_monitor_phantom_procs false
adb shell device_config put activity_manager max_phantom_processes 2147483647
```

**✅ 验收**

```bash
adb shell dumpsys activity settings | grep -i phantom
# 应看到 max_phantom_processes=2147483647
```

### CP-2.4 心跳测试（验证冻结是否真的解决）

```bash
nohup bash -c 'while true; do date +%s >> ~/heartbeat.log; sleep 10; done' &
```

切到别的 App、锁屏、再回来，5 分钟后：

```bash
awk 'NR>1{print $1-prev} {prev=$1}' ~/heartbeat.log | sort -n | tail -5
```

**✅ 验收**：输出都在 10 左右。
**❌ 出现 15/30/120**：回 CP-2.1–2.2 再查。

```bash
pkill -f 'heartbeat[.]log'      # 清理探针
```

---

## 阶段 3：OpenClaw（20 分钟）

### CP-3.1 安装

```bash
npm install -g openclaw
openclaw --version
```

**✅ 验收**：能打印版本号。

### CP-3.2 初始化

```bash
openclaw doctor
```

**✅ 验收**：`openclaw config validate` 输出 `Config valid`。

### CP-3.3 配模型（DeepSeek 示例）

```bash
cat > "$PREFIX/tmp/ds.json5" <<'EOF'
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
openclaw config patch --file "$PREFIX/tmp/ds.json5"
openclaw config validate
```

**✅ 验收**

```bash
openclaw infer model run --model deepseek/deepseek-chat --prompt "只回复两个字：正常"
# 应输出类似「正常」
```

### CP-3.4 关掉 cron（必须）

```bash
openclaw config set cron.enabled false
```

**✅ 验收**

```bash
openclaw config get cron.enabled      # false
```

> ⚠️ 不关的话，Android 上每 2 秒报一次错，会把事件循环拖死。

### CP-3.5 启动网关

```bash
openclaw gateway --port 18789 --bind lan
```

**✅ 验收**（另开一个终端）

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:18789/
# 200
```

**❌ 启动失败常见原因**

| 报错 | 原因 |
|---|---|
| `different PID namespace` | 在 proot 里跑，必须用原生 Termux |
| `config changed during startup` | 两个进程同时启动，先全停再启 |
| 卡住不动 | 正常，冷启动要 55–90 秒 |

---

## 阶段 4：安装本项目（10 分钟）

### CP-4.1 拉代码

```bash
git clone <YOUR_REPO_URL> pad-agent-src
cd pad-agent-src
bash scripts/install.sh
```

**✅ 验收**

```bash
ls ~/pad-agent/ | head
~/pad-agent/status.sh
```

### CP-4.2 改配置

```bash
nano ~/pad-agent/config.env     # 一般不用改（IP 自动探测）
nano ~/pad-agent/services.conf  # 按需关掉不要的服务
nano ~/pad-agent/dufs-users.conf # 改密码！
```

**✅ 验收**

```bash
bash -n ~/pad-agent/config.env
~/pad-agent/start.sh --list
```

### CP-4.3 启动

```bash
~/pad-agent/start.sh
```

**✅ 验收**

```bash
~/pad-agent/status.sh
# 已启用的服务全部 up
```

---

## 阶段 5：文件服务（15 分钟）

### CP-5.1 装 dufs

```bash
mkdir -p ~/bin
curl -L -o ~/bin/dufs \
  https://github.com/sigoden/dufs/releases/latest/download/dufs-aarch64-unknown-linux-musl
chmod +x ~/bin/dufs
~/bin/dufs --version
```

### CP-5.2 配用户与目录

`~/pad-agent/config.env`：

```
DUFS_SERVE_DIR="$HOME/nas"
```

`~/pad-agent/dufs-users.conf`：

```
admin:你的强密码:rw
guest:另一个密码:ro
```

### CP-5.3 启动并验证

```bash
~/pad-agent/start.sh dufs
```

**✅ 验收**

```bash
IP=$(ifconfig | awk '/inet 192/{print $2; exit}')
curl -s -o /dev/null -w "%{http_code}\n" -u admin:你的强密码 "http://$IP:5000/"      # 200
curl -s -o /dev/null -w "%{http_code}\n" "http://$IP:5000/"                          # 401
curl -s -o /dev/null -w "%{http_code}\n" -u guest:另一个密码 "http://$IP:5000/"      # 200
```

**❌ 常见报错**

| 报错 | 解法 |
|---|---|
| `Failed to get local interface addresses` | 别用 `--bind 0.0.0.0`，绑具体 IP |
| `Invalid auth value` | 只读用 `user:pass@/`，不要写 `:r` |

### CP-5.4 电脑挂载（可选）

见 [quickstart.md](quickstart.md) 第 6 节。

---

## 阶段 6：公网访问（10 分钟）

### CP-6.1 装 cloudflared

```bash
pkg install -y cloudflared
```

### CP-6.2 起隧道

```bash
cloudflared tunnel --url http://127.0.0.1:18789
```

**✅ 验收**：日志里出现 `https://xxx.trycloudflare.com`，浏览器能打开。

### CP-6.3 让网关接受代理来源

```bash
cat > "$PREFIX/tmp/proxy.json5" <<'EOF'
{ gateway: { trustedProxies: ["127.0.0.1/32", "::1/128"] } }
EOF
openclaw config patch --file "$PREFIX/tmp/proxy.json5"
```

**✅ 验收**：外网打开面板不再报 `proxy_attribution_required`。

### CP-6.4 加白名单

```bash
~/pad-agent/fix-origin.sh
```

**✅ 验收**：外网打开不再报「浏览器来源不被允许」。

---

## 阶段 7：微信通道（10 分钟，可选）

### CP-7.1 安装

```bash
npx -y @tencent-weixin/openclaw-weixin-cli@latest install
```

**✅ 验收**：终端出现二维码，手机微信扫码成功。

### CP-7.2 设白名单

```bash
openclaw config set channels.openclaw-weixin.dmPolicy allowlist
openclaw config set channels.openclaw-weixin.allowFrom '["<你的微信ID>@im.wechat"]'
~/pad-agent/start.sh gateway
```

**✅ 验收**

```bash
openclaw channels status | grep weixin
# enabled, configured, running
```

---

## 阶段 8：桌面（20 分钟，可选）

见 [desktop-setup.md](desktop-setup.md)。

**✅ 验收**：`deskzh` 后切到 Termux:X11 应用能看到桌面。

---

## 阶段 9：开机自启（10 分钟，可选）

### CP-9.1 装 Termux:Boot

F-Droid 装，**打开一次**。

### CP-9.2 放脚本

```bash
mkdir -p ~/.termux/boot
cp ~/pad-agent/boot-start.sh ~/.termux/boot/start.sh
chmod +x ~/.termux/boot/start.sh
```

**✅ 验收**：重启平板，等 2 分钟，`cat ~/boot.log` 有记录，`~/pad-agent/status.sh` 全 up。

---

## 最终验收清单

```bash
~/pad-agent/full-health.sh
```

- [ ] 9 个服务全 up
- [ ] 面板局域网可开（200）
- [ ] 面板公网可开（隧道地址）
- [ ] dufs 网页可登录 / 未登录 401
- [ ] guest 只读账号写入被拒（403）
- [ ] 电脑挂载 Y: / S: 成功
- [ ] 微信能对话（可选）
- [ ] 重启后自动恢复（可选）

全部打勾 = 复现成功 🎉

---

## 排障入口

| 现象 | 看哪 |
|---|---|
| 服务假死 / 卡住 | [android-pitfalls.md](android-pitfalls.md) 坑 1 |
| Termux 突然重启 | 坑 2 |
| 桌面卡死 | [desktop-setup.md](desktop-setup.md) |
| 具体报错 | [troubleshooting.md](troubleshooting.md) |
| 想理解为什么这么设计 | [build-log.md](build-log.md)、[architecture.md](architecture.md) |