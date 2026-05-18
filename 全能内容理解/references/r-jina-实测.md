# r.jina.ai 实测结论（2026-05-19）

## 核心发现

**Python urllib 直连 r.jina.ai 不稳定**（403/超时），但 curl 稳定。
必须用 `subprocess + curl` 调用，不能用 `urllib.request`。

```python
# ❌ 不稳定
import urllib.request
with urllib.request.urlopen(f"https://r.jina.ai/{url}", timeout=15) as resp:
    return resp.read()

# ✅ 稳定
import subprocess
r = subprocess.run(["curl", "-sL", "--max-time", "15", f"https://r.jina.ai/{url}"],
                   capture_output=True, text=True, timeout=20)
return r.stdout
```

## 实测结果

| URL 类型 | r.jina.ai 结果 | 处理 |
|---------|--------------|------|
| CSDN 文章 | 41696字 ✅ | 直接用 |
| 少数派文章 | 1306字 ✅ | 直接用 |
| 知乎文章 | 259字 ⚠️ | 触发兜底(太短→走Playwright) |
| Wikipedia | 正常 ✅ | 直接用 |

## 知乎内容太短的原因

r.jina.ai 只能拿到导航/侧边栏碎片（259字），正文被知乎平台屏蔽。
这是**平台特性**，不是 r.jina.ai 的 bug——正好触发两级策略的 Playwright 兜底。

## 500字阈值依据

- 内容 > 500字：正文充足，直接用
- 内容 ≤ 500字：正文可能被墙，切换 Playwright CDP

## 哪些平台 r.jina.ai 效果差

- 知乎（需登录）
- 微信公众号（需登录）
- 小红书（需登录）
- 任何需要登录才能看全文的站点

这些统一走 Playwright/CDP 兜底。
