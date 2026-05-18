#!/usr/bin/env python3
"""
MiniMax 多模态能力探针（v2.2 - 2026-05-18）
快速验证当前 MiniMax-M2.7 是否支持图片理解。
用法: python3 test_minimax_vision.py

测试内容：
1. 纯文本对话（验证API连通性）
2. base64 data URL 图片内嵌（/v1/chat/completions 路线）
3. /v1/coding_plan/vlm 端点（MiniMax 专用 VLM 端点）
"""
import json, base64, urllib.request, os, sys

PROXY = "http://172.23.32.1:7897"
CONFIG_PATH = os.path.expanduser("~/.hermes/.env")

def get_api_key():
    with open(CONFIG_PATH) as f:
        for line in f:
            if "API_KEY" in line and "MINIMAX" in line:
                return line.split("=")[1].strip()
    raise RuntimeError("API key not found")

def make_test_image():
    """生成测试图：蓝色矩形+白字"""
    import numpy as np, cv2
    img = np.zeros((200, 400, 3), dtype='uint8')
    cv2.rectangle(img, (20, 20), (380, 180), (100, 150, 200), -1)
    cv2.putText(img, "HERMES TEST", (40, 110), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
    path = "/tmp/vlm_test.jpg"
    cv2.imwrite(path, img)
    with open(path, "rb") as f:
        return path, base64.b64encode(f.read()).decode()

def api_call_text_only(payload):
    api_key = get_api_key()
    proxy_handler = urllib.request.ProxyHandler({'http': PROXY, 'https': PROXY})
    opener = urllib.request.build_opener(proxy_handler)
    req = urllib.request.Request(
        "https://api.minimax.chat/v1/chat/completions",
        data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        method="POST")
    with opener.open(req, timeout=20) as resp:
        return json.loads(resp.read())

def test_text():
    """验证API连通性"""
    r = api_call_text_only({"model": "MiniMax-M2.7", "messages": [{"role": "user", "content": "hi"}], "max_tokens": 10})
    content = r["choices"][0]["message"]["content"]
    ok = len(content) > 0
    print(f"[1] 纯文本: {'✅ OK' if ok else '❌ 空'}")
    return ok

def test_via_chat_completions_b64():
    """测试 /v1/chat/completions + base64 data URL（不支持）"""
    path, b64 = make_test_image()
    payload = {
        "model": "MiniMax-M2.7",
        "messages": [{"role": "user", "content": [
            {"type": "text", "text": "这张图里有什么？"},
            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}}
        ]}],
        "max_tokens": 80
    }
    r = api_call_text_only(payload)
    content = r["choices"][0]["message"]["content"]
    ok = "没有图片" not in content and "没有看到" not in content and len(content) > 5
    print(f"[2] /v1/chat + base64 data URL: {'✅ 支持' if ok else '❌ 不支持（预期）'}")
    if not ok:
        print(f"    模型回复: {content[:100]}")
    os.remove(path)
    return ok

def test_vlm_endpoint():
    """测试 /v1/coding_plan/vlm 端点（MiniMax 专用，✅ 唯一支持图片理解的端点）"""
    path, b64 = make_test_image()
    api_key = get_api_key()
    proxy_handler = urllib.request.ProxyHandler({'http': PROXY, 'https': PROXY})
    opener = urllib.request.build_opener(proxy_handler)
    
    results = []
    for base in ["https://api.minimax.chat", "https://api.minimaxi.com"]:
        ep = f"{base}/v1/coding_plan/vlm"
        req = urllib.request.Request(ep,
            data=json.dumps({"prompt": "详细描述这张图片里有什么？", "image_url": f"data:image/jpeg;base64,{b64}"}).encode(),
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            method="POST")
        try:
            with opener.open(req, timeout=20) as resp:
                r = json.loads(resp.read())
                content = r.get("content", "")
                ok = len(content) > 10
                results.append((base, ok, content[:100]))
        except Exception as e:
            results.append((base, False, str(e)))
    
    os.remove(path)
    for base, ok, detail in results:
        print(f"[3] {base}/v1/coding_plan/vlm: {'✅ 可用' if ok else '❌ 失败'}")
        if ok:
            print(f"    回复: {detail}...")
    return any(ok for _, ok, _ in results)

if __name__ == "__main__":
    print("=== MiniMax 多模态探针 v2.2 ===")
    try:
        t1 = test_text()
        t2 = test_via_chat_completions_b64()
        t3 = test_vlm_endpoint()
        print(f"\n结论:")
        print(f"  /v1/chat/completions + base64: {'✅ 支持' if t2 else '❌ 不支持（正常）'}")
        print(f"  /v1/coding_plan/vlm:           {'✅ 可用' if t3 else '❌ 不可用'}")
        if t3:
            print(f"\n  → MiniMax 图片理解请用 /v1/coding_plan/vlm 端点")
    except Exception as e:
        print(f"❌ 探测失败: {e}")
        import traceback; traceback.print_exc()