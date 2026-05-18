# MiniMax 多模态 API 研究记录（2026-05-18）

## 确认的事实

### 可用
- 纯文本对话：`POST /v1/chat/completions` ✅
- API key 有效：`Authorization: Bearer <key>` ✅
- 模型列表：`GET /v1/models` → MiniMax-M2.7, M2.5, M2.1 等 ✅

### 不支持
- base64 内嵌图片（`data:image/jpeg;base64,...`）→ 模型返回"没有图片" ❌
- 纯 base64 字符串作为 url → 同上 ❌
- `/v1/vision` 系列端点 → 全部 404 ❌
- `/v1/images/understand` → 404 ❌
- `/v1/files/upload`（purpose=vision/image/multimodal 等）→ 2013 invalid purpose ❌

## 探测过的端点

| 端点 | 方法 | 结果 |
|------|------|------|
| `https://api.minimax.chat/v1/chat/completions` | GET | 404 |
| `https://api.minimax.chat/v1/chat/completions` | POST 文本 | 200 ✅ |
| `https://api.minimax.chat/v1/chat/completions` | POST base64图片 | 200 但模型回复"没有图片" ❌ |
| `https://api.minimax.chat/v1/vision` | GET | 404 |
| `https://api.minimax.chat/v1/vision/chat` | GET | 404 |
| `https://api.minimax.chat/v1/images/understand` | GET | 404 |
| `https://api.minimax.chat/v1/images/understand` | POST | 404 |
| `https://api.minimax.io/v1/chat/completions` | GET/POST | 404 |
| `https://api.minimax.chat/v1/files/upload` | POST | 200 (purpose无效) |
| `https://www.minimaxi.com/v1/files` | POST | 404 |

## 待继续研究

1. MiniMax 官方多模态 API 文档（需要找真实 endpoint）
2. MiniMax 的 `/v1/images` 或 `/v1/multimodal` 正确端点
3. 是否有文件上传+图片理解的组合 API
4. MiniMax-M2.7 是否支持 function calling / vision，通过其他方式调用

## 结论

当前 `/v1/chat/completions` 接口**不支持图片理解**（base64 内嵌不工作）。
MiniMax 图片理解需要独立的多模态端点，但尚未找到。

**X.com 配图理解当前只能通过 Playwright 截图 → 展示给用户/手动查看。**
自动化图片理解通路待打通。