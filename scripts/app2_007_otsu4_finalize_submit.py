#!/usr/bin/env python3
"""Final App Store review submission for APP2-007 Otsu4.

Completes safe App Store submission prerequisites that are exposed by the public
App Store Connect API, validates the release/IAP, adds the app version and first
IAP to one review submission, and submits only after all read-back gates pass.
"""
from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path

from app_store_connect_api import BASE_URL, load_private_key, make_token

APP_ID = '6799755566'
BUNDLE_ID = 'jp.allsunday1122.otsu4'
TARGET_VERSION = '1.0'
VERSION_ID = 'd02ea66f-2452-4f75-b900-5d9347384b5d'
LOCALIZATION_ID = '3718791f-0edf-4a18-b045-65540780538b'
APP_INFO_ID = '9fd15be0-6953-4661-be50-7b97f5f4653e'
IAP_ID = '6806477067'
IAP_VERSION_ID = '1a226705-e29a-4161-8ca5-0b77457dd9f9'
MIN_BUILD = 94
COPYRIGHT = '2026 ALLSUNDAY1122'
BASE_TERRITORY = 'JPN'
SUBMITTED = {'WAITING_FOR_REVIEW', 'IN_REVIEW', 'COMPLETING', 'COMPLETE'}
OUT = Path(os.environ.get('OTS4_FINAL_SUBMIT_OUTPUT', 'automation/app2-007-otsu4-final-submit-result.json'))
NOTES = '''本アプリは危険物取扱者 乙種第4類の学習アプリです。アカウント登録、広告、行動解析、トラッキングはありません。学習履歴は端末内に保存されます。\n\n無料版では72問を利用できます。非消耗型アプリ内課金「乙4 プレミアム」（jp.allsunday1122.otsu4.premium）を購入すると、全720問、模擬試験6回、全範囲の復習機能を解放します。購入画面は「設定」→「乙4 プレミアム」から開けます。\n\n審査時は通常のSandbox購入フローをご利用ください。購入済みの場合は「購入を復元」でも権利を再確認できます。'''


def req(token, path, method='GET', payload=None, allow404=False):
    body = None if payload is None else json.dumps(payload, ensure_ascii=False, separators=(',', ':')).encode()
    request = urllib.request.Request(
        BASE_URL + path,
        data=body,
        method=method,
        headers={
            'Authorization': 'Bearer ' + token,
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return response.status, json.loads(raw.decode()) if raw else {}
    except urllib.error.HTTPError as exc:
        if allow404 and exc.code == 404:
            return 404, {}
        raw = exc.read().decode('utf-8', 'replace')
        raise RuntimeError(f'ASC {method} {path} HTTP {exc.code}: {raw[:8000]}') from exc


def rows(payload):
    data = payload.get('data', []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else ([] if data is None else [data])


def attrs(resource):
    return (resource or {}).get('attributes') or {}


def state(resource):
    a = attrs(resource)
    return a.get('state') or a.get('appStoreState') or a.get('appVersionState')


def rel_id(resource, key):
    try:
        return str(resource['relationships'][key]['data']['id'])
    except Exception:
        return None


def is_zero(value):
    try:
        return Decimal(str(value)) == 0
    except (InvalidOperation, TypeError, ValueError):
        return False


def validate_app(token, actions):
    fields = '?fields[apps]=bundleId,contentRightsDeclaration'
    _, payload = req(token, f'/v1/apps/{APP_ID}{fields}')
    app = payload.get('data') or {}
    a = attrs(app)
    if a.get('bundleId') != BUNDLE_ID:
        raise RuntimeError('App/bundle mismatch')
    if not a.get('contentRightsDeclaration'):
        req(
            token,
            f'/v1/apps/{APP_ID}',
            'PATCH',
            {'data': {'type': 'apps', 'id': APP_ID, 'attributes': {'contentRightsDeclaration': 'DOES_NOT_USE_THIRD_PARTY_CONTENT'}}},
        )
        actions.append('content_rights_declared')
        _, payload = req(token, f'/v1/apps/{APP_ID}{fields}')
        a = attrs(payload.get('data') or {})
    if a.get('contentRightsDeclaration') != 'DOES_NOT_USE_THIRD_PARTY_CONTENT':
        raise RuntimeError('Unexpected content rights declaration')
    return a


def ensure_copyright(token, actions):
    _, payload = req(token, f'/v1/appStoreVersions/{VERSION_ID}')
    version = payload.get('data') or {}
    current = attrs(version).get('copyright')
    if not current:
        req(
            token,
            f'/v1/appStoreVersions/{VERSION_ID}',
            'PATCH',
            {'data': {'type': 'appStoreVersions', 'id': VERSION_ID, 'attributes': {'copyright': COPYRIGHT}}},
        )
        actions.append('copyright_set')
    _, after = req(token, f'/v1/appStoreVersions/{VERSION_ID}')
    value = attrs(after.get('data') or {}).get('copyright')
    if not value:
        raise RuntimeError('Copyright read-back is empty after write')
    return value


def app_price_schedule(token):
    status, payload = req(token, f'/v1/apps/{APP_ID}/appPriceSchedule?include=baseTerritory', allow404=True)
    if status == 404 or not (payload.get('data') if isinstance(payload, dict) else None):
        return None
    return payload.get('data')


def read_manual_prices(token, schedule_id):
    _, payload = req(
        token,
        f'/v1/appPriceSchedules/{schedule_id}/manualPrices?include=appPricePoint,territory&limit=200',
    )
    included = payload.get('included') or []
    point_attrs = {str(x.get('id')): attrs(x) for x in included if x.get('type') == 'appPricePoints'}
    result = []
    for price in rows(payload):
        pp_id = rel_id(price, 'appPricePoint')
        result.append(
            {
                'id': str(price.get('id')),
                'territory': rel_id(price, 'territory'),
                'price_point_id': pp_id,
                'customer_price': (point_attrs.get(pp_id) or {}).get('customerPrice'),
            }
        )
    return result


def ensure_free_pricing(token, actions):
    schedule = app_price_schedule(token)
    if schedule:
        sid = str(schedule['id'])
        manual = read_manual_prices(token, sid)
        if any(is_zero(x.get('customer_price')) for x in manual):
            return {'schedule_id': sid, 'base_territory': rel_id(schedule, 'baseTerritory'), 'customer_price': '0', 'existing': True}

    _, points_payload = req(token, f'/v1/apps/{APP_ID}/appPricePoints?filter[territory]={BASE_TERRITORY}&limit=200')
    free_points = [x for x in rows(points_payload) if is_zero(attrs(x).get('customerPrice'))]
    if not free_points:
        raise RuntimeError(f'No zero-price app price point found for {BASE_TERRITORY}')
    free_point = free_points[0]
    price_point_id = str(free_point['id'])
    placeholder = '${new-price}'
    payload = {
        'data': {
            'type': 'appPriceSchedules',
            'relationships': {
                'app': {'data': {'type': 'apps', 'id': APP_ID}},
                'baseTerritory': {'data': {'type': 'territories', 'id': BASE_TERRITORY}},
                'manualPrices': {'data': [{'type': 'appPrices', 'id': placeholder}]},
            },
        },
        'included': [
            {
                'type': 'appPrices',
                'id': placeholder,
                'attributes': {},
                'relationships': {
                    'appPricePoint': {'data': {'type': 'appPricePoints', 'id': price_point_id}},
                },
            }
        ],
    }
    req(token, '/v1/appPriceSchedules', 'POST', payload)
    actions.append('free_app_pricing_set')

    after = app_price_schedule(token)
    if not after:
        raise RuntimeError('App price schedule missing after write')
    sid = str(after['id'])
    manual = read_manual_prices(token, sid)
    if not any(is_zero(x.get('customer_price')) for x in manual):
        raise RuntimeError('Free app price read-back did not contain customerPrice=0')
    return {
        'schedule_id': sid,
        'base_territory': rel_id(after, 'baseTerritory'),
        'customer_price': '0',
        'price_point_id': price_point_id,
        'existing': False,
    }


def resolve_build(token):
    _, payload = req(token, f'/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=100')
    candidates = []
    for build in rows(payload):
        a = attrs(build)
        number = str(a.get('version', ''))
        if not number.isdigit() or int(number) < MIN_BUILD:
            continue
        if a.get('processingState') != 'VALID':
            continue
        if a.get('buildAudienceType') == 'INTERNAL_ONLY':
            continue
        if a.get('usesNonExemptEncryption') not in {False, None}:
            continue
        candidates.append(build)
    if not candidates:
        raise RuntimeError('No VALID non-INTERNAL_ONLY Otsu4 build >= 94 is available')
    candidates.sort(key=lambda x: int(str(attrs(x).get('version', '0'))), reverse=True)
    return candidates[0]


def attach_build(token, build_id, actions):
    _, relationship = req(token, f'/v1/appStoreVersions/{VERSION_ID}/relationships/build')
    current = (relationship.get('data') or {}).get('id')
    if current != build_id:
        req(
            token,
            f'/v1/appStoreVersions/{VERSION_ID}',
            'PATCH',
            {'data': {'type': 'appStoreVersions', 'id': VERSION_ID, 'relationships': {'build': {'data': {'type': 'builds', 'id': build_id}}}}},
        )
        actions.append('build_attached')
    _, after = req(token, f'/v1/appStoreVersions/{VERSION_ID}/relationships/build')
    if (after.get('data') or {}).get('id') != build_id:
        raise RuntimeError('Build attach read-back mismatch')


def validate_metadata(token):
    _, version_payload = req(token, f'/v1/appStoreVersions/{VERSION_ID}')
    version = version_payload.get('data') or {}
    if attrs(version).get('versionString') != TARGET_VERSION:
        raise RuntimeError('Version mismatch')
    if state(version) not in {'PREPARE_FOR_SUBMISSION', 'READY_FOR_REVIEW', 'WAITING_FOR_REVIEW', 'IN_REVIEW'}:
        raise RuntimeError('Unexpected app version state ' + str(state(version)))
    if not attrs(version).get('copyright'):
        raise RuntimeError('Copyright missing after prerequisite write')

    _, localization_payload = req(token, f'/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}')
    localization = attrs(localization_payload.get('data') or {})
    for key in ('description', 'keywords', 'supportUrl'):
        if not localization.get(key):
            raise RuntimeError('Missing version metadata ' + key)

    _, sets = req(token, f'/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}/appScreenshotSets?limit=200&include=appScreenshots')
    complete = [
        x
        for x in (sets.get('included') or [])
        if x.get('type') == 'appScreenshots' and (((attrs(x).get('assetDeliveryState') or {}).get('state')) == 'COMPLETE')
    ]
    if len(complete) < 6:
        raise RuntimeError(f'Expected at least 6 COMPLETE screenshots, found {len(complete)}')

    _, review_payload = req(token, f'/v1/appStoreVersions/{VERSION_ID}/appStoreReviewDetail')
    review = review_payload.get('data') or {}
    review_attrs = attrs(review)
    for key in ('contactFirstName', 'contactLastName', 'contactPhone', 'contactEmail'):
        if not review_attrs.get(key):
            raise RuntimeError('Review contact missing ' + key)
    review_id = str(review['id'])
    if review_attrs.get('notes') != NOTES:
        req(token, f'/v1/appStoreReviewDetails/{review_id}', 'PATCH', {'data': {'type': 'appStoreReviewDetails', 'id': review_id, 'attributes': {'notes': NOTES}}})

    _, infos = req(token, f'/v1/apps/{APP_ID}/appInfos?limit=20&include=appInfoLocalizations')
    info_ids = {str(x.get('id')) for x in rows(infos)}
    if APP_INFO_ID not in info_ids:
        raise RuntimeError('AppInfo mismatch')
    locs = [x for x in (infos.get('included') or []) if x.get('type') == 'appInfoLocalizations']
    ja = next((x for x in locs if attrs(x).get('locale') in {'ja', 'ja-JP'}), None)
    if not ja or not attrs(ja).get('privacyPolicyUrl'):
        raise RuntimeError('Privacy policy URL missing')
    _, age = req(token, f'/v1/appInfos/{APP_INFO_ID}/ageRatingDeclaration')
    if not (age.get('data') or {}).get('id'):
        raise RuntimeError('Age rating declaration missing')
    return {'screenshots': len(complete), 'review_detail_id': review_id, 'age_rating_id': str(age['data']['id'])}


def validate_iap(token):
    _, product_payload = req(token, f'/v2/inAppPurchases/{IAP_ID}?include=appStoreReviewScreenshot,versions')
    product = product_payload.get('data') or {}
    parent_state = state(product)
    if parent_state not in {'READY_TO_SUBMIT', 'READY_FOR_REVIEW', 'WAITING_FOR_REVIEW', 'IN_REVIEW', 'APPROVED'}:
        raise RuntimeError('IAP parent not ready: ' + str(parent_state))
    shots = [x for x in (product_payload.get('included') or []) if x.get('type') == 'inAppPurchaseAppStoreReviewScreenshots']
    if not shots or (((attrs(shots[0]).get('assetDeliveryState') or {}).get('state')) != 'COMPLETE'):
        raise RuntimeError('IAP review screenshot not COMPLETE')
    _, version_payload = req(token, f'/v1/inAppPurchaseVersions/{IAP_VERSION_ID}')
    iap_version = version_payload.get('data') or {}
    version_state = state(iap_version)
    if version_state not in {'PREPARE_FOR_SUBMISSION', 'READY_FOR_REVIEW', 'WAITING_FOR_REVIEW', 'IN_REVIEW', 'APPROVED'}:
        raise RuntimeError('Unexpected IAP version state ' + str(version_state))
    _, loc = req(token, f'/v1/inAppPurchaseVersions/{IAP_VERSION_ID}/localizations?limit=50')
    ja = next((x for x in rows(loc) if attrs(x).get('locale') == 'ja'), None)
    if not ja or not attrs(ja).get('name') or not attrs(ja).get('description'):
        raise RuntimeError('IAP Japanese localization incomplete')
    _, availability = req(token, f'/v1/inAppPurchaseAvailabilities/{IAP_ID}/relationships/availableTerritories?limit=200')
    if 'JPN' not in {str(x.get('id')) for x in rows(availability)}:
        raise RuntimeError('IAP is not available in JPN')
    return {'parent_state': parent_state, 'version_state': version_state, 'review_screenshot_id': str(shots[0]['id'])}


def ensure_submission(token, actions):
    _, payload = req(token, f'/v1/apps/{APP_ID}/reviewSubmissions?limit=200')
    submissions = rows(payload)
    active = next((x for x in submissions if state(x) in SUBMITTED), None)
    if active:
        return str(active['id']), True
    draft = next((x for x in submissions if state(x) == 'READY_FOR_REVIEW'), None)
    if not draft:
        _, created = req(
            token,
            '/v1/reviewSubmissions',
            'POST',
            {'data': {'type': 'reviewSubmissions', 'attributes': {'platform': 'IOS'}, 'relationships': {'app': {'data': {'type': 'apps', 'id': APP_ID}}}}},
        )
        draft = created['data']
        actions.append('review_submission_created')
    submission_id = str(draft['id'])
    _, items = req(token, f'/v1/reviewSubmissions/{submission_id}/items?limit=200&include=appStoreVersion,inAppPurchaseVersion')
    current_items = rows(items)
    has_app = any(rel_id(x, 'appStoreVersion') == VERSION_ID for x in current_items)
    has_iap = any(rel_id(x, 'inAppPurchaseVersion') == IAP_VERSION_ID for x in current_items)
    if not has_app:
        req(
            token,
            '/v1/reviewSubmissionItems',
            'POST',
            {'data': {'type': 'reviewSubmissionItems', 'relationships': {'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': submission_id}}, 'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': VERSION_ID}}}}},
        )
        actions.append('app_version_added_to_review')
    if not has_iap:
        req(
            token,
            '/v1/reviewSubmissionItems',
            'POST',
            {'data': {'type': 'reviewSubmissionItems', 'relationships': {'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': submission_id}}, 'inAppPurchaseVersion': {'data': {'type': 'inAppPurchaseVersions', 'id': IAP_VERSION_ID}}}}},
        )
        actions.append('iap_version_added_to_review')
    _, after = req(token, f'/v1/reviewSubmissions/{submission_id}/items?limit=200&include=appStoreVersion,inAppPurchaseVersion')
    after_rows = rows(after)
    if not any(rel_id(x, 'appStoreVersion') == VERSION_ID for x in after_rows):
        raise RuntimeError('App version review item missing after write')
    if not any(rel_id(x, 'inAppPurchaseVersion') == IAP_VERSION_ID for x in after_rows):
        raise RuntimeError('IAP version review item missing after write')
    return submission_id, False


def main():
    cleanup = None
    actions = []
    result = {
        'task_id': 'APP2-007',
        'app_id': APP_ID,
        'bundle_id': BUNDLE_ID,
        'version': TARGET_VERSION,
        'submitted': False,
        'ok': False,
        'completed_at': datetime.now(timezone.utc).isoformat(),
    }
    try:
        key, cleanup = load_private_key()
        token = make_token(os.environ['ASC_ISSUER_ID'], os.environ['ASC_KEY_ID'], key)
        app_attrs = validate_app(token, actions)
        result['copyright'] = ensure_copyright(token, actions)
        result['app_pricing'] = ensure_free_pricing(token, actions)

        build = resolve_build(token)
        build_id = str(build['id'])
        build_attrs = attrs(build)
        build_number = str(build_attrs.get('version'))
        result.update(
            build_id=build_id,
            build_number=build_number,
            build_processing_state=build_attrs.get('processingState'),
            build_audience_type=build_attrs.get('buildAudienceType'),
            content_rights=app_attrs.get('contentRightsDeclaration'),
        )
        attach_build(token, build_id, actions)
        result['metadata'] = validate_metadata(token)
        result['iap'] = validate_iap(token)
        submission_id, already = ensure_submission(token, actions)
        result['review_submission_id'] = submission_id
        if already:
            _, submission_payload = req(token, f'/v1/reviewSubmissions/{submission_id}')
            submission_state = state(submission_payload.get('data') or {})
            result.update(ok=True, submitted=True, idempotent=True, review_submission_state=submission_state, actions=actions)
        else:
            req(token, f'/v1/reviewSubmissions/{submission_id}', 'PATCH', {'data': {'type': 'reviewSubmissions', 'id': submission_id, 'attributes': {'submitted': True}}})
            time.sleep(2)
            _, submission_payload = req(token, f'/v1/reviewSubmissions/{submission_id}')
            submission_state = state(submission_payload.get('data') or {})
            if submission_state not in SUBMITTED:
                raise RuntimeError('Unexpected review submission state after submit: ' + str(submission_state))
            _, app_version_payload = req(token, f'/v1/appStoreVersions/{VERSION_ID}')
            _, iap_version_payload = req(token, f'/v1/inAppPurchaseVersions/{IAP_VERSION_ID}')
            result.update(
                ok=True,
                submitted=True,
                idempotent=False,
                review_submission_state=submission_state,
                app_version_state=state(app_version_payload.get('data') or {}),
                iap_version_state=state(iap_version_payload.get('data') or {}),
                actions=actions,
            )
    except Exception as exc:
        error = str(exc)
        result['error'] = error
        result['actions'] = actions
        blockers = []
        if 'APP_DATA_USAGES_REQUIRED' in error or 'appDataUsages' in error:
            blockers.append('app_privacy_publish')
        if 'APP_PRICING_REQUIRED' in error:
            blockers.append('app_pricing')
        if "attribute 'copyright'" in error or 'copyright' in error.lower():
            blockers.append('copyright')
        if blockers:
            result['blockers'] = sorted(set(blockers))
        raise
    finally:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(result, ensure_ascii=False))
        if cleanup:
            try:
                cleanup.unlink(missing_ok=True)
            except Exception:
                pass


if __name__ == '__main__':
    main()
