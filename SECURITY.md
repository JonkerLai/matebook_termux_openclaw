# 安全说明

## 这是个人自用项目

本项目把一个**完整的计算环境**暴露给你自己（可能还有网络）。
默认不提供任何企业级安全保证，请自行评估风险。

## 部署前必做

1. **改掉所有默认密码**
   - `dufs-users.conf` 里的 `CHANGE_ME_PLEASE`
   - SSH 密码（`passwd`）

2. **不要无脑开公网隧道**
   - 面板暴露 = 别人拿到 token 就能执行命令
   - 文件服务暴露 = 别人拿到密码就能读写你的文件

3. **收好 token**

```bash
openclaw config get gateway.auth.token
```

不要截图、不要提交到仓库。

4. **给公网面板加一层认证**（推荐）
   用 Cloudflare Access（需要域名），或至少：
   - 定期更换 token
   - 不在公开场合分享隧道地址

## 已知攻击面

| 入口 | 默认状态 | 风险 |
|---|---|---|
| Gateway :18789 | 局域网 | token 泄露 → 可执行任意命令 |
| dufs :5000 | 局域网 | 密码泄露 → 文件读写 |
| sshd :8022 | 局域网 | 弱密码 → 整机失守 |
| 公网隧道 | 手动开启 | 以上全部暴露到公网 |

## 安全加固建议

```bash
# 1. SSH 换强密码
passwd

# 2. 关掉密码登录，改用密钥（进阶）
# 编辑 ~/.ssh/authorized_keys，然后在 sshd_config 关 PasswordAuthentication

# 3. dufs 只读用户
# guest:强密码:ro

# 4. 面板只绑回环，靠隧道访问
# openclaw gateway --bind loopback
```

## 上报问题

发现安全问题请开 Issue 并标注 `security`，不要在公开渠道贴出可利用细节。