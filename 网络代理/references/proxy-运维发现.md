# 网络代理 — 运维发现记录

## WSL ↔ Windows 代理通道（2026-05-15 更新）

**当前可用架构**：

| 通道 | 地址 | 说明 |
|------|------|------|
| WSL mihomo | `127.0.0.1:7897` | VLESS Reality，**TLS 对 curl/yt-dlp 不兼容** |
| Windows Clash Verge（HTTP） | `172.23.32.1:7897` | ✅ WSL 可达，**GitHub/YouTube 正常** |
| Windows Clash Verge（管理口） | `127.0.0.1:33331` | Clash Verge 控制/管理端口（非代理） |

**核心区别**：WSL 的 `127.0.0.1` 是 WSL 网络命名空间，`172.23.32.1` 才是 Windows 主机。两者不相通。

**之前 `172.23.32.1:7897` 不通的原因**：Windows 7897 被 `wslrelay.exe`（WSL→Windows 中继进程）占用，mihomo 无法绑定。wslrelay 退出后 mihomo 绑定成功但 VLESS Reality TLS 不兼容 CLI 工具。Clash Verge 自身监听 33331，不占用 7897。

**yt-dlp / Git / curl 走代理的正确端口**：
```bash
# ✅ 正确：Windows Clash Verge
export http_proxy="http://172.23.32.1:7897"
export https_proxy="http://172.23.32.1:7897"

# ❌ 错误：WSL mihomo（VLESS Reality TLS 不兼容 yt-dlp）
export http_proxy="http://127.0.0.1:7897"
```

**Git 必须单独配置代理**（Git 不继承 shell 环境变量）：
```bash
git config --global http.proxy http://172.23.32.1:7897
git config --global https.proxy http://172.23.32.1:7897
```

**验证**：
```bash
curl -s --proxy http://172.23.32.1:7897 https://github.com -o /dev/null -w "%{http_code}"
# 200 = 通道正常
```

## mihomo 双实例架构

WSL 里同时存在**两个 mihomo 进程**，来源不同：

| 进程 | 启动方式 | 配置目录 | 订阅备份 |
|------|----------|----------|----------|
| PID 11853 | hermes-agent 内置 | `/mnt/d/AI/hermes-agent/proxy/` | **不持久化** |
| `proxy on` 启动 | 网络代理技能 | `/root/.local/share/hermes-proxy/` | `/tmp/sub_backup.txt` |

**教训**：`proxy status` 检查的是 `/root/.local/share/hermes-proxy/mihomo.pid`，但如果 hermes-agent 内置实例在运行，`proxy on` 会尝试启动第二个 mihomo（端口被占用而失败），状态命令显示"未运行"是**误报**。

**正确诊断方法**：
```bash
ss -tlnp | grep mihomo  # 看端口是否在监听
curl http://127.0.0.1:9090/proxies  # 看控制器是否响应
```

## VLESS Reality + curl / yt-dlp 不兼容

**现象**：`curl --proxy http://127.0.0.1:7897 https://xxx` → CONNECT 隧道建立成功（HTTP 200），但 TLS 握手失败（SSL_ERROR_SYSCALL）

**原因**：订阅节点使用 VLESS Reality 协议，curl 的 CONNECT 代理机制对 Reality 的伪造 TLS 指纹不透明。

**不受影响的工具**：Playwright Chromium（自己完成 TLS）、Python requests（部分）、浏览器 — 这些工具自己完成 TLS 握手，不依赖代理的 TLS termination。

**解决方案**：使用 `172.23.32.1:7897`（Windows Clash Verge）而非 `127.0.0.1:7897`（WSL mihomo）。

## 订阅节点故障排查

**症状**：代理 curl 不通，但 Playwright 直连 httpbin.org 正常（直连可用时）

**订阅 URL**：`https://liangxin.xyz/api/v1/liangxin?OwO=85268a6a92b449970cf5382f060a531b`

订阅 URL 本身正常（返回 ~19KB base64 数据），问题在**服务器端节点不响应**（VLESS Reality 服务器下线或被墙）。

**诊断日志**：
```bash
tail -20 /mnt/d/AI/hermes-agent/proxy/proxy.log  # 看是否有最近流量
# 如果日志停在数小时前 → 节点已失效，没有新连接进来
```

**订阅刷新**：
```bash
proxy update  # 会下载新订阅并提示重启
```

## 平台访问状态（2026-05-15 实测）

| 目标 | 直连 | 代理（172.23.32.1:7897） | 说明 |
|------|------|--------------------------|------|
| github.com | ✅ | ✅ | 直连正常，代理正常 |
| httpbin.org | ✅ | ✅ | 直连正常 |
| google.com | ❌ | — | 被墙，需代理 |
| youtube.com | ❌ | ✅ | 被墙，Clash Verge 代理正常 |
| x.com | ❌ | ✅ | 被墙，Clash Verge 代理正常 |
| bilibili.com | ✅ | — | 直连正常 |

## 安装的依赖（实测可用）

```bash
apt-get install -y libasound2t64 libxshmfence1
# Playwright Chromium headless 运行所需最小依赖
```
