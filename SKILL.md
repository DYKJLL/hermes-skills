---
name: 网络代理
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
  - 代理被篡改
  - proxy 安全
  - 流量异常
usage: |
  ## 前置要求
  - mihomo 二进制: `~/bin/mihomo` 或环境变量 `HERMES_MIHOMO` 指定
  - **必须**设置订阅链接环境变量 `HERMES_PROXY_SUBS_URL`（不允许硬编码）

  ## 首次使用
  ```bash
  export HERMES_PROXY_SUBS_URL="你的订阅链接（base64编码）"
  proxy on
  ```

  ## 命令
  - `proxy on`       启动代理 + 自动刷新订阅
  - `proxy off`      停止代理
  - `proxy status`   查看运行状态和当前节点
  - `proxy list`     列出所有可用节点
  - `proxy test 节点` 切换到指定节点并测速
  - `proxy update`   强制刷新订阅

  ## 环境变量

  | 变量 | 必须 | 说明 |
  |------|------|------|
  | `HERMES_PROXY_SUBS_URL` | ✅ 必填 | 订阅链接（无默认值） |
  | `HERMES_PROXY_DIR` | 否 | 配置目录（默认 `~/.hermes-proxy`） |
  | `HERMES_MIHOMO` | 否 | mihomo 二进制（默认 `~/bin/mihomo`） |

  ## 订阅更换
  ```bash
  export HERMES_PROXY_SUBS_URL="新订阅链接"
  proxy update
  ```

  ## 代理规则

  | 流量 | 走向 |
  |------|------|
  | GitHub / Google / Claude / OpenAI / Pypi / NPM | 走代理 |
  | 国内（GEOIP=CN） | 直连 |
  | 其他 | 默认走代理 |

  ## 安全提示
  - 订阅链接必须通过环境变量传入，不允许写死在脚本里
  - 启动前验证 mihomo 二进制 hash，防止被篡改
  - 详情见 `references/proxy-运维发现.md`
---

# hermes-proxy

基于 mihomo（Clash.Meta）v1.19+ 的 WSL/ Linux 网络代理技能。

## 系统要求

- Linux / macOS / WSL
- mihomo 二进制（[下载](https://github.com/MetaCubeX/mihomo/releases)，放在 `~/bin/mihomo`）
- Python 3（用于解析订阅配置）

## 安装

> **源码仓库**: https://github.com/DYKJLL/hermes-skills

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
ln -sf ~/.hermes/skills/network/网络代理/scripts/proxy.sh ~/bin/proxy
chmod +x ~/.hermes/skills/network/网络代理/scripts/proxy.sh
```

### 3. 初始化（必须先设置订阅）

```bash
export HERMES_PROXY_SUBS_URL="你的订阅链接"
proxy on   # 首次自动创建 ~/.hermes-proxy 配置目录并拉取订阅
```

## 文件结构

```
~/.hermes-proxy/              # 配置目录（环境变量 HERMES_PROXY_DIR）
├── config.yaml               # mihomo 主配置（自动生成）
├── subscription_backup.txt   # 订阅原始内容（base64）
├── mihomo.pid                # 进程 PID
└── proxy.log                 # mihomo 运行日志

~/.hermes/skills/network/网络代理/
├── SKILL.md                  # 本文档
├── skill.yaml                # 技能注册文件
├── scripts/
│   └── proxy.sh              # 控制脚本（已在 ~/bin/proxy 软链接）
└── references/
    ├── proxy-tech.md         # mihomo 配置语法等技术细节
    └── proxy-运维发现.md      # 运维发现记录（WSL/Windows 架构、VLESS Reality 兼容性）
```

## 运维发现（重要）

详见 `references/proxy-运维发现.md`，关键结论：

- **WSL mihomo 的 VLESS Reality 对 curl/yt-dlp 不兼容** → 用 Windows Clash Verge（`172.23.32.1:7897`）
- **Git 必须单独配置代理**：`git config --global http.proxy http://172.23.32.1:7897`