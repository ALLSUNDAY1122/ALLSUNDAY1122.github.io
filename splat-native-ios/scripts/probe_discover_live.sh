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
