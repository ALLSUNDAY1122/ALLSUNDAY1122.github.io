#!/usr/bin/env python3
"""Configure HM2 IAP/subscription metadata using current App Store Connect version-scoped APIs.

Apple migrated subscription, subscription-group, and IAP localizations to draft-version
resources. This script keeps the existing product IDs/prices intact and only ensures the
required Japanese metadata is attached to the current PREPARE_FOR_SUBMISSION versions.
"""
import json
import os
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

SUB = '6802988571'
GROUP = '22319275'
IAP = '6802989207'
LOCALE = 'ja'
MONTHLY_NAME = '月額プレミアム'
MONTHLY_DESC = '学習を継続しながら、全300問・全30セット・全分野・苦手復習を利用できます。'
GROUP_NAME = 'プレミアム学習'
LIFETIME_NAME = '買い切りプレミアム'
LIFETIME_DESC = '一度の購入で、全300問・全30セット・全分野・苦手復習を期限なく利用できます。'
REVIEW_NOTE = '第二種衛生管理者の学習アプリです。無料範囲は最新1回相当30問と今日のスプリント。月額または買い切りで同一のPremium権利を付与し、全300問・全30セット・全分野・苦手復習を解放します。購入復元は設定画面から実行できます。'


def data(resp):
    d = resp.get('data') if isinstance(resp, dict) else None
    return d if isinstance(d, list) else ([d] if isinstance(d, dict) else [])


def find_locale(resp):
    for x in data(resp):
        if (x.get('attributes') or {}).get('locale') == LOCALE:
            return x
    for x in (resp.get('included') or []) if isinstance(resp, dict) else []:
        if (x.get('attributes') or {}).get('locale') == LOCALE:
            return x
    return None


def ensure_draft_version(token, *, kind, parent_id, result):
    if kind == 'subscription':
        list_path = f'/v1/subscriptions/{parent_id}/versions?filter[state]=PREPARE_FOR_SUBMISSION&limit=50'
        create_path = '/v1/subscriptionVersions'
        version_type = 'subscriptionVersions'
        relationship = 'subscription'
        parent_type = 'subscriptions'
    elif kind == 'group':
        list_path = f'/v1/subscriptionGroups/{parent_id}/versions?filter[state]=PREPARE_FOR_SUBMISSION&limit=50'
        create_path = '/v1/subscriptionGroupVersions'
        version_type = 'subscriptionGroupVersions'
        relationship = 'subscriptionGroup'
        parent_type = 'subscriptionGroups'
    elif kind == 'iap':
        list_path = f'/v2/inAppPurchases/{parent_id}/versions?filter[state]=PREPARE_FOR_SUBMISSION&limit=50'
        create_path = '/v1/inAppPurchaseVersions'
        version_type = 'inAppPurchaseVersions'
        relationship = 'inAppPurchase'
        parent_type = 'inAppPurchases'
    else:
        raise ValueError(kind)

    _, versions = api_get(token, list_path)
    rows = data(versions)
    if rows:
        chosen = rows[-1]
        result[f'{kind}_version'] = {
            'changed': False,
            'id': chosen['id'],
            'state': (chosen.get('attributes') or {}).get('state'),
        }
        return chosen['id'], version_type

    payload = {
        'data': {
            'type': version_type,
            'relationships': {
                relationship: {'data': {'type': parent_type, 'id': parent_id}}
            },
        }
    }
    status, out = api_request(token, create_path, method='POST', payload=payload)
    created = (out or {}).get('data') or {}
    version_id = created.get('id')
    if not version_id:
        raise RuntimeError(f'{kind} draft version create returned no id')
    result[f'{kind}_version'] = {
        'changed': True,
        'http_status': status,
        'id': version_id,
        'state': (created.get('attributes') or {}).get('state'),
    }
    return version_id, version_type


def ensure_version_localization(token, *, kind, version_id, version_type, attrs, result_key, result):
    if kind == 'subscription':
        list_path = f'/v1/subscriptionVersions/{version_id}/localizations?limit=50'
        create_path = '/v2/subscriptionLocalizations'
        resource_type = 'subscriptionLocalizations'
    elif kind == 'group':
        list_path = f'/v1/subscriptionGroupVersions/{version_id}/localizations?limit=50'
        create_path = '/v2/subscriptionGroupLocalizations'
        resource_type = 'subscriptionGroupLocalizations'
    elif kind == 'iap':
        list_path = f'/v1/inAppPurchaseVersions/{version_id}/localizations?limit=50'
        create_path = '/v2/inAppPurchaseLocalizations'
        resource_type = 'inAppPurchaseLocalizations'
    else:
        raise ValueError(kind)

    _, listed = api_get(token, list_path)
    cur = find_locale(listed)
    if cur:
        actual = cur.get('attributes') or {}
        desired = {k: v for k, v in attrs.items() if k != 'locale'}
        changes = {k: v for k, v in desired.items() if actual.get(k) != v}
        if changes:
            payload = {'data': {'type': resource_type, 'id': cur['id'], 'attributes': changes}}
            status, _ = api_request(token, f'/v2/{resource_type}/{cur["id"]}', method='PATCH', payload=payload)
            result[result_key] = {
                'changed': True,
                'http_status': status,
                'id': cur['id'],
                'version_id': version_id,
            }
        else:
            result[result_key] = {
                'changed': False,
                'id': cur['id'],
                'version_id': version_id,
            }
        return

    payload = {
        'data': {
            'type': resource_type,
            'attributes': attrs,
            'relationships': {
                'version': {'data': {'type': version_type, 'id': version_id}}
            },
        }
    }
    status, out = api_request(token, create_path, method='POST', payload=payload)
    result[result_key] = {
        'changed': True,
        'http_status': status,
        'id': ((out or {}).get('data') or {}).get('id'),
        'version_id': version_id,
    }


def patch_notes(token, result):
    _, sub = api_get(token, f'/v1/subscriptions/{SUB}')
    sub_attrs = (sub.get('data') or {}).get('attributes') or {}
    if sub_attrs.get('reviewNote') != REVIEW_NOTE:
        status, _ = api_request(
            token,
            f'/v1/subscriptions/{SUB}',
            method='PATCH',
            payload={'data': {'type': 'subscriptions', 'id': SUB, 'attributes': {'reviewNote': REVIEW_NOTE}}},
        )
        result['monthly_review_note'] = {'changed': True, 'http_status': status}
    else:
        result['monthly_review_note'] = {'changed': False}

    _, iap = api_get(token, f'/v2/inAppPurchases/{IAP}')
    iap_attrs = (iap.get('data') or {}).get('attributes') or {}
    if iap_attrs.get('reviewNote') != REVIEW_NOTE:
        status, _ = api_request(
            token,
            f'/v2/inAppPurchases/{IAP}',
            method='PATCH',
            payload={'data': {'type': 'inAppPurchases', 'id': IAP, 'attributes': {'reviewNote': REVIEW_NOTE}}},
        )
        result['lifetime_review_note'] = {'changed': True, 'http_status': status}
    else:
        result['lifetime_review_note'] = {'changed': False}


def safe_readback(token, path):
    try:
        status, body = api_get(token, path)
        return {'http_status': status, 'body': body}
    except Exception as exc:
        return {'error': type(exc).__name__, 'message': str(exc)[:500]}


def main():
    issuer = os.environ.get('ASC_ISSUER_ID')
    keyid = os.environ.get('ASC_KEY_ID')
    if not issuer or not keyid:
        raise SystemExit('missing ASC credentials')

    key_path, cleanup = load_private_key()
    result = {
        'schema_version': 2,
        'api_mode': 'version_scoped_metadata',
        'subscription_id': SUB,
        'subscription_group_id': GROUP,
        'lifetime_iap_id': IAP,
    }
    try:
        token = make_token(issuer, keyid, key_path)

        sub_vid, sub_vtype = ensure_draft_version(
            token, kind='subscription', parent_id=SUB, result=result
        )
        ensure_version_localization(
            token,
            kind='subscription',
            version_id=sub_vid,
            version_type=sub_vtype,
            attrs={'locale': LOCALE, 'name': MONTHLY_NAME, 'description': MONTHLY_DESC},
            result_key='monthly_localization',
            result=result,
        )

        group_vid, group_vtype = ensure_draft_version(
            token, kind='group', parent_id=GROUP, result=result
        )
        ensure_version_localization(
            token,
            kind='group',
            version_id=group_vid,
            version_type=group_vtype,
            attrs={'locale': LOCALE, 'name': GROUP_NAME},
            result_key='group_localization',
            result=result,
        )

        iap_vid, iap_vtype = ensure_draft_version(
            token, kind='iap', parent_id=IAP, result=result
        )
        ensure_version_localization(
            token,
            kind='iap',
            version_id=iap_vid,
            version_type=iap_vtype,
            attrs={'locale': LOCALE, 'name': LIFETIME_NAME, 'description': LIFETIME_DESC},
            result_key='lifetime_localization',
            result=result,
        )

        patch_notes(token, result)

        result['monthly_product_readback'] = safe_readback(token, f'/v1/subscriptions/{SUB}?include=versions')
        result['monthly_version_readback'] = safe_readback(token, f'/v1/subscriptionVersions/{sub_vid}?include=localizations')
        result['group_product_readback'] = safe_readback(token, f'/v1/subscriptionGroups/{GROUP}?include=versions')
        result['group_version_readback'] = safe_readback(token, f'/v1/subscriptionGroupVersions/{group_vid}?include=localizations')
        result['lifetime_product_readback'] = safe_readback(token, f'/v2/inAppPurchases/{IAP}?include=versions')
        result['lifetime_version_readback'] = safe_readback(token, f'/v1/inAppPurchaseVersions/{iap_vid}?include=localizations')
        result['monthly_availability_readback'] = safe_readback(token, f'/v1/subscriptions/{SUB}/subscriptionAvailability?include=availableTerritories')
        result['monthly_prices_readback'] = safe_readback(token, f'/v1/subscriptions/{SUB}/prices?include=subscriptionPricePoint&limit=50')
        result['monthly_review_screenshot_readback'] = safe_readback(token, f'/v1/subscriptions/{SUB}/appStoreReviewScreenshot')
        result['lifetime_availability_readback'] = safe_readback(token, f'/v2/inAppPurchases/{IAP}/inAppPurchaseAvailability?include=availableTerritories')
        result['lifetime_price_schedule_readback'] = safe_readback(token, f'/v2/inAppPurchases/{IAP}/iapPriceSchedule?include=baseTerritory,manualPrices')
        result['lifetime_review_screenshot_readback'] = safe_readback(token, f'/v2/inAppPurchases/{IAP}/appStoreReviewScreenshot')
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)

    Path('hm2-iap-metadata-result.json').write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8'
    )
    print('PASS: HM2 version-scoped IAP/subscription metadata configured and read back')


if __name__ == '__main__':
    main()
