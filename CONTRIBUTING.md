# 贡献指南

## 欢迎的贡献

| 类型 | 例子 |
|---|---|
| **机型适配** | 报告某品牌平板的特殊设置（华为/小米/三星/OPPO…） |
| **新服务模块** | Syncthing、Frp、SearXNG、n8n… |
| **省资源方案** | 更低内存占用的配置、可选的插件裁剪 |
| **文档修正** | 错别字、过时命令、更清晰的解释 |
| **Bug 报告** | 附 `~/pad-agent/status.sh` 和日志片段 |

## 加一个新服务

1. 在 `scripts/` 下新建 `NN-名字.sh`（编号决定启动顺序）：

```bash
#!/data/data/com.termux/files/usr/bin/bash
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
NAME=你的服务名

check() { pgrep -f 'my-service' >/dev/null 2>&1; }
start() { setsid nohup my-service >/dev/null 2>&1 & }

. "$SERVICES_DIR/_run.sh"
```

2. 在 `scripts/services.conf.example` 加一行 `你的服务名 1`
3. 在 `scripts/stop.sh` 的 `stop_one()` 里加一个 case 分支
4. 在 `scripts/status.sh` 的 `note` 部分按需加一行展示信息
5. 本地 `bash -n` 过一遍，然后在真机跑 `./start.sh 你的服务名`

## 代码约定

- **POSIX 兼容**：只用 Termux 自带的 bash 功能，不依赖 GNU 扩展
- **不硬编码**：IP 用 `detect_ip()`，端口用 `config.env`
- **幂等**：`start()` 重复调用不能出错
- **可观测**：每个服务必须能通过 `check()` 判断状态
- **别用 `/tmp`**：Android 没有，用 `$PREFIX/tmp`
- **pkill 要防自杀**：用 `pkill -f 'xxx[-]yyy'` 或先取 PID

## 提交规范

```
feat: 新增 Syncthing 服务
fix: dufs 在 VPN 环境下 IP 探测错误
docs: 补充 iOS 访问说明
```

## 安全

不要在提交里包含：真实 IP、token、密码、key、设备序列号。
本项目 `.gitignore` 已排除 `config.env` / `dufs-users.conf`。