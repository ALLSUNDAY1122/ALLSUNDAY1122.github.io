#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import struct
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6799751657"
BUNDLE_ID = "jp.allsunday1122.healthmanager2"
TARGET_VERSION = "1.0"
BUILD_VERSION = "22"
MONTHLY_ID = "6802988571"
LIFETIME_ID = "6802989207"
GROUP_ID = "22319275"
DISPLAY_TYPE = "APP_IPHONE_67"
COPYRIGHT = "2026 ALLSUNDAY1122"

DESCRIPTION = """第二種衛生管理者試験の重要論点を、短い反復で定着させる学習アプリです。

標準は1回8問。4問・8問・16問から自分の学習時間に合わせて選べます。

主な機能
- 公式一次資料・公表問題の論点傾向をもとに独自作成した300問
- 10回相当 × 3科目の30セット
- 本番形式30問模試と科目別40%判定
- 関係法令・労働衛生・労働生理の分野別学習
- 選択肢タップですぐに正誤を確認
- 正解・不正解・操作時のiPhone触覚フィードバック
- 「ここだけ覚える」で要点を短く確認
- 詳細解説
- 間違えた問題を苦手として自動保存
- 苦手問題は3回連続正解で卒業
- 学習日数・正答率・分野別記録
- 途中から再開
- JSON形式で学習データを書き出し、iOS共有シートで保存
- 教材を端末内に同梱し、学習機能はオフライン利用可能

無料版では最新1回相当の30問と「今日のスプリント」を利用できます。プレミアムは月額プランまたは買い切りのどちらでも同じ機能を解放し、全300問、全30セット、全分野学習、苦手復習を利用できます。月額は継続学習のきっかけとして、買い切りは期限を気にせず長く使いたい方向けの選択肢です。

公表試験問題は出題論点・傾向の確認に使用し、公開用の問題文・選択肢・解説は独自作成しています。法令関連問題は基準日と一次確認先を管理しています。

本アプリは試験実施団体・官公庁の公式アプリではありません。最終的な制度・法令の確認には最新の公式情報を参照してください。"""
KEYWORDS = "第二種衛生管理者,衛生管理者,資格,問題集,試験,労働安全衛生,労働衛生,労働生理,関係法令,学習"
PROMO = "今日8問から。第二種衛生管理者の重要論点を独自問題300問、30問模試、苦手復習、学習記録で短時間に反復できます。"
SUBTITLE = "8問から続く 衛生管理者対策"
SUPPORT_URL = "https://allsunday1122.github.io/health-manager-2/support.html"
PRIVACY_URL = "https://allsunday1122.github.io/health-manager-2/privacy.html"
REVIEW_NOTES = """本アプリはサインイン不要です。無料状態でも最新1回相当30問と「今日のスプリント」を利用できます。教材300問と学習ロジックはアプリ内に同梱し、学習履歴は端末内に保存します。広告・解析は使用しません。

プレミアムはStoreKit 2で提供し、月額プランまたは買い切りのどちらかが有効な場合に同じプレミアム機能を解放します。プレミアムでは全300問、全30セット、全分野学習、苦手復習を利用できます。購入復元を設定画面に常設し、月額利用中はApp Storeのサブスクリプション管理導線を表示します。価格表示はStoreKitのProduct.displayPriceを使用します。

確認推奨導線:
1. 無料状態で「今日のスプリント」を開始
2. 選択肢をタップして即時採点と触覚フィードバックを確認
3. 無料範囲外の模試をタップしてプレミアム画面を確認
4. 月額または買い切りを購入し、全300問が解放されることを確認
5. 「購入を復元」を確認
6. 「記録」で学習履歴と苦手一覧を確認
7. 「設定」で文字サイズ・問題数・JSONバックアップ・課金状態を確認

StoreKit商品ID:
- jp.allsunday1122.healthmanager2.monthly（月額200円）
- jp.allsunday1122.healthmanager2.lifetime（買い切り800円）

本アプリは試験実施団体・官公庁の公式アプリではありません。"""

AGE_RATING_ATTRIBUTES = {
    "advertising": False,
    "ageAssurance": False,
    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
    "contests": "NONE",
    "gambling": False,
    "gamblingSimulated": "NONE",
    "gunsOrOtherWeapons": "NONE",
    "healthOrWellnessTopics": True,
    "horrorOrFearThemes": "NONE",
    "lootBox": False,
    "matureOrSuggestiveThemes": "NONE",
    "medicalOrTreatmentInformation": "NONE",
    "messagingAndChat": False,
    "parentalControls": False,
    "profanityOrCrudeHumor": "NONE",
    "sexualContentGraphicAndNudity": "NONE",
    "sexualContentOrNudity": "NONE",
    "socialMedia": False,
    "socialMediaAgeRestricted": False,
    "unrestrictedWebAccess": False,
    "userGeneratedContent": False,
    "violenceCartoonOrFantasy": "NONE",
    "violenceRealistic": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
    "ageRatingOverrideV2": "NONE",
    "koreaAgeRatingOverride": "NONE",
}

ACTIVE_SUBMISSION_STATES = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES", "CANCELING", "COMPLETING"}
SUBMITTED_STATES = {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING"}
REVIEWABLE_VERSION_STATES = {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}


def one(payload: object, label: str) -> dict:
    if not isinstance(payload, dict) or not isinstance(payload.get("data"), dict):
        raise RuntimeError(f"Missing {label}")
    return payload["data"]


def many(payload: object) -> list[dict]:
    if not isinstance(payload, dict):
        return []
    data = payload.get("data", [])
    return data if isinstance(data, list) else ([] if data is None else [data])


def state(resource: dict) -> str | None:
    attrs = resource.get("attributes") or {}
    return attrs.get("state") or attrs.get("appStoreState") or attrs.get("appVersionState")


def request_ok(token: str, path: str, method: str, payload: dict) -> dict:
    status, response = api_request(token, path, method=method, payload=payload)
    if not 200 <= status < 300:
        raise RuntimeError(f"ASC {method} {path} returned HTTP {status}")
    return response


def patch(token: str, path: str, typ: str, rid: str, *, attributes=None, relationships=None) -> None:
    data: dict = {"type": typ, "id": rid}
    if attributes is not None:
        data["attributes"] = attributes
    if relationships is not None:
        data["relationships"] = relationships
    request_ok(token, path, "PATCH", {"data": data})


def upload_operations(operations: list[dict], raw: bytes) -> None:
    for op in operations:
        offset = int(op.get("offset", 0))
        length = int(op.get("length", len(raw) - offset))
        chunk = raw[offset:offset + length]
        request = urllib.request.Request(op["url"], data=chunk, method=op.get("method", "PUT"))
        headers = op.get("requestHeaders") or []
        if isinstance(headers, dict):
            headers = [{"name": k, "value": v} for k, v in headers.items()]
        for h in headers:
            request.add_header(str(h["name"]), str(h["value"]))
        with urllib.request.urlopen(request, timeout=120) as response:
            if not 200 <= response.status < 300:
                raise RuntimeError(f"Asset upload failed HTTP {response.status}")


def wait_complete(token: str, path: str, label: str, timeout: int = 240) -> dict:
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        _, payload = api_get(token, path)
        item = one(payload, label)
        delivery = ((item.get("attributes") or {}).get("assetDeliveryState") or {})
        last = delivery.get("state")
        if last == "COMPLETE":
            return item
        if last in {"FAILED", "UPLOAD_FAILED"}:
            raise RuntimeError(f"{label} processing failed: {delivery}")
        time.sleep(5)
    raise RuntimeError(f"{label} did not reach COMPLETE; state={last}")


def png_size(path: Path) -> tuple[int, int]:
    raw = path.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError(f"Not a PNG: {path}")
    return struct.unpack(">II", raw[16:24])


def resolve_version(token: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}/appStoreVersions?limit=50")
    versions = [x for x in many(payload) if (x.get("attributes") or {}).get("platform") == "IOS" and (x.get("attributes") or {}).get("versionString") == TARGET_VERSION]
    if len(versions) != 1:
        raise RuntimeError(f"Expected one iOS {TARGET_VERSION} version; found {[(x.get('id'), state(x)) for x in versions]}")
    if state(versions[0]) not in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW"}:
        raise RuntimeError(f"Unexpected version state: {state(versions[0])}")
    return versions[0]


def resolve_localization(token: str, version_id: str) -> dict:
    _, payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")
    loc = next((x for x in many(payload) if (x.get("attributes") or {}).get("locale") in {"ja", "ja-JP"}), None)
    if not loc:
        raise RuntimeError("Japanese App Store version localization missing")
    return loc


def ensure_review_detail(token: str, version_id: str) -> str:
    detail = None
    current: dict = {}
    try:
        _, payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
        d = payload.get("data") if isinstance(payload, dict) else None
        if isinstance(d, dict):
            detail = d
            current = detail.get("attributes") or {}
    except Exception:
        pass

    keys = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")
    contact = {k: current.get(k) for k in keys}
    if not all(contact.values()):
        _, beta_payload = api_get(token, f"/v1/apps/{APP_ID}/betaAppReviewDetail")
        beta = one(beta_payload, "beta review detail").get("attributes") or {}
        contact = {k: beta.get(k) for k in keys}
    if not all(contact.values()):
        raise RuntimeError("Real App Review contact data is incomplete")

    attrs = {**contact, "demoAccountRequired": False, "notes": REVIEW_NOTES}
    if detail:
        rid = str(detail["id"])
        patch(token, f"/v1/appStoreReviewDetails/{rid}", "appStoreReviewDetails", rid, attributes=attrs)
        return rid
    payload = {"data":{"type":"appStoreReviewDetails","attributes":attrs,"relationships":{"appStoreVersion":{"data":{"type":"appStoreVersions","id":version_id}}}}}
    return str(one(request_ok(token, "/v1/appStoreReviewDetails", "POST", payload), "created review detail")["id"])


def ensure_app_info(token: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}/appInfos?limit=20")
    infos = many(payload)
    if not infos:
        raise RuntimeError("AppInfo missing")
    info_id = str(infos[0]["id"])
    relationships = {
        "primaryCategory": {"data": {"type": "appCategories", "id": "EDUCATION"}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": "REFERENCE"}},
    }
    try:
        patch(token, f"/v1/appInfos/{info_id}", "appInfos", info_id,
              attributes={"contentRightsDeclaration":"DOES_NOT_USE_THIRD_PARTY_CONTENT"},
              relationships=relationships)
    except Exception:
        patch(token, f"/v1/appInfos/{info_id}", "appInfos", info_id, relationships=relationships)

    _, loc_payload = api_get(token, f"/v1/appInfos/{info_id}/appInfoLocalizations?limit=50")
    locs = many(loc_payload)
    ja = next((x for x in locs if (x.get("attributes") or {}).get("locale") in {"ja", "ja-JP"}), None)
    attrs = {"privacyPolicyUrl": PRIVACY_URL, "subtitle": SUBTITLE}
    if ja:
        patch(token, f"/v1/appInfoLocalizations/{ja['id']}", "appInfoLocalizations", str(ja["id"]), attributes=attrs)
    else:
        body = {"data":{"type":"appInfoLocalizations","attributes":{"locale":"ja","name":"第二種衛生管理者｜学びスプリント",**attrs},"relationships":{"appInfo":{"data":{"type":"appInfos","id":info_id}}}}}
        request_ok(token, "/v1/appInfoLocalizations", "POST", body)

    age_status = "unchanged"
    try:
        _, age_payload = api_get(token, f"/v1/appInfos/{info_id}/ageRatingDeclaration")
        age = one(age_payload, "age rating declaration")
        patch(token, f"/v1/ageRatingDeclarations/{age['id']}", "ageRatingDeclarations", str(age["id"]), attributes=AGE_RATING_ATTRIBUTES)
        age_status = "updated"
    except Exception as exc:
        age_status = f"existing-or-api-not-required: {str(exc)[:180]}"
    return {"app_info_id": info_id, "age_rating": age_status}


def select_build(token: str, version_id: str) -> str:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}/builds?limit=100")
    matches = [x for x in many(payload) if (x.get("attributes") or {}).get("version") == BUILD_VERSION and (x.get("attributes") or {}).get("processingState") == "VALID" and not (x.get("attributes") or {}).get("expired")]
    if len(matches) != 1:
        raise RuntimeError(f"Expected exactly one VALID non-expired Build {BUILD_VERSION}; found {[(x.get('id'), (x.get('attributes') or {}).get('processingState'), (x.get('attributes') or {}).get('expired')) for x in matches]}")
    build_id = str(matches[0]["id"])
    patch(token, f"/v1/appStoreVersions/{version_id}", "appStoreVersions", version_id,
          attributes={"usesIdfa": False, "copyright": COPYRIGHT},
          relationships={"build":{"data":{"type":"builds","id":build_id}}})
    _, rel = api_get(token, f"/v1/appStoreVersions/{version_id}/relationships/build")
    selected = ((rel or {}).get("data") or {}).get("id") if isinstance(rel, dict) else None
    if selected != build_id:
        raise RuntimeError(f"Build selection mismatch: {selected} != {build_id}")
    return build_id


def upload_app_screenshots(token: str, localization_id: str, files: list[Path]) -> dict:
    for image in files:
        if png_size(image) != (1260, 2736):
            raise RuntimeError(f"Unexpected screenshot size for {image.name}: {png_size(image)}")
    _, sets_payload = api_get(token, f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=200")
    sets = many(sets_payload)
    target = next((x for x in sets if (x.get("attributes") or {}).get("screenshotDisplayType") == DISPLAY_TYPE), None)
    if target is None:
        body = {"data":{"type":"appScreenshotSets","attributes":{"screenshotDisplayType":DISPLAY_TYPE},"relationships":{"appStoreVersionLocalization":{"data":{"type":"appStoreVersionLocalizations","id":localization_id}}}}}
        target = one(request_ok(token, "/v1/appScreenshotSets", "POST", body), "created screenshot set")
    set_id = str(target["id"])
    _, existing_payload = api_get(token, f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=200")
    for item in many(existing_payload):
        api_request(token, f"/v1/appScreenshots/{item['id']}", method="DELETE")

    uploaded = []
    for image in files:
        raw = image.read_bytes()
        checksum = hashlib.md5(raw).hexdigest()
        body = {"data":{"type":"appScreenshots","attributes":{"fileSize":len(raw),"fileName":image.name},"relationships":{"appScreenshotSet":{"data":{"type":"appScreenshotSets","id":set_id}}}}}
        reserved = one(request_ok(token, "/v1/appScreenshots", "POST", body), "reserved app screenshot")
        sid = str(reserved["id"])
        upload_operations((reserved.get("attributes") or {}).get("uploadOperations") or [], raw)
        patch(token, f"/v1/appScreenshots/{sid}", "appScreenshots", sid, attributes={"uploaded":True,"sourceFileChecksum":checksum})
        wait_complete(token, f"/v1/appScreenshots/{sid}", "app screenshot")
        uploaded.append(sid)
    return {"set_id": set_id, "display_type": DISPLAY_TYPE, "uploaded": uploaded}


def ensure_product_version(token: str, *, list_path: str, create_path: str, typ: str, relationship_name: str, relationship_type: str, parent_id: str) -> dict:
    _, payload = api_get(token, list_path)
    versions = many(payload)
    reviewable = [v for v in versions if state(v) in REVIEWABLE_VERSION_STATES]
    if reviewable:
        return reviewable[0]
    already = [v for v in versions if state(v) in {"WAITING_FOR_REVIEW", "IN_REVIEW", "APPROVED", "ACCEPTED"}]
    if already:
        return already[0]
    body = {"data":{"type":typ,"relationships":{relationship_name:{"data":{"type":relationship_type,"id":parent_id}}}}}
    return one(request_ok(token, create_path, "POST", body), f"created {typ}")


def require_review_screenshot(token: str, path: str, label: str) -> str:
    _, payload = api_get(token, path)
    resource = one(payload, label)
    delivery = ((resource.get("attributes") or {}).get("assetDeliveryState") or {})
    if delivery.get("state") != "COMPLETE":
        raise RuntimeError(f"{label} is not COMPLETE: {delivery}")
    return str(resource["id"])


def ensure_submission(token: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}/reviewSubmissions?limit=200")
    active = [s for s in many(payload) if state(s) in ACTIVE_SUBMISSION_STATES]
    submitted = [s for s in active if state(s) in SUBMITTED_STATES]
    if submitted:
        return submitted[0]
    draft = next((s for s in active if state(s) == "READY_FOR_REVIEW"), None)
    if draft:
        return draft
    body = {"data":{"type":"reviewSubmissions","attributes":{"platform":"IOS"},"relationships":{"app":{"data":{"type":"apps","id":APP_ID}}}}}
    return one(request_ok(token, "/v1/reviewSubmissions", "POST", body), "created review submission")


def ensure_item(token: str, submission_id: str, rel_name: str, rel_type: str, rid: str) -> None:
    _, payload = api_get(token, f"/v1/reviewSubmissions/{submission_id}/items?limit=200&include=appStoreVersion,inAppPurchaseVersion,subscriptionVersion,subscriptionGroupVersion")
    included = payload.get("included", []) if isinstance(payload, dict) else []
    if any(x.get("type") == rel_type and x.get("id") == rid for x in included):
        return
    body = {"data":{"type":"reviewSubmissionItems","relationships":{"reviewSubmission":{"data":{"type":"reviewSubmissions","id":submission_id}},rel_name:{"data":{"type":rel_type,"id":rid}}}}}
    request_ok(token, "/v1/reviewSubmissionItems", "POST", body)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--screens", required=True)
    parser.add_argument("--output", default="app2-006-hm2-submit-result.json")
    args = parser.parse_args()
    root = Path(args.screens)
    home = root / "01-home.png"
    premium = root / "02-premium.png"
    if not home.is_file() or not premium.is_file():
        raise RuntimeError("Required App Store screenshots missing")

    result: dict = {
        "task_id": "APP2-006",
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "app_id": APP_ID,
        "bundle_id": BUNDLE_ID,
        "target_version": TARGET_VERSION,
        "build": BUILD_VERSION,
        "release_performed": False,
    }
    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        app = one(api_get(token, f"/v1/apps/{APP_ID}")[1], "app")
        if (app.get("attributes") or {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("Target app mismatch")

        version = resolve_version(token)
        version_id = str(version["id"])
        result["version_id"] = version_id
        result["pre_version_state"] = state(version)

        localization = resolve_localization(token, version_id)
        localization_id = str(localization["id"])
        patch(token, f"/v1/appStoreVersionLocalizations/{localization_id}", "appStoreVersionLocalizations", localization_id,
              attributes={"description":DESCRIPTION,"keywords":KEYWORDS,"promotionalText":PROMO,"supportUrl":SUPPORT_URL})
        result.update(ensure_app_info(token))
        result["review_detail_id"] = ensure_review_detail(token, version_id)
        result["build_id"] = select_build(token, version_id)
        result["app_screenshots"] = upload_app_screenshots(token, localization_id, [home, premium])

        result["monthly_review_screenshot_id"] = require_review_screenshot(token, f"/v1/subscriptions/{MONTHLY_ID}/appStoreReviewScreenshot", "monthly review screenshot")
        result["lifetime_review_screenshot_id"] = require_review_screenshot(token, f"/v2/inAppPurchases/{LIFETIME_ID}/appStoreReviewScreenshot", "lifetime review screenshot")

        iap_version = ensure_product_version(token, list_path=f"/v2/inAppPurchases/{LIFETIME_ID}/versions?limit=50", create_path="/v1/inAppPurchaseVersions", typ="inAppPurchaseVersions", relationship_name="inAppPurchase", relationship_type="inAppPurchases", parent_id=LIFETIME_ID)
        sub_version = ensure_product_version(token, list_path=f"/v1/subscriptions/{MONTHLY_ID}/versions?limit=50", create_path="/v1/subscriptionVersions", typ="subscriptionVersions", relationship_name="subscription", relationship_type="subscriptions", parent_id=MONTHLY_ID)
        group_version = ensure_product_version(token, list_path=f"/v1/subscriptionGroups/{GROUP_ID}/versions?limit=50", create_path="/v1/subscriptionGroupVersions", typ="subscriptionGroupVersions", relationship_name="subscriptionGroup", relationship_type="subscriptionGroups", parent_id=GROUP_ID)
        result["iap_version"] = {"id": iap_version.get("id"), "state": state(iap_version)}
        result["subscription_version"] = {"id": sub_version.get("id"), "state": state(sub_version)}
        result["subscription_group_version"] = {"id": group_version.get("id"), "state": state(group_version)}

        submission = ensure_submission(token)
        submission_id = str(submission["id"])
        before = state(submission)
        result["review_submission_id"] = submission_id
        result["pre_submit_state"] = before
        if before in SUBMITTED_STATES:
            result.update({"submitted": True, "idempotent": True, "review_submission_state": before})
        else:
            ensure_item(token, submission_id, "appStoreVersion", "appStoreVersions", version_id)
            ensure_item(token, submission_id, "inAppPurchaseVersion", "inAppPurchaseVersions", str(iap_version["id"]))
            ensure_item(token, submission_id, "subscriptionVersion", "subscriptionVersions", str(sub_version["id"]))
            ensure_item(token, submission_id, "subscriptionGroupVersion", "subscriptionGroupVersions", str(group_version["id"]))
            patch(token, f"/v1/reviewSubmissions/{submission_id}", "reviewSubmissions", submission_id, attributes={"submitted": True})
            after = one(api_get(token, f"/v1/reviewSubmissions/{submission_id}")[1], "submission after")
            after_state = state(after)
            result.update({"submitted": after_state in SUBMITTED_STATES, "idempotent": False, "review_submission_state": after_state})
            if after_state not in SUBMITTED_STATES:
                raise RuntimeError(f"Unexpected submission state after submit: {after_state}")

        final_version = one(api_get(token, f"/v1/appStoreVersions/{version_id}")[1], "version after")
        result["app_store_version_state_after"] = state(final_version)
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"PASS: APP2-006 submitted; state={result['review_submission_state']}")
    except Exception as exc:
        result.update({"submitted": False, "error": str(exc)})
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
