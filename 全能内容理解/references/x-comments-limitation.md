# X.com 评论区提取 — 已知限制

> **更新时间**：2026-05-16  
> **问题等级**：平台级限制（X.com 反爬机制）

---

## 核心问题

X.com 推文的**评论区（Replies）**需要登录才能查看，未登录状态下：

- 点击 "Read N replies" → **无响应或被拦截**
- browser_snapshot 只显示主推文 + 互动数字（7 replies, 6 reposts...）
- 评论区内容完全不暴露

---

## 已尝试的方法

| 方法 | 评论区 | 主推文 | 备注 |
|------|--------|--------|------|
| browser_navigate → snapshot | ❌ 无法获取 | ✅ | 需要登录 |
| browser_click "Read N replies" | ❌ 无响应 | ✅ | X 要求登录 |
| browser_vision（截图分析） | ❌ 截不到 | ✅ | 截图只含主推文区域 |
| yt-dlp | ❌ | ✅ 仅视频推文 | 评论永远拿不到 |
| Chrome DevTools CDP | ⚠️ 未测试 | ✅ | 复用已有登录态可能可行 |

---

## 当前最优方案

### 方案 1：Apify Twitter Scraper（推荐）

需要 Apify API Token，可抓取推文 + 评论：

```python
from apify_client import ApifyClient

client = ApifyClient("YOUR_TOKEN")
tweet_url = "https://x.com/user/status/2055471046791471151"
tweet_id = tweet_url.split("/")[-1]

run = client.actor("apify~twitter-scraper").start(run_input={
    "startUrls": [{"url": tweet_url}],
    "tweetIds": [tweet_id],
    "maxReplies": 50,  # 控制评论数量
})
result = client.run(run).wait_for_finish()
```

> ⚠️ 需要 Token 成本，但**唯一已知可稳定获取评论区**的方案。

### 方案 2：Chrome DevTools CDP（复用登录态）

如果 Windows Chrome 已登录 X.com，理论上可以通过 CDP 复用 session 获取评论区。但**实测未完成**，结果未知。

### 方案 3：nitter.net（仅获取主推文，不能获取评论）

```
https://nitter.net/i/status/{tweet_id}
```

部分推文有效，但评论区同样拿不到。

---

## 结论

| 需求 | 可行性 | 方案 |
|------|--------|------|
| 主推文内容 | ✅ 多种方法 | Playwright / CDP / yt-dlp |
| 评论区（作者+网友回复） | ❌ 需要登录 | Apify（唯一可行）、CDP（未验证） |
| 视频推文字幕 | ✅ | yt-dlp |

**如果用户需要看 X.com 评论区，告知用户需要**：
1. 提供具体评论内容（复制粘贴）
2. 或提供 Apify Token（付费方案）
3. 或告知用户去 X.com 截图

---

## 下次更新方向

测试 Chrome DevTools CDP 复用登录态是否能获取评论区，如果成功，更新此文档。