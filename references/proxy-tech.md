# 网络代理实战技巧

## http_proxy 环境变量陷阱

mihomo 启动后，若 shell 中设置了 `http_proxy`/`https_proxy` 环境变量，curl 会通过代理访问目标，而 mihomo 本身是代理入口——形成**循环路由**：

```
curl → http_proxy=127.0.0.1:7897 → mihomo → 代理出口 → 目标
                                              ↑
                          curl的代理请求又回到了mihomo自身
```

**表现**：`curl` 返回 `502 Bad Gateway` 或 `HTTP 000`。

**解法**：调用 mihomo 的 API 前，`unset http_proxy https_proxy`：

```bash
unset http_proxy https_proxy
curl -s http://127.0.0.1:9090/proxies | python3 -c "import sys,json; ..."
```

**注意**：mihomo 本身监听 7897 端口是正常的 HTTP 代理，不受此变量影响。受影响的是调用 API 的控制命令。

## Cloudflare 订阅下载

若订阅链接返回 Cloudflare 验证页面（`<!DOCTYPE html><html lang="en-US"><head><title>Just a moment...`），**链接本身可能没失效**，只是请求头不对。

**订阅下载标准命令（必须加 User-Agent，否则必拦）**：

```bash
curl -sL \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
  -o ~/.hermes-proxy/subscription_backup.txt \
  "https://your-subscription-url-here"
```

**若仍被拦截**：直连和走 Windows 代理（`-x http://172.23.32.1:7897`）各试一次。

## mihomo API 调用

```bash
# ⚠️ 先清除代理变量，避免循环路由
unset http_proxy https_proxy

# 节点列表
curl -s http://127.0.0.1:9090/proxies

# 切换节点（URL-test 组内自动测速）
curl -X PUT http://127.0.0.1:9090/proxies/♻️%20自动选择 \
  -H "Content-Type: application/json" \
  -d '{"name":"节点名"}'

# 强制测速所有节点
curl -X PUT http://127.0.0.1:9090/proxies/♻️%20自动选择 \
  -H "Content-Type: application/json" \
  -d '{"name":"♻️ 自动选择"}'
```

## Windows Clash → WSL 下载隧道

当 WSL 无法直接访问外网，但 Windows Clash Verge 已运行：

```bash
# 确认 Windows 代理地址
ip route show | grep default   # 通常是 172.23.x.1
curl -s --max-time 5 -x http://172.23.32.1:7897 https://www.google.com -o /dev/null -w "%{http_code}"
# 返回 200 = Windows 代理畅通

# GitHub 下载（走 Windows 代理）
curl -L --proxy http://172.23.32.1:7897 \
  "https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-amd64-v1.19.24.gz" \
  -o /tmp/mihomo.gz
```

## mihomo 调试启动

```bash
# 前台启动（看实时日志）
~/.hermes-proxy/mihomo -f ~/.hermes-proxy/config.yaml

# 查看配置是否正确
python3 -c "
import yaml, sys
d = yaml.safe_load(open('$HOME/.hermes-proxy/config.yaml'))
print('节点数:', len(d.get('proxies', [])))
print('代理组:', [g['name'] for g in d.get('proxy-groups', [])])
"
```

## 常用命令

```bash
proxy on      # 刷新订阅 + 启动 + 设置环境变量
proxy off     # 停止 + 清除环境变量
proxy status  # 查看状态
proxy list    # 列出节点
proxy update  # 强制刷新订阅
```

## 端口说明

| 端口 | 用途 |
|------|------|
| 7897 | HTTP 代理（主要） |
| 9090 | 控制面板 API |

检查端口：`ss -tlnp | grep mihomo`
