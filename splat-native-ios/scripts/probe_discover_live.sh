#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${SCANLAB_PUBLIC_URL:-https://gybchnyqlqwmajwkhsly.supabase.co/functions/v1/scanlab-public}"
BODY="$(mktemp)"
BAD="$(mktemp)"
trap 'rm -f "$BODY" "$BAD"' EXIT

status="$(curl --connect-timeout 10 --max-time 25 --silent --show-error --output "$BODY" --write-out '%{http_code}' \
  "$BASE_URL?mode=feed&limit=1&includeModel=0&q=__d2_runtime_probe__")"
[[ "$status" == "200" ]] || { echo "Discover live feed returned HTTP $status"; cat "$BODY"; exit 1; }

python3 - "$BODY" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    payload=json.load(f)
assert isinstance(payload.get('items'), list), payload
assert payload.get('nextCursor') is None or isinstance(payload.get('nextCursor'), str), payload
assert 'nextOffset' not in payload, payload
assert 'hasMore' not in payload, payload
print('PASS: live Discover feed exposes cursor response contract')
PY

bad_status="$(curl --connect-timeout 10 --max-time 25 --silent --show-error --output "$BAD" --write-out '%{http_code}' \
  "$BASE_URL?mode=feed&cursor=bad")"
[[ "$bad_status" == "400" ]] || { echo "Invalid cursor probe returned HTTP $bad_status"; cat "$BAD"; exit 1; }
python3 - "$BAD" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    payload=json.load(f)
assert payload == {'error': 'invalid_cursor'}, payload
print('PASS: live Discover cursor validation is active')
PY

# Real-data parity gate. This never creates fixtures: it only becomes strict once
# production contains enough genuine public scans to exercise a second page.
python3 - "$BASE_URL" <<'PY'
import json
import sys
import urllib.parse
import urllib.request

base = sys.argv[1]

def get(params):
    url = base + '?' + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={'Accept': 'application/json'})
    with urllib.request.urlopen(req, timeout=25) as response:
        assert response.status == 200, (response.status, url)
        payload = json.load(response)
    assert isinstance(payload.get('items'), list), payload
    cursor = payload.get('nextCursor')
    assert cursor is None or isinstance(cursor, str), payload
    return payload

first = get({'mode': 'feed', 'limit': 20, 'includeModel': 0})
if first.get('nextCursor') is None:
    print(f"PENDING: real-data Discover parity gate needs >20 public scans; first page currently has {len(first['items'])}")
    raise SystemExit(0)

all_items = []
seen_ids = set()
seen_cursors = set()
payload = first
pages = 0
while True:
    pages += 1
    assert pages <= 100, 'Discover pagination did not terminate within 100 pages'
    for item in payload['items']:
        scan_id = item.get('id')
        assert isinstance(scan_id, str) and scan_id, item
        assert scan_id not in seen_ids, f'duplicate Discover scan across pages: {scan_id}'
        seen_ids.add(scan_id)
        all_items.append(item)
    cursor = payload.get('nextCursor')
    if cursor is None:
        break
    assert cursor not in seen_cursors, f'cursor replay detected: {cursor}'
    seen_cursors.add(cursor)
    payload = get({'mode': 'feed', 'limit': 20, 'includeModel': 0, 'cursor': cursor})

assert len(all_items) > 20, len(all_items)
assert pages >= 2, pages
sample = next((item for item in all_items if isinstance(item.get('title'), str) and item['title'].strip()), None)
assert sample is not None, 'no searchable title found in real Discover data'
query = sample['title'].strip()[:80]
searched = get({'mode': 'feed', 'limit': 20, 'includeModel': 0, 'q': query})
assert any(item.get('id') == sample.get('id') for item in searched['items']), (
    'real title search did not return sampled scan', sample.get('id'), query
)
print(f"PASS: real-data Discover parity traversed {pages} pages / {len(all_items)} unique scans, reached terminal cursor, and title search hit {sample.get('id')}")
PY
