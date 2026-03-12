#!/bin/bash
# 通过 admin room 注册所有 appservice 到 conduwuit
# 需要先启动 conduwuit 并创建 admin 用户

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_ROOT/.env"

ACCESS_TOKEN="$1"
ADMIN_ROOM="$2"
HS="http://localhost:${CONDUWUIT_PORT}"

if [ -z "$ACCESS_TOKEN" ] || [ -z "$ADMIN_ROOM" ]; then
    echo "Usage: $0 <access_token> <admin_room_id>"
    exit 1
fi

TXN_ID=0

send_admin_command() {
    local body="$1"
    TXN_ID=$((TXN_ID + 1))
    
    # 构建 JSON body 使用 python3 (正确 escape)
    local json_body
    json_body=$(python3 -c "
import json, sys
body = sys.argv[1]
print(json.dumps({
    'msgtype': 'm.text',
    'body': body
}))
" "$body")
    
    local resp
    resp=$(curl -s -X PUT \
        "${HS}/_matrix/client/v3/rooms/${ADMIN_ROOM}/send/m.room.message/txn_${TXN_ID}" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$json_body")
    
    echo "  送出命令... event: $(echo "$resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("event_id","ERROR"))' 2>/dev/null)"
    
    # 等待处理
    sleep 2
    
    # 读取最新消息看结果
    local messages
    messages=$(curl -s "${HS}/_matrix/client/v3/rooms/${ADMIN_ROOM}/messages?limit=2&dir=b" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" 2>/dev/null)
    
    echo "$messages" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for event in data.get('chunk', []):
    sender = event.get('sender', '')
    if sender != '@admin:localhost':
        body = event.get('content', {}).get('body', '')
        print(f'  回复: {body[:200]}')
        break
" 2>/dev/null || true
}

echo "============================================"
echo " 注册 Appservices 到 Conduwuit"
echo "============================================"
echo ""

for bridge in discord whatsapp slack signal gmessages telegram; do
    reg_file="$PROJECT_ROOT/bridges/mautrix-${bridge}/registration.yaml"
    
    if [ ! -f "$reg_file" ]; then
        echo "⚠ $bridge: registration.yaml 不存在, 跳过"
        continue
    fi
    
    echo "注册 $bridge..."
    
    # 构建消息: 命令 + 代码块
    reg_content=$(cat "$reg_file")
    message="!admin appservice register
\`\`\`
${reg_content}
\`\`\`"
    
    send_admin_command "$message"
    echo ""
done

echo "============================================"
echo " 验证已注册的 Appservices"
echo "============================================"
send_admin_command "!admin appservice list-registered"
