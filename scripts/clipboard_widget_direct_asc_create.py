#!/usr/bin/env python3
import json
import os
from pathlib import Path

from app_store_connect_api import api_request, load_private_key, make_token

OUT = Path(os.environ.get('ASC_CREATE_OUTPUT', '/tmp/clipboard-asc-create-result.json'))
result = {
    'request_id': 'clipboard-widget-direct-asc-create-20260829-r1',
    'bundle_id': 'jp.allsunday1122.clipboardwidget',
    'app_name': 'クリップボードWidget',
    'sku': 'clipboard-widget-20260827',
    'ok': False,
}

issuer = os.environ.get('ASC_ISSUER_ID')
key_id = os.environ.get('ASC_KEY_ID')
if not issuer or not key_id:
    result['error'] = 'Missing App Store Connect API credentials.'
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    raise SystemExit(2)

key_path, cleanup = load_private_key()
try:
    token = make_token(issuer, key_id, key_path)
    payload = {
        'data': {
            'type': 'apps',
            'attributes': {
                'name': 'クリップボードWidget',
                'bundleId': 'jp.allsunday1122.clipboardwidget',
                'sku': 'clipboard-widget-20260827',
                'primaryLocale': 'ja-JP',
                'platform': 'IOS',
            },
        }
    }
    try:
        status, response = api_request(token, '/v1/apps', method='POST', payload=payload)
        result['ok'] = 200 <= status < 300
        result['http_status'] = status
        data = response.get('data') if isinstance(response, dict) else None
        if isinstance(data, dict):
            attrs = data.get('attributes') or {}
            result['app'] = {
                'id': data.get('id'),
                'type': data.get('type'),
                'name': attrs.get('name'),
                'bundleId': attrs.get('bundleId'),
                'sku': attrs.get('sku'),
                'primaryLocale': attrs.get('primaryLocale'),
            }
    except Exception as exc:
        text = str(exc)
        # The transport error contains only HTTP status and ASC JSON error body, never JWT/key material.
        result['error'] = text[:12000]
finally:
    if cleanup:
        try:
            cleanup.unlink(missing_ok=True)
        except Exception:
            pass

OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
if not result['ok']:
    raise SystemExit(1)
print('App Store Connect app record created:', result.get('app', {}).get('id'))
