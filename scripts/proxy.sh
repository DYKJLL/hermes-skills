#!/bin/bash
# hermes-proxy 控制脚本
# 用法: proxy on|off|status|list|test|update
#
# 所需环境变量（可选，有默认值）:
#   HERMES_PROXY_DIR   配置目录（默认 ~/.hermes-proxy）
#   HERMES_PROXY_SUBS_URL  订阅链接

: "${HERMES_PROXY_DIR:=$HOME/.hermes-proxy}"
: "${HERMES_MIHOMO:=$HOME/bin/mihomo}"
: "${SUBS_URL:=https://liangxin.xyz/api/v1/liangxin?OwO=85268a6a92b449970cf5382f060a531b}"

CONFIG_DIR="$HERMES_PROXY_DIR"
MIHOMO="$HERMES_MIHOMO"
PID_FILE="$CONFIG_DIR/mihomo.pid"
SUBS_FILE="$CONFIG_DIR/subscription_backup.txt"

proxy_on() {
    mkdir -p "$CONFIG_DIR"

    # 刷新订阅（直连，15秒超时，User-Agent伪装）
    if curl -s --max-time 15 \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        "$SUBS_URL" -o "$SUBS_FILE" 2>/dev/null && [ -s "$SUBS_FILE" ]; then
        echo "📡 订阅已刷新 ($(wc -c < $SUBS_FILE) bytes)"
        proxy_generate_config
    else
        echo "📡 订阅下载失败，使用本地缓存..."
    fi

    # mihomo已在运行则重载
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "✅ mihomo已在运行 (PID: $(cat $PID_FILE))"
        return 0
    fi

    # 启动mihomo（后台）
    nohup $MIHOMO -d "$CONFIG_DIR" -f "$CONFIG_DIR/config.yaml" > "$CONFIG_DIR/proxy.log" 2>&1 &
    local mihomo_pid=$!
    echo $mihomo_pid > "$PID_FILE"
    sleep 2

    if kill -0 $mihomo_pid 2>/dev/null; then
        echo "✅ mihomo已启动 (PID: $mihomo_pid)"
        export http_proxy="http://127.0.0.1:7897"
        export https_proxy="http://127.0.0.1:7897"
        export HTTP_PROXY="http://127.0.0.1:7897"
        export HTTPS_PROXY="http://127.0.0.1:7897"
        echo "✅ 环境变量已设置 (本机代理: 127.0.0.1:7897)"
    else
        echo "❌ 启动失败，查看日志: cat $CONFIG_DIR/proxy.log"
        return 1
    fi
}

proxy_generate_config() {
    python3 - "$SUBS_FILE" "$CONFIG_DIR/config.yaml" << 'PYEOF'
import sys, base64, urllib.parse, yaml

sub_file = sys.argv[1]
config_file = sys.argv[2]

content = open(sub_file,'rb').read()
decoded = base64.b64decode(content).decode('utf-8')
lines = [l.strip() for l in decoded.split('
') if l.strip()]

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
    if params.get('security', '') == 'reality' and pbk:
        proxy['tls'] = True
        proxy['servername'] = sni or host
        proxy['reality-opts'] = {'public-key': pbk, 'short-id': sid}
    elif params.get('security'):
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
        {'Name': '🚀 节点选择', 'type': 'select', 'proxies': ['♻️ 自动选择'] + [p['name'] for p in proxies]},
        {'Name': '♻️ 自动选择', 'type': 'url-test', 'proxies': [p['name'] for p in proxies], 'url': 'http://www.gstatic.com/generate_204', 'interval': 300, 'tolence': 50},
        {'Name': '🛑 禁用代理', 'type': 'select', 'proxies': ['DIRECT']},
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
}

proxy_off() {
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        kill $pid 2>/dev/null && echo "✅ mihomo已停止 (PID: $pid)" || echo "⚠️ 进程已终止"
        rm -f "$PID_FILE"
    else
        echo "⚠️ mihomo未运行"
    fi
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY 2>/dev/null
}

proxy_status() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "✅ mihomo运行中 (PID: $(cat $PID_FILE))"
        curl -s --max-time 2 http://127.0.0.1:9090/proxies | python3 -c "
import sys, json
d = json.load(sys.stdin)
global_name = d.get('global', {}).get('globalServerName', 'N/A')
print('当前选择:', global_name)
proxies = d.get('proxies', {})
auto = proxies.get('♻️ 自动选择', {})
if 'history' in auto:
    print('测速延迟:', auto['history'][-1].get('delay', 'N/A'), 'ms')
" 2>/dev/null || echo "控制面板: http://127.0.0.1:9090"
    else
        echo "⚠️ mihomo未运行"
    fi
}

proxy_list() {
    if ! command -v python3 &>/dev/null; then
        cat "$CONFIG_DIR/config.yaml" | grep -E '^\s+- name:' | sed 's/.*- name: //' | sort
        return
    fi
    python3 -c "
import yaml
with open('$CONFIG_DIR/config.yaml') as f:
    cfg = yaml.safe_load(f)
groups = cfg.get('proxy-groups', [])
for g in groups:
    if g.get('name') == '🚀 节点选择':
        print('可用节点:')
        for n in g.get('proxies', []):
            if n != '♻️ 自动选择':
                print(' ', n)
        break
"
}

proxy_test() {
    node="\${1:-}"
    if [ -z "\$node" ]; then
        echo "用法: proxy test <节点名>"
        return 1
    fi
    curl -s -X PUT "http://127.0.0.1:9090/proxies/global" -d "{\"serverName\":\"\$node\"}" | python3 -c "
import sys,json
r=json.load(sys.stdin)
print('切换结果:', r.get('global',{}).get('globalServerName','N/A'))
" 2>/dev/null || echo "请先运行 proxy on"
}

proxy_update() {
    echo "正在更新订阅..."
    curl -s --max-time 15 \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        "$SUBS_URL" -o "$SUBS_FILE" && echo "订阅下载成功" || { echo "❌ 订阅下载失败"; return 1; }
    proxy_generate_config
    echo "配置已更新，运行 proxy off && proxy on 重启生效"
}

case "\$1" in
    on)     proxy_on ;;
    off)    proxy_off ;;
    status) proxy_status ;;
    list)   proxy_list ;;
    test)   proxy_test "\$2" ;;
    update) proxy_update ;;
    *)      echo "用法: proxy on|off|status|list|test [节点名]|update" ;;
esac
