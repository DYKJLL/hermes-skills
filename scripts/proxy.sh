#!/bin/bash
# hermes-proxy 控制脚本
# 用法: proxy on|off|status|list|test|update
#
# 所需环境变量:
#   HERMES_PROXY_DIR      配置目录（默认 ~/.hermes-proxy）
#   HERMES_MIHOMO         mihomo 二进制路径（默认 ~/bin/mihomo）
#   HERMES_PROXY_SUBS_URL 订阅链接（默认从环境变量读取）

: "${HERMES_PROXY_DIR:=$HOME/.hermes-proxy}"
: "${HERMES_MIHOMO:=$HOME/bin/mihomo}"

# 订阅链接必须通过环境变量传入，不允许硬编码
if [ -z "$HERMES_PROXY_SUBS_URL" ]; then
    echo "❌ 未设置 HERMES_PROXY_SUBS_URL 环境变量"
    echo "   请先设置: export HERMES_PROXY_SUBS_URL=\"你的订阅链接\""
    echo "   然后再运行 proxy on"
    return 1 2>/dev/null || exit 1
fi

CONFIG_DIR="$HERMES_PROXY_DIR"
MIHOMO="$HERMES_MIHOMO"
PID_FILE="$CONFIG_DIR/mihomo.pid"
SUBS_FILE="$CONFIG_DIR/subscription_backup.txt"
SUBS_URL="$HERMES_PROXY_SUBS_URL"

# ============================================================
# 生成 mihomo 配置（从 base64 订阅解析 VLESS 节点）
# ============================================================
proxy_generate_config() {
    local sub_file="$1"
    local config_file="$2"

    if [ ! -s "$sub_file" ]; then
        echo "❌ 订阅文件为空: $sub_file"
        return 1
    fi

    python3 - "$sub_file" "$config_file" << 'PYEOF'
import sys, base64, urllib.parse, yaml

sub_file = sys.argv[1]
config_file = sys.argv[2]

content = open(sub_file, 'rb').read()
decoded = base64.b64decode(content).decode('utf-8')
lines = [l.strip() for l in decoded.split('\n') if l.strip()]

proxies = []
for line in lines:
    if not line.startswith('vless://'):
        continue
    line = line[8:]
    hash_pos = line.find('#')
    name = urllib.parse.unquote(line[hash_pos+1:]) if hash_pos != -1 else 'unknown'
    if hash_pos != -1:
        line = line[:hash_pos]
    at_pos = line.find('@')
    if at_pos == -1:
        continue
    uuid_str = line[:at_pos]
    rest = line[at_pos+1:]
    colon_port = rest.rfind(':')
    if colon_port == -1:
        continue
    host = rest[:colon_port]
    port_str = rest[colon_port+1:]
    question_pos = port_str.find('?')
    port = int(port_str[:question_pos]) if question_pos != -1 else int(port_str)
    params = dict(urllib.parse.parse_qsl(port_str[question_pos+1:])) if question_pos != -1 else {}
    if host == '127.0.0.1':
        continue
    sni = params.get('sni', '')
    pbk = params.get('pbk', '')
    sid = params.get('sid', '')
    fp = params.get('fp', 'chrome')
    network = params.get('type', 'tcp')
    security = params.get('security', '')
    proxy = {
        'name': name,
        'type': 'vless',
        'server': host,
        'port': port,
        'uuid': uuid_str,
        'client-fingerprint': fp,
        'udp': True,
    }
    if network:
        proxy['network'] = network
    if security == 'reality' and pbk:
        proxy['tls'] = True
        proxy['servername'] = sni or host
        proxy['reality-opts'] = {'public-key': pbk, 'short-id': sid}
    elif security:
        proxy['tls'] = True
        proxy['servername'] = sni or host
    proxies.append(proxy)

config = {
    'port': 7897,
    'bind-address': '127.0.0.1',
    'mode': 'rule',
    'log-level': 'info',
    'allow-lan': False,
    'external-controller': '127.0.0.1:9090',
    'secret': '',
    'proxies': proxies,
    'proxy-groups': [
        {
            'name': '🚀 节点选择',
            'type': 'select',
            'proxies': ['♻️ 自动选择'] + [p['name'] for p in proxies]
        },
        {
            'name': '♻️ 自动选择',
            'type': 'url-test',
            'proxies': [p['name'] for p in proxies],
            'url': 'http://www.gstatic.com/generate_204',
            'interval': 300,
            'tolerance': 50
        },
        {
            'name': '🛑 禁用代理',
            'type': 'select',
            'proxies': ['DIRECT']
        },
    ],
    'rules': [
        'DOMAIN-SUFFIX,github.com,🚀 节点选择',
        'DOMAIN-SUFFIX,githubusercontent.com,🚀 节点选择',
        'DOMAIN-KEYWORD,github,🚀 节点选择',
        'DOMAIN-SUFFIX,claude.ai,🚀 节点选择',
        'DOMAIN-SUFFIX,anthropic.com,🚀 节点选择',
        'DOMAIN-SUFFIX,openai.com,🚀 节点选择',
        'DOMAIN-SUFFIX,openrouter.ai,🚀 节点选择',
        'DOMAIN-SUFFIX,google.com,🚀 节点选择',
        'DOMAIN-SUFFIX,googleapis.com,🚀 节点选择',
        'DOMAIN-SUFFIX,googleusercontent.com,🚀 节点选择',
        'DOMAIN-SUFFIX,storage.googleapis.com,🚀 节点选择',
        'DOMAIN-SUFFIX,pypi.org,🚀 节点选择',
        'DOMAIN-SUFFIX,pythonhosted.org,🚀 节点选择',
        'DOMAIN-SUFFIX,npmjs.org,🚀 节点选择',
        'DOMAIN-SUFFIX,nodejs.org,🚀 节点选择',
        'DOMAIN-SUFFIX,ubuntu.com,🚀 节点选择',
        'DOMAIN-SUFFIX,debian.org,🚀 节点选择',
        'DOMAIN-SUFFIX,cloudflare.com,🚀 节点选择',
        'DOMAIN-SUFFIX,workers.dev,🚀 节点选择',
        'DOMAIN-SUFFIX,vercel.app,🚀 节点选择',
        'DOMAIN-SUFFIX,jsdelivr.net,🚀 节点选择',
        'GEOIP,CN,🛑 禁用代理',
        'MATCH,🚀 节点选择',
    ],
}

with open(config_file, 'w', encoding='utf-8') as f:
    yaml.dump(config, f, allow_unicode=True, default_flow_style=False, sort_keys=False)

print(f"配置已更新，共 {len(proxies)} 个节点")
PYEOF

    return $?
}

# ============================================================
# 启动代理
# ============================================================
proxy_on() {
    mkdir -p "$CONFIG_DIR"

    # 刷新订阅（直连，15秒超时，User-Agent伪装）
    if curl -s --max-time 15 \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        "$SUBS_URL" -o "$SUBS_FILE" 2>/dev/null && [ -s "$SUBS_FILE" ]; then
        echo "📡 订阅已刷新 ($(wc -c < "$SUBS_FILE") bytes)"
        proxy_generate_config "$SUBS_FILE" "$CONFIG_DIR/config.yaml"
    else
        echo "📡 订阅下载失败，使用本地缓存..."
        if [ ! -s "$CONFIG_DIR/config.yaml" ]; then
            echo "❌ 无可用配置，请检查订阅链接"
            return 1
        fi
    fi

    # mihomo 已在运行则跳过
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "✅ mihomo已在运行 (PID: $(cat "$PID_FILE"))"
        return 0
    fi

    # 启动 mihomo（后台，-d 指定配置目录，自动加载 config.yaml）
    nohup "$MIHOMO" -d "$CONFIG_DIR" >> "$CONFIG_DIR/proxy.log" 2>&1 &
    local mihomo_pid=$!
    echo "$mihomo_pid" > "$PID_FILE"
    sleep 2

    if kill -0 "$mihomo_pid" 2>/dev/null; then
        echo "✅ mihomo已启动 (PID: $mihomo_pid)"
        export http_proxy="http://127.0.0.1:7897"
        export https_proxy="http://127.0.0.1:7897"
        export HTTP_PROXY="http://127.0.0.1:7897"
        export HTTPS_PROXY="http://127.0.0.1:7897"
        echo "✅ 环境变量已设置 (本机代理: 127.0.0.1:7897)"
    else
        echo "❌ 启动失败，查看日志: tail $CONFIG_DIR/proxy.log"
        return 1
    fi
}

# ============================================================
# 停止代理
# ============================================================
proxy_off() {
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        kill "$pid" 2>/dev/null && echo "✅ mihomo已停止 (PID: $pid)" || echo "⚠️ 进程已终止"
        rm -f "$PID_FILE"
    else
        echo "⚠️ mihomo未运行"
    fi
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY 2>/dev/null
}

# ============================================================
# 查看状态
# ============================================================
proxy_status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "✅ mihomo运行中 (PID: $(cat "$PID_FILE"))"
        # 通过 RESTful API 获取当前节点和延迟
        curl -s --max-time 2 http://127.0.0.1:9090/proxies | python3 -c "
import sys, json
rocket = '\U0001F680'
auto_sel = '\U0000267B\uFE0F'
try:
    d = json.load(sys.stdin)
    global_name = d.get('global', {}).get('globalServerName', 'N/A')
    print('当前选择:', global_name)
    proxies = d.get('proxies', {})
    auto = proxies.get(auto_sel + ' 自动选择', {})
    if 'history' in auto and auto['history']:
        print('测速延迟:', auto['history'][-1].get('delay', 'N/A'), 'ms')
except:
    print('控制面板: http://127.0.0.1:9090')
" 2>/dev/null || echo "控制面板: http://127.0.0.1:9090"
    else
        echo "⚠️ mihomo未运行"
    fi
}

# ============================================================
# 列出所有节点
# ============================================================
proxy_list() {
    if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
        echo "⚠️ 配置文件不存在，请先运行 proxy on"
        return 1
    fi
    python3 - "$CONFIG_DIR/config.yaml" << 'PYEOF'
import yaml, sys
rocket = '\U0001F680'
auto_sel = '\U0000267B\uFE0F'
with open(sys.argv[1]) as f:
    cfg = yaml.safe_load(f)
for g in cfg.get('proxy-groups', []):
    if rocket in g.get('name', ''):
        print('可用节点:')
        for n in g.get('proxies', []):
            if auto_sel not in n:
                print(' ', n)
        break
PYEOF
}

# ============================================================
# 切换并测速节点
# ============================================================
proxy_test() {
    local node="$1"
    if [ -z "$node" ]; then
        echo "用法: proxy test <节点名>"
        echo "当前可用节点:"
        proxy_list
        return 1
    fi

    local response
    response=$(curl -s --max-time 5 -X PUT "http://127.0.0.1:9090/proxies/global" \
        -H "Content-Type: application/json" \
        -d "{\"serverName\":\"$node\"}" 2>/dev/null)

    if echo "$response" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    name = d.get('global', {}).get('globalServerName', 'N/A')
    print('切换结果:', name)
except:
    print('切换失败:', sys.stdin.read() if hasattr(sys.stdin, 'read') else 'parse error')
" 2>/dev/null; then
        return 0
    else
        echo "❌ 请先运行 proxy on"
        return 1
    fi
}

# ============================================================
# 更新订阅
# ============================================================
proxy_update() {
    echo "正在更新订阅..."
    if ! curl -s --max-time 15 \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        "$SUBS_URL" -o "$SUBS_FILE"; then
        echo "❌ 订阅下载失败"
        return 1
    fi
    echo "订阅下载成功"
    proxy_generate_config "$SUBS_FILE" "$CONFIG_DIR/config.yaml"
    echo "配置已更新，运行 proxy off && proxy on 重启生效"
}

# ============================================================
# 主入口
# ============================================================
case "$1" in
    on)     proxy_on ;;
    off)    proxy_off ;;
    status) proxy_status ;;
    list)   proxy_list ;;
    test)   proxy_test "$2" ;;
    update) proxy_update ;;
    *)      echo "用法: proxy on|off|status|list|test [节点名]|update" ;;
esac