import json, urllib.request, time, sys

HS = 'http://localhost:6167'
TOKEN = 'C2seZDqk1OrBIjnMizBIyJnLv5xmPxRf'
ROOM = '!MebIyXpRdL0lTTqNVT:localhost'

msg = sys.argv[1] if len(sys.argv) > 1 else '!admin --help'
if not msg.startswith('!admin'):
    msg = '!admin ' + msg

txn = str(int(time.time() * 1000))
body = json.dumps({'msgtype': 'm.text', 'body': msg}).encode()
req = urllib.request.Request(
    f'{HS}/_matrix/client/v3/rooms/{ROOM}/send/m.room.message/txn_{txn}',
    data=body, headers={'Authorization': f'Bearer {TOKEN}', 'Content-Type': 'application/json'}, method='PUT')
resp = json.loads(urllib.request.urlopen(req).read())
print('Sent:', resp.get('event_id', 'ERROR'))
sent_event_id = resp.get('event_id', '')

time.sleep(3)

req2 = urllib.request.Request(
    f'{HS}/_matrix/client/v3/rooms/{ROOM}/messages?limit=5&dir=b',
    headers={'Authorization': f'Bearer {TOKEN}'})
resp2 = json.loads(urllib.request.urlopen(req2).read())
for event in resp2.get('chunk', []):
    eid = event.get('event_id', '')
    sender = event.get('sender', '')
    # Find the first bot response that's newer than our sent message
    if eid != sent_event_id and sender != '@admin:localhost':
        body_text = event.get('content', {}).get('body', '')
        print(body_text)
        break
