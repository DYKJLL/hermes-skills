# MiniMax API 端点参考

> 2026-05-18 验证通过，实测记录。

## 文本对话

| 端点 | 方法 | 格式 |
|------|------|------|
| `https://api.minimax.chat/v1/chat/completions` | POST | OpenAI compatible `{model, messages, ...}` |
| `https://api.minimaxi.com/v1/chat/completions` | POST | 同上 |

- 模型名：`MiniMax-M2.7`
- Auth：`Bearer {api_key}`

## 图片理解（VLM）

**正确的端点和格式（已验证 ✅）**

| 端点 | 方法 | Body 格式 |
|------|------|-----------|
| `https://api.minimax.chat/v1/coding_plan/vlm` | POST | `{prompt, image_url}` |
| `https://api.minimaxi.com/v1/coding_plan/vlm` | POST | 同上 |

- `image_url` = `data:image/jpeg;base64,{base64}`（data URI 格式）
- `prompt` = 中文描述要求，如 "描述这张图片内容"
- 返回：`{"content": "描述文本", "base_resp": {"status_code": 0}}`

**错误尝试（不要用）：**
- ❌ `/v1/chat/completions` + `messages.content[].image_url` → 模型返回"没有图片"
- ❌ `/v1/vision` → 404
- ❌ `/v1/images/understand` → 404
- ❌ `vision_analyze` 工具（sandbox 隔离，不支持外部 URL 和 WSL 路径）

## mmx CLI（已安装）

```bash
mmx vision describe /path/to/image.jpg --api-key sk-xxx
# 内部调用 /v1/coding_plan/vlm
```

## 可用工具链

| 工具 | 安装 | 用途 |
|------|------|------|
| ffmpeg | `apt install ffmpeg` | 音频提取 |
| whisper (openai-whisper) | `pip install openai-whisper` | 语音转文字 |
| cv2 (opencv-python) | `pip install opencv-python` | 视频帧截取 |
| yt-dlp | `pip install yt-dlp` | 视频下载 |
| mmx | `npm install -g mmx-cli` | CLI 多模态接口 |

## 代理配置

所有 HTTP 请求通过 `http://172.23.32.1:7897` 代理。

## API Key 来源

`/root/.hermes/.env` 中的 `MINIMAX_API_KEY=...`（Mainland CN key）