# Scrapling — 49,709 ⭐ 自适应 Web 爬虫框架

## 核心定位

> **"一个库，零妥协"** — 自适应 Web Scraping 框架，处理从单次请求到大规模爬取的一切需求。

## 安装

```bash
pip install scrapling --break-system-packages --proxy http://172.23.32.1:7897
pip install "scrapling[fetchers]" --break-system-packages --proxy http://172.23.32.1:7897
```

> WSL 需要加 `--proxy http://172.23.32.1:7897`（Windows Clash Verge），直连 PyPI 会超时。

## 实测验证（2026-05-15）

| 功能 | 状态 |
|------|------|
| `Fetcher().get()` 核心引擎 | ✅ |
| `StealthyFetcher().fetch()` 隐身模式 | ✅ |
| CLI `scrapling extract get` | ✅ |

## 核心 API

### 基础请求（Fetcher）
```python
from scrapling.fetchers import Fetcher
resp = Fetcher().get('https://example.com')
print(resp.css('title::text').get())
```

### 隐身请求（StealthyFetcher）
```python
from scrapling.fetchers import StealthyFetcher
resp = StealthyFetcher().fetch('https://example.com')
# 自动伪造浏览器指纹，绕过 Cloudflare Turnstile 等反机器人
```

### 动态网站（DynamicFetcher）
```python
from scrapling.fetchers import DynamicFetcher
resp = DynamicFetcher().fetch('https://spa.example.com', network_idle=True)
```

## CLI
```bash
scrapling extract get "URL" output.txt
scrapling extract stealthy-fetch "URL" output.txt
```

## 完整文档
`~/.hermes/skills/浏览器自动化/scrapling/` — 含 15 个参考文档（fetching/parsing/spiders）
