#!/usr/bin/env python3
"""Register all appservices with conduwuit via the admin room."""
import json, urllib.request, time, sys, os, glob

HS = 'http://localhost:6167'
TOKEN = sys.argv[1] if len(sys.argv) > 1 else 'NSImajPlFlHC80hHIZuX5bLdhkwmrkDL'
ROOM = '!MebIyXpRdL0lTTqNVT:localhost'

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TXN_COUNTER = [0]

def send_message(body):
    TXN_COUNTER[0] += 1
    txn = f"reg_{int(time.time())}_{TXN_COUNTER[0]}"
    data = json.dumps({'msgtype': 'm.text', 'body': body}).encode()
    req = urllib.request.Request(
        f'{HS}/_matrix/client/v3/rooms/{urllib.parse.quote(ROOM, safe="")}/send/m.room.message/txn_{txn}',
        data=data,
        headers={'Authorization': f'Bearer {TOKEN}', 'Content-Type': 'application/json'},
        method='PUT'
    )
    resp = json.loads(urllib.request.urlopen(req).read())
    sent_id = resp.get('event_id', '')
    
    # Wait for response
    time.sleep(2)
    
    # Read latest messages
    req2 = urllib.request.Request(
        f'{HS}/_matrix/client/v3/rooms/{urllib.parse.quote(ROOM, safe="")}/messages?limit=5&dir=b',
        headers={'Authorization': f'Bearer {TOKEN}'}
    )
    resp2 = json.loads(urllib.request.urlopen(req2).read())
    
    for event in resp2.get('chunk', []):
        if event.get('event_id') == sent_id:
            continue
        sender = event.get('sender', '')
        if '@conduit' in sender or '@conduwuit' in sender:
            return event.get('content', {}).get('body', '')
    
    return '(no response)'

# Register each bridge
bridges = ['discord', 'whatsapp', 'slack', 'signal', 'gmessages', 'telegram']

print("=" * 50)
print(" Unregistering old appservices")
print("=" * 50)
for bridge in bridges:
    result = send_message(f"!admin appservices unregister {bridge}")
    print(f"  {bridge}: {result}")

print()
print("=" * 50)
print(" Registering Appservices with Conduwuit")
print("=" * 50)

for bridge in bridges:
    reg_file = os.path.join(PROJECT_ROOT, 'bridges', f'mautrix-{bridge}', 'registration.yaml')
    if not os.path.exists(reg_file):
        print(f"  SKIP {bridge}: registration.yaml not found")
        continue
    
    with open(reg_file) as f:
        reg_content = f.read().strip()
    
    # Format: !admin appservices register + code block
    message = f"!admin appservices register\n```\n{reg_content}\n```"
    
    print(f"  Registering {bridge}...")
    result = send_message(message)
    print(f"    -> {result}")
    print()

# Verify
print("=" * 50)
print(" Verifying registered appservices")
print("=" * 50)
result = send_message("!admin appservices list-registered")
print(f"  {result}")
