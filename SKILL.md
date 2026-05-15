---
name: hermes-proxy
description: |
  WSL/ Linux 网络代理技能。基于 mihomo（Clash.Meta）实现。
  mihomo 运行于本机 7897 端口作为 SOCKS/HTTP 代理，配合规则分流。
  GitHub/Google 等国外流量走代理，国内（GEOIP CN）直连。
  通过订阅链接自动维护节点列表，支持一键启动/切换/测速。
category: 网络
triggers:
  - 代理
  - proxy
  - 网络代理
  - 翻墙
  - 节点
  - 科学上网
usage: |
  ## 前置要求
  - mihomo 二进制: `~/bin/mihomo` 或环境变量 `HERMES_MIHOMO` 指定
  - 首次运行会自动初始化配置目录

  ## 命令
  - `proxy on`       启动代理 + 自动刷新订阅
  - `proxy off`      停止代理
  - `proxy status`   查看运行状态和当前节点
  - `proxy list`     列出所有可用节点
  - `proxy test 节点` 切换到指定节点并测速
  - `proxy update`   强制刷新订阅

  ## 环境变量

  | 变量 | 默认值 | 说明 |
  |------|--------|------|
  | `HERMES_PROXY_DIR` | `~/.hermes-proxy` | 配置目录 |
  | `HERMES_MIHOMO` | `~/bin/mihomo` | mihomo 二进制路径 |
  | `HERMES_PROXY_SUBS_URL` | （内置）| 订阅链接，更换时设置此变量 |

  ## 订阅更新
  设置环境变量后运行 `proxy update`：
  ```bash
  export HERMES_PROXY_SUBS_URL="你的新订阅链接"
  proxy update
  ```
---

# hermes-proxy

基于 mihomo（Clash.Meta）v1.19+ 的 WSL/ Linux 网络代理技能。

## 系统要求

- Linux / macOS / WSL
- mihomo 二进制（[下载](https://github.com/MetaCubeX/mihomo/releases)，放在 `~/bin/mihomo`）
- Python 3（用于解析订阅配置）

## 安装

> **源码仓库**: https://github.com/DYKJLL/hermes-proxy

### 1. 安装 mihomo

```bash
# Linux/macOS
curl -L https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-amd64-vX.XX.X.gz | gunzip > ~/bin/mihomo
chmod +x ~/bin/mihomo

# WSL（通过 Windows 代理下载）
curl -L --proxy http://172.23.32.1:7897 https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-amd64-vX.XX.X.gz | gunzip > ~/bin/mihomo
```

### 2. 安装本技能

将 `scripts/proxy.sh` 软链接到 PATH 中：

```bash
mkdir -p ~/bin
ln -sf ~/.hermes/skills/network/hermes-proxy/scripts/proxy.sh ~/bin/proxy
chmod +x ~/.hermes/skills/network/hermes-proxy/scripts/proxy.sh
```

### 3. 初始化

```bash
proxy on   # 首次自动创建 ~/.hermes-proxy 配置目录并拉取订阅
```

## 代理规则

| 流量 | 走向 |
|------|------|
| GitHub / Google / Claude / OpenAI / Pypi / NPM | 走代理 |
| 国内（ GEOIP=CN ） | 直连 |
| 其他 | 默认走代理 |

## 架构说明

```
proxy on
  └── 拉取订阅（base64 → vless nodes）
       └── 生成 ~/.hermes-proxy/config.yaml
            └── 启动 mihomo（7897 端口）
                 └── 本机 HTTP/SOCKS5 代理
                      └── 规则分流 → 节点选择 / 自动测速
```

## 订阅链接管理

订阅链接存储在 `HERMES_PROXY_SUBS_URL` 环境变量，默认值在脚本内。

**更换订阅：**
```bash
export HERMES_PROXY_SUBS_URL="https://你的新订阅链接"
proxy update
```

**检查当前订阅：**
```bash
echo $HERMES_PROXY_SUBS_URL
```

## 故障排除

| 问题 | 解决方案 |
|------|---------|
| `curl: (7) Failed to connect` | 检查网络，订阅链接是否被墙阻断 |
| `mihomo: command not found` | 确认 mihomo 在 `~/bin/mihomo` 或设置 `HERMES_MIHOMO` |
| 所有节点延迟 N/A | 订阅过期，运行 `proxy update` 刷新 |
| WSL 无法直连 VLESS | WSL 与 Windows 网络隔离，参考下方「WSL 特殊说明」 |

### WSL 特殊说明

WSL 无法直连某些境外 VLESS 服务器（网络隔离）。可选方案：

**方案 A（推荐）：将 Windows Clash 作为上游代理**
```bash
# WSL 内所有流量走 Windows Clash
export http_proxy="http://172.23.32.1:7890"
export https_proxy="http://172.23.32.1:7890"
```

**方案 B：Clash Verge 的 TUN 模式**
在 Windows Clash Verge 中开启 TUN mode，WSL 内所有流量自动经过 Clash。

## 文件结构

```
~/.hermes-proxy/           # 配置目录（环境变量 HERMES_PROXY_DIR）
├── config.yaml            # mihomo 主配置（自动生成）
├── subscription_backup.txt # 订阅原始内容（base64）
├── mihomo.pid             # 进程 PID
└── proxy.log             # mihomo 运行日志

~/.hermes/skills/network/hermes-proxy/
├── SKILL.md              # 本文档
├── skill.yaml             # 技能注册文件
├── scripts/
│   └── proxy.sh          # 控制脚本（已在 ~/bin/proxy 软链接）
└── references/
    └── proxy-tech.md      # mihomo 配置语法等技术细节
```
