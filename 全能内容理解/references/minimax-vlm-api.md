# MiniMax VLM 端点研究笔记

## 背景
2026-05-18 调试 MiniMax 图片理解 API 时，发现 `/v1/chat/completions` 不支持 base64 内嵌图片，需用独立 VLM 端点。

## 关键发现

### 正确端点
```
POST https://api.minimax.chat/v1/coding_plan/vlm  (Global)
POST https://api.minimaxi.com/v1/coding_plan/vlm    (CN)
```

### 正确请求体格式
```json
{
  "prompt": "详细描述这张图片",
  "image_url": "data:image/jpeg;base64,..." 
}
```

### 错误路线（❌ 不支持）
- `/v1/chat/completions` + `messages[].content[].type="image_url"` — MiniMax 不走这个
- `vision_analyze` 工具 — Sandbox 隔离，不支持外部URL/WSL路径
- 直接把 base64 字符串放 prompt 文本里 — 模型忽略

### mmx CLI 源码线索
`/usr/lib/node_modules/mmx-cli/dist/sdk.mjs` 第1450-1490行附近有 `describe` 方法实现，可参考。

### 验证方法
```python
import base64, json, urllib.request, os

def minimax_vlm(image_path, prompt="描述这张图片"):
    with open(image_path, "rb") as f:
        img_b64 = base64.b64encode(f.read()).decode()
    data_url = f"data:image/jpeg;base64,{img_b64}"
    api_key = "sk-..."  # from /root/.hermes/.env
    proxy_handler = urllib.request.ProxyHandler({"http": "http://172.23.32.1:7897", "https": "http://172.23.32.1:7897"})
    opener = urllib.request.build_opener(proxy_handler)
    ep = "https://api.minimax.chat/v1/coding_plan/vlm"
    req = urllib.request.Request(ep,
        data=json.dumps({"prompt": prompt, "image_url": data_url}).encode(),
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        method="POST")
    with opener.open(req, timeout=20) as resp:
        return json.loads(resp.read()).get("content", "")
```

### 已知限制
- endpoint 可能随模型更新而变化，需验证
- `purpose` 字段在文件上传 API 不支持 vision，需确认当前可用端点

## X.com 视频 URL 解析补充
Playwright 的 `page.content()` 返回的 HTML 中，视频URL含 HTML 实体（如 `&amp;`），需用 `html.unescape()` 解码后再提取。

```python
import html as html_mod
unescaped = html_mod.unescape(page_content)
mp4_urls = re.findall(r'https://video\.twimg\.com/[^"\'>\s]+mp4[^"\'>\s]*', unescaped)
```