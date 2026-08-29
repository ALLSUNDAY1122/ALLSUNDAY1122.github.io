#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from app_store_connect_api import api_get, api_request, load_private_key, make_token

IDENTIFIER = 'jp.allsunday1122.itpassportstudy'
NAME = 'New IT Passport Study'

issuer_id = os.environ.get('ASC_ISSUER_ID')
key_id = os.environ.get('ASC_KEY_ID')
if not issuer_id or not key_id:
    raise SystemExit('Missing App Store Connect API credentials')

key_path, cleanup = load_private_key()
try:
    token = make_token(issuer_id, key_id, key_path)
    path = f'/v1/bundleIds?filter[identifier]={IDENTIFIER}&limit=20'
    _, before = api_get(token, path)
    rows = before.get('data') or []
    if rows:
        resource = rows[0]
        changed = False
    else:
        payload = {
            'data': {
                'type': 'bundleIds',
                'attributes': {
                    'identifier': IDENTIFIER,
                    'name': NAME,
                    'platform': 'IOS',
                },
            }
        }
        status, response = api_request(token, '/v1/bundleIds', method='POST', payload=payload)
        if status < 200 or status >= 300:
            raise SystemExit(f'Bundle ID registration failed HTTP {status}')
        resource = response.get('data')
        changed = True

    _, after = api_get(token, path)
    verified = [x for x in (after.get('data') or []) if (x.get('attributes') or {}).get('identifier') == IDENTIFIER]
    if len(verified) != 1:
        raise SystemExit(f'Bundle ID read-back expected exactly 1 resource, got {len(verified)}')

    item = verified[0]
    attrs = item.get('attributes') or {}
    out = {
        'identifier': IDENTIFIER,
        'changed': changed,
        'id': item.get('id'),
        'name': attrs.get('name'),
        'platform': attrs.get('platform'),
        'verified': True,
    }
    print(json.dumps(out, ensure_ascii=False))
finally:
    if cleanup:
        cleanup.unlink(missing_ok=True)
